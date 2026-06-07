import { useEffect, useState } from 'react';
import { motion } from 'framer-motion';
import { Bell, Heart, MessageCircle, UserPlus, Check } from 'lucide-react';
import { notificationsService, NotificationItem } from '../../services/notifications-service';
import { timeAgo } from '../../utils/date-utils';
import { smartToast } from '../../ui-system/components/SmartToast';

const iconMap: Record<string, typeof Bell> = {
  like: Heart,
  comment: MessageCircle,
  follow: UserPlus,
  message: Bell,
};

const colorMap: Record<string, { text: string; bg: string }> = {
  like: { text: '#E5533D', bg: 'rgba(229,83,61,0.08)' },
  comment: { text: '#5B8CFF', bg: 'rgba(91,140,255,0.08)' },
  follow: { text: '#3CCB7F', bg: 'rgba(60,203,127,0.08)' },
  message: { text: '#F4C430', bg: 'rgba(244,196,48,0.08)' },
};

export default function NotificationsPage() {
  const [items, setItems] = useState<NotificationItem[]>([]);
  const [loading, setLoading] = useState(true);
  const [nextCursor, setNextCursor] = useState<string | null>(null);
  const [unreadCount, setUnreadCount] = useState(0);

  useEffect(() => { loadNotifications(); }, []);

  const loadNotifications = async (cursor?: string) => {
    try {
      setLoading(true);
      const data = await notificationsService.fetchNotifications(20, cursor);
      setItems((prev) => (cursor ? [...prev, ...data.items] : data.items));
      setNextCursor(data.nextCursor ?? null);
      setUnreadCount(data.unreadCount ?? 0);
    } catch {
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
    <div className="max-w-2xl mx-auto pb-8">
      {/* Header */}
      <motion.div
        initial={{ opacity: 0, y: 6 }}
        animate={{ opacity: 1, y: 0 }}
        transition={{ duration: 0.35 }}
        className="app-page-header"
      >
        <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
          <div>
            <h1 className="app-page-title">Notifications</h1>
            <p className="app-page-subtitle">Stay updated with your activity</p>
          </div>
          <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
            {unreadCount > 0 && (
              <span style={{
                padding: '3px 10px', borderRadius: 100,
                background: '#5B8CFF', color: '#fff',
                fontSize: 11, fontWeight: 700,
              }}>
                {unreadCount}
              </span>
            )}
          </div>
        </div>
      </motion.div>

      {/* Mark all read */}
      {unreadCount > 0 && (
        <motion.div
          initial={{ opacity: 0, y: 6 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.35, delay: 0.05 }}
          style={{ display: 'flex', justifyContent: 'flex-end', marginBottom: 12 }}
        >
          <button onClick={handleMarkAllRead} className="app-btn app-btn--ghost app-btn--sm">
            <Check size={13} />
            Mark all read
          </button>
        </motion.div>
      )}

      {/* Notification list */}
      <div style={{ display: 'flex', flexDirection: 'column', gap: 2 }}>
        {loading ? (
          <div className="app-empty">
            <div className="w-6 h-6 border-2 border-prava-accent border-t-transparent rounded-full animate-spin mx-auto" />
          </div>
        ) : items.length === 0 ? (
          <div className="app-empty">
            <div className="app-empty__icon"><Bell size={20} /></div>
            <h3 className="app-empty__title">All caught up</h3>
            <p className="app-empty__desc">No notifications yet.</p>
          </div>
        ) : (
          items.map((notification, i) => {
            const Icon = iconMap[notification.type] ?? Bell;
            const colors = colorMap[notification.type] ?? colorMap.comment;
            const isUnread = !notification.readAt;

            return (
              <motion.div
                key={notification.id}
                initial={{ opacity: 0, y: 6 }}
                animate={{ opacity: 1, y: 0 }}
                transition={{ duration: 0.3, delay: 0.05 + i * 0.02 }}
                onClick={() => handleMarkRead(notification)}
                className={`app-notif ${isUnread ? 'app-notif--unread' : ''}`}
              >
                <div
                  className="app-notif__icon"
                  style={{ background: colors.bg, color: colors.text }}
                >
                  <Icon size={16} />
                </div>

                <div className="app-notif__body">
                  <p>
                    <span className="app-notif__title">{notification.title} </span>
                    <span className="app-notif__text">{notification.body}</span>
                  </p>
                  <span className="app-notif__time">{timeAgo(notification.createdAt)}</span>
                </div>

                {isUnread && <div className="app-notif__dot" />}
              </motion.div>
            );
          })
        )}
      </div>

      {nextCursor && (
        <div style={{ display: 'flex', justifyContent: 'center', marginTop: 12 }}>
          <button
            onClick={() => loadNotifications(nextCursor)}
            className="app-btn app-btn--ghost app-btn--sm"
          >
            Load more
          </button>
        </div>
      )}
    </div>
  );
}
