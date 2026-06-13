import { FormEvent, useEffect, useMemo, useState } from 'react';
import { Link, useSearchParams } from 'react-router-dom';
import { motion } from 'framer-motion';
import { Clock, FileText, Hash, Search as SearchIcon, Users, X } from 'lucide-react';
import {
  SmartHashtagResult,
  SmartPostSearchResult,
  SmartSearchResponse,
  UserSearchResult,
  usersService,
} from '../../services/users-service';
import { smartToast } from '../../ui-system/components/SmartToast';
import { timeAgo } from '../../utils/date-utils';

type SearchCategory = 'accounts' | 'hashtags' | 'posts';

const RECENT_SEARCH_KEY = 'prava:web:recent-searches';

const emptyResults: SmartSearchResponse = {
  accounts: [],
  hashtags: [],
  posts: [],
};

function loadRecentSearches(): string[] {
  try {
    const stored = window.localStorage.getItem(RECENT_SEARCH_KEY);
    const parsed = stored ? JSON.parse(stored) : [];
    return Array.isArray(parsed) ? parsed.filter((item) => typeof item === 'string').slice(0, 8) : [];
  } catch { return []; }
}

function saveRecentSearches(items: string[]) {
  window.localStorage.setItem(RECENT_SEARCH_KEY, JSON.stringify(items.slice(0, 8)));
}

function relationshipLabel(user: UserSearchResult) {
  if (user.isFollowing && user.isFollowedBy) return 'Message';
  if (user.isFollowing) return 'Following';
  if (user.isFollowedBy) return 'Follow back';
  return 'Follow';
}

function postPreview(body: string) {
  return body.length > 130 ? `${body.slice(0, 127).trim()}...` : body;
}

