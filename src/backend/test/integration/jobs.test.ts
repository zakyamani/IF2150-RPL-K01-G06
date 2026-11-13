import { test } from 'node:test';
import assert from 'node:assert/strict';
import { fixture } from '../helpers/fixture.js';
import { paidOrder } from '../helpers/orders.js';
import { sellerOffer } from '../helpers/offers.js';
import { account } from '../helpers/accounts.js';
import { TestClock } from '../../src/core/clock.js';
import { spawn } from 'node:child_process';
import { setTimeout as sleep } from 'node:timers/promises';
test('persistent worker catches up payment expiry and paid no-show without double stock release', async () => {
  const clock = new TestClock();
  const f = await fixture({ clock });
  try {
    const { runDueJobs } = await import('../../src/modules/jobs/service.js');
    const { offer } = await sellerOffer(f);
    const buyer = await account(f, 'buyer');
    const pending = await f.request
      .post('/api/v1/orders/checkout')
      .auth(buyer.access_token, { type: 'bearer' })
      .set('Idempotency-Key', 'worker-expiry')
      .send({ offer_id: offer.id });
    assert.equal(pending.status, 201);
    const paid = await paidOrder(f);
    clock.advance(900000);
    await runDueJobs(f.deps);
    await runDueJobs(f.deps);
    assert.equal(
      (await f.db.query('SELECT status FROM orders WHERE id=$1', [pending.body.order_id])).rows[0]
        .status,
      'cancelled',
    );
    assert.deepEqual(
      (
        await f.db.query('SELECT quota_available,quota_held,quota_sold FROM offers WHERE id=$1', [
          offer.id,
        ])
      ).rows[0],
      { quota_available: 1, quota_held: 0, quota_sold: 0 },
    );
    clock.set(new Date(paid.order.pickup_end));
    await runDueJobs(f.deps);
    await runDueJobs(f.deps);
    assert.equal(
      (await f.db.query('SELECT status FROM orders WHERE id=$1', [paid.order.id])).rows[0].status,
      'no_show',
    );
    assert.equal(
      (await f.db.query('SELECT count(*)::int AS n FROM payout_entitlements')).rows[0].n,
      1,
    );
    assert.equal(
      (await f.db.query("SELECT count(*)::int AS n FROM orders WHERE status='completed'")).rows[0]
        .n,
      0,
    );
  } finally {
    await f.close();
  }
});
test('only closed-shop complaints auto-refund at exact 24h; other disputes remain held', async () => {
  const clock = new TestClock();
  const f = await fixture({ clock });
  try {
    const { runDueJobs } = await import('../../src/modules/jobs/service.js');
    const closed = await paidOrder(f);
    const regular = await paidOrder(f);
    for (const [p, reason] of [
      [closed, 'store_closed'],
      [regular, 'unfit'],
    ] as const) {
      const c = await f.request
        .post('/api/v1/complaints')
        .auth(p.buyer.access_token, { type: 'bearer' })
        .set('Idempotency-Key', reason)
        .send({
          order_id: p.order.id,
          reason,
          description: 'Gerai/paket tidak sesuai saat pickup.',
          media_ids: [],
        });
      assert.equal(c.status, 201);
    }
    clock.advance(86400000 - 1);
    await runDueJobs(f.deps);
    assert.equal((await f.db.query('SELECT count(*)::int AS n FROM refunds')).rows[0].n, 0);
    clock.advance(1);
    await runDueJobs(f.deps);
    await runDueJobs(f.deps);
    assert.equal((await f.db.query('SELECT count(*)::int AS n FROM refunds')).rows[0].n, 1);
    assert.equal(
      (await f.db.query('SELECT status FROM orders WHERE id=$1', [closed.order.id])).rows[0].status,
      'refunded',
    );
    assert.equal(
      (await f.db.query('SELECT status FROM orders WHERE id=$1', [regular.order.id])).rows[0]
        .status,
      'dispute',
    );
    assert.equal(
      (
        await f.db.query('SELECT status FROM payout_entitlements WHERE order_id=$1', [
          regular.order.id,
        ])
      ).rows[0].status,
      'held',
    );
  } finally {
    await f.close();
  }
});
test('lost job acknowledgement rolls back payout; retry and expired lease settle once', async () => {
  const clock = new TestClock();
  const f = await fixture({ clock });
  try {
    const { runDueJobs } = await import('../../src/modules/jobs/service.js');
    const { seller, order } = await paidOrder(f);
    const scan = await f.request
      .post('/api/v1/pickup/validate')
      .auth(seller.access_token, { type: 'bearer' })
      .send({ order_id: order.id, kind: 'qr', value: order.pickup.qr });
    assert.equal(scan.status, 200);
    clock.advance(3600000);
    await f.db.query(
      `CREATE FUNCTION fail_job_ack() RETURNS trigger LANGUAGE plpgsql AS $$ BEGIN IF NEW.status='done' AND NEW.kind='settle_payout' THEN RAISE EXCEPTION 'Injected ack loss'; END IF; RETURN NEW; END $$; CREATE TRIGGER fail_ack BEFORE UPDATE ON jobs FOR EACH ROW EXECUTE FUNCTION fail_job_ack()`,
    );
    const first = await runDueJobs(f.deps);
    assert.equal(first.retried, 1);
    assert.equal(
      (await f.db.query('SELECT status FROM payout_entitlements')).rows[0].status,
      'pending',
    );
    assert.equal(
      (
        await f.db.query(
          "SELECT count(*)::int AS n FROM ledger_entries WHERE kind='payout_settled'",
        )
      ).rows[0].n,
      0,
    );
    await f.db.query('DROP TRIGGER fail_ack ON jobs; DROP FUNCTION fail_job_ack()');
    await f.db.query(
      "UPDATE jobs SET status='running',lease_until=$1,lease_token=gen_random_uuid() WHERE kind='settle_payout'",
      [new Date(clock.now().getTime() - 1)],
    );
    await runDueJobs(f.deps);
    await runDueJobs(f.deps);
    assert.equal(
      (await f.db.query('SELECT status FROM payout_entitlements')).rows[0].status,
      'settled',
    );
    assert.equal(
      (
        await f.db.query(
          "SELECT count(*)::int AS n FROM ledger_entries WHERE kind='payout_settled'",
        )
      ).rows[0].n,
      1,
    );
    assert.equal(
      (await f.db.query("SELECT amount FROM ledger_entries WHERE kind='payout_settled'")).rows[0]
        .amount,
      38000,
    );
  } finally {
    await f.close();
  }
});

