import { useEffect, useRef, useState } from 'react';
import { Link, useParams } from 'react-router-dom';
import { Heart, MessageCircle, Send } from 'lucide-react';
import { feedService, FeedComment, FeedPost } from '../../services/feed-service';
import { smartToast } from '../../ui-system/components/SmartToast';
import { timeAgo } from '../../utils/date-utils';
import { Post } from './components/Post';

function renderLinkedText(text: string) {
  const parts = text.split(/(@[a-zA-Z0-9_.]+|#[a-zA-Z0-9_]+)/g);
  return parts.map((part, index) => {
    if (part.startsWith('@')) {
      const username = part.slice(1);
      return (
        <Link key={`${part}-${index}`} to={`/search?q=${encodeURIComponent(username)}`} className="font-semibold text-prava-accent">
          {part}
        </Link>
      );
    }
    if (part.startsWith('#')) {
      const tag = part.slice(1);
      return (
        <Link key={`${part}-${index}`} to={`/feed?tag=${encodeURIComponent(tag)}`} className="font-semibold text-prava-accent">
          {part}
        </Link>
      );
    }
    return part;
  });
}

export default function PostDetailPage() {
  const { postId = '' } = useParams();
  const [post, setPost] = useState<FeedPost | null>(null);
  const [comments, setComments] = useState<FeedComment[]>([]);
  const [loading, setLoading] = useState(true);
  const [commentBody, setCommentBody] = useState('');
  const [replyTo, setReplyTo] = useState<FeedComment | null>(null);
  const [submitting, setSubmitting] = useState(false);
  const inputRef = useRef<HTMLInputElement>(null);

  useEffect(() => {
    let mounted = true;
    const load = async () => {
      if (!postId) return;
      try {
        setLoading(true);
        const [postData, commentsData] = await Promise.all([
          feedService.getPost(postId),
          feedService.listComments(postId, 80),
        ]);
        if (mounted) {
          setPost(postData);
          setComments(commentsData);
        }
      } catch {
        if (mounted) {
          smartToast.error('Unable to load post');
        }
      } finally {
        if (mounted) {
          setLoading(false);
        }
      }
    };
    load();
    return () => {
      mounted = false;
    };
  }, [postId]);

  const handleLikePost = async () => {
    if (!post) return;
    const previous = post;
    const delta = post.liked ? -1 : 1;
    setPost({ ...post, liked: !post.liked, likeCount: Math.max(post.likeCount + delta, 0) });
    try {
      const result = await feedService.toggleLike(post.id);
      setPost((current) => current ? { ...current, liked: result.liked, likeCount: result.likeCount } : current);
    } catch {
      setPost(previous);
      smartToast.error('Action failed');
    }
  };

  const handleShare = async () => {
    if (!post) return;
    try {
      const result = await feedService.sharePost(post.id);
      setPost({ ...post, shareCount: result.shareCount });
      smartToast.success(result.created ? 'Post shared' : 'Already shared');
    } catch {
      smartToast.error('Share failed');
    }
  };

  const handleSubmitComment = async () => {
    if (!post || submitting || !commentBody.trim()) return;
    try {
      setSubmitting(true);
      const result = await feedService.addComment(post.id, commentBody.trim(), replyTo?.id);
      setComments((prev) => [result.comment, ...prev]);
      setPost({ ...post, commentCount: result.commentCount });
      setCommentBody('');
      setReplyTo(null);
    } catch {
      smartToast.error('Unable to send comment');
    } finally {
      setSubmitting(false);
    }
  };

  const handleLikeComment = async (comment: FeedComment) => {
    const delta = comment.liked ? -1 : 1;
    setComments((prev) => prev.map((item) => (
      item.id === comment.id
        ? { ...item, liked: !item.liked, likeCount: Math.max(item.likeCount + delta, 0) }
        : item
    )));
    try {
      const result = await feedService.toggleCommentLike(comment.postId, comment.id);
      setComments((prev) => prev.map((item) => (
        item.id === comment.id ? { ...item, liked: result.liked, likeCount: result.likeCount } : item
      )));
    } catch {
      setComments((prev) => prev.map((item) => (item.id === comment.id ? comment : item)));
      smartToast.error('Unable to like comment');
    }
  };

  const startReply = (comment: FeedComment) => {
    setReplyTo(comment);
    setCommentBody(`@${comment.author.username} `);
    window.setTimeout(() => inputRef.current?.focus(), 0);
  };

  const roots = comments.filter((comment) => !comment.parentCommentId);
  const repliesByParent = comments.reduce<Record<string, FeedComment[]>>((acc, comment) => {
    if (comment.parentCommentId) {
      acc[comment.parentCommentId] = [...(acc[comment.parentCommentId] || []), comment];
    }
    return acc;
  }, {});

  if (loading) {
    return (
      <div className="mx-auto flex max-w-2xl justify-center py-16">
        <div className="h-8 w-8 animate-spin rounded-full border-2 border-prava-accent border-t-transparent" />
      </div>
    );
  }

  if (!post) {
    return (
      <div className="mx-auto max-w-2xl py-16 text-center">
        <h1 className="text-h2 text-prava-light-text-primary dark:text-prava-dark-text-primary">Post not found</h1>
      </div>
    );
  }

  return (
    <div className="mx-auto max-w-2xl pb-8">
      <h1 className="mb-5 text-h1 text-prava-light-text-primary dark:text-prava-dark-text-primary">
        Post
      </h1>

      <Post
        post={post}
        onLike={handleLikePost}
        onShare={handleShare}
        onComment={() => inputRef.current?.focus()}
      />

      <section className="mt-6">
        <div className="mb-4 flex items-center gap-2">
          <MessageCircle className="h-5 w-5 text-prava-accent" strokeWidth={3} />
          <h2 className="text-h3 text-prava-light-text-primary dark:text-prava-dark-text-primary">
            Comments
          </h2>
        </div>

        {replyTo && (
          <div className="mb-3 flex items-center justify-between rounded-[14px] bg-prava-accent/10 px-3 py-2 text-body-sm text-prava-accent">
            Replying to @{replyTo.author.username}
            <button type="button" onClick={() => setReplyTo(null)} className="font-bold">
              Cancel
            </button>
          </div>
        )}

        <div className="mb-5 flex items-center gap-2">
          <input
            ref={inputRef}
            value={commentBody}
            onChange={(event) => setCommentBody(event.target.value)}
            onKeyDown={(event) => {
              if (event.key === 'Enter') {
                event.preventDefault();
                handleSubmitComment();
              }
            }}
            placeholder="Add a comment"
            className="min-w-0 flex-1 rounded-full bg-prava-light-surface px-4 py-3 text-body text-prava-light-text-primary outline-none focus:ring-2 focus:ring-prava-accent/30 dark:bg-white/[0.08] dark:text-prava-dark-text-primary"
          />
          <button
            type="button"
            onClick={handleSubmitComment}
            disabled={submitting || !commentBody.trim()}
            className="grid h-11 w-11 place-items-center rounded-full bg-prava-accent text-white disabled:opacity-45"
            aria-label="Send comment"
          >
            <Send className="h-5 w-5" strokeWidth={3} />
          </button>
        </div>

        <div className="space-y-5">
          {roots.length === 0 ? (
            <p className="py-10 text-center text-body text-prava-light-text-secondary dark:text-prava-dark-text-secondary">
              No comments yet
            </p>
          ) : (
            roots.map((comment) => (
              <CommentItem
                key={comment.id}
                comment={comment}
                replies={repliesByParent[comment.id] || []}
                onLike={handleLikeComment}
                onReply={startReply}
              />
            ))
          )}
        </div>
      </section>
    </div>
  );
}

function CommentItem({
  comment,
  replies,
  onLike,
  onReply,
}: {
  comment: FeedComment;
  replies: FeedComment[];
  onLike: (comment: FeedComment) => void;
  onReply: (comment: FeedComment) => void;
}) {
  return (
    <div>
      <div className="flex gap-3">
        <Link to={`/profile/${comment.author.id}`} className="shrink-0">
          {comment.author.avatarUrl ? (
            <img src={comment.author.avatarUrl} alt="" className="h-10 w-10 rounded-full object-cover" />
          ) : (
            <span className="grid h-10 w-10 place-items-center rounded-full bg-prava-accent/15 font-bold text-prava-accent">
              {comment.author.displayName.charAt(0).toUpperCase()}
            </span>
          )}
        </Link>
        <div className="min-w-0 flex-1">
          <div className="text-body text-prava-light-text-primary dark:text-prava-dark-text-primary">
            <Link to={`/profile/${comment.author.id}`} className="mr-2 font-bold">
              {comment.author.username}
            </Link>
            {renderLinkedText(comment.body)}
          </div>
          <div className="mt-2 flex items-center gap-4 text-body-sm text-prava-light-text-tertiary dark:text-prava-dark-text-tertiary">
            <span>{timeAgo(comment.createdAt)}</span>
            <button type="button" onClick={() => onLike(comment)} className={comment.liked ? 'text-prava-accent' : ''}>
              {comment.likeCount > 0 ? `${comment.likeCount} likes` : 'Like'}
            </button>
            <button type="button" onClick={() => onReply(comment)}>
              Reply
            </button>
          </div>
        </div>
        <button
          type="button"
          onClick={() => onLike(comment)}
          className={`grid h-9 w-9 place-items-center rounded-full ${comment.liked ? 'text-prava-accent' : 'text-prava-light-text-tertiary dark:text-prava-dark-text-tertiary'}`}
          aria-label="Like comment"
        >
          <Heart className={comment.liked ? 'h-5 w-5 fill-current' : 'h-5 w-5'} strokeWidth={3} />
        </button>
      </div>

      {replies.slice(0, 1).map((reply) => (
        <div key={reply.id} className="ml-12 mt-4">
          <CommentItem comment={reply} replies={[]} onLike={onLike} onReply={onReply} />
        </div>
      ))}
    </div>
  );
}
