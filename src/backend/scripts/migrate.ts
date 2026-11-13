import 'dotenv/config';
import { readdir, readFile } from 'node:fs/promises';
import { createHash } from 'node:crypto';
import { pathToFileURL } from 'node:url';
import { Database } from '../src/core/db.js';
import { loadConfig } from '../src/core/config.js';
export async function migrate(db: Database, options: { through?: string } = {}) {
  await db.transaction(async (tx) => {
    await tx.query('SELECT pg_advisory_xact_lock(92150206)');
    await tx.query(
      'CREATE TABLE IF NOT EXISTS schema_migrations(version text PRIMARY KEY,checksum text NOT NULL,applied_at timestamptz NOT NULL DEFAULT now())',
    );
    for (const version of (await readdir(new URL('../migrations/', import.meta.url)))
      .filter((f) => /^\d+.*\.sql$/.test(f))
      .sort()) {
      if (options.through && version > options.through) continue;
      const sql = await readFile(new URL(`../migrations/${version}`, import.meta.url), 'utf8');
      const checksum = createHash('sha256').update(sql).digest('hex');
      const old = await tx.query('SELECT checksum FROM schema_migrations WHERE version=$1', [
        version,
      ]);
      if (old.rowCount) {
        if (old.rows[0].checksum !== checksum)
          throw new Error(`Migration checksum changed: ${version}`);
        continue;
      }
      await tx.query(sql);
      await tx.query('INSERT INTO schema_migrations(version,checksum) VALUES($1,$2)', [
        version,
        checksum,
      ]);
    }
  });
}
if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  const db = new Database(loadConfig().DATABASE_URL);
  try {
    await migrate(db);
    console.log('Migrations applied');
  } finally {
    await db.close();
  }
}
