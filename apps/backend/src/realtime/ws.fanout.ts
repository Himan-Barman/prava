import { initPubSub, redisPub, redisSub } from '@/redis/redis.pubsub';
import { recordWsFanoutDeliver, recordWsPublish } from '@/observability/metrics';

const CHANNEL_PREFIX = 'ws:';

type LocalPublish = (topic: string, payload: string) => void;

export class WsFanout {
  private subscribed = false;

  constructor(private readonly publishLocal: LocalPublish) {}

  async init() {
    await initPubSub();

    if (this.subscribed || !redisSub.isOpen) {
      return;
    }

    try {
      await redisSub.pSubscribe(
        `${CHANNEL_PREFIX}*`,
        (message, channel) => {
          if (!channel.startsWith(CHANNEL_PREFIX)) return;
          const topic = channel.slice(CHANNEL_PREFIX.length);
          if (!topic) return;

          this.publishLocal(topic, message);
          recordWsFanoutDeliver('redis');
        },
      );

      this.subscribed = true;
    } catch {
      this.subscribed = false;
    }
  }

  publish(input: {
    scope: 'user' | 'conversation';
    topic: string;
    payload: string;
  }) {
    const via =
      this.subscribed && redisPub.isOpen ? 'redis' : 'local';

    recordWsPublish(input.scope, via);

    if (via === 'redis') {
      void redisPub.publish(
        `${CHANNEL_PREFIX}${input.topic}`,
        input.payload,
      );
      return;
    }

    this.publishLocal(input.topic, input.payload);
  }
}
