import { test } from 'node:test';
import assert from 'node:assert/strict';
import { fixture } from '../helpers/fixture.js';
import { account } from '../helpers/accounts.js';
import { offerInput } from '../helpers/offers.js';
import { randomUUID } from 'node:crypto';
test('offer boundary validation and anonymous catalog whitelist/filter', async () => {
  const f = await fixture();
  try {
    const seller = await account(f, 'seller');
    const buyer = await account(f, 'buyer');
    await f.request
      .patch('/api/v1/merchant/profile')
      .auth(seller.access_token, { type: 'bearer' })
      .send({
        shop_name: 'Secret Shop',
        address: 'Secret Street',
        latitude: -6.9,
        longitude: 107.6,
      });
    const create = (extra: Record<string, unknown>) =>
      f.request
        .post('/api/v1/offers')
        .auth(seller.access_token, { type: 'bearer' })
        .send(offerInput(f.clock.now(), extra));
    for (const extra of [
      { discount_price: 51000 },
      { discount_price: 29000 },
      { quota: 0 },
      { quota: 501 },
      { fitness_confirmed: false },
      { pickup_start: new Date(f.clock.now().getTime() + 7200001).toISOString() },
      { safe_eat_until: f.clock.now().toISOString() },
    ])
      assert.equal((await create(extra)).status, 400);
    const good = await create({ allergens: ['susu'] });
    assert.equal(good.status, 201);
    assert.equal(
      (
        await create({
          quota: 500,
          discount_price: 30000,
          pickup_start: new Date(f.clock.now().getTime() + 7200000).toISOString(),
          pickup_end: new Date(f.clock.now().getTime() + 10800000).toISOString(),
          safe_eat_until: new Date(f.clock.now().getTime() + 14400000).toISOString(),
        })
      ).status,
      201,
    );
    const response = await f.request
      .get(`/api/v1/catalog/${good.body.id}?lat=-6.9&lng=107.6`)
      .auth(buyer.access_token, { type: 'bearer' });
    assert.equal(response.status, 200);
    assert.equal(response.body.distance_km, 0);
    assert.deepEqual(
      Object.keys(response.body).sort(),
      [
        'id',
        'category',
        'allergens',
        'quota_available',
        'normal_price',
        'discount_price',
        'discount_percent',
        'pickup_start',
        'pickup_end',
        'safe_eat_until',
        'distance_km',
        'disclaimer',
        'created_at',
      ].sort(),
    );
    assert.ok(!JSON.stringify(response.body).includes(seller.user.id));
    assert.ok(!JSON.stringify(response.body).includes('Secret'));
    assert.equal(
      (
        await f.request
          .get('/api/v1/catalog?lat=NaN&lng=107')
          .auth(buyer.access_token, { type: 'bearer' })
      ).status,
      400,
    );
    assert.equal(
      (await f.request.get('/api/v1/catalog').auth(seller.access_token, { type: 'bearer' })).status,
      403,
    );
    const preference = await f.request
      .patch('/api/v1/auth/allergens')
      .auth(buyer.access_token, { type: 'bearer' })
      .send({ allergen_filters: ['susu'] });
    assert.equal(preference.status, 200);
    assert.deepEqual(preference.body.allergen_filters, ['susu']);
    const stored = await f.db.query('SELECT allergen_filters FROM users WHERE id=$1', [
      buyer.user.id,
    ]);
    assert.deepEqual(stored.rows[0]?.allergen_filters, ['susu']);
    const filtered = await f.request
      .get('/api/v1/catalog')
      .auth(buyer.access_token, { type: 'bearer' });
    assert.equal(filtered.status, 200);
    assert.ok(!filtered.body.items.some((o: any) => o.id === good.body.id));
    assert.ok(filtered.body.disclaimer);
    assert.equal(
      (
        await f.request
          .get(`/api/v1/catalog/${good.body.id}`)
          .auth(buyer.access_token, { type: 'bearer' })
      ).status,
      404,
    );
  } finally {
    await f.close();
  }
});
test('held checkout blocks concurrent offer edits and close', async () => {
  const f = await fixture();
  try {
    const seller = await account(f, 'seller');
    const buyer = await account(f, 'buyer');
    await f.request
      .patch('/api/v1/merchant/profile')
      .auth(seller.access_token, { type: 'bearer' })
      .send({ shop_name: 'Gerai Uji', address: 'Jalan Uji 1', latitude: -6.9, longitude: 107.6 });
    const created = await f.request
      .post('/api/v1/offers')
      .auth(seller.access_token, { type: 'bearer' })
      .send(offerInput(f.clock.now()));
    assert.equal(created.status, 201);
    await f.db.query('UPDATE offers SET quota_available=0,quota_held=1 WHERE id=$1', [
      created.body.id,
    ]);
    const results = await Promise.all([
      f.request
        .patch(`/api/v1/offers/${created.body.id}`)
        .auth(seller.access_token, { type: 'bearer' })
        .send(offerInput(f.clock.now(), { quota: 2 })),
      f.request
        .post(`/api/v1/offers/${created.body.id}/close`)
        .auth(seller.access_token, { type: 'bearer' }),
    ]);
    assert.deepEqual(
      results.map((r) => r.status),
      [409, 409],
    );
    const row = (
      await f.db.query('SELECT quota_total,quota_held,status FROM offers WHERE id=$1', [
        created.body.id,
      ])
    ).rows[0];
    assert.deepEqual(row, { quota_total: 1, quota_held: 1, status: 'active' });
    await f.db.query('UPDATE offers SET quota_available=1,quota_held=0 WHERE id=$1', [
      created.body.id,
    ]);
    await f.db.query(
      `INSERT INTO orders(code,invoice,offer_id,buyer_id,seller_id,status,price,fee,fee_bps,snapshot,payment_deadline,pickup_start,pickup_end,safe_eat_until,paid_at) VALUES($1,$2,$3,$4,$5,'refunded',40000,2000,500,'{}',$6,$6,$7,$7,$6)`,
      [
        'SR-PAID123456',
        randomUUID(),
        created.body.id,
        buyer.user.id,
        seller.user.id,
        f.clock.now(),
        new Date(f.clock.now().getTime() + 3600000),
      ],
    );
    assert.equal(
      (
        await f.request
          .post(`/api/v1/offers/${created.body.id}/close`)
          .auth(seller.access_token, { type: 'bearer' })
      ).status,
      409,
    );
  } finally {
    await f.close();
  }
});

