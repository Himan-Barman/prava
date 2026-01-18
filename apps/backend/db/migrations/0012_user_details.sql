ALTER TABLE "users"
  ADD COLUMN IF NOT EXISTS "first_name" varchar(64),
  ADD COLUMN IF NOT EXISTS "last_name" varchar(64),
  ADD COLUMN IF NOT EXISTS "phone_country" varchar(8),
  ADD COLUMN IF NOT EXISTS "phone_number" varchar(20);
