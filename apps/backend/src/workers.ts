import { emailWorker } from './queue/workers/email.worker';
import { messageWorker } from './queue/workers/message.worker';
import { notificationWorker } from './queue/workers/notification.worker';
import { messageRetryWorker } from './queue/workers/message-retry.worker';
import { mediaWorker } from './queue/workers/media.worker';

async function shutdown(signal: string) {
  console.log(`Workers shutting down (${signal})`);
  await Promise.allSettled([
    emailWorker.close(),
    messageWorker.close(),
    notificationWorker.close(),
    messageRetryWorker.close(),
    mediaWorker.close(),
  ]);
  process.exit(0);
}

process.on('SIGINT', () => {
  void shutdown('SIGINT');
});

process.on('SIGTERM', () => {
  void shutdown('SIGTERM');
});

console.log('Workers online');
