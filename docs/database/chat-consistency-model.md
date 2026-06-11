# Chat Consistency Model

## Ordering

`conversations.seq_counter` remains the legacy ordering source. `messages.sequence_id` is the UUID-layer equivalent and should mirror the per-conversation monotonic sequence.

## Direct Conversations

`direct_conversation_pairs` prevents duplicate one-to-one conversations by storing the lower and higher user UUID pair.

## Membership

`conversation_members` keeps the legacy membership row and adds:

- `conversation_uuid`
- `user_uuid`
- `member_role`
- `status`
- `last_read_message_uuid`
- `last_read_sequence_id`
- mute/archive state

## Receipts

`message_receipts` stores per-message per-user delivery/read receipts. It is append-friendly and deduplicated by `(message_id, user_id, receipt_type)`.

## Events

`conversation_events` records membership, title, invite, role, and moderation changes so chat state can be rebuilt or audited.

