// services/product-health-proxy/index.js
const express = require('express');
const http = require('http');

const app = express();

const REV = process.env.APP_REV || 'unknown';
const HSTS_HEADER = 'max-age=31536000; includeSubDomains; preload';
const STOP_TIMEOUT_SECONDS = Number(process.env.STOP_TIMEOUT_SECONDS || 30);

let shuttingDown = false;

// Global headers + draining hint
app.use((req, res, next) => {
  res.setHeader('Strict-Transport-Security', HSTS_HEADER);
  res.setHeader('X-App-Rev', REV);
  if (shuttingDown) res.setHeader('Connection', 'close');
  next();
});

// Health endpoints
app.get(['/', '/health', '/product/health'], (_req, res) => {
  if (shuttingDown) {
    return res
      .status(503)
      .set('Cache-Control', 'no-store')
      .json({ ok: false, draining: true, rev: REV });
  }
  res.set('Cache-Control', 'no-store');
  res.json({ ok: true, rev: REV });
});

// 404 catch-all
app.use((_req, res) => {
  res.status(404).json({ ok: false, path: 'not found' });
});

// Server + graceful shutdown wiring
const port = process.env.PORT || 3002;
const host = '0.0.0.0';
const server = http.createServer(app);

// Track open sockets for clean shutdown
const sockets = new Set();
server.on('connection', (socket) => {
  sockets.add(socket);
  socket.on('close', () => sockets.delete(socket));
});

function shutdown(signal) {
  console.log(`[graceful] received ${signal}; starting drain (rev=${REV})`);
  shuttingDown = true;

  server.close(() => {
    console.log('[graceful] http server closed cleanly');
    process.exit(0);
  });

  const hardCapMs = Math.max(1000, (STOP_TIMEOUT_SECONDS - 2) * 1000);
  setTimeout(() => {
    console.warn('[graceful] hard cap reached, destroying open sockets');
    for (const s of sockets) {
      try { s.destroy(); } catch (_) {}
    }
  }, hardCapMs);
}

process.on('SIGTERM', () => shutdown('SIGTERM'));
process.on('SIGINT', () => shutdown('SIGINT'));

server.listen(port, host, () => {
  console.log(`health-proxy listening on ${host}:${port}, rev=${REV}`);
});
