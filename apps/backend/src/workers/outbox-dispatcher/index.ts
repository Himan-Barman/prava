import { queryMany, withTransaction } from "../../lib/pg.js";
import { markOutboxFailed, markOutboxProcessed } from "../../shared/outbox/index.js";
import { incrementMetric, observeTiming } from "../../shared/metrics/index.js";

export type OutboxDispatchResult = {
  processed: number;
  failed: number;
};

async function dispatchEvent(event: any): Promise<void> {
  // Durable side effects are intentionally small here. Provider-specific push,
  // email and fanout workers can subscribe by event_type without changing
  // transaction writers.
  if (event.event_type === "noop") {
    return;
  }
}

export async function runOutboxDispatcherBatch(limit = 100): Promise<OutboxDispatchResult> {
  const started = Date.now();
  const events = await queryMany(
    `SELECT *
     FROM outbox_events
     WHERE status = 'pending'
       AND available_at <= NOW()
     ORDER BY created_at ASC
     LIMIT $1`,
    [limit]
  );

  let processed = 0;
  let failed = 0;
  for (const event of events) {
    try {
      await dispatchEvent(event);
      await withTransaction(async (client) => {
        await markOutboxProcessed(String(event.id), client);
      });
      processed += 1;
    } catch (error) {
      await markOutboxFailed(String(event.id), error);
      failed += 1;
    }
  }

  incrementMetric("worker.outbox.processed", processed);
  incrementMetric("worker.outbox.failed", failed);
  observeTiming("worker.outbox.batch_ms", Date.now() - started);
  return { processed, failed };
}
