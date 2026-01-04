CREATE TABLE IF NOT EXISTS "email_otp_tokens" (
  "id" uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  "email" varchar(255) NOT NULL,
  "token_hash" varchar(64) NOT NULL,
  "attempts" integer NOT NULL DEFAULT 0,
  "expires_at" timestamp with time zone NOT NULL,
  "used_at" timestamp with time zone,
  "created_at" timestamp with time zone NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS "email_otp_email_idx"
ON "email_otp_tokens" ("email");

CREATE INDEX IF NOT EXISTS "email_otp_token_idx"
ON "email_otp_tokens" ("token_hash");