export default function SearchPage() {
  const [searchParams, setSearchParams] = useSearchParams();
  const [query, setQuery] = useState(searchParams.get('q') ?? '');
  const [results, setResults] = useState<SmartSearchResponse>(emptyResults);
  const [recentSearches, setRecentSearches] = useState<string[]>(() => loadRecentSearches());
  const [activeCategory, setActiveCategory] = useState<SearchCategory>('accounts');
  const [loading, setLoading] = useState(false);

  const trimmedQuery = query.trim();
  const categories = useMemo(
    () => [
      { id: 'accounts' as const, label: 'Accounts', icon: Users, count: results.accounts.length },
      { id: 'hashtags' as const, label: 'Tags', icon: Hash, count: results.hashtags.length },
      { id: 'posts' as const, label: 'Posts', icon: FileText, count: results.posts.length },
    ],
    [results]
  );

  useEffect(() => {
    const next = query.trim();
    if (next) { setSearchParams({ q: next }, { replace: true }); }
    else { setSearchParams({}, { replace: true }); }
  }, [query, setSearchParams]);

  useEffect(() => {
    if (trimmedQuery.length < 2) { setResults(emptyResults); setLoading(false); return; }
    let cancelled = false;
    setLoading(true);
    const timer = window.setTimeout(async () => {
      try {
        const data = await usersService.smartSearch(trimmedQuery, 10);
        if (!cancelled) setResults(data);
      } catch {
        if (!cancelled) { smartToast.error('Search failed'); setResults(emptyResults); }
      } finally { if (!cancelled) setLoading(false); }
    }, 250);
    return () => { cancelled = true; window.clearTimeout(timer); };
  }, [trimmedQuery]);

  useEffect(() => {
    const current = categories.find((c) => c.id === activeCategory);
    if (current && current.count > 0) return;
    const first = categories.find((c) => c.count > 0);
    if (first) setActiveCategory(first.id);
  }, [activeCategory, categories]);

  const rememberSearch = (value = trimmedQuery) => {
    const n = value.trim();
    if (n.length < 2) return;
    setRecentSearches((prev) => {
      const next = [n, ...prev.filter((i) => i.toLowerCase() !== n.toLowerCase())].slice(0, 8);
      saveRecentSearches(next);
      return next;
    });
  };

  const removeRecentSearch = (value: string) => {
    setRecentSearches((prev) => {
      const next = prev.filter((i) => i !== value);
      saveRecentSearches(next);
      return next;
    });
  };

  const handleSubmit = (event: FormEvent) => { event.preventDefault(); rememberSearch(); };

  const handleToggleFollow = async (userId: string) => {
    try {
      const result = await usersService.toggleFollow(userId);
      setResults((prev) => ({
        ...prev,
        accounts: prev.accounts.map((item) =>
          item.id === userId ? { ...item, isFollowing: result.following } : item
        ),
      }));
    } catch { smartToast.error('Unable to update follow status'); }
  };

  return (
    <div className="mx-auto max-w-2xl pb-8">
      <motion.div
        initial={{ opacity: 0, y: 6 }}
        animate={{ opacity: 1, y: 0 }}
        transition={{ duration: 0.35 }}
        className="app-page-header"
      >
        <h1 className="app-page-title">Search</h1>
      </motion.div>

      {/* Search Input */}
      <motion.form
        initial={{ opacity: 0, y: 6 }}
        animate={{ opacity: 1, y: 0 }}
        transition={{ duration: 0.35, delay: 0.05 }}
        style={{ marginBottom: 16 }}
        onSubmit={handleSubmit}
      >
        <div className="app-search-wrap">
          <SearchIcon size={16} />
          <input
            className="app-search-input"
            placeholder="Search Prava"
            value={query}
            onChange={(e) => setQuery(e.target.value)}
          />
        </div>
      </motion.form>

      {/* Category pills */}
      {trimmedQuery.length >= 2 && (
        <motion.div
          initial={{ opacity: 0, y: 6 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.3, delay: 0.1 }}
          style={{ display: 'flex', gap: 6, marginBottom: 16, overflowX: 'auto' }}
        >
          {categories.map((cat) => {
            const Icon = cat.icon;
            const isActive = activeCategory === cat.id;
            return (
              <button
                key={cat.id}
                onClick={() => setActiveCategory(cat.id)}
                className={`app-btn app-btn--sm ${isActive ? 'app-btn--primary' : 'app-btn--ghost'}`}
              >
                <Icon size={13} /> {cat.label} {cat.count}
              </button>
            );
          })}
        </motion.div>
      )}

      {/* Recent searches */}
      {!trimmedQuery && (
        <motion.section
          initial={{ opacity: 0, y: 6 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.35, delay: 0.1 }}
        >
          <div style={{ display: 'flex', alignItems: 'center', gap: 6, marginBottom: 8 }}>
            <Clock size={13} style={{ color: 'var(--text-tertiary)' }} />
            <span style={{
              fontSize: 11, fontWeight: 700, textTransform: 'uppercase' as const,
              letterSpacing: '0.08em', color: 'var(--text-tertiary)',
            }}>Recent Searches</span>
          </div>
          {recentSearches.length === 0 ? (
            <p style={{ textAlign: 'center', padding: '24px 0', fontSize: 13, color: 'var(--text-secondary)' }}>
              No recent searches
            </p>
          ) : (
            <div style={{ display: 'flex', flexDirection: 'column', gap: 2 }}>
              {recentSearches.map((search) => (
                <div key={search} style={{ display: 'flex', alignItems: 'center', gap: 4 }}>
                  <button
                    onClick={() => setQuery(search)}
                    className="app-list-item"
                    style={{ flex: 1, textAlign: 'left' }}
                  >
                    <SearchIcon size={14} style={{ color: 'var(--text-tertiary)' }} />
                    <span style={{ fontSize: 14, color: 'var(--text-primary)' }}>{search}</span>
                  </button>
                  <button
                    onClick={() => removeRecentSearch(search)}
                    className="app-btn app-btn--icon app-btn--ghost"
                    style={{ width: 28, height: 28 }}
                  >
                    <X size={13} />
                  </button>
                </div>
              ))}
            </div>
          )}
        </motion.section>
      )}

      {/* Results */}
      {trimmedQuery.length >= 2 && (
        <motion.section
          initial={{ opacity: 0, y: 6 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.25 }}
        >
          {loading ? (
            <div style={{ display: 'flex', justifyContent: 'center', padding: '40px 0' }}>
              <div className="w-6 h-6 animate-spin rounded-full border-2 border-prava-accent border-t-transparent" />
            </div>
          ) : (
            <>
              {activeCategory === 'accounts' && (
                <AccountsResults users={results.accounts} onToggleFollow={handleToggleFollow} onOpen={rememberSearch} />
              )}
              {activeCategory === 'hashtags' && (
                <HashtagResults hashtags={results.hashtags} onOpen={rememberSearch} />
              )}
              {activeCategory === 'posts' && (
                <PostResults posts={results.posts} onOpen={rememberSearch} />
              )}
            </>
          )}
        </motion.section>
      )}
    </div>
  );
}

