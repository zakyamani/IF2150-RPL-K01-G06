import { test } from 'node:test';
import assert from 'node:assert/strict';
import { fixture } from '../helpers/fixture.js';
import { loadConfig } from '../../src/core/config.js';
import { migrate } from '../../scripts/migrate.js';

test('production refuses example secrets', () => {
  assert.throws(() =>
    loadConfig({
      NODE_ENV: 'production',
      DATABASE_URL: 'postgres://x',
      ACCESS_SECRET: 'example',
      CALLBACK_SECRET: 'example',
      PICKUP_KEY: 'example',
    }),
  );
});
test('readiness reflects PostgreSQL and malformed JSON has request id', async () => {
  const f = await fixture();
  try {
    assert.equal((await f.request.get('/health/ready')).status, 200);
    const bad = await f.request
      .post('/api/v1/auth/login')
      .set('Content-Type', 'application/json')
      .send('{');
    assert.equal(bad.status, 400);
    assert.equal(bad.body.code, 'INVALID_JSON');
    assert.ok(bad.body.request_id);
    await f.server.sockets.stop();
    await f.db.close();
    assert.equal((await f.request.get('/health/ready')).status, 503);
  } finally {
    await f.close();
  }
});
test('database counter constraint and transaction rollback', async () => {
  const f = await fixture();
  try {
    const u = await f.db.query(
      "INSERT INTO users(email,password_hash,role) VALUES('seller@example.test','x','seller') RETURNING id",
    );
    await assert.rejects(
      f.db.query(
        `INSERT INTO offers(seller_id,category,allergens,quota_total,quota_available,quota_held,quota_sold,normal_price,discount_price,pickup_start,pickup_end,safe_eat_until,fitness_confirmed) VALUES($1,'campuran','{}',1,1,1,0,100000,40000,now(),now()+interval '1 hour',now()+interval '2 hours',true)`,
        [u.rows[0].id],
      ),
    );
    await assert.rejects(
      f.db.transaction(async (tx) => {
        await tx.query(
          "INSERT INTO users(email,password_hash,role) VALUES('rollback@example.test','x','buyer')",
        );
        throw new Error('Injected failure');
      }),
    );
    assert.equal(
      (await f.db.query("SELECT id FROM users WHERE email='rollback@example.test'")).rowCount,
      0,
    );
    assert.equal(
      (await f.db.query('SELECT count(*)::int AS n FROM schema_migrations')).rows[0].n,
      2,
    );
  } finally {
    await f.close();
  }
});
test('forward migration preserves existing data and repeated migration is non-destructive', async () => {
  const f = await fixture({ migrationThrough: '001_initial.sql' });
  try {
    assert.equal(
      (await f.db.query('SELECT count(*)::int AS n FROM schema_migrations')).rows[0].n,
      1,
    );
    await f.db.query(
      "INSERT INTO users(email,password_hash,role) VALUES('forward@example.test','preserved-hash','buyer')",
    );
    await migrate(f.db);
    await migrate(f.db);
    assert.equal(
      (await f.db.query("SELECT password_hash FROM users WHERE email='forward@example.test'"))
        .rows[0].password_hash,
      'preserved-hash',
    );
    assert.equal(
      (await f.db.query('SELECT count(*)::int AS n FROM schema_migrations')).rows[0].n,
      2,
    );
    assert.equal(
      (
        await f.db.query(
          "SELECT count(*)::int AS n FROM pg_indexes WHERE indexname='outbox_due_delivery'",
        )
      ).rows[0].n,
      1,
    );
  } finally {
    await f.close();
  }
});
