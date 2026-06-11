# Load Test Plan

Use `autocannon` or an equivalent tool for REST and a WebSocket harness for realtime.

Scenarios:

- Login burst.
- Profile reads.
- Following feed reads.
- For You feed reads.
- Post creation.
- Likes.
- WebSocket connection ramp-up.
- Chat send burst.
- Group chat fanout.
- Reconnection storm.
- Notification fanout.

Measure p50, p95, p99 latency, error rate, DB connections, Redis latency, queue backlog, event-loop lag and active sockets.
