import React, { useEffect, useState } from 'react';
import { motion, AnimatePresence } from 'framer-motion';
import {
  Search,
  UserPlus,
  UserCheck,
  MoreHorizontal,
  Send,
  X,
  Check,
  MessageCircle,
  Phone,
  Star,
  BellOff,
  Pin
} from 'lucide-react';
import { GlassCard, PravaInput } from '../../ui-system';
import { friendsService, FriendsResponse, FriendRequest, SentRequest, FriendConnection } from '../../services/friends-service';
import { smartToast } from '../../ui-system/components/SmartToast';

type Tab = 'requests' | 'sent' | 'friends';

export default function FriendsPage() {
  const [activeTab, setActiveTab] = useState<Tab>('requests');
  const [data, setData] = useState<FriendsResponse | null>(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    loadData();
  }, []);

  const loadData = async () => {
    try {
      setLoading(true);
      const res = await friendsService.getConnections();
      setData(res);
      // Auto-switch to friends if no requests
      if (res.requests.length === 0 && res.friends.length > 0) {
        setActiveTab('friends');
      }
    } catch (error) {
      smartToast.error('Failed to load connections');
    } finally {
      setLoading(false);
    }
  };

  const handleAccept = async (req: FriendRequest) => {
    try {
      await friendsService.acceptRequest(req.user.id);
      smartToast.success(`Accepted ${req.user.displayName}`);
      // Optimistic update
      setData(prev => prev ? {
        ...prev,
        requests: prev.requests.filter(r => r.user.id !== req.user.id),
        friends: [{
          user: req.user,
          connectedSince: 'Just now',
          isFavorite: false,
          isMuted: false,
          isPinned: false
        }, ...prev.friends]
      } : null);
    } catch (e) {
      smartToast.error('Action failed');
    }
  };

  const handleDecline = async (req: FriendRequest) => {
    try {
      await friendsService.declineRequest(req.user.id);
      smartToast.info('Request declined');
      setData(prev => prev ? {
        ...prev,
        requests: prev.requests.filter(r => r.user.id !== req.user.id)
      } : null);
    } catch (e) {
      smartToast.error('Action failed');
    }
  };

  const handleCancel = async (req: SentRequest) => {
    try {
      await friendsService.cancelRequest(req.user.id);
      smartToast.warning('Request canceled');
      setData(prev => prev ? {
        ...prev,
        sent: prev.sent.filter(s => s.user.id !== req.user.id)
      } : null);
    } catch (e) {
      smartToast.error('Action failed');
    }
  };

  const handleNudge = (req: SentRequest) => {
    smartToast.success(`Nudged @${req.user.username}`);
  };

  return (
    <div className="max-w-2xl mx-auto pb-8">
      {/* Header */}
      <motion.div
        initial={{ opacity: 0, y: 10 }}
        animate={{ opacity: 1, y: 0 }}
        className="mb-6"
      >
        <h1 className="text-h1 text-prava-light-text-primary dark:text-prava-dark-text-primary">
          Connections
        </h1>
        <p className="mt-1 text-body text-prava-light-text-secondary dark:text-prava-dark-text-secondary">
          Manage your network
        </p>
      </motion.div>

      {/* Summary / Stats Strip */}
      <GlassCard className="mb-6 p-2 flex justify-between items-center">
        {[
          { id: 'requests', label: 'Requests', count: data?.requests.length || 0 },
          { id: 'sent', label: 'Sent', count: data?.sent.length || 0 },
          { id: 'friends', label: 'Friends', count: data?.friends.length || 0 },
        ].map((tab) => (
          <button
            key={tab.id}
            onClick={() => setActiveTab(tab.id as Tab)}
            className={`
              flex-1 py-3 px-4 rounded-[14px] flex flex-col items-center gap-1 transition-all
              ${activeTab === tab.id
                ? 'bg-prava-accent/10 text-prava-accent'
                : 'text-prava-light-text-secondary dark:text-prava-dark-text-secondary hover:bg-black/5 dark:hover:bg-white/5'
              }
            `}
          >
            <span className="text-2xl font-bold font-outfit">
              {loading ? '-' : tab.count}
            </span>
            <span className="text-xs font-semibold uppercase tracking-wide opacity-80">
              {tab.label}
            </span>
          </button>
        ))}
      </GlassCard>

      {/* Content Area */}
      <AnimatePresence mode="wait">
        {activeTab === 'requests' && (
          <motion.div
            key="requests"
            initial={{ opacity: 0, x: -20 }}
            animate={{ opacity: 1, x: 0 }}
            exit={{ opacity: 0, x: 20 }}
            transition={{ duration: 0.2 }}
          >
            {data?.requests.length === 0 ? (
              <EmptyState title="No requests" subtitle="New friend requests will appear here." />
            ) : (
              <div className="space-y-4">
                {data?.requests.map(req => (
                  <GlassCard key={req.user.id} className="flex gap-4 items-center">
                    <Avatar user={req.user} size="lg" />
                    <div className="flex-1 min-w-0">
                      <div className="flex items-center gap-2 mb-1">
                        <h3 className="font-bold text-lg text-prava-light-text-primary dark:text-prava-dark-text-primary truncate">
                          {req.user.displayName}
                        </h3>
                        {req.priorityLabel && (
                          <span className="px-2 py-0.5 rounded-full bg-prava-accent/20 text-prava-accent text-[10px] font-bold uppercase">
                            {req.priorityLabel}
                          </span>
                        )}
                      </div>
                      <p className="text-sm text-prava-light-text-secondary dark:text-prava-dark-text-secondary mb-3">
                        {req.message}
                      </p>
                      <div className="flex gap-3">
                        <button
                          onClick={() => handleAccept(req)}
                          className="flex-1 py-2 bg-prava-accent text-white rounded-[12px] font-semibold text-sm hover:scale-[1.02] transition-transform"
                        >
                          Accept
                        </button>
                        <button
                          onClick={() => handleDecline(req)}
                          className="flex-1 py-2 bg-prava-light-surface dark:bg-prava-dark-surface border border-prava-light-border dark:border-prava-dark-border text-prava-light-text-primary dark:text-prava-dark-text-primary rounded-[12px] font-semibold text-sm hover:bg-black/5 dark:hover:bg-white/5 transition-colors"
                        >
                          Decline
                        </button>
                      </div>
                    </div>
                  </GlassCard>
                ))}
              </div>
            )}
          </motion.div>
        )}

        {activeTab === 'sent' && (
          <motion.div
            key="sent"
            initial={{ opacity: 0, x: -20 }}
            animate={{ opacity: 1, x: 0 }}
            exit={{ opacity: 0, x: 20 }}
            transition={{ duration: 0.2 }}
          >
            {data?.sent.length === 0 ? (
              <EmptyState title="No sent requests" subtitle="Send requests to grow your network." />
            ) : (
              <div className="space-y-4">
                {data?.sent.map(req => (
                  <GlassCard key={req.user.id} className="flex gap-4 items-center">
                    <Avatar user={req.user} />
                    <div className="flex-1 min-w-0">
                      <h3 className="font-bold text-prava-light-text-primary dark:text-prava-dark-text-primary">
                        {req.user.displayName}
                      </h3>
                      <p className="text-sm text-prava-light-text-tertiary dark:text-prava-dark-text-tertiary">
                        {req.timeLabel} • {req.status}
                      </p>
                    </div>
                    <div className="flex gap-2">
                      <button
                        onClick={() => handleNudge(req)}
                        className="p-2 text-prava-accent hover:bg-prava-accent/10 rounded-full transition-colors"
                        title="Nudge"
                      >
                        <Send className="w-5 h-5" />
                      </button>
                      <button
                        onClick={() => handleCancel(req)}
                        className="p-2 text-prava-error hover:bg-prava-error/10 rounded-full transition-colors"
                        title="Cancel"
                      >
                        <X className="w-5 h-5" />
                      </button>
                    </div>
                  </GlassCard>
                ))}
              </div>
            )}
          </motion.div>
        )}

        {activeTab === 'friends' && (
          <motion.div
            key="friends"
            initial={{ opacity: 0, x: -20 }}
            animate={{ opacity: 1, x: 0 }}
            exit={{ opacity: 0, x: 20 }}
            transition={{ duration: 0.2 }}
          >
            <div className="mb-4">
              <PravaInput
                placeholder="Search friends..."
                prefixIcon={<Search className="w-5 h-5 text-prava-light-text-tertiary" />}
              />
            </div>

            {data?.friends.length === 0 ? (
              <EmptyState title="No friends yet" subtitle="Connect with people to see them here." />
            ) : (
              <div className="space-y-3">
                {data?.friends.map(friend => (
                  <div
                    key={friend.user.id}
                    className="group bg-white/80 dark:bg-white/[0.04] p-4 rounded-[20px] border border-transparent hover:border-prava-light-border dark:hover:border-prava-dark-border transition-all hover:bg-white dark:hover:bg-white/10"
                  >
                    <div className="flex items-center gap-4">
                      <Avatar user={friend.user} isOnline={friend.user.isOnline} />
                      <div className="flex-1 min-w-0">
                        <div className="flex items-center gap-2">
                          <h3 className="font-bold text-prava-light-text-primary dark:text-prava-dark-text-primary">
                            {friend.user.displayName}
                          </h3>
                          {friend.isFavorite && <Star className="w-3 h-3 fill-prava-warning text-prava-warning" />}
                        </div>
                        <p className="text-sm text-prava-light-text-tertiary dark:text-prava-dark-text-tertiary">
                          @{friend.user.username} • {friend.connectedSince}
                        </p>
                      </div>
                      <div className="flex gap-1 opacity-0 group-hover:opacity-100 transition-opacity">
                        <button className="p-2 text-prava-accent hover:bg-prava-accent/10 rounded-full">
                          <MessageCircle className="w-5 h-5" />
                        </button>
                        <button className="p-2 text-prava-light-text-secondary dark:text-prava-dark-text-secondary hover:bg-black/5 dark:hover:bg-white/5 rounded-full">
                          <Phone className="w-5 h-5" />
                        </button>
                        <button className="p-2 text-prava-light-text-secondary dark:text-prava-dark-text-secondary hover:bg-black/5 dark:hover:bg-white/5 rounded-full">
                          <MoreHorizontal className="w-5 h-5" />
                        </button>
                      </div>
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

function Avatar({ user, size = 'md', isOnline }: { user: any, size?: 'md' | 'lg', isOnline?: boolean }) {
  return (
    <div className="relative">
      <div className={`
        ${size === 'lg' ? 'w-14 h-14' : 'w-12 h-12'}
        rounded-full bg-gradient-to-br from-prava-accent to-prava-accent-muted
        flex items-center justify-center shrink-0 text-white font-bold
        ${size === 'lg' ? 'text-xl' : 'text-lg'}
      `}>
        {user.avatarUrl ? (
          <img src={user.avatarUrl} alt={user.username} className="w-full h-full rounded-full object-cover" />
        ) : (
          user.displayName[0]
        )}
      </div>
      {isOnline !== undefined && (
        <div className={`
          absolute bottom-0 right-0 border-2 border-white dark:border-[#1D1D1D] rounded-full
          ${size === 'lg' ? 'w-4 h-4' : 'w-3 h-3'}
          ${isOnline ? 'bg-prava-success' : 'bg-prava-light-text-tertiary'}
        `} />
      )}
    </div>
  );
}

function EmptyState({ title, subtitle }: { title: string, subtitle: string }) {
  return (
    <div className="text-center py-12 opacity-60">
      <div className="w-16 h-16 bg-prava-light-surface dark:bg-prava-dark-surface rounded-full flex items-center justify-center mx-auto mb-4">
        <UserPlus className="w-8 h-8 text-prava-light-text-tertiary" />
      </div>
      <h3 className="text-xl font-bold text-prava-light-text-primary dark:text-prava-dark-text-primary mb-1">
        {title}
      </h3>
      <p className="text-prava-light-text-secondary dark:text-prava-dark-text-secondary">
        {subtitle}
      </p>
    </div>
  );
}
