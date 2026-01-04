import 'uWebSockets.js';

declare module 'uWebSockets.js' {
  interface WebSocket {
    userId: string;
    deviceId?: string;
    rateLimit?: { windowStart: number; count: number };
    presenceInterval?: NodeJS.Timeout;
  }
}
