import client from 'prom-client';

const registry = new client.Registry();

client.collectDefaultMetrics({ register: registry });

const httpDuration = new client.Histogram({
  name: 'http_request_duration_seconds',
  help: 'HTTP request duration in seconds',
  labelNames: ['method', 'status'],
  buckets: [0.005, 0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1, 2.5, 5],
  registers: [registry],
});

const httpRequests = new client.Counter({
  name: 'http_requests_total',
  help: 'Total HTTP requests',
  labelNames: ['method', 'status'],
  registers: [registry],
});

const wsConnections = new client.Gauge({
  name: 'ws_connections',
  help: 'Active WebSocket connections',
  registers: [registry],
});

const wsMessages = new client.Counter({
  name: 'ws_messages_total',
  help: 'WebSocket messages received',
  labelNames: ['type'],
  registers: [registry],
});

const wsPublishes = new client.Counter({
  name: 'ws_fanout_publish_total',
  help: 'WebSocket fanout publishes',
  labelNames: ['scope', 'via'],
  registers: [registry],
});

const wsFanoutDeliveries = new client.Counter({
  name: 'ws_fanout_deliver_total',
  help: 'WebSocket fanout deliveries to local server',
  labelNames: ['via'],
  registers: [registry],
});

export function recordHttpRequest(
  method: string,
  status: string,
  durationSeconds: number,
) {
  httpRequests.labels(method, status).inc();
  httpDuration.labels(method, status).observe(durationSeconds);
}

export function recordWsConnection(delta: 1 | -1) {
  if (delta === 1) {
    wsConnections.inc();
  } else {
    wsConnections.dec();
  }
}

export function recordWsMessage(type: string) {
  wsMessages.labels(type).inc();
}

export function recordWsPublish(
  scope: 'user' | 'conversation',
  via: 'local' | 'redis',
) {
  wsPublishes.labels(scope, via).inc();
}

export function recordWsFanoutDeliver(via: 'redis') {
  wsFanoutDeliveries.labels(via).inc();
}

export function metricsContentType() {
  return registry.contentType;
}

export function metricsSnapshot() {
  return registry.metrics();
}