test('INT-TC01/02 offer edit, filter with zero matches, and explicit close reach the catalog', async () => {
  const f = await fixture();
  try {
    const seller = await account(f, 'seller');
    const buyer = await account(f, 'buyer');
    const sellerToken = seller.access_token;
    const buyerToken = buyer.access_token;
    const bearer = { type: 'bearer' } as const;
    assert.equal(
      (
        await f.request.patch('/api/v1/merchant/profile').auth(sellerToken, bearer).send({
          shop_name: 'Gerai Katalog M10',
          address: 'Alamat fiktif Bandung',
          latitude: -6.9,
          longitude: 107.6,
        })
      ).status,
      200,
    );
    const input = offerInput(f.clock.now(), { allergens: ['susu'] });
    const created = await f.request.post('/api/v1/offers').auth(sellerToken, bearer).send(input);
    assert.equal(created.status, 201);
    const id = created.body.id;
    const edited = await f.request
      .patch(`/api/v1/offers/${id}`)
      .auth(sellerToken, bearer)
      .send({ ...input, quota: 2 });
    assert.equal(edited.status, 200);
    const catalog = () => f.request.get('/api/v1/catalog').auth(buyerToken, bearer);
    const visible = await catalog();
    assert.equal(visible.status, 200);
    assert.equal(visible.body.items.length, 1);
    assert.equal(visible.body.items[0].id, id);
    assert.equal(visible.body.items[0].quota_available, 2);
    assert.equal(visible.body.items[0].distance_km, null);
    const setFilter = (filters: string[]) =>
      f.request
        .patch('/api/v1/auth/allergens')
        .auth(buyerToken, bearer)
        .send({ allergen_filters: filters });
    assert.equal((await setFilter(['susu'])).status, 200);
    const empty = await catalog();
    assert.equal(empty.status, 200);
    assert.deepEqual(empty.body.items, []);
    assert.ok(empty.body.disclaimer);
    assert.equal((await setFilter([])).status, 200);
    assert.equal(
      (await f.request.post(`/api/v1/offers/${id}/close`).auth(sellerToken, bearer)).status,
      200,
    );
    assert.deepEqual((await catalog()).body.items, []);
    const stored = await f.db.query('SELECT status, quota_total FROM offers WHERE id=$1', [id]);
    assert.deepEqual(stored.rows[0], { status: 'closed', quota_total: 2 });
  } finally {
    await f.close();
  }
});
