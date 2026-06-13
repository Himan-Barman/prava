import type pg from "pg";

import { query } from "../../lib/pg.js";
import { generateId, now } from "../../lib/security.js";

type Queryable = Pick<pg.PoolClient, "query">;

export type OutboxEventInput = {
  eventType: string;
  aggregateType: string;
  aggregateId?: string | null;
  payload?: Record<string, unknown>;
  availableAt?: Date;
};

export async function enqueueOutboxEvent(
  input: OutboxEventInput,
  client?: Queryable
): Promise<string> {
  const id = generateId();
  const runner = client || { query };
  await runner.query(
    `INSERT INTO outbox_events (
       id, aggregate_type, aggregate_uuid, aggregate_id, event_type,
       payload, status, available_at, created_at
     )
     VALUES ($1, $2, $3, $4, $5, $6, 'pending', $7, $8)
     ON CONFLICT (id) DO NOTHING`,
    [
      id,
      input.aggregateType,
      input.aggregateId || null,
      input.aggregateId || null,
      input.eventType,
      JSON.stringify(input.payload || {}),
      input.availableAt || now(),
      now(),
    ]
  );
  return id;
}

export async function markOutboxProcessed(eventId: string, client?: Queryable): Promise<void> {
  const runner = client || { query };
  await runner.query(
    `UPDATE outbox_events
     SET status = 'processed',
         processed_at = COALESCE(processed_at, NOW()),
         last_error = NULL
     WHERE id = $1`,
    [eventId]
  );
}

export async function markOutboxFailed(
  eventId: string,
  error: unknown,
  client?: Queryable
): Promise<void> {
  const runner = client || { query };
  const message = error instanceof Error ? error.message : String(error);
  const nextRetryAt = new Date(Date.now() + Math.min(3_600_000, 1000 * 2 ** 3));
  await runner.query(
    `UPDATE outbox_events
     SET attempts = attempts + 1,
         status = CASE WHEN attempts >= 9 THEN 'dead' ELSE 'pending' END,
         available_at = $3,
         last_error = $2
     WHERE id = $1`,
    [eventId, message.slice(0, 1000), nextRetryAt]
  );
}
