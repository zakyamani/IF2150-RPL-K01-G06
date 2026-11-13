import assert from 'node:assert/strict';
import { setTimeout as sleep } from 'node:timers/promises';
import type { Database } from '../../src/core/db.js';

// Pause a real PostgreSQL transaction after a chosen statement has acquired
// its locks. Other actors still use the real database and production services.
export function pauseNextQuery(db: Database, needle: string) {
  const original = db.transaction.bind(db);
  let reached = false;
  let release!: () => void;
  const gate = new Promise<void>((resolve) => {
    release = resolve;
  });
  db.transaction = (fn, options) =>
    original(
      (tx) =>
        fn(
          new Proxy(tx, {
            get(target, property) {
              if (property !== 'query') return Reflect.get(target, property);
              return async (...args: Parameters<typeof tx.query>) => {
                const result = await tx.query(...args);
                if (!reached && typeof args[0] === 'string' && args[0].includes(needle)) {
                  reached = true;
                  await gate;
                }
                return result;
              };
            },
          }),
        ),
      options,
    );
  return {
    release,
    restore() {
      release();
      db.transaction = original;
    },
    async ready() {
      for (let n = 0; n < 200 && !reached; n++) await sleep(10);
      assert.ok(reached, `Transaction did not reach ${needle}`);
    },
    async contenderBlocked() {
      for (let n = 0; n < 200; n++) {
        const r = await db.query(
          'SELECT pid FROM pg_stat_activity WHERE datname=current_database() AND cardinality(pg_blocking_pids(pid))>0',
        );
        if (r.rowCount) return;
        await sleep(10);
      }
      assert.fail('Contender never waited for the real PostgreSQL transaction');
    },
  };
}