function AccountsResults({ users, onToggleFollow, onOpen }: {
  users: UserSearchResult[];
  onToggleFollow: (userId: string) => void;
  onOpen: () => void;
}) {
  if (users.length === 0) return <EmptyState label="No accounts found" />;

  return (
    <div style={{ display: 'flex', flexDirection: 'column', gap: 2 }}>
      {users.map((user) => (
        <Link
          key={user.id}
          to={`/profile/${user.id}`}
          onClick={() => onOpen()}
          className="app-list-item"
          style={{ textDecoration: 'none' }}
        >
          {user.avatarUrl ? (
            <img src={user.avatarUrl} alt="" style={{ width: 40, height: 40, borderRadius: '50%', objectFit: 'cover' }} />
          ) : (
            <div className="app-list-item__avatar">{user.displayName.charAt(0).toUpperCase()}</div>
          )}
          <div className="app-list-item__body">
            <div className="app-list-item__name">{user.displayName}</div>
            <div className="app-list-item__meta">@{user.username}</div>
          </div>
          <button
            onClick={(e) => {
              e.preventDefault(); e.stopPropagation();
              if (user.isFollowing && user.isFollowedBy) { smartToast.info('Open chats to message'); }
              else { onToggleFollow(user.id); }
            }}
            className={`app-btn app-btn--sm ${
              user.isFollowing && !user.isFollowedBy ? 'app-btn--ghost' : 'app-btn--primary'
            }`}
          >
            {relationshipLabel(user)}
          </button>
        </Link>
      ))}
    </div>
  );
}

function HashtagResults({ hashtags, onOpen }: { hashtags: SmartHashtagResult[]; onOpen: () => void }) {
  if (hashtags.length === 0) return <EmptyState label="No hashtags found" />;

  return (
    <div style={{ display: 'flex', flexDirection: 'column', gap: 2 }}>
      {hashtags.map((item) => (
        <Link
          key={item.tag}
          to={`/feed?tag=${encodeURIComponent(item.tag)}`}
          onClick={() => onOpen()}
          className="app-list-item"
          style={{ textDecoration: 'none' }}
        >
          <div className="app-list-item__avatar" style={{ background: 'var(--p-brand-subtle)', color: 'var(--p-brand)' }}>
            <Hash size={16} />
          </div>
          <div className="app-list-item__body">
            <div className="app-list-item__name">#{item.tag}</div>
            <div className="app-list-item__meta">{item.postCount} posts</div>
          </div>
        </Link>
      ))}
    </div>
  );
}

function PostResults({ posts, onOpen }: { posts: SmartPostSearchResult[]; onOpen: () => void }) {
  if (posts.length === 0) return <EmptyState label="No posts found" />;

  return (
    <div style={{ display: 'flex', flexDirection: 'column', gap: 6 }}>
      {posts.map((post) => (
        <Link
          key={post.id}
          to={`/post/${post.id}`}
          onClick={() => onOpen()}
          className="app-list-item"
          style={{ textDecoration: 'none', alignItems: 'flex-start', padding: '10px 14px' }}
        >
          {post.author.avatarUrl ? (
            <img src={post.author.avatarUrl} alt="" style={{ width: 36, height: 36, borderRadius: '50%', objectFit: 'cover' }} />
          ) : (
            <div className="app-list-item__avatar" style={{ width: 36, height: 36, fontSize: 13 }}>
              {post.author.displayName.charAt(0).toUpperCase()}
            </div>
          )}
          <div className="app-list-item__body">
            <div className="app-list-item__name" style={{ fontSize: 13 }}>
              {post.author.displayName}
              <span className="app-list-item__meta" style={{ marginLeft: 6 }}>
                @{post.author.username} · {timeAgo(post.createdAt)}
              </span>
            </div>
            <p style={{ fontSize: 13, color: 'var(--text-primary)', marginTop: 2, lineHeight: 1.4 }}>
              {postPreview(post.body)}
            </p>
            <p className="app-list-item__meta" style={{ marginTop: 4 }}>
              {post.likeCount} likes · {post.commentCount} comments · {post.shareCount} shares
            </p>
          </div>
        </Link>
      ))}
    </div>
  );
}

function EmptyState({ label }: { label: string }) {
  return (
    <div className="app-empty">
      <div className="app-empty__icon"><SearchIcon size={20} /></div>
      <h3 className="app-empty__title">{label}</h3>
    </div>
  );
}
