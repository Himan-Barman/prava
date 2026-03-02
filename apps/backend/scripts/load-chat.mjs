import autocannon from "autocannon";

function requiredEnv(name) {
  const value = process.env[name];
  if (!value || !value.trim()) {
    throw new Error(`Missing required env var: ${name}`);
  }
  return value.trim();
}

function parsePositiveInt(name, fallback) {
  const raw = process.env[name];
  if (!raw || !raw.trim()) {
    return fallback;
  }
  const parsed = Number.parseInt(raw, 10);
  if (Number.isNaN(parsed) || parsed <= 0) {
    throw new Error(`Invalid positive integer for ${name}`);
  }
  return parsed;
}

async function run() {
  const baseUrl = requiredEnv("CHAT_LOAD_BASE_URL").replace(/\/+$/, "");
  const token = requiredEnv("CHAT_LOAD_ACCESS_TOKEN");
  const conversationId = requiredEnv("CHAT_LOAD_CONVERSATION_ID");

  const connections = parsePositiveInt("CHAT_LOAD_CONNECTIONS", 100);
  const durationSec = parsePositiveInt("CHAT_LOAD_DURATION_SEC", 30);
  const pipelining = parsePositiveInt("CHAT_LOAD_PIPELINING", 1);
  const workers = parsePositiveInt("CHAT_LOAD_WORKERS", 1);
  const timeoutSec = parsePositiveInt("CHAT_LOAD_TIMEOUT_SEC", 10);

  const url = `${baseUrl}/api/conversations/${conversationId}/messages`;
  let counter = 0;

  console.log("Starting chat send load test");
  console.log(`Target: ${url}`);
  console.log(`Connections: ${connections} Duration: ${durationSec}s Workers: ${workers}`);

  const instance = autocannon({
    url,
    method: "POST",
    connections,
    duration: durationSec,
    workers,
    pipelining,
    timeout: timeoutSec,
    headers: {
      authorization: `Bearer ${token}`,
      "content-type": "application/json",
    },
    setupClient: (client) => {
      client.on("body", () => {
        counter += 1;
      });
    },
    requests: [
      {
        setupRequest: (request) => {
          const payload = {
            body: `load message ${Date.now()}_${Math.random().toString(36).slice(2, 10)}`,
            contentType: "text",
            deviceId: "load-tester",
            tempId: `tmp_${Date.now()}_${Math.random().toString(36).slice(2, 8)}`,
            clientTimestamp: new Date().toISOString(),
          };
          request.body = JSON.stringify(payload);
          return request;
        },
      },
    ],
  });

  autocannon.track(instance, { renderProgressBar: true });

  const result = await new Promise((resolve, reject) => {
    instance.on("done", resolve);
    instance.on("error", reject);
  });

  console.log("\nLoad test completed.");
  console.log(JSON.stringify(result, null, 2));
  console.log(`Approx responses observed: ${counter}`);
}

run().catch((error) => {
  console.error(error instanceof Error ? error.message : error);
  process.exit(1);
});
