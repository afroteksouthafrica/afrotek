const express = require("express");
const http = require("http");

const app = express();

// Use environment variable for revision, fallback to 0.0.1
const REV = process.env.APP_REV || "product-svc-0.0.1";
const HSTS_HEADER = "max-age=31536000; includeSubDomains; preload";

// Optional: let ECS stopTimeout be visible to the app (default 30s)
const STOP_TIMEOUT_SECONDS = Number(process.env.STOP_TIMEOUT_SECONDS || 30);

// ==== Global headers + draining hint ====
let shuttingDown = false;
app.use((req, res, next) => {
  res.set("Strict-Transport-Security", HSTS_HEADER);
  res.set("X-App-Rev", REV);
  if (shuttingDown) res.set("Connection", "close"); // nudge clients to reconnect
  next();
});

/**
 * Primary lightweight /health endpoint (for ALB/ECS)
 * - Uncacheable (Cache-Control: no-store)
 * - Exposes current revision
 * - Safe for load balancer health checks
 * During drain we return 503 so ALB stops routing new traffic to this task.
 */
app.get("/health", (_req, res) => {
  if (shuttingDown) {
    return res
      .status(503)
      .set("Cache-Control", "no-store")
      .json({ ok: false, draining: true, rev: REV, component: "product-service" });
  }
  res.set("Cache-Control", "no-store");
  res.json({ ok: true, rev: REV, component: "product-service" });
});

/**
 * Product-service scoped health (for dashboards, deeper checks)
 * (Stays 200 during drain; ALB does not use this path.)
 */
app.get("/product/health", (_req, res) => {
  res.json({ ok: true, rev: REV, component: "product-service" });
});

/**
 * Optional: root path to confirm the service is alive
 */
app.get("/", (_req, res) => {
  res.json({ ok: true, rev: REV, component: "product-service" });
});

/**
 * Catch-all for undefined routes
 */
app.all("*", (_req, res) => {
  res.status(404).json({ ok: false, error: "not found" });
});

// ==== Server + graceful shutdown wiring ====
const port = process.env.PORT || 3002;
const host = "0.0.0.0";
const server = http.createServer(app);

// Track open sockets so we can destroy stragglers before SIGKILL
const sockets = new Set();
server.on("connection", (socket) => {
  sockets.add(socket);
  socket.on("close", () => sockets.delete(socket));
});

function shutdown(signal) {
  console.log(`[graceful] received ${signal}; starting drain (rev=${REV})`);
  shuttingDown = true;

  // Stop accepting new connections; keep serving in-flight
  server.close(() => {
    console.log("[graceful] http server closed cleanly");
    process.exit(0);
  });

  // Hard cap: destroy lingering sockets shortly before ECS SIGKILL
  const hardCapMs = Math.max(1000, (STOP_TIMEOUT_SECONDS - 2) * 1000); // leave ~2s buffer
  setTimeout(() => {
    console.warn("[graceful] hard cap reached, destroying open sockets");
    for (const s of sockets) {
      try { s.destroy(); } catch (_) {}
    }
  }, hardCapMs);
}

process.on("SIGTERM", () => shutdown("SIGTERM"));
process.on("SIGINT", () => shutdown("SIGINT"));

server.listen(port, host, () => {
  console.log(`product-service listening on ${host}:${port}, rev=${REV}`);
});
