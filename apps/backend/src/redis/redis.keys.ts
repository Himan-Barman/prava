export const redisKeys = {
  rateLimit: (ip: string, route: string) =>
    `ratelimit:${route}:${ip}`,

  presence: (userId: string) =>
    `presence:${userId}`,

  presenceDevices: (userId: string) =>
    `presence:devices:${userId}`,

  wsSession: (userId: string) =>
    `ws:${userId}`,
};
