import { redisPub } from '@/redis/redis.pubsub';
import { userTopic } from '@/realtime/ws.hub';

const WS_CHANNEL_PREFIX = 'ws:';

export async function publishNotification(
  userId: string,
  payload: unknown,
) {
  if (!redisPub.isOpen) return;

  await redisPub.publish(
    `${WS_CHANNEL_PREFIX}${userTopic(userId)}`,
    JSON.stringify(payload),
  );
}
