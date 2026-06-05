import { FormEvent, useEffect, useMemo, useState } from 'react';
import { Link, useSearchParams } from 'react-router-dom';
import { motion } from 'framer-motion';
import { Clock, FileText, Hash, Search as SearchIcon, Users, X } from 'lucide-react';
import { PravaInput } from '../../ui-system';
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
  } catch {
    return [];
  }
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
      { id: 'hashtags' as const, label: 'Hashtags', icon: Hash, count: results.hashtags.length },
      { id: 'posts' as const, label: 'Posts', icon: FileText, count: results.posts.length },
    ],
    [results]
  );

  useEffect(() => {
    const next = query.trim();
    if (next) {
      setSearchParams({ q: next }, { replace: true });
    } else {
      setSearchParams({}, { replace: true });
    }
  }, [query, setSearchParams]);

  useEffect(() => {
    if (trimmedQuery.length < 2) {
      setResults(emptyResults);
      setLoading(false);
      return;
    }

    let cancelled = false;
    setLoading(true);
    const timer = window.setTimeout(async () => {
      try {
        const data = await usersService.smartSearch(trimmedQuery, 10);
        if (!cancelled) {
          setResults(data);
        }
      } catch (error) {
        if (!cancelled) {
          smartToast.error('Search failed');
          setResults(emptyResults);
        }
      } finally {
        if (!cancelled) {
          setLoading(false);
        }
      }
    }, 250);

    return () => {
      cancelled = true;
      window.clearTimeout(timer);
    };
  }, [trimmedQuery]);

  useEffect(() => {
    const current = categories.find((category) => category.id === activeCategory);
    if (current && current.count > 0) return;
    const firstWithResults = categories.find((category) => category.count > 0);
    if (firstWithResults) {
      setActiveCategory(firstWithResults.id);
    }
  }, [activeCategory, categories]);

  const rememberSearch = (value = trimmedQuery) => {
    const normalized = value.trim();
    if (normalized.length < 2) return;
    setRecentSearches((prev) => {
      const next = [normalized, ...prev.filter((item) => item.toLowerCase() !== normalized.toLowerCase())].slice(0, 8);
      saveRecentSearches(next);
      return next;
    });
  };

  const removeRecentSearch = (value: string) => {
    setRecentSearches((prev) => {
      const next = prev.filter((item) => item !== value);
      saveRecentSearches(next);
      return next;
    });
  };

  const handleSubmit = (event: FormEvent) => {
    event.preventDefault();
    rememberSearch();
  };

  const handleToggleFollow = async (userId: string) => {
    try {
      const result = await usersService.toggleFollow(userId);
      setResults((prev) => ({
        ...prev,
        accounts: prev.accounts.map((item) =>
          item.id === userId ? { ...item, isFollowing: result.following } : item
        ),
      }));
    } catch {
      smartToast.error('Unable to update follow status');
    }
  };

  return (
    <div className="mx-auto max-w-2xl pb-8">
      <motion.div
        initial={{ opacity: 0, y: 8 }}
        animate={{ opacity: 1, y: 0 }}
        transition={{ duration: 0.4 }}
        className="mb-5"
      >
        <h1 className="text-h1 text-prava-light-text-primary dark:text-prava-dark-text-primary">
          Search
        </h1>
      </motion.div>

      <motion.form
        initial={{ opacity: 0, y: 8 }}
        animate={{ opacity: 1, y: 0 }}
        transition={{ duration: 0.4, delay: 0.1 }}
        className="mb-5"
        onSubmit={handleSubmit}
      >
        <PravaInput
          placeholder="Search Prava"
          value={query}
          onChange={(event) => setQuery(event.target.value)}
        />
      </motion.form>

      {trimmedQuery.length >= 2 && (
        <motion.div
          initial={{ opacity: 0, y: 8 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.4, delay: 0.15 }}
          className="mb-6 overflow-x-auto"
        >
          <div className="flex min-w-max gap-2">
            {categories.map((category) => {
              const Icon = category.icon;
              const isActive = activeCategory === category.id;
              return (
                <button
                  key={category.id}
                  type="button"
                  onClick={() => setActiveCategory(category.id)}
                  className={`inline-flex items-center gap-2 rounded-full px-4 py-2.5 text-body-sm font-bold transition-colors ${
                    isActive
                      ? 'bg-prava-accent text-white'
                      : 'bg-prava-light-surface text-prava-light-text-secondary hover:text-prava-light-text-primary dark:bg-white/[0.08] dark:text-prava-dark-text-secondary dark:hover:text-white'
                  }`}
                >
                  <Icon className="h-4 w-4" strokeWidth={3} />
                  {category.label} {category.count}
                </button>
              );
            })}
          </div>
        </motion.div>
      )}

      {!trimmedQuery && (
        <motion.section
          initial={{ opacity: 0, y: 8 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.4, delay: 0.15 }}
        >
          <div className="mb-3 flex items-center gap-2">
            <Clock className="h-4 w-4 text-prava-light-text-tertiary dark:text-prava-dark-text-tertiary" strokeWidth={3} />
            <h2 className="text-label font-semibold uppercase tracking-wider text-prava-light-text-tertiary dark:text-prava-dark-text-tertiary">
              Recent Searches
            </h2>
          </div>
          {recentSearches.length === 0 ? (
            <p className="py-8 text-center text-body text-prava-light-text-secondary dark:text-prava-dark-text-secondary">
              No recent searches
            </p>
          ) : (
            <div className="space-y-1">
              {recentSearches.map((search) => (
                <div key={search} className="flex items-center gap-2 py-2">
                  <button
                    type="button"
                    onClick={() => setQuery(search)}
                    className="flex flex-1 items-center gap-3 rounded-[14px] py-2 text-left text-prava-light-text-primary transition-colors hover:bg-prava-light-surface dark:text-prava-dark-text-primary dark:hover:bg-white/[0.08]"
                  >
                    <SearchIcon className="h-4 w-4 text-prava-light-text-tertiary dark:text-prava-dark-text-tertiary" strokeWidth={3} />
                    <span className="text-body">{search}</span>
                  </button>
                  <button
                    type="button"
                    onClick={() => removeRecentSearch(search)}
                    className="grid h-9 w-9 place-items-center rounded-full text-prava-light-text-tertiary transition-colors hover:bg-prava-light-surface dark:text-prava-dark-text-tertiary dark:hover:bg-white/[0.08]"
                    aria-label={`Remove ${search}`}
                  >
                    <X className="h-4 w-4" strokeWidth={3} />
                  </button>
                </div>
              ))}
            </div>
          )}
        </motion.section>
      )}

      {trimmedQuery.length >= 2 && (
        <motion.section
          initial={{ opacity: 0, y: 8 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.3 }}
        >
          {loading ? (
            <div className="flex items-center justify-center py-16">
              <div className="h-8 w-8 animate-spin rounded-full border-2 border-prava-accent border-t-transparent" />
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

function AccountsResults({
  users,
  onToggleFollow,
  onOpen,
}: {
  users: UserSearchResult[];
  onToggleFollow: (userId: string) => void;
  onOpen: () => void;
}) {
  if (users.length === 0) return <EmptyState label="No accounts found" />;

  return (
    <div className="space-y-1">
      {users.map((user) => (
        <Link
          key={user.id}
          to={`/profile/${user.id}`}
          onClick={() => onOpen()}
          className="flex items-center gap-3 rounded-[18px] py-3 transition-colors hover:bg-prava-light-surface dark:hover:bg-white/[0.08]"
        >
          {user.avatarUrl ? (
            <img src={user.avatarUrl} alt="" className="h-12 w-12 rounded-full object-cover" />
          ) : (
            <span className="grid h-12 w-12 shrink-0 place-items-center rounded-full bg-prava-accent/15 text-lg font-bold text-prava-accent">
              {user.displayName.charAt(0).toUpperCase()}
            </span>
          )}
          <span className="min-w-0 flex-1">
            <span className="block truncate font-semibold text-prava-light-text-primary dark:text-prava-dark-text-primary">
              {user.displayName}
            </span>
            <span className="block truncate text-body-sm text-prava-light-text-tertiary dark:text-prava-dark-text-tertiary">
              @{user.username}
            </span>
          </span>
          <button
            type="button"
            onClick={(event) => {
              event.preventDefault();
              event.stopPropagation();
              if (user.isFollowing && user.isFollowedBy) {
                smartToast.info('Open chats to message');
              } else {
                onToggleFollow(user.id);
              }
            }}
            className={`shrink-0 rounded-full px-4 py-2 text-body-sm font-bold transition-colors ${
              user.isFollowing && !user.isFollowedBy
                ? 'bg-prava-light-surface text-prava-light-text-secondary dark:bg-white/[0.08] dark:text-prava-dark-text-secondary'
                : 'bg-prava-accent text-white'
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
    <div className="space-y-1">
      {hashtags.map((item) => (
        <Link
          key={item.tag}
          to={`/feed?tag=${encodeURIComponent(item.tag)}`}
          onClick={() => onOpen()}
          className="flex items-center gap-3 rounded-[18px] py-3 transition-colors hover:bg-prava-light-surface dark:hover:bg-white/[0.08]"
        >
          <span className="grid h-11 w-11 place-items-center rounded-full bg-prava-accent/15 text-prava-accent">
            <Hash className="h-5 w-5" strokeWidth={3} />
          </span>
          <span className="min-w-0 flex-1">
            <span className="block truncate font-semibold text-prava-light-text-primary dark:text-prava-dark-text-primary">
              #{item.tag}
            </span>
            <span className="block text-body-sm text-prava-light-text-tertiary dark:text-prava-dark-text-tertiary">
              {item.postCount} posts
            </span>
          </span>
        </Link>
      ))}
    </div>
  );
}

function PostResults({ posts, onOpen }: { posts: SmartPostSearchResult[]; onOpen: () => void }) {
  if (posts.length === 0) return <EmptyState label="No posts found" />;

  return (
    <div className="space-y-2">
      {posts.map((post) => (
        <Link
          key={post.id}
          to={`/post/${post.id}`}
          onClick={() => onOpen()}
          className="block rounded-[18px] py-3 transition-colors hover:bg-prava-light-surface dark:hover:bg-white/[0.08]"
        >
          <div className="mb-2 flex items-center gap-3">
            {post.author.avatarUrl ? (
              <img src={post.author.avatarUrl} alt="" className="h-9 w-9 rounded-full object-cover" />
            ) : (
              <span className="grid h-9 w-9 place-items-center rounded-full bg-prava-accent/15 text-sm font-bold text-prava-accent">
                {post.author.displayName.charAt(0).toUpperCase()}
              </span>
            )}
            <span className="min-w-0">
              <span className="block truncate font-semibold text-prava-light-text-primary dark:text-prava-dark-text-primary">
                {post.author.displayName}
              </span>
              <span className="block truncate text-body-sm text-prava-light-text-tertiary dark:text-prava-dark-text-tertiary">
                @{post.author.username} - {timeAgo(post.createdAt)}
              </span>
            </span>
          </div>
          <p className="text-body text-prava-light-text-primary dark:text-prava-dark-text-primary">
            {postPreview(post.body)}
          </p>
          <p className="mt-2 text-body-sm text-prava-light-text-tertiary dark:text-prava-dark-text-tertiary">
            {post.likeCount} likes - {post.commentCount} comments - {post.shareCount} shares
          </p>
        </Link>
      ))}
    </div>
  );
}

function EmptyState({ label }: { label: string }) {
  return (
    <div className="py-16 text-center">
      <SearchIcon className="mx-auto mb-4 h-10 w-10 text-prava-light-text-tertiary dark:text-prava-dark-text-tertiary" strokeWidth={3} />
      <p className="text-body font-semibold text-prava-light-text-secondary dark:text-prava-dark-text-secondary">
        {label}
      </p>
    </div>
  );
}
