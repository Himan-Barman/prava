# Moderation Flow

Implemented:

- User reports through `/api/v1/reports`.
- Admin moderation case list/detail.
- Admin moderation notes through outbox events.
- Admin action creation and reversal event.
- Shared moderation policy gate based on user role.

Automatic enforcement workers can consume `moderation.*` outbox events.
