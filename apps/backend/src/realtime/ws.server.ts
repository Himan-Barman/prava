import jwt from 'jsonwebtoken';
import { URLSearchParams } from 'url';

import { config } from '@/app.config';
import { MAX_WS_PAYLOAD_BYTES } from '@/common/constants';
import { JwtPayload } from '@/common/types/jwt-payload';
import { ConversationsService } from '@/modules/conversations/conversations.service';
import { MessagesService } from '@/modules/messages/messages.service';
import { MediaService } from '@/modules/media/media.service';
import { presenceManager } from './presence.manager';
import { WsHub } from './ws.hub';
import { handleWsMessage } from './ws.router';
import { SyncService } from './sync.service';
import { WsFanout } from './ws.fanout';
import {
  recordWsConnection,
  recordWsMessage,
} from '@/observability/metrics';

const WS_RATE_LIMIT_WINDOW_MS = 10_000;
const WS_RATE_LIMIT_MAX = 120;
const PRESENCE_REFRESH_MS = 30_000;

type WsSocket = {
  readyState: number;
  OPEN: number;
  send: (payload: string) => void;
  close: (code?: number, reason?: string) => void;
  on: (event: string, listener: (...args: any[]) => void) => void;
};

type RateLimitSocket = { rateLimit?: { windowStart: number; count: number } };

type UsListenSocket = unknown;
type UwsModule = {
  App: () => any;
  us_listen_socket_close: (socket: UsListenSocket) => void;
};

const { WebSocketServer } = require('ws') as {
  WebSocketServer: new (options: {
    port: number;
    maxPayload?: number;
  }) => {
    on: (event: string, listener: (...args: any[]) => void) => void;
    close: () => void;
  };
};

const isRateLimited = (ws: RateLimitSocket) => {
  const now = Date.now();
  const state = ws.rateLimit;

  if (!state || now - state.windowStart >= WS_RATE_LIMIT_WINDOW_MS) {
    ws.rateLimit = { windowStart: now, count: 1 };
    return false;
  }

  state.count += 1;
  return state.count > WS_RATE_LIMIT_MAX;
};

const tryLoadUws = (): UwsModule | null => {
  try {
    // eslint-disable-next-line @typescript-eslint/no-var-requires
    return require('uWebSockets.js') as UwsModule;
  } catch (err) {
    console.warn('uWebSockets.js unavailable, falling back to ws');
    return null;
  }
};

class LocalTopicRegistry {
  private readonly topics = new Map<string, Set<WsSocket>>();
  private readonly socketTopics = new WeakMap<WsSocket, Set<string>>();

  subscribe(socket: WsSocket, topic: string) {
    if (!topic) return;

    let set = this.topics.get(topic);
    if (!set) {
      set = new Set();
      this.topics.set(topic, set);
    }
    set.add(socket);

    let socketSet = this.socketTopics.get(socket);
    if (!socketSet) {
      socketSet = new Set();
      this.socketTopics.set(socket, socketSet);
    }
    socketSet.add(topic);
  }

  publish(topic: string, payload: string) {
    const set = this.topics.get(topic);
    if (!set) return;

    for (const socket of set) {
      if (socket.readyState === socket.OPEN) {
        socket.send(payload);
      }
    }
  }

  remove(socket: WsSocket) {
    const socketSet = this.socketTopics.get(socket);
    if (!socketSet) return;

    for (const topic of socketSet) {
      const set = this.topics.get(topic);
      if (!set) continue;
      set.delete(socket);
      if (set.size === 0) {
        this.topics.delete(topic);
      }
    }

    this.socketTopics.delete(socket);
  }
}

