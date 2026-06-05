import { useEffect, useRef, useState } from 'react';
import { useSearchParams } from 'react-router-dom';
import { AnimatePresence, motion } from 'framer-motion';
import { AtSign, Hash, PencilLine, X } from 'lucide-react';
import { GlassCard } from '../../ui-system';
import { feedService, FeedPost, FeedTag } from '../../services/feed-service';
import { usersService, UserSearchResult } from '../../services/users-service';
import { Post } from './components/Post';
import { useAuth } from '../../context/auth-context';
import { smartToast } from '../../ui-system/components/SmartToast';

type FeedMode = 'for-you' | 'following';

interface ComposerToken {
  symbol: '@' | '#';
  query: string;
  start: number;
  end: number;
}

const PAGE_SIZE = 20;
const MAX_POST_CHARS = 1600;

function getActiveComposerToken(text: string): ComposerToken | null {
  const match = /(^|\s)([@#])([a-zA-Z0-9_.]*)$/.exec(text);
  if (!match) return null;
  return {
    symbol: match[2] as '@' | '#',
    query: match[3] || '',
    start: match.index + match[1].length,
    end: text.length,
  };
}

export default function FeedPage() {
  const [searchParams] = useSearchParams();
  const { user } = useAuth();
  const tag = searchParams.get('tag')?.trim() || '';
  const userInitial = (
    user?.displayName?.trim().charAt(0) ||
    user?.username?.trim().charAt(0) ||
    user?.email?.trim().charAt(0) ||
    'Y'
  ).toUpperCase();
  const [posts, setPosts] = useState<FeedPost[]>([]);
  const [loading, setLoading] = useState(true);
  const [loadingMore, setLoadingMore] = useState(false);
  const [postBody, setPostBody] = useState('');
  const [isPosting, setIsPosting] = useState(false);
  const [composerOpen, setComposerOpen] = useState(false);
  const [feedMode, setFeedMode] = useState<FeedMode>('for-you');
  const [mentionSuggestions, setMentionSuggestions] = useState<UserSearchResult[]>([]);
  const [tagSuggestions, setTagSuggestions] = useState<FeedTag[]>([]);
  const [suggestionLoading, setSuggestionLoading] = useState(false);
  const composerInputRef = useRef<HTMLTextAreaElement>(null);

  const activeToken = getActiveComposerToken(postBody);

  const beforeCursor = useRef<string | undefined>(undefined);
  const observerTarget = useRef<HTMLDivElement>(null);
  const hasMore = useRef(true);

  useEffect(() => {
    let isMounted = true;

    const loadInitialFeed = async () => {
      try {
        setLoading(true);
        setPosts([]);
        hasMore.current = true;
        beforeCursor.current = undefined;

        const data = await feedService.listFeed({
          limit: PAGE_SIZE,
          mode: feedMode,
          tag,
        });

        if (!isMounted) return;

        setPosts(data);
        if (data.length > 0) {
          beforeCursor.current = data[data.length - 1].createdAt;
          hasMore.current = data.length >= PAGE_SIZE;
        } else {
          hasMore.current = false;
        }
      } catch (error) {
        console.error('Failed to load feed:', error);
        if (isMounted) {
          smartToast.error('Could not load feed');
        }
      } finally {
        if (isMounted) {
          setLoading(false);
        }
      }
    };

    loadInitialFeed();

    return () => {
      isMounted = false;
    };
  }, [feedMode, tag]);

  useEffect(() => {
    const observer = new IntersectionObserver(
      entries => {
        if (entries[0].isIntersecting && !loading && !loadingMore && hasMore.current) {
          loadMorePosts();
        }
      },
      { threshold: 1.0 }
    );

    if (observerTarget.current) {
      observer.observe(observerTarget.current);
    }

    return () => observer.disconnect();
  }, [loading, loadingMore, feedMode, tag]);

  useEffect(() => {
    if (!composerOpen) return;
    const timer = window.setTimeout(() => composerInputRef.current?.focus(), 120);
    return () => window.clearTimeout(timer);
  }, [composerOpen]);

  useEffect(() => {
    if (!composerOpen || !activeToken) {
      setMentionSuggestions([]);
      setTagSuggestions([]);
      setSuggestionLoading(false);
      return;
    }

    let cancelled = false;
    setSuggestionLoading(true);
    const timer = window.setTimeout(async () => {
      try {
        if (activeToken.symbol === '@') {
          const data = await usersService.searchUsers(activeToken.query, 8);
          if (!cancelled) {
            setMentionSuggestions(data);
            setTagSuggestions([]);
          }
        } else {
          const data = await feedService.listTags(24);
          const query = activeToken.query.toLowerCase();
          const filtered = query
            ? data.filter((item) => item.tag.toLowerCase().includes(query)).slice(0, 8)
            : data.slice(0, 8);
          if (!cancelled) {
            setTagSuggestions(filtered);
            setMentionSuggestions([]);
          }
        }
      } catch {
        if (!cancelled) {
          setMentionSuggestions([]);
          setTagSuggestions([]);
        }
      } finally {
        if (!cancelled) {
          setSuggestionLoading(false);
        }
      }
    }, activeToken.query ? 180 : 0);

    return () => {
      cancelled = true;
      window.clearTimeout(timer);
    };
  }, [composerOpen, activeToken?.symbol, activeToken?.query]);

  const loadMorePosts = async () => {
    if (!beforeCursor.current) return;

    try {
      setLoadingMore(true);
      const data = await feedService.listFeed({
        limit: PAGE_SIZE,
        before: beforeCursor.current,
        mode: feedMode,
        tag,
      });

      if (data.length > 0) {
        setPosts(prev => [...prev, ...data]);
        beforeCursor.current = data[data.length - 1].createdAt;
      } else {
        hasMore.current = false;
      }
    } catch (error) {
      console.error('Failed to load more posts:', error);
    } finally {
      setLoadingMore(false);
    }
  };

  const handleCreatePost = async () => {
    const body = postBody.trim();
    if (!body || isPosting) return;

    try {
      setIsPosting(true);
      const newPost = await feedService.createPost(body);
      setPosts(prev => [newPost, ...prev]);
      setPostBody('');
      setComposerOpen(false);
      smartToast.success('Posted');
    } catch (error) {
      smartToast.error('Failed to create post');
    } finally {
      setIsPosting(false);
    }
  };

  const handleLike = async (postId: string) => {
    setPosts(prev => prev.map((post) => {
      if (post.id !== postId) return post;
      const delta = post.liked ? -1 : 1;
      return {
        ...post,
        liked: !post.liked,
        likeCount: Math.max(post.likeCount + delta, 0),
      };
    }));

    try {
      const result = await feedService.toggleLike(postId);
      setPosts(prev => prev.map((post) => (
        post.id === postId
          ? { ...post, liked: result.liked, likeCount: result.likeCount }
          : post
      )));
    } catch (error) {
      setPosts(prev => prev.map((post) => {
        if (post.id !== postId) return post;
        const delta = post.liked ? -1 : 1;
        return {
          ...post,
          liked: !post.liked,
          likeCount: Math.max(post.likeCount + delta, 0),
        };
      }));
      smartToast.error('Action failed');
    }
  };

  const handleShare = async (postId: string) => {
    try {
      const result = await feedService.sharePost(postId);
      setPosts(prev => prev.map((post) => (
        post.id === postId
          ? { ...post, shareCount: result.shareCount }
          : post
      )));
      smartToast.success(result.created ? 'Post shared' : 'Already shared');
    } catch (error) {
      smartToast.error('Share failed');
    }
  };

  const handleComment = () => {
    smartToast.info('Comments coming soon');
  };

  const appendToken = (symbol: '@' | '#') => {
    setComposerOpen(true);
    setPostBody((current) => {
      if (!current) return symbol;
      return /\s$/.test(current) ? `${current}${symbol}` : `${current} ${symbol}`;
    });
  };

  const insertSuggestion = (value: string) => {
    const token = getActiveComposerToken(postBody);
    if (!token) return;
    const next = `${postBody.slice(0, token.start)}${token.symbol}${value} ${postBody.slice(token.end)}`;
    setPostBody(next.slice(0, MAX_POST_CHARS));
    window.setTimeout(() => composerInputRef.current?.focus(), 0);
  };

  const modes: Array<{ id: FeedMode; label: string }> = [
    { id: 'for-you', label: 'For you' },
    { id: 'following', label: 'Following' },
  ];

  const canPost = postBody.trim().length > 0 && postBody.length <= MAX_POST_CHARS && !isPosting;

  return (
    <>
      <div className="max-w-2xl mx-auto pb-8">
        <motion.div
          initial={{ opacity: 0, y: 8 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.4 }}
          className="prava-tab-page-header mb-5"
        >
          <h1 className="text-h1 text-prava-light-text-primary dark:text-prava-dark-text-primary">
            Prava
          </h1>
          {tag && (
            <p className="mt-1 text-body text-prava-light-text-secondary dark:text-prava-dark-text-secondary">
              Posts tagged #{tag}
            </p>
          )}
        </motion.div>

        <motion.div
          initial={{ opacity: 0, y: 8 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.4, delay: 0.1 }}
          className="feed-mode-control sticky top-4 z-30 mb-5 flex justify-center"
        >
          <div className="inline-grid grid-cols-2 gap-1 p-1 rounded-[18px] bg-prava-light-surface/92 dark:bg-prava-dark-surface/92 backdrop-blur-2xl border border-prava-light-border/70 dark:border-prava-dark-border/70">
            {modes.map((mode) => (
              <button
                key={mode.id}
                type="button"
                onClick={() => setFeedMode(mode.id)}
                className="relative min-w-32 px-4 py-2.5 text-body-sm font-semibold rounded-[14px] transition-colors"
                aria-pressed={feedMode === mode.id}
              >
                {feedMode === mode.id && (
                  <motion.span
                    layoutId="feedModePill"
                    className="absolute inset-0 rounded-[14px] bg-prava-accent shadow-[0_8px_24px_rgba(91,140,255,0.25)]"
                    transition={{ type: 'spring', bounce: 0.2, duration: 0.5 }}
                  />
                )}
                <span className={`relative z-10 ${feedMode === mode.id
                  ? 'text-white'
                  : 'text-prava-light-text-tertiary dark:text-prava-dark-text-tertiary'
                  }`}>
                  {mode.label}
                </span>
              </button>
            ))}
          </div>
        </motion.div>

        <div className="space-y-4">
          {loading && posts.length === 0 ? (
            [1, 2, 3].map((i) => (
              <GlassCard key={i} className="animate-pulse">
                <div className="flex gap-4">
                  <div className="w-10 h-10 rounded-full bg-gray-200 dark:bg-white/10" />
                  <div className="flex-1 space-y-2">
                    <div className="h-4 w-1/3 bg-gray-200 dark:bg-white/10 rounded" />
                    <div className="h-16 w-full bg-gray-200 dark:bg-white/10 rounded" />
                  </div>
                </div>
              </GlassCard>
            ))
          ) : (
            posts.map((post, i) => (
              <Post
                key={post.id}
                post={post}
                delay={i < 5 ? i * 0.1 : 0}
                onLike={handleLike}
                onShare={handleShare}
                onComment={handleComment}
              />
            ))
          )}

          <div ref={observerTarget} className="h-4 w-full flex justify-center p-4">
            {loadingMore && <div className="w-6 h-6 rounded-full border-2 border-prava-accent border-t-transparent animate-spin" />}
          </div>
        </div>
      </div>

      <button
        type="button"
        onClick={() => setComposerOpen(true)}
        className="feed-compose-fab fixed bottom-[86px] right-5 tablet:bottom-8 tablet:right-8 z-40 grid h-14 w-14 place-items-center rounded-full bg-prava-accent text-white shadow-[0_14px_28px_rgba(0,0,0,0.20)] transition-transform hover:scale-105 active:scale-95"
        aria-label="Write post"
      >
        <PencilLine className="w-7 h-7" strokeWidth={3} />
      </button>

      <AnimatePresence>
        {composerOpen && (
          <motion.div
            className="fixed inset-0 z-[60] flex items-end justify-center bg-black/55 px-3 pb-3 pt-8 backdrop-blur-sm sm:items-center sm:p-6"
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            exit={{ opacity: 0 }}
            onClick={() => setComposerOpen(false)}
          >
            <motion.div
              initial={{ opacity: 0, y: 28, scale: 0.98 }}
              animate={{ opacity: 1, y: 0, scale: 1 }}
              exit={{ opacity: 0, y: 24, scale: 0.98 }}
              transition={{ type: 'spring', damping: 28, stiffness: 340 }}
              className="w-full max-w-2xl rounded-[28px] bg-white dark:bg-[#1D1D1D] p-5 shadow-[0_28px_70px_rgba(0,0,0,0.34)]"
              onClick={(event) => event.stopPropagation()}
            >
              <div className="mb-5 flex items-center justify-between">
                <div className="flex items-center gap-3">
                  <div className="grid h-12 w-12 shrink-0 place-items-center rounded-full bg-prava-accent/15 text-lg font-bold text-prava-accent">
                    {userInitial}
                  </div>
                  <div>
                    <p className="font-semibold text-prava-light-text-primary dark:text-prava-dark-text-primary">
                      {user?.displayName || user?.username || 'Your post'}
                    </p>
                    <p className="text-body-sm text-prava-light-text-tertiary dark:text-prava-dark-text-tertiary">
                      @{user?.username || 'you'}
                    </p>
                  </div>
                </div>
                <button
                  type="button"
                  onClick={() => setComposerOpen(false)}
                  className="grid h-10 w-10 place-items-center rounded-full text-prava-light-text-tertiary transition-colors hover:bg-black/5 dark:text-prava-dark-text-tertiary dark:hover:bg-white/10"
                  aria-label="Close composer"
                >
                  <X className="w-6 h-6" strokeWidth={3} />
                </button>
              </div>

              <textarea
                ref={composerInputRef}
                placeholder="Share something premium..."
                className="h-44 w-full resize-none overflow-y-auto rounded-[18px] bg-prava-light-surface px-4 py-4 text-body text-prava-light-text-primary outline-none placeholder:text-prava-light-text-tertiary focus:ring-2 focus:ring-prava-accent/30 dark:bg-white/[0.06] dark:text-prava-dark-text-primary dark:placeholder:text-prava-dark-text-tertiary"
                value={postBody}
                maxLength={MAX_POST_CHARS}
                onChange={(event) => setPostBody(event.target.value)}
              />

              <div className="mt-5 flex flex-wrap items-center gap-3">
                <button
                  type="button"
                  onClick={() => appendToken('@')}
                  className="inline-flex items-center gap-2 rounded-full bg-prava-light-surface px-4 py-2.5 text-body-sm font-bold text-prava-accent transition-colors hover:bg-prava-accent/10 dark:bg-white/[0.08]"
                >
                  <AtSign className="w-5 h-5" strokeWidth={3} />
                  Mention
                </button>
                <button
                  type="button"
                  onClick={() => appendToken('#')}
                  className="inline-flex items-center gap-2 rounded-full bg-prava-light-surface px-4 py-2.5 text-body-sm font-bold text-prava-accent transition-colors hover:bg-prava-accent/10 dark:bg-white/[0.08]"
                >
                  <Hash className="w-5 h-5" strokeWidth={3} />
                  Hashtag
                </button>
                <span className={`ml-auto text-body-sm font-semibold ${postBody.length > MAX_POST_CHARS
                  ? 'text-prava-error'
                  : 'text-prava-light-text-tertiary dark:text-prava-dark-text-tertiary'
                  }`}>
                  {postBody.length}/{MAX_POST_CHARS}
                </span>
                <button
                  type="button"
                  onClick={handleCreatePost}
                  disabled={!canPost}
                  className="rounded-full bg-prava-accent px-6 py-2.5 text-body-sm font-bold text-white transition-all disabled:cursor-not-allowed disabled:opacity-45"
                >
                  {isPosting ? 'Posting...' : 'Post'}
                </button>
              </div>

              {activeToken && (
                <div className="mt-4 max-h-56 overflow-y-auto rounded-[18px] bg-prava-light-surface/80 p-2 dark:bg-white/[0.06]">
                  {suggestionLoading ? (
                    <div className="flex items-center justify-center py-8">
                      <div className="h-6 w-6 animate-spin rounded-full border-2 border-prava-accent border-t-transparent" />
                    </div>
                  ) : activeToken.symbol === '@' ? (
                    mentionSuggestions.length === 0 ? (
                      <p className="px-3 py-4 text-center text-body-sm text-prava-light-text-tertiary dark:text-prava-dark-text-tertiary">
                        No accounts found
                      </p>
                    ) : (
                      mentionSuggestions.map((item) => (
                        <button
                          key={item.id}
                          type="button"
                          onClick={() => insertSuggestion(item.username)}
                          className="flex w-full items-center gap-3 rounded-[14px] px-3 py-2 text-left transition-colors hover:bg-white dark:hover:bg-white/10"
                        >
                          {item.avatarUrl ? (
                            <img src={item.avatarUrl} alt="" className="h-10 w-10 rounded-full object-cover" />
                          ) : (
                            <span className="grid h-10 w-10 place-items-center rounded-full bg-prava-accent/15 font-bold text-prava-accent">
                              {item.displayName.charAt(0).toUpperCase()}
                            </span>
                          )}
                          <span className="min-w-0">
                            <span className="block truncate font-semibold text-prava-light-text-primary dark:text-prava-dark-text-primary">
                              {item.displayName}
                            </span>
                            <span className="block truncate text-body-sm text-prava-light-text-tertiary dark:text-prava-dark-text-tertiary">
                              @{item.username}
                            </span>
                          </span>
                        </button>
                      ))
                    )
                  ) : tagSuggestions.length === 0 ? (
                    <p className="px-3 py-4 text-center text-body-sm text-prava-light-text-tertiary dark:text-prava-dark-text-tertiary">
                      No hashtags found
                    </p>
                  ) : (
                    tagSuggestions.map((item) => (
                      <button
                        key={item.tag}
                        type="button"
                        onClick={() => insertSuggestion(item.tag)}
                        className="flex w-full items-center justify-between rounded-[14px] px-3 py-3 text-left transition-colors hover:bg-white dark:hover:bg-white/10"
                      >
                        <span className="inline-flex items-center gap-3 font-semibold text-prava-light-text-primary dark:text-prava-dark-text-primary">
                          <Hash className="h-5 w-5 text-prava-accent" strokeWidth={3} />
                          #{item.tag}
                        </span>
                        <span className="text-body-sm text-prava-light-text-tertiary dark:text-prava-dark-text-tertiary">
                          {item.postCount} posts
                        </span>
                      </button>
                    ))
                  )}
                </div>
              )}
            </motion.div>
          </motion.div>
        )}
      </AnimatePresence>
    </>
  );
}
