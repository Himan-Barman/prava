import { query, queryMany } from "../../lib/pg.js";
import { runFeedAggregationJobs } from "../../services/feed/recommendation.js";
import {
  archiveProcessedNotificationOutbox,
  cleanupInvalidDeviceTokens,
  expireOldNotifications,
  reconcileUnreadCounters,
  retryPendingDeliveries,
} from "../../services/notification/repository.js";
import { incrementMetric, observeTiming } from "../../shared/metrics/index.js";

export async function reconcileCounters(): Promise<{ users: number; posts: number; notificationCounters: number }> {
  const started = Date.now();
  const [users, posts] = await Promise.all([
    queryMany(`SELECT id FROM users WHERE id IS NOT NULL LIMIT 1000`),
    queryMany(`SELECT id FROM posts WHERE id IS NOT NULL LIMIT 1000`),
  ]);

  for (const user of users) {
    await query(`SELECT prava_reconcile_user_stats($1)`, [user.id]).catch(() => undefined);
  }
  for (const post of posts) {
    await query(`SELECT prava_reconcile_post_stats($1)`, [post.id]).catch(() => undefined);
  }

  await runFeedAggregationJobs();
  const notificationResult = await reconcileUnreadCounters(1000);
  incrementMetric("worker.reconciliation.users", users.length);
  incrementMetric("worker.reconciliation.posts", posts.length);
  incrementMetric("worker.reconciliation.notification_counters", notificationResult.repaired);
  observeTiming("worker.reconciliation.batch_ms", Date.now() - started);
  return {
    users: users.length,
    posts: posts.length,
    notificationCounters: notificationResult.repaired,
  };
}

export async function runRetentionAndPartitions(): Promise<void> {
  await query(`SELECT * FROM prava_create_future_partitions(3)`).catch(() => undefined);
  const policies = await queryMany(
    `SELECT policy_key FROM retention_policies WHERE enabled = true AND action = 'delete'`
  ).catch(() => []);
  for (const policy of policies) {
    await query(`SELECT prava_run_retention_policy($1, 10000)`, [policy.policy_key]).catch(() => undefined);
  }
  await expireOldNotifications(5000);
  await cleanupInvalidDeviceTokens(5000);
  await retryPendingDeliveries(1000);
  await archiveProcessedNotificationOutbox(14);
}
