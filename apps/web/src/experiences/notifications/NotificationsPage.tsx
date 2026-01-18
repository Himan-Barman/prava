import { useEffect, useState } from 'react';
import { motion } from 'framer-motion';
import { Bell, Heart, MessageCircle, UserPlus, Settings, Check } from 'lucide-react';
import { GlassCard } from '../../ui-system';
import { Link } from 'react-router-dom';
import { notificationsService, NotificationItem } from '../../services/notifications-service';
import { timeAgo } from '../../utils/date-utils';
import { smartToast } from '../../ui-system/components/SmartToast';

const iconMap: Record<string, typeof Bell> = {
  like: Heart,
  comment: MessageCircle,
  follow: UserPlus,
  message: Bell,
};

const colorMap: Record<string, string> = {
  like: 'text-prava-error bg-prava-error/10',
  comment: 'text-prava-accent bg-prava-accent/10',
  follow: 'text-prava-success bg-prava-success/10',
  message: 'text-prava-warning bg-prava-warning/10',
};

export default function NotificationsPage() {
  const [items, setItems] = useState<NotificationItem[]>([]);
  const [loading, setLoading] = useState(true);
  const [nextCursor, setNextCursor] = useState<string | null>(null);
  const [unreadCount, setUnreadCount] = useState(0);

  useEffect(() => {
    loadNotifications();
  }, []);

  const loadNotifications = async (cursor?: string) => {
    try {
      setLoading(true);
      const data = await notificationsService.fetchNotifications(20, cursor);
      setItems((prev) => (cursor ? [...prev, ...data.items] : data.items));
      setNextCursor(data.nextCursor ?? null);
      setUnreadCount(data.unreadCount ?? 0);
    } catch (error) {
      smartToast.error('Failed to load notifications');
    } finally {
      setLoading(false);
    }
  };

  const handleMarkAllRead = async () => {
    try {
      await notificationsService.markAllRead();
      setItems((prev) => prev.map((item) => ({ ...item, readAt: item.readAt ?? new Date().toISOString() })));
      setUnreadCount(0);
    } catch {
      smartToast.error('Could not mark all as read');
    }
  };

  const handleMarkRead = async (notification: NotificationItem) => {
    if (notification.readAt) return;
    try {
      await notificationsService.markRead(notification.id);
      setItems((prev) =>
        prev.map((item) =>
          item.id === notification.id ? { ...item, readAt: new Date().toISOString() } : item
        )
      );
      setUnreadCount((count) => Math.max(count - 1, 0));
    } catch {
      smartToast.error('Could not update notification');
    }
  };

  return (
    <div className="max-w-2xl mx-auto">
      {/* Page Header */}
      <motion.div
        initial={{ opacity: 0, y: 8 }}
        animate={{ opacity: 1, y: 0 }}
        transition={{ duration: 0.4 }}
        className="mb-6"
      >
        <div className="flex items-center justify-between">
          <div>
            <h1 className="text-h1 text-prava-light-text-primary dark:text-prava-dark-text-primary">
              Notifications
            </h1>
            <p className="mt-1 text-body text-prava-light-text-secondary dark:text-prava-dark-text-secondary">
              Stay updated with your activity
            </p>
          </div>
          <div className="flex items-center gap-3">
            {unreadCount > 0 && (
              <span className="px-2 py-1 rounded-full bg-prava-accent text-white text-[10px] font-semibold">
                {unreadCount} unread
              </span>
            )}
            <Link
              to="/settings"
              className="p-3 rounded-[14px] bg-prava-light-surface dark:bg-prava-dark-surface border border-prava-light-border dark:border-prava-dark-border hover:bg-prava-light-border/50 dark:hover:bg-prava-dark-border/50 transition-colors"
            >
              <Settings className="w-5 h-5 text-prava-light-text-secondary dark:text-prava-dark-text-secondary" />
            </Link>
          </div>
        </div>
      </motion.div>

      {/* Mark All Read */}
      <motion.div
        initial={{ opacity: 0, y: 8 }}
        animate={{ opacity: 1, y: 0 }}
        transition={{ duration: 0.4, delay: 0.1 }}
        className="flex justify-end mb-4"
      >
        <button
          onClick={handleMarkAllRead}
          className="flex items-center gap-2 px-4 py-2 rounded-[12px] text-body-sm font-medium text-prava-accent hover:bg-prava-accent/10 transition-colors"
        >
          <Check className="w-4 h-4" />
          Mark all as read
        </button>
      </motion.div>

      {/* Notifications List */}
      <div className="space-y-2">
        {loading ? (
          <GlassCard className="text-center py-10">
            <div className="w-8 h-8 border-2 border-prava-accent border-t-transparent rounded-full animate-spin mx-auto mb-3" />
            <p className="text-body text-prava-light-text-secondary dark:text-prava-dark-text-secondary">
              Loading notifications...
            </p>
          </GlassCard>
        ) : items.length === 0 ? (
          <GlassCard className="text-center py-10">
            <Bell className="w-10 h-10 mx-auto mb-3 text-prava-light-text-tertiary dark:text-prava-dark-text-tertiary" />
            <p className="text-body text-prava-light-text-secondary dark:text-prava-dark-text-secondary">
              You're all caught up.
            </p>
          </GlassCard>
        ) : (
          items.map((notification, i) => {
            const Icon = iconMap[notification.type] ?? Bell;
            const colorClass = colorMap[notification.type] ?? 'text-prava-accent bg-prava-accent/10';
            const isUnread = !notification.readAt;

            return (
              <motion.div
                key={notification.id}
                initial={{ opacity: 0, y: 8 }}
                animate={{ opacity: 1, y: 0 }}
                transition={{ duration: 0.4, delay: 0.1 + i * 0.03 }}
                onClick={() => handleMarkRead(notification)}
                className={`flex items-center gap-3 p-4 rounded-[16px] border transition-colors cursor-pointer ${isUnread
                    ? 'bg-white/80 dark:bg-white/[0.04] border-prava-light-border/50 dark:border-prava-dark-border/50'
                    : 'bg-white/50 dark:bg-white/[0.02] border-prava-light-border/30 dark:border-prava-dark-border/30'
                  } hover:bg-white dark:hover:bg-white/[0.08]`}
              >
                <div className={`p-2.5 rounded-full ${colorClass}`}>
                  <Icon className="w-5 h-5" />
                </div>

                <div className="flex-1 min-w-0">
                  <p className="text-body text-prava-light-text-primary dark:text-prava-dark-text-primary">
                    <span className="font-semibold">{notification.title}</span>{' '}
                    <span className="text-prava-light-text-secondary dark:text-prava-dark-text-secondary">
                      {notification.body}
                    </span>
                  </p>
                  <p className="text-caption text-prava-light-text-tertiary dark:text-prava-dark-text-tertiary">
                    {timeAgo(notification.createdAt)}
                  </p>
                </div>

                {isUnread && (
                  <div className="w-2 h-2 rounded-full bg-prava-accent" />
                )}
              </motion.div>
            );
          })
        )}
      </div>

      {nextCursor && (
        <div className="mt-4 flex justify-center">
          <button
            onClick={() => loadNotifications(nextCursor)}
            className="px-4 py-2 text-body-sm font-semibold text-prava-accent hover:bg-prava-accent/10 rounded-[12px] transition-colors"
          >
            Load more
          </button>
        </div>
      )}
    </div>
  );
}
