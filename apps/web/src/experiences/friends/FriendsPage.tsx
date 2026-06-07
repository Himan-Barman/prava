import { useEffect, useState } from 'react';
import { motion, AnimatePresence } from 'framer-motion';
import {
  Search,
  UserPlus,
  Send,
  X,
  MessageCircle,
  MoreHorizontal,
  Star,
} from 'lucide-react';
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
      if (res.requests.length === 0 && res.friends.length > 0) {
        setActiveTab('friends');
      }
    } catch {
      smartToast.error('Failed to load connections');
    } finally {
      setLoading(false);
    }
  };

  const handleAccept = async (req: FriendConnectionItem) => {
    try {
      await friendsService.acceptRequest(req.id);
      smartToast.success(`Accepted ${req.displayName}`);
      setData(prev => prev ? {
        ...prev,
        requests: prev.requests.filter(r => r.id !== req.id),
        friends: [{ ...req, isFollowing: true, isFollowedBy: true }, ...prev.friends]
      } : null);
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

  const handleNudge = (req: FriendConnectionItem) => {
    smartToast.success(`Nudged @${req.username}`);
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
    <div className="max-w-2xl mx-auto pb-8">
      {/* Header */}
      <motion.div
        initial={{ opacity: 0, y: 6 }}
        animate={{ opacity: 1, y: 0 }}
        transition={{ duration: 0.35 }}
        className="app-page-header"
      >
        <h1 className="app-page-title">Connections</h1>
        <p className="app-page-subtitle">Manage your network</p>
      </motion.div>

      {/* Tab bar — compact */}
      <div className="app-tabs">
        {tabs.map((tab) => (
          <button
            key={tab.id}
            onClick={() => setActiveTab(tab.id)}
            className={`app-tab ${activeTab === tab.id ? 'app-tab--active' : ''}`}
          >
            <span className="app-tab__count">{loading ? '-' : tab.count}</span>
            <span className="app-tab__label">{tab.label}</span>
          </button>
        ))}
      </div>

      {/* Content */}
      <AnimatePresence mode="wait">
        {activeTab === 'requests' && (
          <motion.div
            key="requests"
            initial={{ opacity: 0, x: -12 }}
            animate={{ opacity: 1, x: 0 }}
            exit={{ opacity: 0, x: 12 }}
            transition={{ duration: 0.2 }}
          >
            {data?.requests.length === 0 ? (
              <EmptyState title="No requests" desc="New friend requests will appear here." />
            ) : (
              <div style={{ display: 'flex', flexDirection: 'column', gap: 6 }}>
                {data?.requests.map(req => (
                  <div key={req.id} className="app-card" style={{ display: 'flex', gap: 12, alignItems: 'center' }}>
                    <Avatar user={req} isOnline={req.isOnline} />
                    <div style={{ flex: 1, minWidth: 0 }}>
                      <div style={{ display: 'flex', alignItems: 'center', gap: 6, marginBottom: 2 }}>
                        <span className="app-list-item__name">{req.displayName}</span>
                        {req.isVerified && (
                          <span style={{
                            padding: '1px 6px', borderRadius: 100,
                            background: 'rgba(91,140,255,0.1)', color: '#5B8CFF',
                            fontSize: 10, fontWeight: 700,
                          }}>Verified</span>
                        )}
                      </div>
                      <span className="app-list-item__meta">@{req.username} · {req.since ? timeAgo(req.since) : 'recently'}</span>
                      <div style={{ display: 'flex', gap: 6, marginTop: 8 }}>
                        <button onClick={() => handleAccept(req)} className="app-btn app-btn--primary app-btn--sm" style={{ flex: 1 }}>
                          Accept
                        </button>
                        <button onClick={() => handleDecline(req)} className="app-btn app-btn--ghost app-btn--sm" style={{ flex: 1 }}>
                          Decline
                        </button>
                      </div>
                    </div>
                  </div>
                ))}
              </div>
            )}
          </motion.div>
        )}

        {activeTab === 'sent' && (
          <motion.div
            key="sent"
            initial={{ opacity: 0, x: -12 }}
            animate={{ opacity: 1, x: 0 }}
            exit={{ opacity: 0, x: 12 }}
            transition={{ duration: 0.2 }}
          >
            {data?.sent.length === 0 ? (
              <EmptyState title="No sent requests" desc="Send requests to grow your network." />
            ) : (
              <div style={{ display: 'flex', flexDirection: 'column', gap: 2 }}>
                {data?.sent.map(req => (
                  <div key={req.id} className="app-list-item">
                    <Avatar user={req} />
                    <div className="app-list-item__body">
                      <div className="app-list-item__name">{req.displayName}</div>
                      <div className="app-list-item__meta">@{req.username} · Pending</div>
                    </div>
                    <div className="app-list-item__actions">
                      <button onClick={() => handleNudge(req)} className="app-btn app-btn--icon app-btn--ghost" title="Nudge">
                        <Send size={14} />
                      </button>
                      <button onClick={() => handleCancel(req)} className="app-btn app-btn--icon app-btn--danger" title="Cancel">
                        <X size={14} />
                      </button>
                    </div>
                  </div>
                ))}
              </div>
            )}
          </motion.div>
        )}

        {activeTab === 'friends' && (
          <motion.div
            key="friends"
            initial={{ opacity: 0, x: -12 }}
            animate={{ opacity: 1, x: 0 }}
            exit={{ opacity: 0, x: 12 }}
            transition={{ duration: 0.2 }}
          >
            {/* Search */}
            <div className="app-search-wrap" style={{ marginBottom: 12 }}>
              <Search size={16} />
              <input
                className="app-search-input"
                placeholder="Search friends..."
                value={searchQuery}
                onChange={(e) => setSearchQuery(e.target.value)}
              />
            </div>

            {filteredFriends.length === 0 ? (
              <EmptyState
                title={searchQuery ? 'No matches' : 'No friends yet'}
                desc={searchQuery ? 'Try a different search term.' : 'Connect with people to see them here.'}
              />
            ) : (
              <div style={{ display: 'flex', flexDirection: 'column', gap: 2 }}>
                {filteredFriends.map(friend => (
                  <div key={friend.id} className="app-list-item">
                    <Avatar user={friend} isOnline={friend.isOnline} />
                    <div className="app-list-item__body">
                      <div style={{ display: 'flex', alignItems: 'center', gap: 4 }}>
                        <span className="app-list-item__name">{friend.displayName}</span>
                        {friend.isVerified && <Star size={11} style={{ color: '#F4C430', fill: '#F4C430' }} />}
                      </div>
                      <div className="app-list-item__meta">@{friend.username}</div>
                    </div>
                    <div className="app-list-item__actions">
                      <button className="app-btn app-btn--icon app-btn--ghost" title="Message">
                        <MessageCircle size={14} />
                      </button>
                      <button className="app-btn app-btn--icon app-btn--ghost" title="More">
                        <MoreHorizontal size={14} />
                      </button>
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
      <div className="app-list-item__avatar">
        {user.displayName[0]}
      </div>
      {isOnline !== undefined && (
        <div className={`app-online-dot ${isOnline ? 'app-online-dot--active' : 'app-online-dot--offline'}`} />
      )}
    </div>
  );
}

function EmptyState({ title, desc }: { title: string; desc: string }) {
  return (
    <div className="app-empty">
      <div className="app-empty__icon"><UserPlus size={20} /></div>
      <h3 className="app-empty__title">{title}</h3>
      <p className="app-empty__desc">{desc}</p>
    </div>
  );
}
