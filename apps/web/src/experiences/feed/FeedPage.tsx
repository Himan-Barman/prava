import React, { useEffect, useRef, useState } from 'react';
import { motion } from 'framer-motion';
import { Image, Video, Smile } from 'lucide-react';
import { toast } from 'react-hot-toast';
import { GlassCard } from '../../ui-system';
import { feedService, FeedPost } from '../../services/feed-service';
import { Post } from './components/Post';
import { useAuth } from '../../context/auth-context';
import { smartToast } from '../../ui-system/components/SmartToast';

export default function FeedPage() {
  const { user } = useAuth();
  const [posts, setPosts] = useState<FeedPost[]>([]);
  const [loading, setLoading] = useState(true);
  const [loadingMore, setLoadingMore] = useState(false);
  const [postBody, setPostBody] = useState('');
  const [isPosting, setIsPosting] = useState(false);

  // Pagination
  const beforeCursor = useRef<string | undefined>(undefined);
  const observerTarget = useRef<HTMLDivElement>(null);
  const hasMore = useRef(true);

  useEffect(() => {
    let isMounted = true;

    const loadInitialFeed = async () => {
      try {
        setLoading(true);
        const data = await feedService.listFeed({ limit: 20 });
        if (isMounted) {
          setPosts(data);
          if (data.length > 0) {
            beforeCursor.current = data[data.length - 1].id;
          } else {
            hasMore.current = false;
          }
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
  }, []);

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
  }, [loading, loadingMore]);

  const loadMorePosts = async () => {
    if (!beforeCursor.current) return;

    try {
      setLoadingMore(true);
      const data = await feedService.listFeed({
        limit: 20,
        before: beforeCursor.current
      });

      if (data.length > 0) {
        setPosts(prev => [...prev, ...data]);
        beforeCursor.current = data[data.length - 1].id;
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
    try {
      await feedService.toggleLike(postId);
      // UI update is handled optimistically in Post component via local state
    } catch (error) {
      console.error('Like failed:', error);
      toast.error('Action failed');
    }
  };

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

      {/* Composer */}
      <GlassCard className="mb-6">
        <div className="flex gap-3">
          <div className="w-10 h-10 rounded-full bg-gradient-to-br from-prava-accent to-prava-accent-muted flex items-center justify-center shrink-0">
            <span className="text-white font-semibold text-sm">
              {/* Fallback avatar if user data missing */}
              Y
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
