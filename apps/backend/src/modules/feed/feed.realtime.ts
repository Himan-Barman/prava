import { redisPub } from '@/redis/redis.pubsub';
import { feedTopic } from '@/realtime/ws.hub';

const WS_CHANNEL_PREFIX = 'ws:';

export async function publishFeedEvent(payload: unknown) {
  if (!redisPub.isOpen) return;

  await redisPub.publish(
    `${WS_CHANNEL_PREFIX}${feedTopic()}`,
    JSON.stringify(payload),
  );
}
