# Chat Service

Base path: `/api/conversations`

Core:
- `GET /` list user conversations
  - Query: `archived=true`, `includeArchived=true`, `starred=true`, `favorite=true`, `limit`
  - Summary rows include unread count, request state, peer metadata, preference flags, marked-unread state, and draft metadata.
- `GET /:conversationId` conversation metadata
- `POST /dm` create/reuse direct chat
- `POST /group` create group chat

Chat controls:
- `GET /settings` read chat settings
- `PATCH /settings` update chat settings
- `PUT /:conversationId/preferences` patch favourite/star/mute/archive/marked-unread/draft preferences
- `POST /:conversationId/archive`
- `POST /:conversationId/unarchive`
- `POST /:conversationId/pin`
- `POST /:conversationId/unpin`
- `POST /:conversationId/favourite`
- `POST /:conversationId/unfavourite`
- `POST /:conversationId/mute`
- `POST /:conversationId/unmute`
- `POST /:conversationId/mark-unread`

Group management:
- `PATCH /:conversationId` update group title
- `GET /:conversationId/members`
- `POST /:conversationId/members`
- `DELETE /:conversationId/members/:memberUserId`
- `PATCH /groups/:conversationId/members/:memberUserId/role`
- `GET /groups/:conversationId/invites`
- `POST /groups/:conversationId/invites`
- `DELETE /groups/:conversationId/invites/:inviteId`
- `POST /groups/join/:inviteToken`
- `GET /groups/:conversationId/join-requests`
- `POST /groups/:conversationId/join-requests/:requestId/approve`
- `POST /groups/:conversationId/join-requests/:requestId/reject`
- `POST /:conversationId/leave`
- `POST /:conversationId/admins`
- `DELETE /:conversationId/admins/:memberUserId`

Attachments:
- `POST /attachments/upload-init` creates a pending chat attachment and returns the media upload endpoint.
- `POST /attachments/upload-complete` links an owned media asset to the pending attachment.
- `GET /:conversationId/attachments` lists ready/attached media for a conversation.
- `DELETE /attachments/:attachmentId` soft-deletes an owned pending/ready attachment.

Messages:
- `GET /:conversationId/messages`
- `GET /:conversationId/search?q=keyword`
- `GET /:conversationId/pinned-messages`
- `GET /:conversationId/messages/:messageId/details`
- `POST /:conversationId/messages`
- `PATCH /:conversationId/messages/:messageId`
- `DELETE /:conversationId/messages/:messageId`
- `POST /:conversationId/messages/:messageId/pin`
- `DELETE /:conversationId/messages/:messageId/pin`
- `POST /:conversationId/messages/:messageId/reactions`
- `DELETE /:conversationId/messages/:messageId/reactions`

Safety:
- `POST /report` creates a chat-level or message-level report after verifying the reporter is a conversation member.

Sync and receipts:
- `GET /:conversationId/reads`
- `POST /:conversationId/read`
- `POST /:conversationId/delivery`
- `POST /sync` batch delta sync by `lastKnownSeq`

Realtime events:
- `MESSAGE_PUSH`: emitted once for a newly created message. Retries with the same `clientMessageId` return the existing message and do not re-emit.
- `MESSAGE_ACK`: sent back to the sender when a temp/client id is provided.
- `READ_UPDATE` and `DELIVERY_UPDATE`: emitted for receipt changes.
- `REACTION_UPDATE`, `MESSAGE_EDIT`, `MESSAGE_DELETE`: emitted for message mutations.
- `MESSAGE_PINNED` and `MESSAGE_UNPINNED`: emitted when pinned messages change.
- `MESSAGE_REQUEST_ACCEPTED` and `MESSAGE_REQUEST_DECLINED`: emitted for DM request state changes.
