import { useEffect, useRef, useState, type FormEvent } from 'react';
import { Send, Image, Phone, Video, MoreVertical, ArrowLeft } from 'lucide-react';
import { useAuth } from '../../../context/auth-context';
import { messagesService, normalizeMessage, Message, ConversationSummary } from '../../../services/messages-service';
import { webSocketService } from '../../../services/websocket-service';
import { timeAgo } from '../../../utils/date-utils';
import { smartToast } from '../../../ui-system/components/SmartToast';

interface ChatWindowProps {
  conversation: ConversationSummary;
  onBack?: () => void;
}

export function ChatWindow({ conversation, onBack }: ChatWindowProps) {
  const { user } = useAuth();
  const [messages, setMessages] = useState<Message[]>([]);
  const [inputText, setInputText] = useState('');
  const [sending, setSending] = useState(false);
  const messagesEndRef = useRef<HTMLDivElement>(null);
  const lastReadSeq = useRef<number | null>(null);

  useEffect(() => {
    lastReadSeq.current = null;
    loadMessages();

    // Subscribe to new messages
    const unsubscribe = webSocketService.subscribe('MESSAGE_PUSH', (payload: any) => {
      if (payload.conversationId === conversation.id) {
        setMessages(prev => [...prev, normalizeMessage(payload)]);
        scrollToBottom();
      }
    });

    return () => {
      unsubscribe?.();
    };
  }, [conversation.id]);

  const loadMessages = async () => {
    try {
      const data = await messagesService.listMessages(conversation.id);
      setMessages(data);
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
    messagesService.markRead(conversation.id, lastSeq).catch(() => {});
  }, [conversation.id, messages]);

  const handleSend = async (e?: FormEvent) => {
    e?.preventDefault();
    if (!inputText.trim() || sending) return;

    try {
      setSending(true);
      const text = inputText;
      setInputText(''); // Optimistic clear

      // Optimistic add (optional, but good for UX)
      // We wait for server response here for simplicity/correctness
      const msg = await messagesService.sendMessage(conversation.id, text);
      setMessages(prev => [...prev, msg]);
      scrollToBottom();
    } catch (error) {
      smartToast.error('Failed to send message');
      setInputText(inputText); // Restore on error
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
              Online
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
                {msg.body}
              </div>
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
            onChange={(e) => setInputText(e.target.value)}
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
