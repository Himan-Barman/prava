import { useEffect, useRef, useState } from 'react';
import { useNavigate, useSearchParams } from 'react-router-dom';
import { AnimatePresence, motion } from 'framer-motion';
import { AtSign, Hash, MoreVertical, PencilLine } from 'lucide-react';
import { GlassCard } from '../../ui-system';
import { feedService, FeedPost, FeedTag } from '../../services/feed-service';
import { usersService, UserSearchResult } from '../../services/users-service';
import { Post } from './components/Post';
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
  const navigate = useNavigate();
  const [searchParams] = useSearchParams();
  const tag = searchParams.get('tag')?.trim() || '';
  const [posts, setPosts] = useState<FeedPost[]>([]);
  const [loading, setLoading] = useState(true);
  const [loadingMore, setLoadingMore] = useState(false);
  const [postBody, setPostBody] = useState('');
  const [isPosting, setIsPosting] = useState(false);
  const [composerOpen, setComposerOpen] = useState(false);
  const [composerMenuOpen, setComposerMenuOpen] = useState(false);
  const [feedMode, setFeedMode] = useState<FeedMode>('for-you');
  const [mentionSuggestions, setMentionSuggestions] = useState<UserSearchResult[]>([]);
  const [tagSuggestions, setTagSuggestions] = useState<FeedTag[]>([]);
  const [suggestionLoading, setSuggestionLoading] = useState(false);
  const composerInputRef = useRef<HTMLTextAreaElement>(null);

  const activeToken = getActiveComposerToken(postBody);

  const beforeCursor = useRef<string | undefined>(undefined);
  const observerTarget = useRef<HTMLDivElement>(null);
  const hasMore = useRef(true);
  const feedSessionId = useRef(`web-feed-${Date.now()}-${Math.random().toString(36).slice(2)}`);
  const recordedImpressions = useRef<Set<string>>(new Set());

  useEffect(() => {
    let isMounted = true;

    const loadInitialFeed = async () => {
      try {
        setLoading(true);
        setPosts([]);
        hasMore.current = true;
        beforeCursor.current = undefined;
        recordedImpressions.current = new Set();

        const data = await feedService.listFeed({
          limit: PAGE_SIZE,
          mode: feedMode,
          tag,
          sessionId: feedSessionId.current,
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
    const fresh = posts.filter((post) => !recordedImpressions.current.has(post.id));
    if (fresh.length === 0) return;

    for (const post of fresh) {
      recordedImpressions.current.add(post.id);
    }

    void feedService.recordEvents(fresh.map((post) => ({
      type: 'impression',
      postId: post.id,
      source: feedMode,
      sessionId: feedSessionId.current,
      metadata: {
        reason: post.recommendationReason || null,
      },
    }))).catch(() => {
      // Feed rendering should not fail because analytics ingestion is unavailable.
    });
  }, [posts, feedMode]);

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
        sessionId: feedSessionId.current,
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
      setComposerMenuOpen(false);
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

  const handleNotInterested = async (postId: string) => {
    const previous = posts;
    setPosts(prev => prev.filter((post) => post.id !== postId));
    try {
      await feedService.markNotInterested(postId);
      smartToast.success('Removed from your feed');
    } catch {
      setPosts(previous);
      smartToast.error('Action failed');
    }
  };

  const handleHide = async (postId: string) => {
    const previous = posts;
    setPosts(prev => prev.filter((post) => post.id !== postId));
    try {
      await feedService.hidePost(postId);
      smartToast.success('Post hidden');
    } catch {
      setPosts(previous);
      smartToast.error('Action failed');
    }
  };

  const handleComment = (postId: string) => {
    navigate(`/post/${postId}`);
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
          className="feed-mode-control sticky top-4 z-30 mb-4 flex justify-center"
        >
          <div className="inline-grid grid-cols-2 gap-1 rounded-[18px] border border-prava-light-border/70 bg-prava-light-surface/95 p-1 backdrop-blur-xl dark:border-prava-dark-border/70 dark:bg-prava-dark-surface/95">
            {modes.map((mode) => (
              <button
                key={mode.id}
                type="button"
                onClick={() => setFeedMode(mode.id)}
                className="relative min-w-28 px-4 py-2 text-body-sm font-bold rounded-[14px] transition-colors"
                aria-pressed={feedMode === mode.id}
              >
                {feedMode === mode.id && (
                  <motion.span
                    layoutId="feedModePill"
                    className="absolute inset-0 rounded-[14px] bg-prava-accent"
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
                onHide={handleHide}
                onNotInterested={handleNotInterested}
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
        className="feed-compose-fab fixed bottom-[86px] right-5 tablet:bottom-8 tablet:right-8 z-40 grid h-14 w-14 place-items-center rounded-full bg-prava-accent text-white transition-transform hover:scale-105 active:scale-95"
        aria-label="Write post"
      >
        <PencilLine className="w-7 h-7" strokeWidth={3} />
      </button>

      <AnimatePresence>
        {composerOpen && (
          <motion.div
            className="fixed inset-0 z-[60] flex flex-col bg-prava-light-bg text-prava-light-text-primary dark:bg-prava-dark-bg dark:text-prava-dark-text-primary"
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            exit={{ opacity: 0 }}
          >
            <motion.div
              initial={{ opacity: 0, y: 10 }}
              animate={{ opacity: 1, y: 0 }}
              exit={{ opacity: 0, y: 10 }}
              transition={{ duration: 0.2 }}
              className="mx-auto flex h-full w-full max-w-2xl flex-col px-4 pb-4 pt-[env(safe-area-inset-top,0px)]"
            >
              <div className="relative flex h-16 shrink-0 items-center gap-3 border-b border-prava-light-border/80 dark:border-prava-dark-border/80">
                <h1 className="min-w-0 flex-1 text-[28px] font-extrabold leading-none tracking-normal">Post</h1>
                <button
                  type="button"
                  onClick={() => setComposerMenuOpen((current) => !current)}
                  className="grid h-11 w-11 place-items-center rounded-full text-prava-light-text-secondary transition-colors hover:bg-prava-light-surface dark:text-prava-dark-text-secondary dark:hover:bg-white/10"
                  aria-label="Post options"
                >
                  <MoreVertical className="h-7 w-7" strokeWidth={3} />
                </button>
                <button
                  type="button"
                  onClick={handleCreatePost}
                  disabled={!canPost}
                  className="h-11 rounded-full bg-prava-accent px-6 text-body-sm font-bold text-white transition-all disabled:cursor-not-allowed disabled:opacity-45"
                >
                  {isPosting ? 'Posting' : 'Post'}
                </button>
                {composerMenuOpen && (
                  <div className="absolute right-0 top-14 z-10 w-48 overflow-hidden rounded-[16px] border border-prava-light-border bg-white p-1 shadow-[0_16px_40px_rgba(0,0,0,0.14)] dark:border-prava-dark-border dark:bg-prava-dark-elevated">
                    <button
                      type="button"
                      className="w-full rounded-[12px] px-3 py-2 text-left text-body-sm font-bold text-prava-light-text-primary hover:bg-prava-light-surface dark:text-prava-dark-text-primary dark:hover:bg-white/10"
                      onClick={() => {
                        setPostBody('');
                        setComposerMenuOpen(false);
                        setComposerOpen(false);
                      }}
                    >
                      Discard post
                    </button>
                    <button
                      type="button"
                      className="w-full rounded-[12px] px-3 py-2 text-left text-body-sm font-bold text-prava-light-text-primary hover:bg-prava-light-surface dark:text-prava-dark-text-primary dark:hover:bg-white/10"
                      onClick={() => {
                        setComposerMenuOpen(false);
                        smartToast.info('Post settings are synced with your feed preferences');
                      }}
                    >
                      Post settings
                    </button>
                  </div>
                )}
              </div>

              <textarea
                ref={composerInputRef}
                placeholder="What's happening?"
                className="min-h-0 flex-1 resize-none overflow-y-auto bg-transparent py-5 text-[22px] leading-snug text-prava-light-text-primary outline-none placeholder:text-prava-light-text-tertiary dark:text-prava-dark-text-primary dark:placeholder:text-prava-dark-text-tertiary"
                value={postBody}
                maxLength={MAX_POST_CHARS}
                onChange={(event) => setPostBody(event.target.value)}
              />

              {activeToken && (
                <div className="mb-3 max-h-56 overflow-y-auto rounded-[18px] bg-prava-light-surface/90 p-2 dark:bg-white/[0.06]">
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

              <div className="flex shrink-0 flex-wrap items-center gap-3 border-t border-prava-light-border/80 py-3 dark:border-prava-dark-border/80">
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
              </div>
            </motion.div>
          </motion.div>
        )}
      </AnimatePresence>
    </>
  );
}
