CREATE TABLE IF NOT EXISTS feed_posts (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  author_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  body text NOT NULL,
  like_count integer NOT NULL DEFAULT 0,
  comment_count integer NOT NULL DEFAULT 0,
  share_count integer NOT NULL DEFAULT 0,
  metadata jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS feed_posts_created_idx
ON feed_posts (created_at);

CREATE INDEX IF NOT EXISTS feed_posts_author_idx
ON feed_posts (author_id);

CREATE TABLE IF NOT EXISTS feed_likes (
  post_id uuid NOT NULL REFERENCES feed_posts(id) ON DELETE CASCADE,
  user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT feed_likes_pk PRIMARY KEY (post_id, user_id)
);

CREATE INDEX IF NOT EXISTS feed_likes_user_idx
ON feed_likes (user_id);

CREATE TABLE IF NOT EXISTS feed_comments (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  post_id uuid NOT NULL REFERENCES feed_posts(id) ON DELETE CASCADE,
  author_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  body text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS feed_comments_post_idx
ON feed_comments (post_id);

CREATE INDEX IF NOT EXISTS feed_comments_author_idx
ON feed_comments (author_id);

CREATE TABLE IF NOT EXISTS feed_shares (
  post_id uuid NOT NULL REFERENCES feed_posts(id) ON DELETE CASCADE,
  user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT feed_shares_pk PRIMARY KEY (post_id, user_id)
);

CREATE INDEX IF NOT EXISTS feed_shares_user_idx
ON feed_shares (user_id);

CREATE TABLE IF NOT EXISTS follows (
  follower_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  following_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT follows_pk PRIMARY KEY (follower_id, following_id)
);

CREATE INDEX IF NOT EXISTS follows_follower_idx
ON follows (follower_id);

CREATE INDEX IF NOT EXISTS follows_following_idx
ON follows (following_id);
