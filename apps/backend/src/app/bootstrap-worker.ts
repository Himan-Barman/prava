import { env } from "../config/env.js";
import { closePg, connectPg } from "../lib/pg.js";
import { closeRedis, connectRedis } from "../lib/redis.js";
import { runOutboxDispatcherBatch } from "../workers/outbox-dispatcher/index.js";
import { reconcileCounters } from "../workers/reconciliation/index.js";

let shuttingDown = false;

async function loop(): Promise<void> {
  await connectPg();
  await connectRedis().catch(() => null);

  const intervalMs = Math.max(5000, Number(process.env.WORKER_INTERVAL_MS || 15000));
  while (!shuttingDown) {
    await runOutboxDispatcherBatch(100);
    await reconcileCounters();
    await new Promise((resolve) => setTimeout(resolve, intervalMs));
  }
}

async function shutdown(): Promise<void> {
  shuttingDown = true;
  await closeRedis().catch(() => undefined);
  await closePg().catch(() => undefined);
}

process.on("SIGINT", () => void shutdown());
process.on("SIGTERM", () => void shutdown());

loop().catch((error) => {
  // eslint-disable-next-line no-console
  console.error({ error, env: env.NODE_ENV }, "worker failed");
  process.exit(1);
});
