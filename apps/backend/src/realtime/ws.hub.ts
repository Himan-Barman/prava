import { WsFanout } from './ws.fanout';
import { recordWsPublish } from '@/observability/metrics';

export const userTopic = (userId: string) => `user:${userId}`;
export const conversationTopic = (conversationId: string) =>
  `conversation:${conversationId}`;
export const feedTopic = () => 'feed:global';

type SubscribableSocket = { subscribe(topic: string): void };
type Publisher = { publish(topic: string, payload: string): void };

export class WsHub {
  constructor(
    private readonly publisher: Publisher,
    private readonly fanout?: WsFanout,
  ) {}

  subscribeUser(ws: SubscribableSocket, userId: string) {
    ws.subscribe(userTopic(userId));
  }

  subscribeConversation(ws: SubscribableSocket, conversationId: string) {
    ws.subscribe(conversationTopic(conversationId));
  }

  subscribeFeed(ws: SubscribableSocket) {
    ws.subscribe(feedTopic());
  }

  publishToUser(userId: string, payload: unknown) {
    const message = JSON.stringify(payload);

    if (this.fanout) {
      this.fanout.publish({
        scope: 'user',
        topic: userTopic(userId),
        payload: message,
      });
      return;
    }

    recordWsPublish('user', 'local');
    this.publisher.publish(userTopic(userId), message);
  }

  publishToConversation(conversationId: string, payload: unknown) {
    const message = JSON.stringify(payload);

    if (this.fanout) {
      this.fanout.publish({
        scope: 'conversation',
        topic: conversationTopic(conversationId),
        payload: message,
      });
      return;
    }

    recordWsPublish('conversation', 'local');
    this.publisher.publish(conversationTopic(conversationId), message);
  }
}
