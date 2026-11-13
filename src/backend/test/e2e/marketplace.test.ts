import test from 'node:test';
import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';
import { fixture } from '../helpers/fixture.js';
import { TestClock } from '../../src/core/clock.js';
import { offerInput } from '../helpers/offers.js';
import { runDueJobs } from '../../src/modules/jobs/service.js';

test('E2E buyer/seller register, anonymous offer, retry checkout, signed payment, QR, review and settled ledger', async () => {
  const clock = new TestClock(),
    f = await fixture({ clock });
  try {
    async function register(role: 'buyer' | 'seller') {
      const r = await f.request.post('/api/v1/auth/register').send({
        email: randomUUID() + '@example.test',
        password: 'Testing-password-2026',
        name: role === 'seller' ? 'Gerai E2E' : 'Pembeli E2E',
        role,
      });
      assert.equal(r.status, 201);
      return r.body;
    }
    const buyer = await register('buyer'),
      seller = await register('seller');
    assert.equal(
      (
        await f.request
          .patch('/api/v1/merchant/profile')
          .auth(seller.access_token, { type: 'bearer' })
          .send({
            shop_name: 'Gerai E2E',
            address: 'Bandung E2E 12',
            latitude: -6.9,
            longitude: 107.6,
          })
      ).status,
      200,
    );
    const offer = await f.request
      .post('/api/v1/offers')
      .auth(seller.access_token, { type: 'bearer' })
      .send(offerInput(clock.now()));
    assert.equal(offer.status, 201);
    const catalog = await f.request
      .get('/api/v1/catalog')
      .auth(buyer.access_token, { type: 'bearer' });
    assert.equal(catalog.status, 200);
    assert.equal(catalog.body.items[0].merchant, undefined);
    assert.equal(catalog.body.items[0].seller_id, undefined);
    const key = randomUUID(),
      checkout = () =>
        f.request
          .post('/api/v1/orders/checkout')
          .auth(buyer.access_token, { type: 'bearer' })
          .set('Idempotency-Key', key)
          .send({ offer_id: offer.body.id });
    const first = await checkout(),
      retry = await checkout();
    assert.equal(first.status, 201);
    assert.deepEqual(retry.body, first.body);
    const before = await f.request
      .get('/api/v1/orders/' + first.body.order_id)
      .auth(buyer.access_token, { type: 'bearer' });
    assert.equal(before.body.merchant, undefined);
    assert.equal(before.body.pickup, undefined);
    assert.equal(
      (
        await f.request
          .post('/api/v1/payments/' + first.body.intent_id + '/demo-event')
          .auth(buyer.access_token, { type: 'bearer' })
          .send({ outcome: 'succeeded' })
      ).status,
      200,
    );
    const paid = await f.request
      .get('/api/v1/orders/' + first.body.order_id)
      .auth(buyer.access_token, { type: 'bearer' });
    assert.equal(paid.body.merchant.name, 'Gerai E2E');
    assert.ok(paid.body.pickup.qr.startsWith('sisarasa:v1:'));
    assert.equal(
      (
        await f.request
          .post('/api/v1/pickup/validate')
          .auth(seller.access_token, { type: 'bearer' })
          .send({ kind: 'qr', order_id: paid.body.id, value: paid.body.pickup.qr })
      ).status,
      200,
    );
    assert.equal(
      (
        await f.request
          .post('/api/v1/reviews')
          .auth(buyer.access_token, { type: 'bearer' })
          .send({ order_id: paid.body.id, rating: 5, comment: 'Paket sesuai, pengambilan mudah.' })
      ).status,
      201,
    );
    clock.advance(3600000);
    await runDueJobs(f.deps);
    await runDueJobs(f.deps);
    const payout = (await f.db.query('SELECT gross,fee,net,status FROM payout_entitlements'))
      .rows[0];
    assert.deepEqual(payout, { gross: 40000, fee: 2000, net: 38000, status: 'settled' });
    const entries = (await f.db.query('SELECT kind,amount FROM ledger_entries ORDER BY id')).rows;
    assert.equal(entries.filter((e) => e.kind === 'payout_settled').length, 1);
    assert.ok(entries.some((e) => e.kind === 'fee' && e.amount === 2000));
    const renewed = await f.request
      .post('/api/v1/auth/refresh')
      .send({ refresh_token: seller.refresh_token });
    assert.equal(renewed.status, 200);
    const history = await f.request
      .get('/api/v1/orders')
      .auth(renewed.body.access_token, { type: 'bearer' });
    assert.equal(history.body.items[0].status, 'completed');
    assert.equal((await f.db.query('SELECT count(*)::int AS n FROM reviews')).rows[0].n, 1);
  } finally {
    await f.close();
  }
});
