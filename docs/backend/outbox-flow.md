# Outbox Flow

Writers enqueue durable rows in `outbox_events` inside or immediately after the transaction. The worker reads pending rows, dispatches side effects, marks rows processed, and backs off failures. Failed events can become dead-letter candidates after repeated attempts.

Implemented helper:

- `enqueueOutboxEvent`
- `markOutboxProcessed`
- `markOutboxFailed`
- `runOutboxDispatcherBatch`
