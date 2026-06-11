import { env } from "../config/env.js";
import { closePg, connectPg } from "../lib/pg.js";
import { runRetentionAndPartitions } from "../workers/reconciliation/index.js";

let timer: ReturnType<typeof setInterval> | null = null;

async function runOnce(): Promise<void> {
  await runRetentionAndPartitions();
}

async function main(): Promise<void> {
  await connectPg();
  await runOnce();
  const intervalMs = Math.max(60_000, Number(process.env.SCHEDULER_INTERVAL_MS || 300_000));
  timer = setInterval(() => {
    void runOnce();
  }, intervalMs);
}

async function shutdown(): Promise<void> {
  if (timer) {
    clearInterval(timer);
  }
  await closePg().catch(() => undefined);
}

process.on("SIGINT", () => void shutdown());
process.on("SIGTERM", () => void shutdown());

main().catch((error) => {
  // eslint-disable-next-line no-console
  console.error({ error, env: env.NODE_ENV }, "scheduler failed");
  process.exit(1);
});
