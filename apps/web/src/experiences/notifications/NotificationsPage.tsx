import { useEffect, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { motion } from 'framer-motion';
import { Bell, Heart, MessageCircle, UserPlus, Check } from 'lucide-react';
import { notificationsService, NotificationItem } from '../../services/notifications-service';
import { timeAgo } from '../../utils/date-utils';
import { smartToast } from '../../ui-system/components/SmartToast';

const iconMap: Record<string, typeof Bell> = {
  like: Heart, comment: MessageCircle, follow: UserPlus, message: Bell,
};
const colorMap: Record<string, { text: string; bg: string }> = {
  like: { text: 'var(--p-danger)', bg: 'var(--p-danger-subtle)' },
  comment: { text: 'var(--p-brand)', bg: 'var(--p-brand-subtle)' },
  follow: { text: 'var(--p-success)', bg: 'var(--p-success-subtle)' },
  message: { text: 'var(--p-warning)', bg: 'var(--p-warning-subtle)' },
};

export default function NotificationsPage() {
  const navigate = useNavigate();
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
    } catch { smartToast.error('Failed to load notifications'); }
    finally { setLoading(false); }
  };

  const handleMarkAllRead = async () => {
    try {
      await notificationsService.markAllRead();
      setItems((prev) => prev.map((item) => ({ ...item, readAt: item.readAt ?? new Date().toISOString() })));
      setUnreadCount(0);
    } catch { smartToast.error('Could not mark all as read'); }
  };

  const handleMarkRead = async (n: NotificationItem) => {
    if (n.readAt) return;
    try {
      await notificationsService.markRead(n.id);
      setItems((prev) => prev.map((item) => item.id === n.id ? { ...item, readAt: new Date().toISOString() } : item));
      setUnreadCount((c) => Math.max(c - 1, 0));
    } catch { smartToast.error('Could not update notification'); }
  };

  const handleOpen = async (n: NotificationItem) => {
    await handleMarkRead(n);
    const postId = typeof n.data?.postId === 'string' ? n.data.postId : null;
    const actorId = n.actor?.id;
    if (postId) {
      navigate(`/post/${postId}`);
      return;
    }
    if (actorId) {
      navigate(`/profile/${actorId}`);
    }
  };

  return (
    <div className="p-page">
      <motion.div initial={{ opacity: 0, y: 6 }} animate={{ opacity: 1, y: 0 }} transition={{ duration: 0.3 }} className="p-page-header">
        <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
          <div>
            <h1 className="p-page-title">Notifications</h1>
            <p className="p-page-subtitle">Stay updated with your activity</p>
          </div>
          {unreadCount > 0 && <span className="p-badge p-badge--primary">{unreadCount}</span>}
        </div>
      </motion.div>

      {unreadCount > 0 && (
        <div style={{ display: 'flex', justifyContent: 'flex-end', marginBottom: 12 }}>
          <button onClick={handleMarkAllRead} className="p-btn p-btn--ghost p-btn--sm"><Check size={13} /> Mark all read</button>
        </div>
      )}

      <div style={{ display: 'flex', flexDirection: 'column', gap: 2 }}>
        {loading ? (
          <div style={{ display: 'flex', justifyContent: 'center', padding: '40px 0' }}><div className="p-spinner" /></div>
        ) : items.length === 0 ? (
          <div className="p-empty">
            <div className="p-empty__icon"><Bell size={20} /></div>
            <h3 className="p-empty__title">All caught up</h3>
            <p className="p-empty__desc">No notifications yet.</p>
          </div>
        ) : (
          items.map((n, i) => {
            const Icon = iconMap[n.type] ?? Bell;
            const c = colorMap[n.type] ?? colorMap.comment;
            const unread = !n.readAt;
            return (
              <motion.div key={n.id} initial={{ opacity: 0, y: 6 }} animate={{ opacity: 1, y: 0 }} transition={{ duration: 0.25, delay: 0.03 + i * 0.015 }}
                onClick={() => handleOpen(n)} className={`p-notif ${unread ? 'p-notif--unread' : ''}`}>
                {n.actor?.avatarUrl ? (
                  <img src={n.actor.avatarUrl} alt="" className="p-notif__icon" style={{ objectFit: 'cover', borderRadius: 'var(--p-radius-pill)' }} />
                ) : (
                  <div className="p-notif__icon" style={{ background: c.bg, color: c.text }}><Icon size={16} /></div>
                )}
                <div className="p-notif__body">
                  <p><span className="p-notif__title">{n.title} </span><span className="p-notif__text">{n.body}</span></p>
                  <span className="p-notif__time">{timeAgo(n.createdAt)}</span>
                </div>
                {unread && <div className="p-notif__dot" />}
              </motion.div>
            );
          })
        )}
      </div>

      {nextCursor && (
        <div style={{ display: 'flex', justifyContent: 'center', marginTop: 12 }}>
          <button onClick={() => loadNotifications(nextCursor)} className="p-btn p-btn--ghost p-btn--sm">Load more</button>
        </div>
      )}
    </div>
  );
}
