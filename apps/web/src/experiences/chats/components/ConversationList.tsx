import { useEffect, useMemo, useRef, useState } from 'react';
import { Plus, Search } from 'lucide-react';
import { PravaInput } from '../../../ui-system';
import { messagesService, ConversationSummary } from '../../../services/messages-service';
import { timeAgo } from '../../../utils/date-utils';
import { webSocketService } from '../../../services/websocket-service';
import { chatSyncStore } from '../../../services/chat-sync-store';

interface ConversationListProps {
  activeId?: string;
  onSelect: (conversation: ConversationSummary) => void;
  onNewChat: () => void;
}

export function ConversationList({ activeId, onSelect, onNewChat }: ConversationListProps) {
  const [conversations, setConversations] = useState<ConversationSummary[]>([]);
  const [loading, setLoading] = useState(true);
  const [typingByConversation, setTypingByConversation] = useState<Record<string, boolean>>({});
  const [query, setQuery] = useState('');
  const typingTimers = useRef<Map<string, ReturnType<typeof setTimeout>>>(new Map());

  const syncInit = (rows: ConversationSummary[]) => {
    const payload = rows.map((row) => {
      const known = chatSyncStore.getLastDeliveredSeq(row.id) || row.lastMessageSeq || 0;
      return {
        conversationId: row.id,
        lastDeliveredSeq: known,
      };
    });

    if (payload.length > 0) {
      webSocketService.send('SYNC_INIT', { conversations: payload });
    }
  };

  useEffect(() => {
    loadConversations();
  }, []);

  useEffect(() => {
    const unsubscribePush = webSocketService.subscribe('MESSAGE_PUSH', (payload: any) => {
      const conversationId = String(payload?.conversationId || '');
      if (!conversationId) return;

      setConversations((prev) => {
        const index = prev.findIndex((item) => item.id === conversationId);
        if (index === -1) return prev;

        const next = [...prev];
        const current = next[index];
        const body = String(payload?.body || '');
        const isEncrypted = body.startsWith('e2ee.v1:') || body.startsWith('e2ee.g1:');
        const nextPreview = payload?.deletedForAllAt
          ? 'Message deleted'
          : payload?.contentType === 'media'
            ? 'Media message'
            : isEncrypted
              ? 'Encrypted message'
              : (body || current.lastMessageBody || '');

        next[index] = {
          ...current,
          lastMessageId: payload?.messageId ?? current.lastMessageId,
          lastMessageSeq: typeof payload?.seq === 'number' ? payload.seq : current.lastMessageSeq,
          lastMessageSenderUserId: payload?.senderUserId ?? current.lastMessageSenderUserId,
          lastMessageBody: nextPreview,
          lastMessageContentType: payload?.contentType ?? current.lastMessageContentType,
          lastMessageDeletedForAllAt: payload?.deletedForAllAt ?? null,
          lastMessageCreatedAt: payload?.createdAt ?? new Date().toISOString(),
          updatedAt: payload?.createdAt ?? new Date().toISOString(),
          unreadCount: activeId === conversationId ? 0 : (current.unreadCount || 0) + 1,
        };
        const seq = typeof payload?.seq === 'number' ? payload.seq : 0;
        if (seq > 0) {
          chatSyncStore.updateLastDeliveredSeq(conversationId, seq);
        }

        const moved = next[index];
        next.splice(index, 1);
        next.unshift(moved);
        return next;
      });
    });

    const unsubscribeTyping = webSocketService.subscribe('TYPING', (payload: any) => {
      const conversationId = String(payload?.conversationId || '');
      if (!conversationId) return;
      const userId = String(payload?.userId || '');
      if (userId === String(localStorage.getItem('prava_user_id') || '')) {
        return;
      }

      const active = payload?.isTyping === true;
      setTypingByConversation((prev) => ({
        ...prev,
        [conversationId]: active,
      }));

      const existingTimer = typingTimers.current.get(conversationId);
      if (existingTimer) {
        clearTimeout(existingTimer);
      }
      if (active) {
        const timer = setTimeout(() => {
          setTypingByConversation((prev) => ({
            ...prev,
            [conversationId]: false,
          }));
          typingTimers.current.delete(conversationId);
        }, 4000);
        typingTimers.current.set(conversationId, timer);
      }
    });

    const unsubscribeConnection = webSocketService.subscribe('connection', (payload: any) => {
      if (payload?.status === 'connected') {
        syncInit(conversations);
      }
    });

    return () => {
      unsubscribePush?.();
      unsubscribeTyping?.();
      unsubscribeConnection?.();
      for (const timer of typingTimers.current.values()) {
        clearTimeout(timer);
      }
      typingTimers.current.clear();
    };
  }, [activeId, conversations]);

  const loadConversations = async () => {
    try {
      setLoading(true);
      const data = await messagesService.listConversations();
      setConversations(data);
      for (const row of data) {
        if (row.lastMessageSeq && row.lastMessageSeq > 0) {
          chatSyncStore.updateLastDeliveredSeq(row.id, row.lastMessageSeq);
        }
      }
      syncInit(data);
    } catch (error) {
      console.error('Failed to load conversations:', error);
    } finally {
      setLoading(false);
    }
  };

  const visibleConversations = useMemo(() => {
    const trimmed = query.trim().toLowerCase();
    if (!trimmed) {
      return conversations;
    }
    return conversations.filter((chat) => {
      const title = String(chat.title || '').toLowerCase();
      const preview = String(chat.lastMessageBody || '').toLowerCase();
      return title.includes(trimmed) || preview.includes(trimmed);
    });
  }, [conversations, query]);

  return (
    <div className="h-full flex flex-col">
      <div className="mb-4 space-y-4">
        <div className="flex items-center justify-between">
          <h1 className="text-2xl font-bold text-prava-light-text-primary dark:text-prava-dark-text-primary">
            Chats
          </h1>
          <button
            onClick={onNewChat}
            className="p-2 rounded-full bg-prava-accent/10 text-prava-accent hover:bg-prava-accent/20 transition-colors"
          >
            <Plus className="w-5 h-5" />
          </button>
        </div>
        <PravaInput
          placeholder="Search..."
          prefixIcon={<Search className="w-4 h-4" />}
          value={query}
          onChange={(event) => setQuery(event.target.value)}
        />
      </div>

      <div className="flex-1 overflow-y-auto -mx-2 px-2 space-y-1">
        {loading ? (
          <div className="flex items-center justify-center py-10 text-sm text-prava-light-text-tertiary dark:text-prava-dark-text-tertiary">
            Loading chats...
          </div>
        ) : (
          visibleConversations.map((chat) => {
          const displayName = chat.title?.trim()
            ? chat.title
            : chat.type === 'group'
              ? 'Group chat'
              : 'Conversation';
          const timeLabel = chat.lastMessageCreatedAt ?? chat.updatedAt;
          const preview = chat.lastMessageDeletedForAllAt
            ? 'Message deleted'
            : chat.lastMessageContentType === 'media'
              ? 'Media message'
              : typingByConversation[chat.id]
                ? 'typing...'
                : chat.lastMessageBody?.trim()
                ? chat.lastMessageBody
                : 'No messages yet';

          return (
            <button
              key={chat.id}
              onClick={() => {
                setConversations((prev) => prev.map((item) => (
                  item.id === chat.id
                    ? { ...item, unreadCount: 0 }
                    : item
                )));
                onSelect({ ...chat, unreadCount: 0 });
              }}
              className={`w-full flex items-center gap-3 p-3 rounded-[16px] transition-colors ${activeId === chat.id
                  ? 'bg-prava-accent text-white shadow-prava-glow'
                  : 'hover:bg-white/50 dark:hover:bg-white/5'
                }`}
            >
              <div className={`w-12 h-12 rounded-full flex items-center justify-center shrink-0 ${activeId === chat.id ? 'bg-white/20' : 'bg-prava-accent/15'
                }`}>
                <span className={`font-semibold ${activeId === chat.id ? 'text-white' : 'text-prava-accent'}`}>
                  {displayName.charAt(0)}
                </span>
              </div>

              <div className="flex-1 min-w-0 text-left">
                <div className="flex items-center justify-between mb-0.5">
                  <span className={`font-semibold truncate ${activeId === chat.id
                      ? 'text-white'
                      : 'text-prava-light-text-primary dark:text-prava-dark-text-primary'
                    }`}>
                    {displayName}
                  </span>
                  {timeLabel && (
                    <span className={`text-[10px] ${activeId === chat.id
                        ? 'text-white/70'
                        : 'text-prava-light-text-tertiary dark:text-prava-dark-text-tertiary'
                      }`}>
                      {timeAgo(timeLabel)}
                    </span>
                  )}
                </div>
                <div className="flex items-center justify-between">
                  <p className={`text-xs truncate ${activeId === chat.id
                      ? 'text-white/80'
                      : 'text-prava-light-text-secondary dark:text-prava-dark-text-secondary'
                    }`}>
                    {preview}
                  </p>
                  {chat.unreadCount > 0 && (
                    <span className={`ml-2 px-1.5 py-0.5 rounded-full text-[10px] font-bold ${activeId === chat.id
                        ? 'bg-white text-prava-accent'
                        : 'bg-prava-accent text-white'
                      }`}>
                      {chat.unreadCount}
                    </span>
                  )}
                </div>
              </div>
            </button>
          );
        })
        )}
      </div>
    </div>
  );
}
