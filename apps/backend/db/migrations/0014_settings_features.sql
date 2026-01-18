CREATE TABLE IF NOT EXISTS "user_blocks" (
  "id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
  "blocker_id" uuid NOT NULL REFERENCES "users"("id") ON DELETE CASCADE,
  "blocked_id" uuid NOT NULL REFERENCES "users"("id") ON DELETE CASCADE,
  "created_at" timestamp with time zone DEFAULT now() NOT NULL,
  CONSTRAINT "user_blocks_unique" UNIQUE("blocker_id", "blocked_id")
);

CREATE INDEX IF NOT EXISTS "user_blocks_blocker_idx"
ON "user_blocks" ("blocker_id");

CREATE INDEX IF NOT EXISTS "user_blocks_blocked_idx"
ON "user_blocks" ("blocked_id");

CREATE TABLE IF NOT EXISTS "user_muted_words" (
  "id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
  "user_id" uuid NOT NULL REFERENCES "users"("id") ON DELETE CASCADE,
  "phrase" varchar(120) NOT NULL,
  "created_at" timestamp with time zone DEFAULT now() NOT NULL,
  CONSTRAINT "user_muted_words_unique" UNIQUE("user_id", "phrase")
);

CREATE INDEX IF NOT EXISTS "user_muted_words_user_idx"
ON "user_muted_words" ("user_id");

CREATE TABLE IF NOT EXISTS "user_data_exports" (
  "id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
  "user_id" uuid NOT NULL REFERENCES "users"("id") ON DELETE CASCADE,
  "status" varchar(16) NOT NULL DEFAULT 'ready',
  "format" varchar(16) NOT NULL DEFAULT 'json',
  "payload" jsonb NOT NULL DEFAULT '{}'::jsonb,
  "created_at" timestamp with time zone DEFAULT now() NOT NULL,
  "completed_at" timestamp with time zone
);

CREATE INDEX IF NOT EXISTS "user_data_exports_user_idx"
ON "user_data_exports" ("user_id", "created_at");

CREATE TABLE IF NOT EXISTS "support_tickets" (
  "id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
  "user_id" uuid REFERENCES "users"("id") ON DELETE SET NULL,
  "type" varchar(16) NOT NULL,
  "category" varchar(32),
  "message" text NOT NULL,
  "metadata" jsonb NOT NULL DEFAULT '{}'::jsonb,
  "created_at" timestamp with time zone DEFAULT now() NOT NULL
);

CREATE INDEX IF NOT EXISTS "support_tickets_user_idx"
ON "support_tickets" ("user_id");

CREATE INDEX IF NOT EXISTS "support_tickets_type_idx"
ON "support_tickets" ("type");

ALTER TABLE "refresh_tokens"
  ADD COLUMN IF NOT EXISTS "device_name" varchar(64);

ALTER TABLE "refresh_tokens"
  ADD COLUMN IF NOT EXISTS "platform" varchar(16);

ALTER TABLE "refresh_tokens"
  ADD COLUMN IF NOT EXISTS "last_seen_at" timestamp with time zone;
