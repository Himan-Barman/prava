CREATE TABLE IF NOT EXISTS "user_interest_profiles" (
  "id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
  "user_id" uuid NOT NULL REFERENCES "users"("id") ON DELETE CASCADE,
  "tag" text NOT NULL,
  "score" double precision DEFAULT 0 NOT NULL,
  "created_at" timestamptz DEFAULT now() NOT NULL,
  "updated_at" timestamptz DEFAULT now() NOT NULL,
  CONSTRAINT "user_interest_profiles_user_tag_unique" UNIQUE ("user_id","tag")
);

CREATE INDEX IF NOT EXISTS "user_interest_profiles_user_idx"
  ON "user_interest_profiles" ("user_id");

CREATE INDEX IF NOT EXISTS "user_interest_profiles_tag_idx"
  ON "user_interest_profiles" ("tag");
