ALTER TABLE messages
ADD COLUMN IF NOT EXISTS client_temp_id varchar(64);

CREATE UNIQUE INDEX IF NOT EXISTS idx_messages_temp_id_unique
ON messages (
  conversation_id,
  sender_user_id,
  sender_device_id,
  client_temp_id
);
