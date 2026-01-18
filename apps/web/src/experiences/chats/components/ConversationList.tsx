import { useEffect, useState } from 'react';
import { Plus, Search } from 'lucide-react';
import { PravaInput, GlassCard } from '../../../ui-system';
import { messagesService, ConversationSummary } from '../../../services/messages-service';
import { timeAgo } from '../../../utils/date-utils';

interface ConversationListProps {
  activeId?: string;
  onSelect: (conversation: ConversationSummary) => void;
  onNewChat: () => void;
}

export function ConversationList({ activeId, onSelect, onNewChat }: ConversationListProps) {
  const [conversations, setConversations] = useState<ConversationSummary[]>([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    loadConversations();
  }, []);

  const loadConversations = async () => {
    try {
      setLoading(true);
      const data = await messagesService.listConversations();
      setConversations(data);
    } catch (error) {
      console.error('Failed to load conversations:', error);
    } finally {
      setLoading(false);
    }
  };

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
        />
      </div>

      <div className="flex-1 overflow-y-auto -mx-2 px-2 space-y-1">
        {loading ? (
          <div className="flex items-center justify-center py-10 text-sm text-prava-light-text-tertiary dark:text-prava-dark-text-tertiary">
            Loading chats...
          </div>
        ) : (
          conversations.map((chat) => {
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
              : chat.lastMessageBody?.trim()
                ? chat.lastMessageBody
                : 'No messages yet';

          return (
            <button
              key={chat.id}
              onClick={() => onSelect(chat)}
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
