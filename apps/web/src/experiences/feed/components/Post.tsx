import { useState } from 'react';
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
  const [isAnimating, setIsAnimating] = useState(false);

  const handleLike = () => {
    setIsAnimating(true);
    setTimeout(() => setIsAnimating(false), 300);
    onLike?.(post.id);
  };

  return (
    <GlassCard delay={delay} className="hover:bg-white/[0.95] dark:hover:bg-white/[0.06] transition-colors duration-300">
      <div className="flex items-start gap-4">
        {/* Avatar */}
        <div className="flex-shrink-0">
          <div className="w-10 h-10 rounded-full bg-gradient-to-br from-prava-accent to-prava-accent-muted flex items-center justify-center text-white font-semibold text-sm">
            {post.author.displayName.charAt(0)}
          </div>
        </div>

        {/* Content */}
        <div className="flex-1 min-w-0">
          <div className="flex items-center justify-between mb-1">
            <div className="flex items-center gap-2">
              <span className="font-semibold text-prava-light-text-primary dark:text-prava-dark-text-primary hover:underline cursor-pointer">
                {post.author.displayName}
              </span>
              <span className="text-prava-light-text-tertiary dark:text-prava-dark-text-tertiary text-sm">
                @{post.author.username}
              </span>
              <span className="text-prava-light-text-tertiary dark:text-prava-dark-text-tertiary text-xs">
                - {timeAgo(post.createdAt)}
              </span>
            </div>
            <button className="text-prava-light-text-tertiary dark:text-prava-dark-text-tertiary hover:bg-prava-light-surface dark:hover:bg-prava-dark-surface p-1.5 rounded-full transition-colors">
              <MoreHorizontal className="w-4 h-4" />
            </button>
          </div>

          <p className="text-prava-light-text-primary dark:text-prava-dark-text-primary whitespace-pre-wrap mb-3 leading-relaxed">
            {post.body}
          </p>

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
                  {post.commentCount}
                </span>
              </motion.button>
            </div>

            <div className="flex items-center gap-1">
              <motion.button
                whileTap={{ scale: 0.8 }}
                onClick={handleLike}
                className={`flex items-center gap-2 p-2 rounded-full transition-colors group ${post.liked
                  ? 'text-pink-500 hover:bg-pink-500/10'
                  : 'text-prava-light-text-tertiary dark:text-prava-dark-text-tertiary hover:bg-pink-500/10 hover:text-pink-500'
                  }`}
              >
                <div className="relative">
                  <Heart className={`w-4.5 h-4.5 ${post.liked ? 'fill-current' : ''}`} />
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
                <span className={`text-xs font-medium ${post.liked ? 'text-pink-500' : 'group-hover:text-pink-500'}`}>
                  {post.likeCount}
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
                  {post.shareCount}
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
