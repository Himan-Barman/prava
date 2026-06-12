import { useEffect, useState } from 'react';
import { motion, AnimatePresence } from 'framer-motion';
import { Link, useParams } from 'react-router-dom';
import { Settings, Shield, Users, MessageCircle, Share2, UserPlus, UserCheck } from 'lucide-react';
import { usersService } from '../../services/users-service';
import { profileService } from '../../services/profile-service';
import { publicProfileService } from '../../services/public-profile-service';
import { friendsService, FriendConnectionItem } from '../../services/friends-service';
import { useAuth } from '../../context/auth-context';
import { smartToast } from '../../ui-system/components/SmartToast';

type ProfileView = {
  user: { id: string; username: string; displayName: string; bio?: string };
  stats: { posts: number; followers: number; following: number; likes?: number };
  relationship?: { isFollowing: boolean; isFollowedBy: boolean };
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

  useEffect(() => { if (userId) loadProfile(); }, [userId]);

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
    } finally { setLoading(false); }
  };

  useEffect(() => {
    if (activeTab === 'connections' && isOwnProfile && connections.length === 0) {
      friendsService.getConnections().then((data) => setConnections(data.friends)).catch(console.error);
    }
  }, [activeTab, isOwnProfile]);

  const handleToggleFollow = async () => {
    if (!profile?.user?.id) return;
    try {
      const next = !profile.relationship?.isFollowing;
      await usersService.setFollow(profile.user.id, next);
      setProfile((prev) => prev ? {
        ...prev,
        relationship: { isFollowing: next, isFollowedBy: prev.relationship?.isFollowedBy ?? false },
      } : prev);
    } catch { smartToast.error('Unable to update follow status'); }
  };

  if (loading && !profile) {
    return <div className="p-page" style={{ display: 'flex', justifyContent: 'center', paddingTop: 48 }}><div className="p-spinner" /></div>;
  }

  if (!profile) {
    return <div className="p-page p-empty"><p className="p-empty__title">User not found</p></div>;
  }

  return (
    <div className="p-page">
      <motion.div initial={{ opacity: 0, y: 6 }} animate={{ opacity: 1, y: 0 }} transition={{ duration: 0.3 }}>
        <div className="p-profile">
          <div className="p-profile__cover" />
          <div className="p-profile__info">
            <div className="p-profile__avatar">{profile.user.displayName.charAt(0)}</div>
            <h1 className="p-profile__name">{profile.user.displayName}</h1>
            <p className="p-profile__handle">@{profile.user.username}</p>
            {profile.user.bio && <p className="p-profile__bio">{profile.user.bio}</p>}
            <div style={{ display: 'flex', gap: 8, marginTop: 12 }}>
              {isOwnProfile ? (
                <Link to="/settings" className="p-btn p-btn--secondary"><Settings size={15} /> Settings</Link>
              ) : (
                <>
                  <button onClick={handleToggleFollow} className="p-btn p-btn--primary">
                    {profile.relationship?.isFollowing ? <UserCheck size={14} /> : <UserPlus size={14} />}
                    {profile.relationship?.isFollowing ? 'Following' : 'Follow'}
                  </button>
                  <button className="p-btn p-btn--secondary p-btn--icon"><MessageCircle size={16} /></button>
                </>
              )}
            </div>
          </div>
        </div>
      </motion.div>

      <motion.div initial={{ opacity: 0, y: 6 }} animate={{ opacity: 1, y: 0 }} transition={{ duration: 0.3, delay: 0.06 }} className="p-stats" style={{ marginTop: 16 }}>
        {[
          { label: 'Following', value: profile.stats.following },
          { label: 'Followers', value: profile.stats.followers },
          { label: 'Posts', value: profile.stats.posts },
        ].map((s) => (
          <div key={s.label} className="p-stat">
            <div className="p-stat__value">{s.value}</div>
            <div className="p-stat__label">{s.label}</div>
          </div>
        ))}
      </motion.div>

      <div className="p-utabs" style={{ marginTop: 16 }}>
        <button onClick={() => setActiveTab('activity')} className={`p-utab ${activeTab === 'activity' ? 'p-utab--active' : ''}`}>Activity</button>
        <button onClick={() => setActiveTab('connections')} className={`p-utab ${activeTab === 'connections' ? 'p-utab--active' : ''}`}>Connections</button>
      </div>

      <AnimatePresence mode="wait">
        {activeTab === 'activity' ? (
          <motion.div key="activity" initial={{ opacity: 0, y: 6 }} animate={{ opacity: 1, y: 0 }} exit={{ opacity: 0, y: -6 }} transition={{ duration: 0.18 }}>
            <div className="p-empty">
              <div className="p-empty__icon"><Shield size={22} /></div>
              <h3 className="p-empty__title">Secured Activity</h3>
              <p className="p-empty__desc">User activity is encrypted. Only mutual connections may see detailed post history.</p>
            </div>
          </motion.div>
        ) : (
          <motion.div key="connections" initial={{ opacity: 0, y: 6 }} animate={{ opacity: 1, y: 0 }} exit={{ opacity: 0, y: -6 }} transition={{ duration: 0.18 }}>
            {connections.length > 0 ? (
              <div style={{ display: 'flex', flexDirection: 'column', gap: 2 }}>
                {connections.map((c) => (
                  <Link key={c.id} to={`/profile/${c.id}`} className="p-list-item">
                    <div className="p-avatar p-avatar--md">{c.displayName.charAt(0)}</div>
                    <div className="p-list-item__body">
                      <div className="p-list-item__name">{c.displayName}</div>
                      <div className="p-list-item__meta">@{c.username}</div>
                    </div>
                    <Share2 size={14} style={{ color: 'var(--p-text-muted)' }} />
                  </Link>
                ))}
              </div>
            ) : (
              <div className="p-empty">
                <div className="p-empty__icon"><Users size={20} /></div>
                <h3 className="p-empty__title">No connections yet</h3>
                <p className="p-empty__desc">Connect with people to see them here.</p>
              </div>
            )}
          </motion.div>
        )}
      </AnimatePresence>
    </div>
  );
}
