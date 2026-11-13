import 'dotenv/config';
import pino from 'pino';
import { Database } from './core/db.js';
import { loadConfig } from './core/config.js';
import { systemClock } from './core/clock.js';
import { createServer } from './app.js';
const config = loadConfig();
const db = new Database(config.DATABASE_URL);
const log = pino();
const server = createServer({ config, db, clock: systemClock });
server.listen(config.PORT, '0.0.0.0', () => log.info({ port: config.PORT }, 'api.started'));
let stopping = false;
async function stop() {
  if (stopping) return;
  stopping = true;
  await server.sockets.stop();
  const force = setTimeout(() => server.closeAllConnections(), 15000);
  force.unref();
  await new Promise<void>((resolve) => server.close(() => resolve()));
  clearTimeout(force);
  await db.close();
  log.info('api.stopped');
}
for (const signal of ['SIGTERM', 'SIGINT'] as const)
  process.once(signal, () => {
    void stop();
  });
