import request from 'supertest';
import { Database } from '../../src/core/db.js';
import { loadConfig } from '../../src/core/config.js';
import { TestClock } from '../../src/core/clock.js';
import { createServer } from '../../src/app.js';
import { randomUUID } from 'node:crypto';
import { rm } from 'node:fs/promises';
import { migrate } from '../../scripts/migrate.js';
import type { Clock } from '../../src/core/clock.js';
export async function fixture(options: { clock?: Clock; migrationThrough?: string } = {}) {
  const url =
    process.env.TEST_DATABASE_URL ??
    'postgres://sisarasa_test:disposable-test-only@127.0.0.1:55433/sisarasa_test';
  if (!new URL(url).pathname.endsWith('_test'))
    throw new Error('Disposable database name must end _test');
  const db = new Database(url);
  await db.query('DROP SCHEMA public CASCADE');
  await db.query('CREATE SCHEMA public');
  await migrate(db, { through: options.migrationThrough });
  await migrate(db, { through: options.migrationThrough });
  const config = loadConfig({
    NODE_ENV: 'test',
    DATABASE_URL: url,
    MEDIA_DIR: `/tmp/sisarasa-v2-test-${randomUUID()}`,
  });
  const clock = options.clock ?? new TestClock();
  const deps = { db, config, clock };
  const server = createServer(deps);
  await server.sockets.ready;
  await new Promise<void>((resolve, reject) => {
    server.once('error', reject);
    server.listen(0, '127.0.0.1', () => {
      server.removeListener('error', reject);
      resolve();
    });
  });
  return {
    db,
    config,
    clock,
    deps,
    server,
    request: request(server),
    services: deps,
    close: async () => {
      await server.sockets.stop();
      server.closeAllConnections();
      if (server.listening)
        await new Promise<void>((resolve, reject) =>
          server.close((e) => (e ? reject(e) : resolve())),
        );
      await db.close();
      await rm(config.MEDIA_DIR, { recursive: true, force: true });
    },
  };
}
