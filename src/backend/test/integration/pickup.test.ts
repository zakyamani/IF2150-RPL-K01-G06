import { test } from 'node:test';
import assert from 'node:assert/strict';
import { fixture } from '../helpers/fixture.js';
import { account } from '../helpers/accounts.js';
import { paidOrder } from '../helpers/orders.js';
import { TestClock } from '../../src/core/clock.js';
test('QR and OTP race completes once and schedules exactly one payout', async () => {
  const f = await fixture();
  try {
    const { seller, buyer, order } = await paidOrder(f);
    const other = await account(f, 'seller');
    const validate = (token: string, kind: 'qr' | 'otp', value: string) =>
      f.request
        .post('/api/v1/pickup/validate')
        .auth(token, { type: 'bearer' })
        .send({ order_id: order.id, kind, value });
    assert.equal((await validate(other.access_token, 'qr', order.pickup.qr)).status, 404);
    assert.equal((await validate(buyer.access_token, 'qr', order.pickup.qr)).status, 403);
    const results = await Promise.all([
      validate(seller.access_token, 'qr', order.pickup.qr),
      validate(seller.access_token, 'otp', order.pickup.otp),
    ]);
    assert.deepEqual(results.map((r) => r.status).sort(), [200, 409]);
    assert.equal(
      (await f.db.query('SELECT count(*)::int AS n FROM payout_entitlements')).rows[0].n,
      1,
    );
    const payout = (await f.db.query('SELECT gross,fee,net,status FROM payout_entitlements'))
      .rows[0];
    assert.deepEqual(payout, { gross: 40000, fee: 2000, net: 38000, status: 'pending' });
    assert.equal(
      (
        await f.db.query(
          "SELECT count(*)::int AS n FROM audit_logs WHERE action='pickup.completed'",
        )
      ).rows[0].n,
      1,
    );
    const metric = await f.request
      .get('/api/v1/metrics')
      .auth(buyer.access_token, { type: 'bearer' });
    assert.equal(metric.status, 200);
    assert.equal(metric.body.packages_saved, 1);
    const detail = await f.request
      .get(`/api/v1/orders/${order.id}`)
      .auth(buyer.access_token, { type: 'bearer' });
    assert.equal(detail.body.status, 'completed');
    assert.ok(!detail.body.pickup);
  } finally {
    await f.close();
  }
});
test('OTP attempts persist, block sixth attempt, bind to order and reset after window', async () => {
  const f = await fixture();
  try {
    const { seller, order } = await paidOrder(f);
    assert.match(order.pickup.otp, /^\d{6}$/);
    const validate = (value: string) =>
      f.request
        .post('/api/v1/pickup/validate')
        .auth(seller.access_token, { type: 'bearer' })
        .send({ order_id: order.code, kind: 'otp', value });
    const wrong = order.pickup.otp === '111111' ? '222222' : '111111';
    for (let n = 0; n < 5; n++) assert.equal((await validate(wrong)).status, 400);
    assert.equal((await validate(order.pickup.otp)).status, 429);
    assert.equal((await f.db.query('SELECT attempts FROM pickup_credentials')).rows[0].attempts, 5);
    const { PickupService } = await import('../../src/modules/pickup/service.js');
    (f.clock as TestClock).advance(900000);
    const result = await new PickupService(f.deps).validate(seller.ctx, {
      order_id: order.id,
      kind: 'otp',
      value: order.pickup.otp,
    });
    assert.equal(result.status, 'completed');
  } finally {
    await f.close();
  }
});
test('pickup start is inclusive and end exclusive; malformed QR is recoverable', async () => {
  const clock = new TestClock();
  const f = await fixture({ clock });
  try {
    const { seller, order } = await paidOrder(f, {
      pickup_start: new Date(clock.now().getTime() + 600000).toISOString(),
    });
    const { PickupService } = await import('../../src/modules/pickup/service.js');
    const s = new PickupService(f.deps);
    const input = { order_id: order.id, kind: 'qr' as const, value: order.pickup.qr };
    await assert.rejects(
      s.validate(seller.ctx, input),
      (e: any) => e.code === 'PICKUP_NOT_STARTED',
    );
    clock.advance(600000);
    await assert.rejects(
      s.validate(seller.ctx, { ...input, value: 'http://fake/qr' }),
      (e: any) => e.status === 400,
    );
    clock.set(new Date(order.pickup_end));
    await assert.rejects(s.validate(seller.ctx, input), (e: any) => e.status === 410);
    assert.equal((await f.db.query('SELECT status FROM orders')).rows[0].status, 'paid');
    assert.equal(
      (await f.db.query('SELECT count(*)::int AS n FROM payout_entitlements')).rows[0].n,
      0,
    );
  } finally {
    await f.close();
  }
});