export function startWsServer(port: number) {
  const syncService = new SyncService();
  const conversationsService = new ConversationsService();
  const mediaService = new MediaService(conversationsService);
  const messagesService = new MessagesService(mediaService);

  const uws = tryLoadUws();

  if (uws) {
    const app = uws.App();
    const fanout = new WsFanout((topic, payload) => {
      app.publish(topic, payload);
    });
    void fanout.init();

    const hub = new WsHub(app, fanout);
    const publishPresence = async (userId: string, isOnline: boolean) => {
      const conversationIds =
        await conversationsService.listConversationIdsForUser(
          userId,
        );
      for (const conversationId of conversationIds) {
        hub.publishToConversation(conversationId, {
          type: 'PRESENCE_UPDATE',
          payload: {
            conversationId,
            userId,
            isOnline,
          },
          ts: Date.now(),
        });
      }
    };
    let listenSocket: UsListenSocket | null = null;

    app.ws('/*', {
      idleTimeout: 60,
      maxBackpressure: 1024 * 1024,
      maxPayloadLength: MAX_WS_PAYLOAD_BYTES,

      upgrade: (res: any, req: any, context: any) => {
        const authHeader = req.getHeader('authorization');
        const queryParams = new URLSearchParams(req.getQuery());

        const headerToken =
          authHeader && authHeader.startsWith('Bearer ')
            ? authHeader.slice(7).trim()
            : undefined;

        const queryToken = queryParams.get('token')?.trim();
        const token = headerToken || queryToken;

        const deviceId =
          queryParams.get('deviceId')?.trim() ||
          req.getHeader('x-device-id');

        if (!token) {
          res.writeStatus('401 Unauthorized').end();
          return;
        }

        if (!deviceId) {
          res.writeStatus('400 Bad Request').end();
          return;
        }

        try {
          const payload = jwt.verify(
            token,
            config.JWT_PUBLIC_KEY,
            { algorithms: ['RS256'] },
          ) as JwtPayload;

          res.upgrade(
            { userId: payload.sub, deviceId },
            req.getHeader('sec-websocket-key'),
            req.getHeader('sec-websocket-protocol'),
            req.getHeader('sec-websocket-extensions'),
            context,
          );
        } catch {
          res.writeStatus('401 Unauthorized').end();
        }
      },

      open: (ws: any) => {
        void (async () => {
          const wasOnline = await presenceManager.isOnline(ws.userId);
          await presenceManager.connect(ws.userId, ws.deviceId);
          if (!wasOnline) {
            await publishPresence(ws.userId, true);
          }
        })();
        recordWsConnection(1);
        hub.subscribeUser(ws, ws.userId);

        void (async () => {
          const conversationIds =
            await conversationsService.listConversationIdsForUser(
              ws.userId,
            );
          for (const conversationId of conversationIds) {
            hub.subscribeConversation(ws, conversationId);
          }
        })();

        ws.presenceInterval = setInterval(() => {
          void presenceManager.connect(ws.userId, ws.deviceId);
        }, PRESENCE_REFRESH_MS);
      },

      message: (ws: any, message: any, isBinary: boolean) => {
        if (isBinary) return;

        if (isRateLimited(ws)) {
          ws.close(1008, 'Rate limit exceeded');
          return;
        }

        const text = Buffer.from(message).toString('utf8');
        let parsed: { type: string; payload?: unknown };

        try {
          parsed = JSON.parse(text);
        } catch {
          ws.close();
          return;
        }

        recordWsMessage(parsed.type ?? 'UNKNOWN');

        if (!ws.deviceId) {
          ws.close();
          return;
        }

        void presenceManager.connect(ws.userId, ws.deviceId);

        void handleWsMessage({
          ws,
          msg: parsed,
          userId: ws.userId,
          deviceId: ws.deviceId,
          syncService,
          conversationsService,
          messagesService,
          hub,
        }).catch((err) => {
          console.warn('WS message handler error', err);
          ws.close();
        });
      },

      close: (ws: any) => {
        if (ws.presenceInterval) {
          clearInterval(ws.presenceInterval);
          ws.presenceInterval = undefined;
        }
        recordWsConnection(-1);
        void (async () => {
          await presenceManager.disconnect(ws.userId, ws.deviceId);
          const stillOnline = await presenceManager.isOnline(ws.userId);
          if (!stillOnline) {
            await publishPresence(ws.userId, false);
          }
        })();
      },
    });

    app.listen(port, (socket: UsListenSocket | null) => {
      if (socket) {
        listenSocket = socket;
        console.log(`WS server running on :${port}`);
      } else {
        console.error('Failed to start WS server');
      }
    });

    return {
      close: () => {
        if (!listenSocket) return;
        uws.us_listen_socket_close(listenSocket);
        listenSocket = null;
      },
    };
  }

  const registry = new LocalTopicRegistry();
  const fanout = new WsFanout((topic, payload) => {
    registry.publish(topic, payload);
  });
  void fanout.init();

  const hub = new WsHub(
    {
      publish: (topic: string, payload: string) => {
        registry.publish(topic, payload);
      },
    },
    fanout,
  );
  const publishPresence = async (userId: string, isOnline: boolean) => {
    const conversationIds =
      await conversationsService.listConversationIdsForUser(userId);
    for (const conversationId of conversationIds) {
      hub.publishToConversation(conversationId, {
        type: 'PRESENCE_UPDATE',
        payload: {
          conversationId,
          userId,
          isOnline,
        },
        ts: Date.now(),
      });
    }
  };

  const wss = new WebSocketServer({
    port,
    maxPayload: MAX_WS_PAYLOAD_BYTES,
  });

  wss.on('connection', (socket: WsSocket, req: any) => {
    const authHeader = req.headers.authorization;
    const url = new URL(req.url ?? '', 'http://localhost');
    const queryToken = url.searchParams.get('token')?.trim();
    const headerToken =
      authHeader && authHeader.startsWith('Bearer ')
        ? authHeader.slice(7).trim()
        : undefined;
    const token = headerToken || queryToken;
    const deviceId =
      url.searchParams.get('deviceId')?.trim() ||
      req.headers['x-device-id']?.toString();

    if (!token || !deviceId) {
      socket.close(1008, 'Unauthorized');
      return;
    }

    let userId: string;
    try {
      const payload = jwt.verify(
        token,
        config.JWT_PUBLIC_KEY,
        { algorithms: ['RS256'] },
      ) as JwtPayload;
      userId = payload.sub;
    } catch {
      socket.close(1008, 'Unauthorized');
      return;
    }

    const socketAny = socket as WsSocket & {
      userId: string;
      deviceId?: string;
      subscribe: (topic: string) => void;
      rateLimit?: { windowStart: number; count: number };
      presenceInterval?: NodeJS.Timeout;
    };

    socketAny.userId = userId;
    socketAny.deviceId = deviceId;
    socketAny.subscribe = (topic: string) => {
      registry.subscribe(socketAny, topic);
    };

    void (async () => {
      const wasOnline = await presenceManager.isOnline(userId);
      await presenceManager.connect(userId, deviceId);
      if (!wasOnline) {
        await publishPresence(userId, true);
      }
    })();
    recordWsConnection(1);
    hub.subscribeUser(socketAny, userId);

    void (async () => {
      const conversationIds =
        await conversationsService.listConversationIdsForUser(
          userId,
        );
      for (const conversationId of conversationIds) {
        hub.subscribeConversation(socketAny, conversationId);
      }
    })();

    socketAny.presenceInterval = setInterval(() => {
      void presenceManager.connect(userId, deviceId);
    }, PRESENCE_REFRESH_MS);

    socket.on('message', (data: any) => {
      if (isRateLimited(socketAny)) {
        socketAny.close(1008, 'Rate limit exceeded');
        return;
      }

      const text =
        typeof data === 'string' ? data : data.toString();
      let parsed: { type: string; payload?: unknown };

      try {
        parsed = JSON.parse(text);
      } catch {
        socketAny.close();
        return;
      }

      recordWsMessage(parsed.type ?? 'UNKNOWN');

      void presenceManager.connect(userId, deviceId);

      void handleWsMessage({
        ws: socketAny,
        msg: parsed,
        userId,
        deviceId,
        syncService,
        conversationsService,
        messagesService,
        hub,
      }).catch((err) => {
        console.warn('WS message handler error', err);
        socketAny.close();
      });
    });

    socket.on('close', () => {
      if (socketAny.presenceInterval) {
        clearInterval(socketAny.presenceInterval);
        socketAny.presenceInterval = undefined;
      }
      registry.remove(socketAny);
      recordWsConnection(-1);
      void (async () => {
        await presenceManager.disconnect(userId, deviceId);
        const stillOnline = await presenceManager.isOnline(userId);
        if (!stillOnline) {
          await publishPresence(userId, false);
        }
      })();
    });
  });

  console.log(`WS server running on :${port} (ws fallback)`);

  return {
    close: () => {
      wss.close();
    },
  };
}
