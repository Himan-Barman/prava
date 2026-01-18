CREATE TABLE IF NOT EXISTS device_identity_keys (
  user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  device_id varchar(128) NOT NULL,
  platform varchar(16) NOT NULL,
  device_name varchar(64),
  identity_key text NOT NULL,
  registration_id integer,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  last_seen_at timestamptz,
  revoked_at timestamptz,
  CONSTRAINT device_identity_keys_pk PRIMARY KEY (user_id, device_id)
);

CREATE INDEX IF NOT EXISTS device_identity_user_idx
ON device_identity_keys (user_id);

CREATE INDEX IF NOT EXISTS device_identity_device_idx
ON device_identity_keys (device_id);

CREATE TABLE IF NOT EXISTS device_signed_prekeys (
  user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  device_id varchar(128) NOT NULL,
  key_id integer NOT NULL,
  public_key text NOT NULL,
  signature text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  expires_at timestamptz,
  revoked_at timestamptz,
  CONSTRAINT device_signed_prekeys_pk PRIMARY KEY (user_id, device_id, key_id)
);

CREATE INDEX IF NOT EXISTS device_signed_prekeys_user_device_idx
ON device_signed_prekeys (user_id, device_id);

CREATE TABLE IF NOT EXISTS device_prekeys (
  user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  device_id varchar(128) NOT NULL,
  key_id integer NOT NULL,
  public_key text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  consumed_at timestamptz,
  CONSTRAINT device_prekeys_pk PRIMARY KEY (user_id, device_id, key_id)
);

CREATE INDEX IF NOT EXISTS device_prekeys_user_device_idx
ON device_prekeys (user_id, device_id);

CREATE INDEX IF NOT EXISTS device_prekeys_consumed_idx
ON device_prekeys (user_id, device_id, consumed_at);

CREATE TABLE IF NOT EXISTS device_trust (
  trusting_user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  trusted_user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  trusted_device_id varchar(128) NOT NULL,
  status varchar(16) NOT NULL DEFAULT 'unverified',
  verified_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT device_trust_pk PRIMARY KEY (trusting_user_id, trusted_user_id, trusted_device_id)
);

CREATE INDEX IF NOT EXISTS device_trust_trusting_idx
ON device_trust (trusting_user_id);

CREATE INDEX IF NOT EXISTS device_trust_trusted_idx
ON device_trust (trusted_user_id);
