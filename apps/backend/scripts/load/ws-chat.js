import ws from 'k6/ws';
import { sleep } from 'k6';

export const options = {
  vus: Number(__ENV.VUS ?? 25),
  duration: __ENV.DURATION ?? '1m',
};

export default function () {
  const token = __ENV.TOKEN;
  const conversationId = __ENV.CONVERSATION_ID;
  const deviceId = __ENV.DEVICE_ID ?? `loadtest-${__VU}-${__ITER}`;
  const wsUrl = __ENV.WS_URL ?? 'ws://localhost:3001';

  if (!token || !conversationId) {
    console.error('TOKEN and CONVERSATION_ID are required');
    return;
  }

  const url = `${wsUrl}?token=${token}&deviceId=${deviceId}`;

  ws.connect(url, {}, (socket) => {
    socket.on('open', () => {
      socket.send(
        JSON.stringify({
          type: 'CONVERSATION_SUBSCRIBE',
          payload: { conversationId },
        }),
      );

      socket.send(
        JSON.stringify({
          type: 'PING',
        }),
      );
    });

    socket.on('message', () => {
      // ignore server pushes for load test
    });

    socket.setInterval(() => {
      socket.send(
        JSON.stringify({
          type: 'MESSAGE_SEND',
          payload: {
            conversationId,
            body: `loadtest ${Date.now()}`,
          },
        }),
      );
    }, 2000);

    socket.setTimeout(() => {
      socket.close();
    }, 10000);
  });

  sleep(1);
}
