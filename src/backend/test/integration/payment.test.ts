import { test } from 'node:test';
import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';
import { fixture } from '../helpers/fixture.js';
import { account } from '../helpers/accounts.js';
import { sellerOffer } from '../helpers/offers.js';
import { hmac } from '../../src/core/crypto.js';
import { TestClock } from '../../src/core/clock.js';

test('20 checkouts for one package reserve exactly one; retry recovers same order', async () => {
  const f = await fixture();
  try {
    const { offer } = await sellerOffer(f);
    const buyer = await account(f, 'buyer');
    const checkout = (key: string, offer_id = offer.id) =>
      f.request
        .post('/api/v1/orders/checkout')
        .auth(buyer.access_token, { type: 'bearer' })
        .set('Idempotency-Key', key)
        .send({ offer_id });
    const responses = await Promise.all(
      Array.from({ length: 20 }, (_, n) => checkout(`contend-${n}`)),
    );
    assert.equal(responses.filter((r) => r.status === 201).length, 1);
    assert.equal(responses.filter((r) => r.status === 409).length, 19);
    const first = responses.find((r) => r.status === 201)!;
    const index = responses.indexOf(first);
    const retry = await checkout(`contend-${index}`);
    assert.equal(retry.status, 201);
    assert.equal(retry.body.order_id, first.body.order_id);
    assert.equal(retry.body.intent_id, first.body.intent_id);
    assert.equal((await checkout(`contend-${index}`, randomUUID())).status, 409);
    assert.equal((await f.db.query('SELECT count(*)::int AS n FROM orders')).rows[0].n, 1);
    assert.deepEqual(
      (await f.db.query('SELECT quota_total,quota_available,quota_held,quota_sold FROM offers'))
        .rows[0],
      { quota_total: 1, quota_available: 0, quota_held: 1, quota_sold: 0 },
    );
    const pending = await f.request
      .get(`/api/v1/orders/${first.body.order_id}`)
      .auth(buyer.access_token, { type: 'bearer' });
    assert.equal(pending.status, 200);
    assert.ok(!pending.body.merchant);
    assert.ok(!pending.body.pickup);
    assert.equal(pending.body.fee, 2000);
  } finally {
    await f.close();
  }
});
test('signed callbacks reject identity/amount forgery and duplicate success has one effect', async () => {
  const f = await fixture();
  try {
    const { seller, offer } = await sellerOffer(f);
    const buyer = await account(f, 'buyer');
    const other = await account(f, 'buyer');
    const c = await f.request
      .post('/api/v1/orders/checkout')
      .auth(buyer.access_token, { type: 'bearer' })
      .set('Idempotency-Key', 'pay-1')
      .send({ offer_id: offer.id });
    assert.equal(c.status, 201);
    const event = {
      id: randomUUID(),
      intent_id: c.body.intent_id,
      order_id: c.body.order_id,
      amount: 40000,
      currency: 'IDR',
      outcome: 'succeeded',
    };
    const send = (e = event, signature?: string) => {
      const raw = JSON.stringify(e);
      return f.request
        .post('/api/v1/gateway/webhook')
        .set('Content-Type', 'application/json')
        .set('X-Gateway-Signature', signature ?? hmac(raw, f.config.CALLBACK_SECRET))
        .send(raw);
    };
    assert.equal((await send(event, 'f'.repeat(64))).status, 401);
    assert.equal((await send({ ...event, amount: 1 })).status, 400);
    assert.equal((await send({ ...event, order_id: randomUUID() })).status, 400);
    assert.equal(
      (
        await f.request
          .post(`/api/v1/payments/${event.intent_id}/demo-event`)
          .auth(seller.access_token, { type: 'bearer' })
          .send({ outcome: 'succeeded' })
      ).status,
      403,
    );
    const paid = await Promise.all([send(), send()]);
    assert.deepEqual(
      paid.map((p) => p.status),
      [200, 200],
    );
    assert.equal(paid[0]!.body.status, 'succeeded');
    assert.equal(
      (await f.db.query("SELECT count(*)::int AS n FROM ledger_entries WHERE kind='funds_held'"))
        .rows[0].n,
      1,
    );
    assert.equal((await f.db.query('SELECT count(*)::int AS n FROM payment_events')).rows[0].n, 1);
    assert.deepEqual(
      (await f.db.query('SELECT quota_available,quota_held,quota_sold FROM offers')).rows[0],
      { quota_available: 0, quota_held: 0, quota_sold: 1 },
    );
    const view = await f.request
      .get(`/api/v1/orders/${event.order_id}`)
      .auth(buyer.access_token, { type: 'bearer' });
    assert.equal(view.body.merchant.name, 'Gerai Rahasia');
    assert.match(view.body.pickup.otp, /^\d{6}$/);
    assert.match(view.body.pickup.qr, /^sisarasa:v1:/);
    const sv = await f.request
      .get(`/api/v1/orders/${event.order_id}`)
      .auth(seller.access_token, { type: 'bearer' });
    assert.ok(!sv.body.pickup);
    assert.equal(
      (
        await f.request
          .get(`/api/v1/orders/${event.order_id}`)
          .auth(other.access_token, { type: 'bearer' })
      ).status,
      404,
    );
  } finally {
    await f.close();
  }
});
test('payment at exact expiry releases stock once and cannot resurrect cancelled order', async () => {
  const clock = new TestClock();
  const f = await fixture({ clock });
  try {
    const { offer } = await sellerOffer(f);
    const buyer = await account(f, 'buyer');
    const c = await f.request
      .post('/api/v1/orders/checkout')
      .auth(buyer.access_token, { type: 'bearer' })
      .set('Idempotency-Key', 'expire-1')
      .send({ offer_id: offer.id });
    assert.equal(c.status, 201);
    clock.advance(900000);
    const pay = () =>
      f.request
        .post(`/api/v1/payments/${c.body.intent_id}/demo-event`)
        .auth((buyer as any).access_token, { type: 'bearer' })
        .send({ outcome: 'succeeded' });
    // Obtain a new session at the expiry boundary; an expired access token must not mask invoice expiry.
    const { AuthService } = await import('../../src/modules/auth/service.js');
    const refresh = await new AuthService(f.deps).refresh(buyer.refresh_token);
    (buyer as any).access_token = refresh.access_token;
    assert.equal((await pay()).status, 410);
    assert.equal((await pay()).status, 410);
    assert.deepEqual(
      (await f.db.query('SELECT quota_available,quota_held,quota_sold FROM offers')).rows[0],
      { quota_available: 1, quota_held: 0, quota_sold: 0 },
    );
    assert.equal((await f.db.query('SELECT status FROM orders')).rows[0].status, 'cancelled');
  } finally {
    await f.close();
  }
});
test('audit storage failure rolls back payment and can safely retry', async () => {
  const f = await fixture();
  try {
    const { offer } = await sellerOffer(f);
    const buyer = await account(f, 'buyer');
    const c = await f.request
      .post('/api/v1/orders/checkout')
      .auth(buyer.access_token, { type: 'bearer' })
      .set('Idempotency-Key', 'atomic-audit')
      .send({ offer_id: offer.id });
    assert.equal(c.status, 201);
    await f.db.query(
      `CREATE FUNCTION fail_audit() RETURNS trigger LANGUAGE plpgsql AS $$ BEGIN IF NEW.action='payment.succeeded' THEN RAISE EXCEPTION 'Injected audit failure'; END IF; RETURN NEW; END $$; CREATE TRIGGER fail_payment_audit BEFORE INSERT ON audit_logs FOR EACH ROW EXECUTE FUNCTION fail_audit()`,
    );
    const pay = () =>
      f.request
        .post(`/api/v1/payments/${c.body.intent_id}/demo-event`)
        .auth(buyer.access_token, { type: 'bearer' })
        .send({ outcome: 'succeeded' });
    assert.equal((await pay()).status, 503);
    assert.equal((await f.db.query('SELECT status FROM orders')).rows[0].status, 'pending_payment');
    assert.equal((await f.db.query('SELECT count(*)::int AS n FROM payment_events')).rows[0].n, 0);
    await f.db.query('DROP TRIGGER fail_payment_audit ON audit_logs; DROP FUNCTION fail_audit()');
    assert.equal((await pay()).status, 200);
  } finally {
    await f.close();
  }
});
