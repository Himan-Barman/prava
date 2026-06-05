import { useState } from 'react';
import { Link } from 'react-router-dom';
import { motion, AnimatePresence } from 'framer-motion';
import { Heart, MessageCircle, Share2, MoreHorizontal, Eye } from 'lucide-react';
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

  const renderBody = () => {
    const parts = post.body.split(/(@[a-zA-Z0-9_.]{2,32}|#[a-zA-Z0-9_]{2,32})/g);
    return parts.map((part, index) => {
      if (part.startsWith('@')) {
        return (
          <Link
            key={`${part}-${index}`}
            to={`/search?q=${encodeURIComponent(part.slice(1))}`}
            className="font-semibold text-prava-accent hover:underline"
          >
            {part}
          </Link>
        );
      }
      if (part.startsWith('#')) {
        return (
          <Link
            key={`${part}-${index}`}
            to={`/feed?tag=${encodeURIComponent(part.slice(1))}`}
            className="font-semibold text-prava-accent hover:underline"
          >
            {part}
          </Link>
        );
      }
      return <span key={`${index}-${part.slice(0, 8)}`}>{part}</span>;
    });
  };

  return (
    <GlassCard delay={delay} className="hover:bg-white/[0.95] dark:hover:bg-white/[0.06] transition-colors duration-300">
      <div className="flex items-start gap-3">
        {/* Avatar */}
        <div className="flex-shrink-0">
          <Link
            to={`/profile/${post.author.id}`}
            className="flex h-10 w-10 items-center justify-center overflow-hidden rounded-full bg-prava-accent/15 text-sm font-semibold text-prava-accent"
          >
            {post.author.avatarUrl ? (
              <img
                src={post.author.avatarUrl}
                alt=""
                className="h-full w-full object-cover"
              />
            ) : (
              post.author.displayName.charAt(0)
            )}
          </Link>
        </div>

        {/* Content */}
        <div className="flex-1 min-w-0">
          <div className="flex items-start justify-between gap-2 mb-2">
            <div className="min-w-0">
              <Link
                to={`/profile/${post.author.id}`}
                className="block truncate font-semibold text-prava-light-text-primary hover:underline dark:text-prava-dark-text-primary"
              >
                {post.author.displayName}
              </Link>
              <div className="truncate text-xs text-prava-light-text-tertiary dark:text-prava-dark-text-tertiary">
                @{post.author.username} - {timeAgo(post.createdAt)}
              </div>
            </div>
            <button className="text-prava-light-text-tertiary dark:text-prava-dark-text-tertiary hover:bg-prava-light-surface dark:hover:bg-prava-dark-surface p-1.5 rounded-full transition-colors">
              <MoreHorizontal className="w-4 h-4" />
            </button>
          </div>

          <p className="text-prava-light-text-primary dark:text-prava-dark-text-primary whitespace-pre-wrap mb-3 leading-relaxed text-[14px]">
            {renderBody()}
          </p>

          {/* Actions */}
          <div className="flex items-center justify-between pt-1">
            <div className="flex items-center gap-1.5">
              <motion.button
                whileTap={{ scale: 0.8 }}
                onClick={handleLike}
                className={`flex min-w-12 items-center gap-1.5 rounded-full px-1.5 py-1.5 transition-colors group ${post.liked
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
                onClick={() => onComment?.(post.id)}
                className="flex min-w-12 items-center gap-1.5 rounded-full px-1.5 py-1.5 text-prava-light-text-tertiary dark:text-prava-dark-text-tertiary hover:bg-prava-accent/10 hover:text-prava-accent transition-colors group"
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
                onClick={() => onShare?.(post.id)}
                className="flex min-w-12 items-center gap-1.5 rounded-full px-1.5 py-1.5 text-prava-light-text-tertiary dark:text-prava-dark-text-tertiary hover:bg-green-500/10 hover:text-green-500 transition-colors group"
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
                className="flex min-w-12 items-center gap-1.5 rounded-full px-1.5 py-1.5 text-prava-light-text-tertiary dark:text-prava-dark-text-tertiary"
              >
                <Eye className="w-4.5 h-4.5" />
                <span className="text-xs font-medium">{post.readCount ?? 0}</span>
              </motion.button>
            </div>
          </div>
        </div>
      </div>
    </GlassCard>
  );
}
