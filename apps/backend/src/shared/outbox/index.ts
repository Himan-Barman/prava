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
  await runner.query(
    `UPDATE outbox_events
     SET attempts = attempts + 1,
         status = CASE WHEN attempts >= 9 THEN 'dead' ELSE 'pending' END,
         available_at = NOW() + make_interval(secs => LEAST(3600, POWER(2, attempts + 1)::int)),
         last_error = $2
     WHERE id = $1`,
    [eventId, error instanceof Error ? error.message : String(error)]
  );
}
