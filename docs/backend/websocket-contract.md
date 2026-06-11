# WebSocket Contract

Current endpoint:

- `/`
- `/ws`

Authentication is provided by `?token=<accessToken>&deviceId=<deviceId>`.

Client events supported by the gateway:

- `CONVERSATION_SUBSCRIBE`
- `FEED_SUBSCRIBE`
- `MESSAGE_SEND`
- `MESSAGE_EDIT`
- `MESSAGE_DELETE`
- `REACTION_SET`
- `REACTION_REMOVE`
- `READ_RECEIPT`
- `DELIVERY_RECEIPT`
- `SYNC_INIT`
- `TYPING_START`
- `TYPING_STOP`

Server events include message push, acknowledgement, read and delivery updates, typing, presence and notification fanout.