test('real worker SIGTERM drains an in-flight transaction and restart does not duplicate settlement', async () => {
  const f = await fixture();
  let child: ReturnType<typeof spawn> | undefined;
  try {
    const { seller, order } = await paidOrder(f);
    assert.equal(
      (
        await f.request
          .post('/api/v1/pickup/validate')
          .auth(seller.access_token, { type: 'bearer' })
          .send({ order_id: order.id, kind: 'otp', value: order.pickup.otp })
      ).status,
      200,
    );
    await f.db.query(
      "UPDATE payout_entitlements SET due_at=now()-interval '1 minute'; UPDATE jobs SET due_at=now()-interval '1 minute' WHERE kind='settle_payout'",
    );
    await f.db.query(
      `CREATE FUNCTION slow_settlement() RETURNS trigger LANGUAGE plpgsql AS $$ BEGIN IF NEW.kind='payout_settled' THEN PERFORM pg_sleep(1); END IF; RETURN NEW; END $$; CREATE TRIGGER slow_payout BEFORE INSERT ON ledger_entries FOR EACH ROW EXECUTE FUNCTION slow_settlement()`,
    );
    const start = () =>
      spawn(process.execPath, ['--import', 'tsx', 'src/worker.ts'], {
        env: {
          ...process.env,
          NODE_ENV: 'test',
          DATABASE_URL: f.config.DATABASE_URL,
          MEDIA_DIR: f.config.MEDIA_DIR,
        },
        stdio: ['ignore', 'pipe', 'pipe'],
      });
    child = start();
    child.stdout!.resume();
    child.stderr!.resume();
    const exited = new Promise<number | null>((resolve) => child!.once('exit', resolve));
    let running = false;
    for (let n = 0; n < 150; n++) {
      if (
        (await f.db.query("SELECT id FROM jobs WHERE kind='settle_payout' AND status='running'"))
          .rowCount
      ) {
        running = true;
        break;
      }
      await sleep(20);
    }
    assert.equal(running, true);
    child.kill('SIGTERM');
    assert.equal(await exited, 0);
    assert.equal(
      (await f.db.query("SELECT status FROM jobs WHERE kind='settle_payout'")).rows[0].status,
      'done',
    );
    assert.equal(
      (await f.db.query('SELECT status FROM payout_entitlements')).rows[0].status,
      'settled',
    );
    child = start();
    const stopped = new Promise<number | null>((resolve) => child!.once('exit', resolve));
    child.stderr!.resume();
    await new Promise<void>((resolve, reject) => {
      const timeout = setTimeout(() => reject(new Error('Worker restart timed out')), 5000);
      child!.stdout!.on('data', (chunk) => {
        if (String(chunk).includes('worker.started')) {
          clearTimeout(timeout);
          resolve();
        }
      });
    });
    child.kill('SIGTERM');
    assert.equal(await stopped, 0);
    assert.equal(
      (
        await f.db.query(
          "SELECT count(*)::int AS n FROM ledger_entries WHERE kind='payout_settled'",
        )
      ).rows[0].n,
      1,
    );
  } finally {
    child?.kill('SIGTERM');
    await f.close();
  }
});
