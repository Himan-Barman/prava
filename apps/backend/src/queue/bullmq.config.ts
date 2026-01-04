import { Queue, Worker } from 'bullmq';
import { config } from '@/app.config';

export const connection = {
  connection: {
    url: config.REDIS_URL,
  },
};

export const emailQueue = new Queue('email', connection);
export const messageQueue = new Queue('message', connection);
export const notificationQueue = new Queue('notification', connection);
export const messageRetryQueue = new Queue('message-retry', connection);
export const mediaQueue = new Queue('media', connection);
