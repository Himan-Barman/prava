import { useEffect, useMemo, useState } from 'react';
import { motion, AnimatePresence } from 'framer-motion';
import { Link, useParams } from 'react-router-dom';
import {
  BarChart3,
  CheckCircle2,
  ExternalLink,
  FileText,
  Link as LinkIcon,
  MapPin,
  MessageCircle,
  Shield,
  UserCheck,
  UserPlus,
} from 'lucide-react';
import { usersService } from '../../services/users-service';
import { profileService, type ProfileFeedPost } from '../../services/profile-service';
import { publicProfileService, type PublicProfilePost } from '../../services/public-profile-service';
import { useAuth } from '../../context/auth-context';
import { smartToast } from '../../ui-system/components/SmartToast';
import { timeAgo } from '../../utils/date-utils';

type ProfilePost = ProfileFeedPost | PublicProfilePost;

type ProfileView = {
  user: {
    id: string;
    username: string;
    displayName: string;
    bio?: string;
    location?: string;
    website?: string;
    isVerified?: boolean;
    avatarUrl?: string;
  };
  stats: { posts: number; followers: number; following: number; likes?: number };
  posts: ProfilePost[];
  liked?: ProfilePost[];
  relationship?: { isFollowing: boolean; isFollowedBy: boolean };
};

type ProfileTab = 'posts' | 'mentions' | 'details' | 'links';

function initials(name: string) {
  return (name.trim().charAt(0) || 'P').toUpperCase();
}

function compactNumber(value: number) {
  if (value >= 1_000_000) return `${(value / 1_000_000).toFixed(value >= 10_000_000 ? 0 : 1)}M`;
  if (value >= 1_000) return `${(value / 1_000).toFixed(value >= 10_000 ? 0 : 1)}K`;
  return String(value);
}

