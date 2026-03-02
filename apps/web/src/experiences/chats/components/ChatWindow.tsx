import { useEffect, useRef, useState, type FormEvent } from 'react';
import { Send, Image, Phone, Video, MoreVertical, ArrowLeft } from 'lucide-react';
import { useAuth } from '../../../context/auth-context';
import { messagesService, normalizeMessage, Message, ConversationSummary } from '../../../services/messages-service';
import { webSocketService } from '../../../services/websocket-service';
import { timeAgo } from '../../../utils/date-utils';
import { smartToast } from '../../../ui-system/components/SmartToast';
import { getOrCreateDeviceId } from '../../../adapters/device-id';

interface ChatWindowProps {
  conversation: ConversationSummary;
  onBack?: () => void;
}

export function ChatWindow({ conversation, onBack }: ChatWindowProps) {
  const { user } = useAuth();
  const [messages, setMessages] = useState<Message[]>([]);
  const [inputText, setInputText] = useState('');
  const [sending, setSending] = useState(false);
  const [peerTyping, setPeerTyping] = useState(false);
  const messagesEndRef = useRef<HTMLDivElement>(null);
  const lastReadSeq = useRef<number | null>(null);
  const typingSent = useRef(false);
  const typingTimeout = useRef<ReturnType<typeof setTimeout> | null>(null);
  const peerTypingTimeout = useRef<ReturnType<typeof setTimeout> | null>(null);

  const sortMessages = (input: Message[]) => {
    return [...input].sort((a, b) => {
      const aSeq = typeof a.sequence === 'number' ? a.sequence : Number.MAX_SAFE_INTEGER;
      const bSeq = typeof b.sequence === 'number' ? b.sequence : Number.MAX_SAFE_INTEGER;
      if (aSeq !== bSeq) {
        return aSeq - bSeq;
      }
      return new Date(a.createdAt).getTime() - new Date(b.createdAt).getTime();
    });
  };

  const upsertMessage = (incoming: Message) => {
    setMessages((prev) => {
      const index = prev.findIndex((item) => item.id === incoming.id);
      if (index === -1) {
        return sortMessages([...prev, incoming]);
      }

      const next = [...prev];
      next[index] = { ...next[index], ...incoming };
      return sortMessages(next);
    });
  };

  const isEncryptedPayload = (body: string) =>
    body.startsWith('e2ee.v1:') || body.startsWith('e2ee.g1:');

  useEffect(() => {
    lastReadSeq.current = null;
    setPeerTyping(false);
    loadMessages();

    webSocketService.send('CONVERSATION_SUBSCRIBE', { conversationId: conversation.id });

    const unsubscribeMessagePush = webSocketService.subscribe('MESSAGE_PUSH', (payload: any) => {
      if (payload.conversationId === conversation.id) {
        upsertMessage(normalizeMessage(payload));
        scrollToBottom();
      }
    });

    const unsubscribeMessageAck = webSocketService.subscribe('MESSAGE_ACK', (payload: any) => {
      if (payload.conversationId !== conversation.id || !payload.tempId || !payload.messageId) return;

      setMessages((prev) => {
        const index = prev.findIndex((msg) => msg.id === payload.tempId);
        if (index === -1) return prev;
        const next = [...prev];
        next[index] = {
          ...next[index],
          id: payload.messageId,
          sequence: payload.seq ?? next[index].sequence,
          createdAt: payload.createdAt ?? next[index].createdAt,
        };
        return sortMessages(next);
      });
    });

    const unsubscribeEdit = webSocketService.subscribe('MESSAGE_EDIT', (payload: any) => {
      if (payload.conversationId !== conversation.id || !payload.messageId) return;
      setMessages((prev) => prev.map((message) => (
        message.id === payload.messageId
          ? {
              ...message,
              body: String(payload.body ?? ''),
              editVersion: Number(payload.editVersion ?? message.editVersion ?? 0),
            }
          : message
      )));
    });

    const unsubscribeDelete = webSocketService.subscribe('MESSAGE_DELETE', (payload: any) => {
      if (payload.conversationId !== conversation.id || !payload.messageId) return;
      setMessages((prev) => prev.map((message) => (
        message.id === payload.messageId
          ? {
              ...message,
              body: '',
              contentType: 'system',
              deletedForAllAt: payload.deletedForAllAt ?? new Date().toISOString(),
            }
          : message
      )));
    });

    const unsubscribeReaction = webSocketService.subscribe('REACTION_UPDATE', (payload: any) => {
      if (payload.conversationId !== conversation.id || !payload.messageId || !payload.userId) return;

      setMessages((prev) => prev.map((message) => {
        if (message.id !== payload.messageId) {
          return message;
        }

        const reactions = Array.isArray(message.reactions) ? [...message.reactions] : [];
        const index = reactions.findIndex((reaction) => reaction.userId === payload.userId);
        const emoji = payload.emoji ? String(payload.emoji) : null;
        if (!emoji) {
          if (index !== -1) {
            reactions.splice(index, 1);
          }
        } else if (index === -1) {
          reactions.push({
            userId: payload.userId,
            emoji,
            updatedAt: payload.updatedAt ?? new Date().toISOString(),
          });
        } else {
          reactions[index] = {
            ...reactions[index],
            emoji,
            updatedAt: payload.updatedAt ?? new Date().toISOString(),
          };
        }

        return {
          ...message,
          reactions,
        };
      }));
    });

    const unsubscribeTyping = webSocketService.subscribe('TYPING', (payload: any) => {
      if (payload.conversationId !== conversation.id) return;
      if (!payload.userId || payload.userId === user?.id) return;

      const active = payload.isTyping === true;
      setPeerTyping(active);
      if (peerTypingTimeout.current) {
        clearTimeout(peerTypingTimeout.current);
      }
      if (active) {
        peerTypingTimeout.current = setTimeout(() => {
          setPeerTyping(false);
        }, 3500);
      }
    });

    return () => {
      unsubscribeMessagePush?.();
      unsubscribeMessageAck?.();
      unsubscribeEdit?.();
      unsubscribeDelete?.();
      unsubscribeReaction?.();
      unsubscribeTyping?.();
      if (typingTimeout.current) {
        clearTimeout(typingTimeout.current);
      }
      if (peerTypingTimeout.current) {
        clearTimeout(peerTypingTimeout.current);
      }
      if (typingSent.current) {
        typingSent.current = false;
        webSocketService.send('TYPING_STOP', { conversationId: conversation.id });
      }
    };
  }, [conversation.id, user?.id]);

  const loadMessages = async () => {
    try {
      const data = await messagesService.listMessages(conversation.id);
      setMessages(sortMessages(data));
      scrollToBottom();
    } catch (error) {
      console.error('Failed to load messages:', error);
    }
  };

  const scrollToBottom = () => {
    setTimeout(() => {
      messagesEndRef.current?.scrollIntoView({ behavior: 'smooth' });
    }, 100);
  };

  useEffect(() => {
    const lastSeq = messages[messages.length - 1]?.sequence;
    if (typeof lastSeq !== 'number' || lastSeq === lastReadSeq.current) return;
    lastReadSeq.current = lastSeq;
    if (webSocketService.isConnected()) {
      webSocketService.send('READ_RECEIPT', {
        conversationId: conversation.id,
        lastReadSeq: lastSeq,
      });
      webSocketService.send('DELIVERY_RECEIPT', {
        conversationId: conversation.id,
        lastDeliveredSeq: lastSeq,
      });
      return;
    }
    messagesService.markRead(conversation.id, lastSeq).catch(() => {});
    messagesService.markDelivered(conversation.id, lastSeq).catch(() => {});
  }, [conversation.id, messages]);

  const handleComposerChange = (nextValue: string) => {
    setInputText(nextValue);
    const hasText = nextValue.trim().length > 0;

    if (webSocketService.isConnected()) {
      if (hasText && !typingSent.current) {
        typingSent.current = true;
        webSocketService.send('TYPING_START', { conversationId: conversation.id });
      }

      if (typingTimeout.current) {
        clearTimeout(typingTimeout.current);
      }
      if (hasText) {
        typingTimeout.current = setTimeout(() => {
          typingSent.current = false;
          webSocketService.send('TYPING_STOP', { conversationId: conversation.id });
        }, 2000);
      } else if (typingSent.current) {
        typingSent.current = false;
        webSocketService.send('TYPING_STOP', { conversationId: conversation.id });
      }
    }
  };

  const handleSend = async (e?: FormEvent) => {
    e?.preventDefault();
    if (!inputText.trim() || sending) return;

    const text = inputText.trim();
    const tempId = `web_${Date.now()}_${Math.random().toString(36).slice(2, 10)}`;
    setInputText('');

    if (typingTimeout.current) {
      clearTimeout(typingTimeout.current);
    }
    if (typingSent.current) {
      typingSent.current = false;
      webSocketService.send('TYPING_STOP', { conversationId: conversation.id });
    }

    upsertMessage({
      id: tempId,
      conversationId: conversation.id,
      senderId: user?.id || '',
      body: text,
      contentType: 'text',
      createdAt: new Date().toISOString(),
      sequence: undefined,
      reactions: [],
      editVersion: 0,
      deletedForAllAt: null,
    });
    scrollToBottom();

    try {
      if (webSocketService.isConnected()) {
        webSocketService.send('MESSAGE_SEND', {
          conversationId: conversation.id,
          body: text,
          contentType: 'text',
          tempId,
          deviceId: getOrCreateDeviceId(),
          clientTimestamp: new Date().toISOString(),
        });
        return;
      }

      setSending(true);
      const msg = await messagesService.sendMessage(conversation.id, text, 'text', { tempId });
      upsertMessage(msg);
    } catch (error) {
      smartToast.error('Failed to send message');
      setInputText(text);
      setMessages((prev) => prev.filter((msg) => msg.id !== tempId));
    } finally {
      setSending(false);
    }
  };

  const displayName = conversation.title?.trim()
    ? conversation.title
    : conversation.type === 'group'
      ? 'Group chat'
      : 'Conversation';

  return (
    <div className="flex flex-col h-full bg-prava-light-surface dark:bg-prava-dark-surface rounded-[24px] overflow-hidden border border-prava-light-border dark:border-prava-dark-border shadow-2xl relative">
      {/* Header */}
      <div className="flex items-center justify-between p-4 border-b border-prava-light-border dark:border-prava-dark-border bg-white/50 dark:bg-black/20 backdrop-blur-md z-10">
        <div className="flex items-center gap-3">
          {onBack && (
            <button onClick={onBack} className="md:hidden p-2 -ml-2 rounded-full hover:bg-black/5 dark:hover:bg-white/10">
              <ArrowLeft className="w-5 h-5 text-prava-light-text-secondary dark:text-prava-dark-text-secondary" />
            </button>
          )}
          <div className="w-10 h-10 rounded-full bg-prava-accent/15 flex items-center justify-center shrink-0">
            <span className="text-prava-accent font-semibold">{displayName.charAt(0)}</span>
          </div>
          <div>
            <h3 className="font-semibold text-prava-light-text-primary dark:text-prava-dark-text-primary">
              {displayName}
            </h3>
            <p className="text-xs text-prava-light-text-tertiary dark:text-prava-dark-text-tertiary">
              {peerTyping ? 'Typing...' : 'Online'}
            </p>
          </div>
        </div>

        <div className="flex items-center gap-2 text-prava-accent">
          <button className="p-2 rounded-full hover:bg-prava-accent/10 transition-colors">
            <Phone className="w-5 h-5" />
          </button>
          <button className="p-2 rounded-full hover:bg-prava-accent/10 transition-colors">
            <Video className="w-5 h-5" />
          </button>
          <button className="p-2 rounded-full hover:bg-prava-accent/10 transition-colors text-prava-light-text-secondary dark:text-prava-dark-text-secondary">
            <MoreVertical className="w-5 h-5" />
          </button>
        </div>
      </div>

      {/* Messages */}
      <div className="flex-1 overflow-y-auto p-4 space-y-4 bg-prava-light-bg dark:bg-prava-dark-bg">
        {messages.map((msg, i) => {
          const isMe = msg.senderId === user?.id;
          const isSequential = i > 0 && messages[i - 1].senderId === msg.senderId;

          return (
            <div
              key={msg.id}
              className={`flex flex-col ${isMe ? 'items-end' : 'items-start'} ${isSequential ? 'mt-1' : 'mt-4'}`}
            >
              <div
                className={`max-w-[70%] px-4 py-2.5 rounded-[18px] text-body-sm ${isMe
                    ? 'bg-prava-accent text-white rounded-tr-sm'
                    : 'bg-white dark:bg-white/[0.08] text-prava-light-text-primary dark:text-prava-dark-text-primary border border-prava-light-border dark:border-prava-dark-border rounded-tl-sm'
                  }`}
              >
                {msg.deletedForAllAt
                  ? 'Message deleted'
                  : isEncryptedPayload(msg.body)
                    ? 'Encrypted message'
                    : msg.body}
              </div>
              {Array.isArray(msg.reactions) && msg.reactions.length > 0 && (
                <div className="mt-1 text-[10px] px-2 py-0.5 rounded-full bg-black/5 dark:bg-white/10">
                  {Object.entries(
                    msg.reactions.reduce<Record<string, number>>((acc, reaction) => {
                      const emoji = reaction.emoji || '';
                      if (!emoji) return acc;
                      acc[emoji] = (acc[emoji] || 0) + 1;
                      return acc;
                    }, {})
                  )
                    .map(([emoji, count]) => `${emoji} ${count}`)
                    .join('  ')}
                </div>
              )}
              <span className="text-[10px] text-prava-light-text-tertiary dark:text-prava-dark-text-tertiary mt-1 px-1">
                {timeAgo(msg.createdAt)}
              </span>
            </div>
          );
        })}
        <div ref={messagesEndRef} />
      </div>

      {/* Input */}
      <div className="p-4 bg-white dark:bg-prava-dark-surface border-t border-prava-light-border dark:border-prava-dark-border">
        <form onSubmit={handleSend} className="flex items-center gap-2">
          <button type="button" className="p-2 text-prava-light-text-tertiary dark:text-prava-dark-text-tertiary hover:bg-black/5 dark:hover:bg-white/10 rounded-full transition-colors">
            <Image className="w-5 h-5" />
          </button>
          <input
            className="flex-1 px-4 py-2.5 rounded-full bg-prava-light-bg dark:bg-prava-dark-bg border border-prava-light-border dark:border-prava-dark-border focus:outline-none focus:border-prava-accent transition-colors text-body-sm text-prava-light-text-primary dark:text-prava-dark-text-primary"
            placeholder="Type a message..."
            value={inputText}
            onChange={(e) => handleComposerChange(e.target.value)}
          />
          <button
            type="submit"
            disabled={!inputText.trim() || sending}
            className="p-2.5 circle bg-prava-accent text-white rounded-full hover:bg-prava-accent-muted disabled:opacity-50 disabled:cursor-not-allowed transition-all shadow-prava-glow"
          >
            <Send className="w-5 h-5 ml-0.5" />
          </button>
        </form>
      </div>
    </div>
  );
}
