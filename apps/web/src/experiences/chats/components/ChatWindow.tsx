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
    <div className="chat-window">
      {/* Header */}
      <div className="chat-window__header">
        <div className="chat-window__header-left">
          {onBack && (
            <button onClick={onBack} className="chat-window__back" aria-label="Back">
              <ArrowLeft size={20} />
            </button>
          )}
          <div className="chat-window__avatar">
            <span>{displayName.charAt(0)}</span>
          </div>
          <div className="chat-window__header-info">
            <h3>{displayName}</h3>
            <p>{peerTyping ? 'Typing...' : 'Online'}</p>
          </div>
        </div>

        <div className="chat-window__header-actions">
          <button aria-label="Audio call"><Phone size={20} /></button>
          <button aria-label="Video call"><Video size={20} /></button>
          <button aria-label="More options"><MoreVertical size={20} /></button>
        </div>
      </div>

      {/* Messages */}
      <div className="chat-window__messages">
        {messages.map((msg, i) => {
          const isMe = msg.senderId === user?.id;
          const isSequential = i > 0 && messages[i - 1].senderId === msg.senderId;

          return (
            <div
              key={msg.id}
              className={`chat-msg ${isMe ? 'chat-msg--own' : 'chat-msg--peer'} ${isSequential ? 'chat-msg--sequential' : ''}`}
            >
              <div className={`chat-msg__bubble ${isMe ? 'chat-msg__bubble--own' : 'chat-msg__bubble--peer'}`}>
                {msg.deletedForAllAt
                  ? 'Message deleted'
                  : isEncryptedPayload(msg.body)
                    ? 'Encrypted message'
                    : msg.body}
              </div>
              {Array.isArray(msg.reactions) && msg.reactions.length > 0 && (
                <div className="chat-msg__reactions">
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
              <span className="chat-msg__time">{timeAgo(msg.createdAt)}</span>
            </div>
          );
        })}
        <div ref={messagesEndRef} />
      </div>

      {/* Input */}
      <div className="chat-window__composer">
        <form onSubmit={handleSend} className="chat-window__composer-form">
          <button type="button" className="chat-window__composer-action" aria-label="Attach image">
            <Image size={20} />
          </button>
          <input
            className="chat-window__input"
            placeholder="Type a message..."
            value={inputText}
            onChange={(e) => handleComposerChange(e.target.value)}
          />
          <button
            type="submit"
            disabled={!inputText.trim() || sending}
            className="chat-window__send"
            aria-label="Send"
          >
            <Send size={20} />
          </button>
        </form>
      </div>
    </div>
  );
}
