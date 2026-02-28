import Fastify from "fastify";
import auth from "./services/auth/index.js";
import feed from "./services/feed/index.js";

const app = Fastify();

app.register(auth, { prefix: "/auth" });
app.register(feed, { prefix: "/feed" });

app.get("/health", async () => ({ status: "ok" }));

app.listen({ port: 3000, host: "0.0.0.0" });
