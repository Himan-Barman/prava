import { useEffect, useState } from 'react';
import { motion, AnimatePresence } from 'framer-motion';
import { Link, useParams } from 'react-router-dom';
import { Settings, Edit3, Shield, Users, MessageCircle, Share2, Grid, UserPlus, UserCheck } from 'lucide-react';
import { toast } from 'react-hot-toast';
import { GlassCard } from '../../ui-system';
import { usersService } from '../../services/users-service';
import { profileService } from '../../services/profile-service';
import { publicProfileService } from '../../services/public-profile-service';
import { friendsService, FriendConnectionItem } from '../../services/friends-service';
import { useAuth } from '../../context/auth-context';

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
    if (userId) {
      loadProfile();
    }
  }, [userId]);

  const loadProfile = async () => {
    try {
      setLoading(true);
      if (isOwnProfile) {
        const data = await profileService.fetchMyProfile();
        setProfile({
          user: data.user,
          stats: data.stats,
        });
      } else if (userId) {
        const data = await publicProfileService.fetchProfile(userId);
        setProfile({
          user: data.user,
          stats: data.stats,
          relationship: data.relationship,
        });
      }

      if (activeTab === 'connections' && isOwnProfile) {
        const conns = await friendsService.getConnections();
        setConnections(conns.friends);
      }

    } catch (error) {
      console.error('Failed to load profile:', error);
      toast.error('Failed to load profile');
    } finally {
      setLoading(false);
    }
  };

  // Effect to load connections when tab changes
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
      const next = profile.relationship?.isFollowing ? false : true;
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
    } catch (error) {
      toast.error('Unable to update follow status');
    }
  };

  if (loading && !profile) {
    return (
      <div className="max-w-2xl mx-auto flex justify-center py-12">
        <div className="w-8 h-8 border-2 border-prava-accent border-t-transparent rounded-full animate-spin" />
      </div>
    );
  }

  if (!profile) {
    return (
      <div className="max-w-2xl mx-auto py-12 text-center text-prava-light-text-secondary dark:text-prava-dark-text-secondary">
        User not found
      </div>
    );
  }

  return (
    <div className="max-w-2xl mx-auto pb-8">
      {/* Profile Header */}
      <motion.div
        initial={{ opacity: 0, y: 8 }}
        animate={{ opacity: 1, y: 0 }}
        transition={{ duration: 0.4 }}
      >
        <GlassCard className="mb-6 bg-gradient-to-br from-prava-accent/10 to-prava-success/5 relative overflow-hidden">
          {/* Cover Photo Placeholder */}
          <div className="absolute top-0 left-0 right-0 h-32 bg-gradient-to-r from-prava-accent/20 to-blue-500/20" />

          <div className="relative pt-16 flex flex-col sm:flex-row items-center sm:items-end gap-4 px-2">
            {/* Avatar */}
            <div className="relative">
              <div className="w-32 h-32 rounded-full border-4 border-prava-light-surface dark:border-prava-dark-surface bg-gradient-to-br from-prava-accent to-prava-accent-muted flex items-center justify-center shadow-lg overflow-hidden">
                <span className="text-white font-bold text-4xl">{profile.user.displayName.charAt(0)}</span>
              </div>
              {isOwnProfile && (
                <button className="absolute bottom-2 right-2 p-2 rounded-full bg-prava-light-bg dark:bg-prava-dark-bg border border-prava-light-border dark:border-prava-dark-border shadow-sm hover:scale-105 transition-transform">
                  <Edit3 className="w-4 h-4 text-prava-light-text-secondary dark:text-prava-dark-text-secondary" />
                </button>
              )}
            </div>

            {/* Info */}
            <div className="flex-1 text-center sm:text-left mb-2">
              <h1 className="text-3xl font-bold text-prava-light-text-primary dark:text-prava-dark-text-primary">
                {profile.user.displayName}
              </h1>
              <p className="text-body text-prava-accent font-medium">@{profile.user.username}</p>
              {profile.user.bio && (
                <p className="mt-2 text-body-sm text-prava-light-text-secondary dark:text-prava-dark-text-secondary max-w-md">
                  {profile.user.bio}
                </p>
              )}
            </div>

            {/* Actions */}
            <div className="flex gap-2 mb-4">
              {isOwnProfile ? (
                <Link
                  to="/settings"
                  className="p-3 rounded-[14px] bg-prava-light-surface dark:bg-prava-dark-surface border border-prava-light-border dark:border-prava-dark-border hover:bg-prava-light-border/50 dark:hover:bg-prava-dark-border/50 transition-colors"
                >
                  <Settings className="w-5 h-5 text-prava-light-text-secondary dark:text-prava-dark-text-secondary" />
                </Link>
              ) : (
                <>
                  <button
                    onClick={handleToggleFollow}
                    className="flex items-center gap-2 px-4 py-2 rounded-[14px] bg-prava-accent text-white font-semibold shadow-prava-glow hover:bg-prava-accent-muted transition-colors"
                  >
                    {profile.relationship?.isFollowing ? <UserCheck className="w-4 h-4" /> : <UserPlus className="w-4 h-4" />}
                    {profile.relationship?.isFollowing ? 'Following' : 'Follow'}
                  </button>
                  <button className="p-3 rounded-[14px] bg-prava-light-surface dark:bg-prava-dark-surface border border-prava-light-border dark:border-prava-dark-border hover:bg-prava-light-border/50 dark:hover:bg-prava-dark-border/50 transition-colors">
                    <MessageCircle className="w-5 h-5 text-prava-light-text-secondary dark:text-prava-dark-text-secondary" />
                  </button>
                </>
              )}
            </div>
          </div>
        </GlassCard>
      </motion.div>

      {/* Stats */}
      <motion.div
        initial={{ opacity: 0, y: 8 }}
        animate={{ opacity: 1, y: 0 }}
        transition={{ duration: 0.4, delay: 0.1 }}
        className="grid grid-cols-3 gap-3 mb-6"
      >
        {[
          { label: 'Following', value: profile.stats.following, icon: Users },
          { label: 'Followers', value: profile.stats.followers, icon: Users },
          { label: 'Posts', value: profile.stats.posts, icon: Share2 },
        ].map((stat, i) => (
          <GlassCard key={stat.label} delay={0.15 + i * 0.05} className="text-center py-4">
            <stat.icon className="w-5 h-5 mx-auto mb-2 text-prava-accent" />
            <p className="text-h2 text-prava-light-text-primary dark:text-prava-dark-text-primary">
              {stat.value}
            </p>
            <p className="text-caption text-prava-light-text-tertiary dark:text-prava-dark-text-tertiary">
              {stat.label}
            </p>
          </GlassCard>
        ))}
      </motion.div>

      {/* Tabs */}
      <div className="flex items-center gap-6 border-b border-prava-light-border dark:border-prava-dark-border mb-6 px-2">
        <button
          onClick={() => setActiveTab('activity')}
          className={`pb-3 text-body-sm font-semibold transition-colors relative ${activeTab === 'activity'
            ? 'text-prava-accent'
            : 'text-prava-light-text-secondary dark:text-prava-dark-text-secondary hover:text-prava-light-text-primary dark:hover:text-prava-dark-text-primary'
            }`}
        >
          <div className="flex items-center gap-2">
            <Grid className="w-4 h-4" />
            Activity
          </div>
          {activeTab === 'activity' && (
            <motion.div
              layoutId="activeTab"
              className="absolute bottom-0 left-0 right-0 h-0.5 bg-prava-accent rounded-full"
            />
          )}
        </button>
        <button
          onClick={() => setActiveTab('connections')}
          className={`pb-3 text-body-sm font-semibold transition-colors relative ${activeTab === 'connections'
            ? 'text-prava-accent'
            : 'text-prava-light-text-secondary dark:text-prava-dark-text-secondary hover:text-prava-light-text-primary dark:hover:text-prava-dark-text-primary'
            }`}
        >
          <div className="flex items-center gap-2">
            <Users className="w-4 h-4" />
            Connections
          </div>
          {activeTab === 'connections' && (
            <motion.div
              layoutId="activeTab"
              className="absolute bottom-0 left-0 right-0 h-0.5 bg-prava-accent rounded-full"
            />
          )}
        </button>
      </div>

      {/* Content */}
      <AnimatePresence mode="wait">
        {activeTab === 'activity' ? (
          <motion.div
            key="activity"
            initial={{ opacity: 0, y: 10 }}
            animate={{ opacity: 1, y: 0 }}
            exit={{ opacity: 0, y: -10 }}
            transition={{ duration: 0.2 }}
          >
            <GlassCard className="text-center py-12">
              <div className="inline-flex p-4 rounded-full bg-prava-accent/10 mb-4">
                <Shield className="w-8 h-8 text-prava-accent" />
              </div>
              <h3 className="text-h3 text-prava-light-text-primary dark:text-prava-dark-text-primary mb-2">
                Secured Activity
              </h3>
              <p className="text-body text-prava-light-text-secondary dark:text-prava-dark-text-secondary max-w-sm mx-auto">
                User activity is encrypted. Only mutual connections may see detailed post history.
              </p>
            </GlassCard>
          </motion.div>
        ) : (
          <motion.div
            key="connections"
            initial={{ opacity: 0, y: 10 }}
            animate={{ opacity: 1, y: 0 }}
            exit={{ opacity: 0, y: -10 }}
            transition={{ duration: 0.2 }}
            className="grid grid-cols-1 sm:grid-cols-2 gap-4"
          >
            {connections.length > 0 ? (
              connections.map(conn => (
                <GlassCard key={conn.id} className="flex items-center gap-3 p-3">
                  <div className="w-12 h-12 rounded-full bg-prava-accent/15 flex items-center justify-center shrink-0">
                    <span className="text-prava-accent font-bold">{conn.displayName.charAt(0)}</span>
                  </div>
                  <div className="flex-1 min-w-0">
                    <h4 className="font-semibold text-prava-light-text-primary dark:text-prava-dark-text-primary truncate">
                      {conn.displayName}
                    </h4>
                    <p className="text-caption text-prava-light-text-tertiary dark:text-prava-dark-text-tertiary truncate">
                      @{conn.username}
                    </p>
                  </div>
                  <Link to={`/profile/${conn.id}`} className="p-2 hover:bg-prava-light-bg dark:hover:bg-prava-dark-bg rounded-full transition-colors">
                    <Share2 className="w-4 h-4 text-prava-light-text-secondary dark:text-prava-dark-text-secondary" />
                  </Link>
                </GlassCard>
              ))
            ) : (
              <div className="col-span-full text-center py-8 text-prava-light-text-tertiary dark:text-prava-dark-text-tertiary">
                No connections yet.
              </div>
            )}
          </motion.div>
        )}
      </AnimatePresence>
    </div>
  );
}
