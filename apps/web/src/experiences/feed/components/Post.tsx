import React, { useState } from 'react';
import { motion, AnimatePresence } from 'framer-motion';
import { Heart, MessageCircle, Share2, MoreHorizontal, Bookmark } from 'lucide-react';
import { GlassCard } from '../../../ui-system';
import { FeedPost } from '../../../services/feed-service';
import { timeAgo } from '../../../utils/date-utils';

interface PostProps {
  post: FeedPost;
  onLike?: (postId: string) => void;
  onComment?: (postId: string) => void;
  onShare?: (postId: string) => void;
  delay?: number;
}

export function Post({ post, onLike, onComment, onShare, delay = 0 }: PostProps) {
  const [isLiked, setIsLiked] = useState(post.hasLiked);
  const [likeCount, setLikeCount] = useState(post.stats.likes);
  const [isAnimating, setIsAnimating] = useState(false);

  const handleLike = () => {
    const newLiked = !isLiked;
    setIsLiked(newLiked);
    setLikeCount(prev => newLiked ? prev + 1 : prev - 1);
    setIsAnimating(true);

    // Reset animation state
    setTimeout(() => setIsAnimating(false), 300);

    onLike?.(post.id);
  };

  return (
    <GlassCard delay={delay} className="hover:bg-white/[0.95] dark:hover:bg-white/[0.06] transition-colors duration-300">
      <div className="flex items-start gap-4">
        {/* Avatar */}
        <div className="flex-shrink-0">
          {post.user.avatarUrl ? (
            <img
              src={post.user.avatarUrl}
              alt={post.user.displayName}
              className="w-10 h-10 rounded-full object-cover border border-prava-light-border dark:border-prava-dark-border"
            />
          ) : (
            <div className="w-10 h-10 rounded-full bg-gradient-to-br from-prava-accent to-prava-accent-muted flex items-center justify-center text-white font-semibold text-sm">
              {post.user.displayName.charAt(0)}
            </div>
          )}
        </div>

        {/* Content */}
        <div className="flex-1 min-w-0">
          <div className="flex items-center justify-between mb-1">
            <div className="flex items-center gap-2">
              <span className="font-semibold text-prava-light-text-primary dark:text-prava-dark-text-primary hover:underline cursor-pointer">
                {post.user.displayName}
              </span>
              <span className="text-prava-light-text-tertiary dark:text-prava-dark-text-tertiary text-sm">
                @{post.user.username}
              </span>
              <span className="text-prava-light-text-tertiary dark:text-prava-dark-text-tertiary text-xs">
                • {timeAgo(post.createdAt)}
              </span>
            </div>
            <button className="text-prava-light-text-tertiary dark:text-prava-dark-text-tertiary hover:bg-prava-light-surface dark:hover:bg-prava-dark-surface p-1.5 rounded-full transition-colors">
              <MoreHorizontal className="w-4 h-4" />
            </button>
          </div>

          <p className="text-prava-light-text-primary dark:text-prava-dark-text-primary whitespace-pre-wrap mb-3 leading-relaxed">
            {post.body}
          </p>

          {/* Media Placeholder */}
          {post.media && post.media.length > 0 && (
            <div className="mb-3 rounded-[16px] overflow-hidden border border-prava-light-border dark:border-prava-dark-border">
              {/* Only handling first media for now */}
              {post.media[0].type === 'image' && (
                <img
                  src={post.media[0].url}
                  alt="Post content"
                  className="w-full h-auto max-h-[500px] object-cover"
                />
              )}
            </div>
          )}

          {/* Actions */}
          <div className="flex items-center justify-between pt-1 -ml-2">
            <div className="flex items-center gap-1">
              <motion.button
                whileTap={{ scale: 0.8 }}
                onClick={() => onComment?.(post.id)}
                className="flex items-center gap-2 p-2 rounded-full text-prava-light-text-tertiary dark:text-prava-dark-text-tertiary hover:bg-prava-accent/10 hover:text-prava-accent transition-colors group"
              >
                <MessageCircle className="w-4.5 h-4.5" />
                <span className="text-xs font-medium group-hover:text-prava-accent">
                  {post.stats.comments || 0}
                </span>
              </motion.button>
            </div>

            <div className="flex items-center gap-1">
              <motion.button
                whileTap={{ scale: 0.8 }}
                onClick={handleLike}
                className={`flex items-center gap-2 p-2 rounded-full transition-colors group ${isLiked
                  ? 'text-pink-500 hover:bg-pink-500/10'
                  : 'text-prava-light-text-tertiary dark:text-prava-dark-text-tertiary hover:bg-pink-500/10 hover:text-pink-500'
                  }`}
              >
                <div className="relative">
                  <Heart className={`w-4.5 h-4.5 ${isLiked ? 'fill-current' : ''}`} />
                  <AnimatePresence>
                    {isAnimating && (
                      <motion.div
                        initial={{ scale: 0, opacity: 1 }}
                        animate={{ scale: 2, opacity: 0 }}
                        exit={{ opacity: 0 }}
                        className="absolute inset-0 bg-pink-500 rounded-full -z-10"
                      />
                    )}
                  </AnimatePresence>
                </div>
                <span className={`text-xs font-medium ${isLiked ? 'text-pink-500' : 'group-hover:text-pink-500'}`}>
                  {likeCount}
                </span>
              </motion.button>
            </div>

            <div className="flex items-center gap-1">
              <motion.button
                whileTap={{ scale: 0.8 }}
                onClick={() => onShare?.(post.id)}
                className="flex items-center gap-2 p-2 rounded-full text-prava-light-text-tertiary dark:text-prava-dark-text-tertiary hover:bg-green-500/10 hover:text-green-500 transition-colors group"
              >
                <Share2 className="w-4.5 h-4.5" />
                <span className="text-xs font-medium group-hover:text-green-500">
                  {post.stats.shares || 0}
                </span>
              </motion.button>
            </div>

            <div className="flex items-center gap-1">
              <motion.button
                whileTap={{ scale: 0.8 }}
                className="flex items-center gap-2 p-2 rounded-full text-prava-light-text-tertiary dark:text-prava-dark-text-tertiary hover:bg-prava-accent/10 hover:text-prava-accent transition-colors"
              >
                <Bookmark className="w-4.5 h-4.5" />
              </motion.button>
            </div>
          </div>
        </div>
      </div>
    </GlassCard>
  );
}
