import { useEffect, useState } from 'react';
import { motion, AnimatePresence } from 'framer-motion';
import { Search, UserPlus, Send, X, MessageCircle, MoreHorizontal, Star } from 'lucide-react';
import { friendsService, FriendsResponse, FriendConnectionItem } from '../../services/friends-service';
import { smartToast } from '../../ui-system/components/SmartToast';
import { timeAgo } from '../../utils/date-utils';

type Tab = 'requests' | 'sent' | 'friends';

export default function FriendsPage() {
  const [activeTab, setActiveTab] = useState<Tab>('requests');
  const [data, setData] = useState<FriendsResponse | null>(null);
  const [loading, setLoading] = useState(true);
  const [searchQuery, setSearchQuery] = useState('');

  useEffect(() => { loadData(); }, []);

  const loadData = async () => {
    try {
      setLoading(true);
      const res = await friendsService.getConnections();
      setData(res);
      if (res.requests.length === 0 && res.friends.length > 0) setActiveTab('friends');
    } catch { smartToast.error('Failed to load connections'); }
    finally { setLoading(false); }
  };

  const handleAccept = async (req: FriendConnectionItem) => {
    try {
      await friendsService.acceptRequest(req.id);
      smartToast.success(`Accepted ${req.displayName}`);
      setData(prev => prev ? { ...prev, requests: prev.requests.filter(r => r.id !== req.id), friends: [{ ...req, isFollowing: true, isFollowedBy: true }, ...prev.friends] } : null);
    } catch { smartToast.error('Action failed'); }
  };

  const handleDecline = async (req: FriendConnectionItem) => {
    try {
      await friendsService.declineRequest(req.id);
      smartToast.info('Request declined');
      setData(prev => prev ? { ...prev, requests: prev.requests.filter(r => r.id !== req.id) } : null);
    } catch { smartToast.error('Action failed'); }
  };

  const handleCancel = async (req: FriendConnectionItem) => {
    try {
      await friendsService.cancelRequest(req.id);
      smartToast.warning('Request canceled');
      setData(prev => prev ? { ...prev, sent: prev.sent.filter(s => s.id !== req.id) } : null);
    } catch { smartToast.error('Action failed'); }
  };

  const tabs = [
    { id: 'requests' as const, label: 'Requests', count: data?.requests.length || 0 },
    { id: 'sent' as const, label: 'Sent', count: data?.sent.length || 0 },
    { id: 'friends' as const, label: 'Friends', count: data?.friends.length || 0 },
  ];

  const filteredFriends = data?.friends.filter(f => {
    if (!searchQuery.trim()) return true;
    const q = searchQuery.toLowerCase();
    return f.displayName.toLowerCase().includes(q) || f.username.toLowerCase().includes(q);
  }) ?? [];

  return (
    <div className="p-page">
      <motion.div initial={{ opacity: 0, y: 6 }} animate={{ opacity: 1, y: 0 }} transition={{ duration: 0.3 }} className="p-page-header">
        <h1 className="p-page-title">Connections</h1>
        <p className="p-page-subtitle">Manage your network</p>
      </motion.div>

      <div className="p-tabs" style={{ marginBottom: 16 }}>
        {tabs.map((t) => (
          <button key={t.id} onClick={() => setActiveTab(t.id)} className={`p-tab ${activeTab === t.id ? 'p-tab--active' : ''}`}>
            <span className="p-tab__count">{loading ? '-' : t.count}</span>
            <span className="p-tab__label">{t.label}</span>
          </button>
        ))}
      </div>

      <AnimatePresence mode="wait">
        {activeTab === 'requests' && (
          <motion.div key="req" initial={{ opacity: 0, x: -12 }} animate={{ opacity: 1, x: 0 }} exit={{ opacity: 0, x: 12 }} transition={{ duration: 0.18 }}>
            {data?.requests.length === 0 ? (
              <EmptyState title="No requests" desc="New friend requests will appear here." />
            ) : (
              <div style={{ display: 'flex', flexDirection: 'column', gap: 8 }}>
                {data?.requests.map(req => (
                  <div key={req.id} className="p-card" style={{ display: 'flex', gap: 12, alignItems: 'center' }}>
                    <Avatar user={req} isOnline={req.isOnline} />
                    <div style={{ flex: 1, minWidth: 0 }}>
                      <div style={{ display: 'flex', alignItems: 'center', gap: 6, marginBottom: 2 }}>
                        <span className="p-list-item__name">{req.displayName}</span>
                        {req.isVerified && <span className="p-badge p-badge--primary" style={{ fontSize: 9 }}>Verified</span>}
                      </div>
                      <span className="p-list-item__meta">@{req.username} · {req.since ? timeAgo(req.since) : 'recently'}</span>
                      <div style={{ display: 'flex', gap: 6, marginTop: 8 }}>
                        <button onClick={() => handleAccept(req)} className="p-btn p-btn--primary p-btn--sm" style={{ flex: 1 }}>Accept</button>
                        <button onClick={() => handleDecline(req)} className="p-btn p-btn--secondary p-btn--sm" style={{ flex: 1 }}>Decline</button>
                      </div>
                    </div>
                  </div>
                ))}
              </div>
            )}
          </motion.div>
        )}

        {activeTab === 'sent' && (
          <motion.div key="sent" initial={{ opacity: 0, x: -12 }} animate={{ opacity: 1, x: 0 }} exit={{ opacity: 0, x: 12 }} transition={{ duration: 0.18 }}>
            {data?.sent.length === 0 ? (
              <EmptyState title="No sent requests" desc="Send requests to grow your network." />
            ) : (
              <div style={{ display: 'flex', flexDirection: 'column', gap: 2 }}>
                {data?.sent.map(req => (
                  <div key={req.id} className="p-list-item">
                    <Avatar user={req} />
                    <div className="p-list-item__body">
                      <div className="p-list-item__name">{req.displayName}</div>
                      <div className="p-list-item__meta">@{req.username} · Pending</div>
                    </div>
                    <div className="p-list-item__actions">
                      <button className="p-btn p-btn--ghost p-btn--icon p-btn--sm" title="Nudge"><Send size={14} /></button>
                      <button onClick={() => handleCancel(req)} className="p-btn p-btn--danger p-btn--icon p-btn--sm" title="Cancel"><X size={14} /></button>
                    </div>
                  </div>
                ))}
              </div>
            )}
          </motion.div>
        )}

        {activeTab === 'friends' && (
          <motion.div key="fri" initial={{ opacity: 0, x: -12 }} animate={{ opacity: 1, x: 0 }} exit={{ opacity: 0, x: 12 }} transition={{ duration: 0.18 }}>
            <div className="p-search" style={{ marginBottom: 12 }}>
              <Search size={16} className="p-search__icon" />
              <input className="p-search__input" placeholder="Search friends..." value={searchQuery} onChange={(e) => setSearchQuery(e.target.value)} />
            </div>
            {filteredFriends.length === 0 ? (
              <EmptyState title={searchQuery ? 'No matches' : 'No friends yet'} desc={searchQuery ? 'Try a different term.' : 'Connect with people to see them here.'} />
            ) : (
              <div style={{ display: 'flex', flexDirection: 'column', gap: 2 }}>
                {filteredFriends.map(f => (
                  <div key={f.id} className="p-list-item">
                    <Avatar user={f} isOnline={f.isOnline} />
                    <div className="p-list-item__body">
                      <div style={{ display: 'flex', alignItems: 'center', gap: 4 }}>
                        <span className="p-list-item__name">{f.displayName}</span>
                        {f.isVerified && <Star size={11} style={{ color: 'var(--p-warning)', fill: 'var(--p-warning)' }} />}
                      </div>
                      <div className="p-list-item__meta">@{f.username}</div>
                    </div>
                    <div className="p-list-item__actions">
                      <button className="p-btn p-btn--ghost p-btn--icon p-btn--sm" title="Message"><MessageCircle size={14} /></button>
                      <button className="p-btn p-btn--ghost p-btn--icon p-btn--sm" title="More"><MoreHorizontal size={14} /></button>
                    </div>
                  </div>
                ))}
              </div>
            )}
          </motion.div>
        )}
      </AnimatePresence>
    </div>
  );
}

function Avatar({ user, isOnline }: { user: FriendConnectionItem; isOnline?: boolean }) {
  return (
    <div style={{ position: 'relative', flexShrink: 0 }}>
      <div className="p-avatar p-avatar--md">{user.displayName[0]}</div>
      {isOnline !== undefined && <div className={`p-online-dot ${isOnline ? 'p-online-dot--on' : 'p-online-dot--off'}`} />}
    </div>
  );
}

function EmptyState({ title, desc }: { title: string; desc: string }) {
  return (
    <div className="p-empty">
      <div className="p-empty__icon"><UserPlus size={20} /></div>
      <h3 className="p-empty__title">{title}</h3>
      <p className="p-empty__desc">{desc}</p>
    </div>
  );
}
