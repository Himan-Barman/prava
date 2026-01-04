CREATE TABLE IF NOT EXISTS "notifications" (
  "id" uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  "user_id" uuid NOT NULL,
  "actor_id" uuid,
  "type" varchar(32) NOT NULL,
  "title" varchar(120) NOT NULL,
  "body" text NOT NULL,
  "data" jsonb,
  "read_at" timestamp with time zone,
  "created_at" timestamp with time zone NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS "notifications_user_idx"
ON "notifications" ("user_id");

CREATE INDEX IF NOT EXISTS "notifications_read_idx"
ON "notifications" ("user_id", "read_at");

CREATE INDEX IF NOT EXISTS "notifications_created_idx"
ON "notifications" ("user_id", "created_at");
