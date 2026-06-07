import { useEffect, useState } from 'react';
import { motion, AnimatePresence } from 'framer-motion';
import { Link, useParams } from 'react-router-dom';
import { Settings, Edit3, Shield, Users, MessageCircle, Share2, UserPlus, UserCheck } from 'lucide-react';
import { usersService } from '../../services/users-service';
import { profileService } from '../../services/profile-service';
import { publicProfileService } from '../../services/public-profile-service';
import { friendsService, FriendConnectionItem } from '../../services/friends-service';
import { useAuth } from '../../context/auth-context';
import { smartToast } from '../../ui-system/components/SmartToast';

type ProfileView = {
  user: {
    id: string;
    username: string;
    displayName: string;
    bio?: string;
  };
  stats: {
    posts: number;
    followers: number;
    following: number;
    likes?: number;
  };
  relationship?: {
    isFollowing: boolean;
    isFollowedBy: boolean;
  };
};

export default function ProfilePage() {
  const { user: currentUser } = useAuth();
  const { id } = useParams<{ id: string }>();
  const isOwnProfile = !id || id === currentUser?.id;
  const userId = id || currentUser?.id;

  const [profile, setProfile] = useState<ProfileView | null>(null);
  const [connections, setConnections] = useState<FriendConnectionItem[]>([]);
  const [loading, setLoading] = useState(true);
  const [activeTab, setActiveTab] = useState<'activity' | 'connections'>('activity');

  useEffect(() => {
    if (userId) loadProfile();
  }, [userId]);

  const loadProfile = async () => {
    try {
      setLoading(true);
      if (isOwnProfile) {
        const data = await profileService.fetchMyProfile();
        setProfile({ user: data.user, stats: data.stats });
      } else if (userId) {
        const data = await publicProfileService.fetchProfile(userId);
        setProfile({ user: data.user, stats: data.stats, relationship: data.relationship });
      }
      if (activeTab === 'connections' && isOwnProfile) {
        const conns = await friendsService.getConnections();
        setConnections(conns.friends);
      }
    } catch (error) {
      console.error('Failed to load profile:', error);
      smartToast.error('Failed to load profile');
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    if (activeTab === 'connections' && isOwnProfile && connections.length === 0) {
      friendsService
        .getConnections()
        .then((data) => setConnections(data.friends))
        .catch(console.error);
    }
  }, [activeTab, isOwnProfile]);

  const handleToggleFollow = async () => {
    if (!profile?.user?.id) return;
    try {
      const next = !profile.relationship?.isFollowing;
      await usersService.setFollow(profile.user.id, next);
      setProfile((prev) =>
        prev
          ? {
              ...prev,
              relationship: {
                isFollowing: next,
                isFollowedBy: prev.relationship?.isFollowedBy ?? false,
              },
            }
          : prev
      );
    } catch {
      smartToast.error('Unable to update follow status');
    }
  };

  if (loading && !profile) {
    return (
      <div className="max-w-2xl mx-auto flex justify-center py-12">
        <div className="w-6 h-6 border-2 border-prava-accent border-t-transparent rounded-full animate-spin" />
      </div>
    );
  }

  if (!profile) {
    return (
      <div className="max-w-2xl mx-auto py-12 text-center" style={{ color: 'var(--text-secondary)' }}>
        User not found
      </div>
    );
  }

  return (
    <div className="max-w-2xl mx-auto pb-8">
      {/* Profile Header — Compact, Solid */}
      <motion.div
        initial={{ opacity: 0, y: 6 }}
        animate={{ opacity: 1, y: 0 }}
        transition={{ duration: 0.35 }}
      >
        <div className="app-profile-header">
          <div className="app-profile-cover" />
          <div className="app-profile-info">
            <div className="app-profile-avatar">
              {profile.user.displayName.charAt(0)}
            </div>
            <h1 className="app-profile-name">{profile.user.displayName}</h1>
            <p className="app-profile-handle">@{profile.user.username}</p>
            {profile.user.bio && (
              <p className="app-profile-bio">{profile.user.bio}</p>
            )}

            {/* Actions */}
            <div style={{ display: 'flex', gap: 8, marginTop: 12 }}>
              {isOwnProfile ? (
                <Link to="/settings" className="app-btn app-btn--ghost">
                  <Settings size={15} />
                  Settings
                </Link>
              ) : (
                <>
                  <button onClick={handleToggleFollow} className="app-btn app-btn--primary">
                    {profile.relationship?.isFollowing ? <UserCheck size={14} /> : <UserPlus size={14} />}
                    {profile.relationship?.isFollowing ? 'Following' : 'Follow'}
                  </button>
                  <button className="app-btn app-btn--ghost app-btn--icon">
                    <MessageCircle size={16} />
                  </button>
                </>
              )}
            </div>
          </div>
        </div>
      </motion.div>

      {/* Stats — Compact */}
      <motion.div
        initial={{ opacity: 0, y: 6 }}
        animate={{ opacity: 1, y: 0 }}
        transition={{ duration: 0.35, delay: 0.08 }}
        className="app-stats"
      >
        {[
          { label: 'Following', value: profile.stats.following },
          { label: 'Followers', value: profile.stats.followers },
          { label: 'Posts', value: profile.stats.posts },
        ].map((stat) => (
          <div key={stat.label} className="app-stat">
            <div className="app-stat__value">{stat.value}</div>
            <div className="app-stat__label">{stat.label}</div>
          </div>
        ))}
      </motion.div>

      {/* Tabs — Compact underline */}
      <div className="app-underline-tabs">
        <button
          onClick={() => setActiveTab('activity')}
          className={`app-underline-tab ${activeTab === 'activity' ? 'app-underline-tab--active' : ''}`}
        >
          Activity
        </button>
        <button
          onClick={() => setActiveTab('connections')}
          className={`app-underline-tab ${activeTab === 'connections' ? 'app-underline-tab--active' : ''}`}
        >
          <Users size={14} style={{ display: 'inline', marginRight: 4, verticalAlign: -2 }} />
          Connections
        </button>
      </div>

      {/* Content */}
      <AnimatePresence mode="wait">
        {activeTab === 'activity' ? (
          <motion.div
            key="activity"
            initial={{ opacity: 0, y: 8 }}
            animate={{ opacity: 1, y: 0 }}
            exit={{ opacity: 0, y: -8 }}
            transition={{ duration: 0.2 }}
          >
            <div className="app-empty">
              <div className="app-empty__icon">
                <Shield size={22} />
              </div>
              <h3 className="app-empty__title">Secured Activity</h3>
              <p className="app-empty__desc">
                User activity is encrypted. Only mutual connections may see detailed post history.
              </p>
            </div>
          </motion.div>
        ) : (
          <motion.div
            key="connections"
            initial={{ opacity: 0, y: 8 }}
            animate={{ opacity: 1, y: 0 }}
            exit={{ opacity: 0, y: -8 }}
            transition={{ duration: 0.2 }}
          >
            {connections.length > 0 ? (
              <div style={{ display: 'flex', flexDirection: 'column', gap: 2 }}>
                {connections.map((conn) => (
                  <Link key={conn.id} to={`/profile/${conn.id}`} className="app-list-item" style={{ textDecoration: 'none' }}>
                    <div className="app-list-item__avatar">{conn.displayName.charAt(0)}</div>
                    <div className="app-list-item__body">
                      <div className="app-list-item__name">{conn.displayName}</div>
                      <div className="app-list-item__meta">@{conn.username}</div>
                    </div>
                    <Share2 size={14} style={{ color: 'var(--text-tertiary)' }} />
                  </Link>
                ))}
              </div>
            ) : (
              <div className="app-empty">
                <div className="app-empty__icon"><Users size={20} /></div>
                <h3 className="app-empty__title">No connections yet</h3>
                <p className="app-empty__desc">Connect with people to see them here.</p>
              </div>
            )}
          </motion.div>
        )}
      </AnimatePresence>
    </div>
  );
}
