import assert from 'node:assert/strict';
import { test } from 'node:test';
import { account } from '../helpers/accounts.js';
import { fixture } from '../helpers/fixture.js';
import { paidOrder } from '../helpers/orders.js';

const bearer = { type: 'bearer' } as const;

test('INT-TC12 seller profile persists and rejects buyer access', async () => {
  const f = await fixture();
  try {
    const seller = await account(f, 'seller');
    const buyer = await account(f, 'buyer');
    const path = '/api/v1/merchant/profile';
    const profile = {
      shop_name: 'Gerai M10',
      address: 'Alamat fiktif Bandung 12',
      latitude: -6.9,
      longitude: 107.6,
      bank_destination: '12345678',
    };
    const saved = await f.request.patch(path).auth(seller.access_token, bearer).send(profile);
    assert.equal(saved.status, 200);
    const loaded = await f.request.get(path).auth(seller.access_token, bearer);
    assert.equal(loaded.status, 200);
    assert.equal(loaded.body.shop_name, profile.shop_name);
    assert.equal(loaded.body.address, profile.address);
    assert.equal(loaded.body.bank_masked, '••••5678');
    assert.equal((await f.request.get(path).auth(buyer.access_token, bearer)).status, 403);
    assert.equal(
      (await f.request.patch(path).auth(buyer.access_token, bearer).send(profile)).status,
      403,
    );
    const stored = await f.db.query(
      'SELECT to_jsonb(p) AS profile FROM merchant_profiles p WHERE user_id=$1',
      [seller.user.id],
    );
    assert.equal(stored.rows[0]?.profile.shop_name, profile.shop_name);
    assert.ok(!JSON.stringify(stored.rows[0]?.profile).includes(profile.bank_destination));
  } finally {
    await f.close();
  }
});

test('INT-TC11 order history scopes buyer and seller and exposes status audit', async () => {
  const f = await fixture();
  try {
    const { seller, buyer, order } = await paidOrder(f);
    const unrelated = await paidOrder(f);
    const pickup = await f.request
      .post('/api/v1/pickup/validate')
      .auth(seller.access_token, bearer)
      .send({ order_id: order.id, kind: 'otp', value: order.pickup.otp });
    assert.equal(pickup.status, 200);
    for (const actor of [buyer, seller]) {
      const history = await f.request
        .get('/api/v1/orders?status=completed')
        .auth(actor.access_token, bearer);
      assert.equal(history.status, 200);
      assert.deepEqual(
        history.body.items.map((item: { id: string }) => item.id),
        [order.id],
      );
      assert.equal(history.body.items[0].status, 'completed');
      const detail = await f.request
        .get(`/api/v1/orders/${order.id}`)
        .auth(actor.access_token, bearer);
      assert.equal(detail.status, 200);
      assert.ok(
        detail.body.history.some((entry: { action: string }) => entry.action === 'order.created'),
      );
      assert.ok(detail.body.history.length >= 3);
    }
    assert.equal(
      (await f.request.get(`/api/v1/orders/${order.id}`).auth(unrelated.buyer.access_token, bearer))
        .status,
      404,
    );
    const filtered = await f.request
      .get('/api/v1/orders?status=paid')
      .auth(buyer.access_token, bearer);
    assert.equal(filtered.status, 200);
    assert.deepEqual(filtered.body.items, []);
  } finally {
    await f.close();
  }
});
