CREATE TABLE IF NOT EXISTS push_tokens (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  device_id varchar(128) NOT NULL,
  platform varchar(16) NOT NULL,
  token varchar(512) NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  revoked_at timestamptz
);

CREATE UNIQUE INDEX IF NOT EXISTS push_tokens_device_unique
ON push_tokens (user_id, device_id);

CREATE UNIQUE INDEX IF NOT EXISTS push_tokens_token_unique
ON push_tokens (token);

CREATE INDEX IF NOT EXISTS push_tokens_user_idx
ON push_tokens (user_id);