export default function ProfilePage() {
  const { user: currentUser } = useAuth();
  const { id } = useParams<{ id: string }>();
  const isOwnProfile = !id || id === currentUser?.id;
  const userId = id || currentUser?.id;

  const [profile, setProfile] = useState<ProfileView | null>(null);
  const [loading, setLoading] = useState(true);
  const [activeTab, setActiveTab] = useState<ProfileTab>('posts');

  useEffect(() => {
    if (userId) {
      void loadProfile();
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [userId, isOwnProfile]);

  const loadProfile = async () => {
    try {
      setLoading(true);
      if (isOwnProfile) {
        const data = await profileService.fetchMyProfile(24);
        setProfile({
          user: data.user,
          stats: data.stats,
          posts: data.posts ?? [],
          liked: data.liked ?? [],
        });
      } else if (userId) {
        const data = await publicProfileService.fetchProfile(userId, 24);
        setProfile({
          user: data.user,
          stats: data.stats,
          posts: data.posts ?? [],
          relationship: data.relationship,
        });
      }
    } catch (error) {
      console.error('Failed to load profile:', error);
      smartToast.error('Failed to load profile');
    } finally {
      setLoading(false);
    }
  };

  const handleToggleFollow = async () => {
    if (!profile?.user?.id) return;
    try {
      const next = !profile.relationship?.isFollowing;
      await usersService.setFollow(profile.user.id, next);
      setProfile((prev) => prev ? {
        ...prev,
        relationship: {
          isFollowing: next,
          isFollowedBy: prev.relationship?.isFollowedBy ?? false,
        },
        stats: {
          ...prev.stats,
          followers: Math.max(prev.stats.followers + (next ? 1 : -1), 0),
        },
      } : prev);
    } catch {
      smartToast.error('Unable to update follow status');
    }
  };

  const mentionPosts = useMemo(() => {
    if (!profile?.user.username) return [];
    const mention = `@${profile.user.username.toLowerCase()}`;
    return [...profile.posts, ...(profile.liked ?? [])]
      .filter((post, index, all) => all.findIndex((item) => item.id === post.id) === index)
      .filter((post) => post.body.toLowerCase().includes(mention));
  }, [profile]);

  if (loading && !profile) {
    return (
      <div className="p-page" style={{ display: 'flex', justifyContent: 'center', paddingTop: 48 }}>
        <div className="p-spinner" />
      </div>
    );
  }

  if (!profile) {
    return (
      <div className="p-page p-empty">
        <p className="p-empty__title">User not found</p>
      </div>
    );
  }

  const tabs: Array<{ id: ProfileTab; label: string }> = isOwnProfile
    ? [
        { id: 'posts', label: 'Posts' },
        { id: 'mentions', label: 'Mentions' },
        { id: 'details', label: 'Details' },
        { id: 'links', label: 'Links' },
      ]
    : [
        { id: 'posts', label: 'Posts' },
        { id: 'details', label: 'Details' },
        { id: 'links', label: 'Links' },
      ];

  return (
    <div className="p-page">
      <motion.section
        initial={{ opacity: 0, y: 6 }}
        animate={{ opacity: 1, y: 0 }}
        transition={{ duration: 0.26 }}
        className="p-profile p-profile--simple"
      >
        <div className="p-profile__info">
          <div className="p-profile__avatar">
            {profile.user.avatarUrl ? (
              <img src={profile.user.avatarUrl} alt="" style={{ width: '100%', height: '100%', objectFit: 'cover', borderRadius: 'inherit' }} />
            ) : (
              initials(profile.user.displayName)
            )}
          </div>
          <div className="p-profile__identity">
            <div className="p-profile__name-row">
              <h1 className="p-profile__name" style={{ marginTop: 0 }}>{profile.user.displayName}</h1>
              {profile.user.isVerified && <CheckCircle2 className="p-profile__verified" strokeWidth={3} fill="currentColor" />}
            </div>
            <p className="p-profile__handle">@{profile.user.username}</p>
            {profile.user.bio && <p className="p-profile__bio">{profile.user.bio}</p>}
            <div className="p-profile__meta">
              {profile.user.location && (
                <span style={{ display: 'inline-flex', alignItems: 'center', gap: 5 }}>
                  <MapPin size={14} strokeWidth={2.7} />
                  {profile.user.location}
                </span>
              )}
              {profile.user.website && (
                <a
                  href={profile.user.website.startsWith('http') ? profile.user.website : `https://${profile.user.website}`}
                  target="_blank"
                  rel="noreferrer"
                  style={{ display: 'inline-flex', alignItems: 'center', gap: 5, color: 'var(--p-brand)', textDecoration: 'none' }}
                >
                  <ExternalLink size={14} strokeWidth={2.7} />
                  Website
                </a>
              )}
            </div>
            {!isOwnProfile && (
              <div className="p-profile__action-row">
                <button type="button" onClick={handleToggleFollow} className="p-btn p-btn--primary p-btn--sm">
                  {profile.relationship?.isFollowing ? <UserCheck size={14} /> : <UserPlus size={14} />}
                  {profile.relationship?.isFollowing ? 'Following' : profile.relationship?.isFollowedBy ? 'Follow back' : 'Follow'}
                </button>
                <Link to="/chats" className="p-btn p-btn--secondary p-btn--sm">
                  <MessageCircle size={14} />
                  Message
                </Link>
              </div>
            )}
          </div>
        </div>

        <div className="p-stats" style={{ marginTop: 16 }}>
          {[
            { label: 'Posts', value: profile.stats.posts },
            { label: 'Followers', value: profile.stats.followers },
            { label: 'Following', value: profile.stats.following },
          ].map((stat) => (
            <div key={stat.label} className="p-stat">
              <div className="p-stat__value">{compactNumber(stat.value)}</div>
              <div className="p-stat__label">{stat.label}</div>
            </div>
          ))}
        </div>

        {isOwnProfile && (
          <Link to="/settings/creator" className="p-profile-dashboard">
            <span style={{ display: 'inline-flex', alignItems: 'center', gap: 8 }}>
              <BarChart3 size={18} strokeWidth={2.8} />
              Dashboard
            </span>
            <span style={{ color: 'var(--p-text-muted)', fontSize: 'var(--p-text-caption)' }}>
              Post analytics
            </span>
          </Link>
        )}
      </motion.section>

      <div className="p-utabs" style={{ marginTop: 16 }}>
        {tabs.map((tab) => (
          <button
            key={tab.id}
            type="button"
            onClick={() => setActiveTab(tab.id)}
            className={`p-utab ${activeTab === tab.id ? 'p-utab--active' : ''}`}
          >
            {tab.label}
          </button>
        ))}
      </div>

      <AnimatePresence mode="wait">
        <motion.div
          key={activeTab}
          initial={{ opacity: 0, y: 6 }}
          animate={{ opacity: 1, y: 0 }}
          exit={{ opacity: 0, y: -6 }}
          transition={{ duration: 0.18 }}
          style={{ marginTop: 14 }}
        >
          {activeTab === 'posts' && <PostList posts={profile.posts} emptyTitle="No posts yet" />}
          {activeTab === 'mentions' && <PostList posts={mentionPosts} emptyTitle="No mentions yet" />}
          {activeTab === 'details' && <Details profile={profile} />}
          {activeTab === 'links' && <LinksPanel profile={profile} />}
        </motion.div>
      </AnimatePresence>
    </div>
  );
}

function PostList({ posts, emptyTitle }: { posts: ProfilePost[]; emptyTitle: string }) {
  if (posts.length === 0) {
    return (
      <div className="p-empty">
        <div className="p-empty__icon"><FileText size={20} /></div>
        <h3 className="p-empty__title">{emptyTitle}</h3>
        <p className="p-empty__desc">Posts will appear here when available.</p>
      </div>
    );
  }

  return (
    <div style={{ display: 'flex', flexDirection: 'column', gap: 8 }}>
      {posts.map((post) => (
        <Link key={post.id} to={`/post/${post.id}`} className="p-card" style={{ color: 'inherit', textDecoration: 'none' }}>
          <p style={{ color: 'var(--p-text-primary)', fontSize: 'var(--p-text-body)', lineHeight: 1.45 }}>
            {post.body.length > 220 ? `${post.body.slice(0, 217).trim()}...` : post.body}
          </p>
          <p className="p-list-item__meta" style={{ marginTop: 8 }}>
            {timeAgo(post.createdAt)} - {post.likeCount} likes - {post.commentCount} comments - {post.shareCount} shares
          </p>
        </Link>
      ))}
    </div>
  );
}

function Details({ profile }: { profile: ProfileView }) {
  return (
    <div className="settings-section-stack">
      <section>
        <p className="p-section-label">Category</p>
        <div className="settings-control-list">
          <div className="settings-control-row">
            <span className="settings-control-row__icon"><Shield size={20} strokeWidth={2.8} /></span>
            <span className="settings-control-row__body">
              <strong>Personal profile</strong>
              <small>Standard Prava account</small>
            </span>
          </div>
        </div>
      </section>
      <section>
        <p className="p-section-label">Personal details</p>
        <div className="settings-control-list">
          <InfoRow label="Full name" value={profile.user.displayName} />
          <InfoRow label="Username" value={`@${profile.user.username}`} />
          <InfoRow label="Location" value={profile.user.location || 'Not added'} />
        </div>
      </section>
    </div>
  );
}

function LinksPanel({ profile }: { profile: ProfileView }) {
  return (
    <section>
      <p className="p-section-label">Links</p>
      <div className="settings-control-list">
        <div className="settings-control-row">
          <span className="settings-control-row__icon"><LinkIcon size={20} strokeWidth={2.8} /></span>
          <span className="settings-control-row__body">
            <strong>Website</strong>
            <small>{profile.user.website || 'No link added'}</small>
          </span>
          {profile.user.website && (
            <a
              className="p-btn p-btn--ghost p-btn--sm"
              href={profile.user.website.startsWith('http') ? profile.user.website : `https://${profile.user.website}`}
              target="_blank"
              rel="noreferrer"
            >
              Open
            </a>
          )}
        </div>
      </div>
    </section>
  );
}

function InfoRow({ label, value }: { label: string; value: string }) {
  return (
    <div className="settings-control-row">
      <span className="settings-control-row__body">
        <strong>{label}</strong>
        <small>{value}</small>
      </span>
    </div>
  );
}
