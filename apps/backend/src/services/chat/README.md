# Chat Service

Base path: `/api/conversations`

Core:
- `GET /` list user conversations
- `GET /:conversationId` conversation metadata
- `POST /dm` create/reuse direct chat
- `POST /group` create group chat

Group management:
- `PATCH /:conversationId` update group title
- `GET /:conversationId/members`
- `POST /:conversationId/members`
- `DELETE /:conversationId/members/:memberUserId`
- `POST /:conversationId/leave`
- `POST /:conversationId/admins`
- `DELETE /:conversationId/admins/:memberUserId`

Messages:
- `GET /:conversationId/messages`
- `POST /:conversationId/messages`
- `PATCH /:conversationId/messages/:messageId`
- `DELETE /:conversationId/messages/:messageId`
- `POST /:conversationId/messages/:messageId/reactions`
- `DELETE /:conversationId/messages/:messageId/reactions`

Sync and receipts:
- `GET /:conversationId/reads`
- `POST /:conversationId/read`
- `POST /:conversationId/delivery`
- `POST /sync` batch delta sync by `lastKnownSeq`
