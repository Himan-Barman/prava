ALTER TABLE users
ADD COLUMN IF NOT EXISTS username varchar(32);

ALTER TABLE users
ADD COLUMN IF NOT EXISTS display_name varchar(64);

UPDATE users
SET username = lower(split_part(email, '@', 1))
WHERE username IS NULL;

ALTER TABLE users
ALTER COLUMN username SET NOT NULL;

CREATE UNIQUE INDEX IF NOT EXISTS users_username_unique
ON users (username);
