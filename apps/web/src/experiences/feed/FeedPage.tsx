import { useEffect, useRef, useState } from 'react';
import { motion } from 'framer-motion';
import { Image, Video, Smile } from 'lucide-react';
import { GlassCard } from '../../ui-system';
import { feedService, FeedPost } from '../../services/feed-service';
import { Post } from './components/Post';
import { useAuth } from '../../context/auth-context';
import { smartToast } from '../../ui-system/components/SmartToast';

type FeedMode = 'for-you' | 'following';

const PAGE_SIZE = 20;

export default function FeedPage() {
  const { user } = useAuth();
  const userInitial = user?.email?.trim().charAt(0).toUpperCase() || 'Y';
  const [posts, setPosts] = useState<FeedPost[]>([]);
  const [loading, setLoading] = useState(true);
  const [loadingMore, setLoadingMore] = useState(false);
  const [postBody, setPostBody] = useState('');
  const [isPosting, setIsPosting] = useState(false);
  const [feedMode, setFeedMode] = useState<FeedMode>('for-you');

  // Pagination
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
  }, [feedMode]);

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
  }, [loading, loadingMore, feedMode]);

  const loadMorePosts = async () => {
    if (!beforeCursor.current) return;

    try {
      setLoadingMore(true);
      const data = await feedService.listFeed({
        limit: PAGE_SIZE,
        before: beforeCursor.current,
        mode: feedMode,
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
    if (!postBody.trim()) return;

    try {
      setIsPosting(true);
      const newPost = await feedService.createPost(postBody);
      setPosts(prev => [newPost, ...prev]);
      setPostBody('');
      smartToast.success('Posted!');
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

  const modes: Array<{ id: FeedMode; label: string }> = [
    { id: 'for-you', label: 'For you' },
    { id: 'following', label: 'Following' },
  ];

  return (
    <div className="max-w-2xl mx-auto pb-8">
      {/* Page Header */}
      <motion.div
        initial={{ opacity: 0, y: 8 }}
        animate={{ opacity: 1, y: 0 }}
        transition={{ duration: 0.4 }}
        className="mb-6"
      >
        <h1 className="text-h1 text-prava-light-text-primary dark:text-prava-dark-text-primary">
          Feed
        </h1>
        <p className="mt-1 text-body text-prava-light-text-secondary dark:text-prava-dark-text-secondary">
          See what is happening in your network
        </p>
      </motion.div>

      {/* Feed Mode */}
      <motion.div
        initial={{ opacity: 0, y: 8 }}
        animate={{ opacity: 1, y: 0 }}
        transition={{ duration: 0.4, delay: 0.1 }}
        className="mb-6"
      >
        <div className="inline-grid grid-cols-2 gap-1 p-1 rounded-[16px] bg-prava-light-surface dark:bg-prava-dark-surface border border-prava-light-border dark:border-prava-dark-border">
          {modes.map((mode) => (
            <button
              key={mode.id}
              type="button"
              onClick={() => setFeedMode(mode.id)}
              className="relative px-4 py-2 text-body-sm font-semibold rounded-[12px] transition-colors"
              aria-pressed={feedMode === mode.id}
            >
              {feedMode === mode.id && (
                <motion.span
                  layoutId="feedModePill"
                  className="absolute inset-0 rounded-[12px] bg-white dark:bg-prava-dark-elevated shadow-[0_8px_20px_rgba(0,0,0,0.08)]"
                  transition={{ type: 'spring', bounce: 0.2, duration: 0.5 }}
                />
              )}
              <span className={`relative z-10 ${feedMode === mode.id
                ? 'text-prava-light-text-primary dark:text-prava-dark-text-primary'
                : 'text-prava-light-text-tertiary dark:text-prava-dark-text-tertiary'
                }`}>
                {mode.label}
              </span>
            </button>
          ))}
        </div>
      </motion.div>

      {/* Composer */}
      <GlassCard className="mb-6">
        <div className="flex gap-3">
          <div className="w-10 h-10 rounded-full bg-gradient-to-br from-prava-accent to-prava-accent-muted flex items-center justify-center shrink-0">
            <span className="text-white font-semibold text-sm">
              {/* Fallback avatar if user data missing */}
              {userInitial}
            </span>
          </div>
          <div className="flex-1">
            <textarea
              placeholder="What is on your mind?"
              className="w-full p-3 rounded-[14px] bg-prava-light-surface dark:bg-prava-dark-surface border border-prava-light-border dark:border-prava-dark-border resize-none text-body text-prava-light-text-primary dark:text-prava-dark-text-primary placeholder:text-prava-light-text-tertiary dark:placeholder:text-prava-dark-text-tertiary focus:outline-none focus:ring-2 focus:ring-prava-accent/30"
              rows={3}
              value={postBody}
              onChange={(e) => setPostBody(e.target.value)}
            />
            <div className="flex items-center justify-between mt-3">
              <div className="flex items-center gap-2">
                <button className="p-2 rounded-[10px] text-prava-light-text-tertiary dark:text-prava-dark-text-tertiary hover:bg-prava-light-surface dark:hover:bg-prava-dark-surface transition-colors">
                  <Image className="w-5 h-5" />
                </button>
                <button className="p-2 rounded-[10px] text-prava-light-text-tertiary dark:text-prava-dark-text-tertiary hover:bg-prava-light-surface dark:hover:bg-prava-dark-surface transition-colors">
                  <Video className="w-5 h-5" />
                </button>
                <button className="p-2 rounded-[10px] text-prava-light-text-tertiary dark:text-prava-dark-text-tertiary hover:bg-prava-light-surface dark:hover:bg-prava-dark-surface transition-colors">
                  <Smile className="w-5 h-5" />
                </button>
              </div>
              <button
                onClick={handleCreatePost}
                disabled={isPosting || !postBody.trim()}
                className="px-4 py-2 rounded-[12px] bg-gradient-to-r from-prava-accent to-prava-accent-muted text-white text-body-sm font-semibold shadow-prava-glow hover:shadow-[0_12px_28px_rgba(91,140,255,0.4)] transition-all disabled:opacity-50 disabled:cursor-not-allowed"
              >
                {isPosting ? 'Posting...' : 'Post'}
              </button>
            </div>
          </div>
        </div>
      </GlassCard>

      {/* Posts */}
      <div className="space-y-4">
        {loading && posts.length === 0 ? (
          // Skeleton loader
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

        {/* Infinite Scroll Sentinel */}
        <div ref={observerTarget} className="h-4 w-full flex justify-center p-4">
          {loadingMore && <div className="w-6 h-6 rounded-full border-2 border-prava-accent border-t-transparent animate-spin" />}
        </div>
      </div>
    </div>
  );
}
