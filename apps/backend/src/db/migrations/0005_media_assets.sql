CREATE TABLE IF NOT EXISTS media_assets (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  conversation_id uuid REFERENCES conversations(id) ON DELETE SET NULL,
  status varchar(16) NOT NULL DEFAULT 'pending',
  content_type varchar(128) NOT NULL,
  file_name varchar(256),
  size_bytes bigint,
  sha256 varchar(64),
  storage_bucket varchar(128) NOT NULL,
  storage_key varchar(512) NOT NULL,
  storage_region varchar(64),
  metadata jsonb,
  encryption_algorithm varchar(32),
  encryption_key_id varchar(128),
  encryption_iv varchar(128),
  encryption_key_hash varchar(128),
  thumbnail_key varchar(512),
  thumbnail_content_type varchar(128),
  retention_policy varchar(32) NOT NULL DEFAULT 'standard',
  expires_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  uploaded_at timestamptz,
  processed_at timestamptz
);

CREATE UNIQUE INDEX IF NOT EXISTS media_assets_storage_key_unique
ON media_assets (storage_key);

CREATE INDEX IF NOT EXISTS media_assets_user_idx
ON media_assets (user_id);

CREATE INDEX IF NOT EXISTS media_assets_conversation_idx
ON media_assets (conversation_id);

CREATE INDEX IF NOT EXISTS media_assets_status_idx
ON media_assets (status);

ALTER TABLE messages
ADD COLUMN IF NOT EXISTS media_asset_id uuid REFERENCES media_assets(id) ON DELETE SET NULL;
