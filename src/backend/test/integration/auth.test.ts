import { test } from 'node:test';
import assert from 'node:assert/strict';
import { fixture } from '../helpers/fixture.js';
import { TestClock } from '../../src/core/clock.js';
const buyer = {
  email: ' Buyer@Example.test ',
  password: 'A-secure-password-2026',
  name: 'Pembeli',
  role: 'buyer',
};
test('registration normalizes email, hides hashes and atomically creates seller profile', async () => {
  const f = await fixture();
  try {
    const a = await f.request.post('/api/v1/auth/register').send(buyer);
    assert.equal(a.status, 201);
    assert.equal(a.body.user.email, 'buyer@example.test');
    assert.ok(!('password_hash' in a.body.user));
    const row = (await f.db.query('SELECT password_hash FROM users')).rows[0];
    assert.match(row.password_hash, /^\$2[aby]\$12\$/);
    assert.notEqual(row.password_hash, buyer.password);
    assert.equal(
      (
        await f.request
          .post('/api/v1/auth/register')
          .send({ ...buyer, email: 'buyer@example.test' })
      ).status,
      409,
    );
    const s = await f.request
      .post('/api/v1/auth/register')
      .send({ ...buyer, email: 'seller@example.test', role: 'seller' });
    assert.equal(s.status, 201);
    assert.equal(
      (await f.db.query('SELECT count(*)::int AS n FROM merchant_profiles')).rows[0].n,
      1,
    );
    const invalid = await f.request
      .patch('/api/v1/merchant/profile')
      .auth(s.body.access_token, { type: 'bearer' })
      .send({ shop_name: 'Gerai', address: 'Jalan Bandung', latitude: 91, longitude: 107 });
    assert.equal(invalid.status, 400);
    assert.equal(
      (
        await f.request
          .patch('/api/v1/merchant/profile')
          .auth(a.body.access_token, { type: 'bearer' })
          .send({ shop_name: 'Gerai', address: 'Bandung', latitude: -6.9, longitude: 107.6 })
      ).status,
      403,
    );
    const good = await f.request
      .patch('/api/v1/merchant/profile')
      .auth(s.body.access_token, { type: 'bearer' })
      .send({
        shop_name: 'Gerai',
        address: 'Jalan Bandung',
        latitude: -6.9,
        longitude: 107.6,
        bank_destination: '1234567890',
      });
    assert.equal(good.status, 200);
    assert.equal(good.body.bank_masked, '••••7890');
  } finally {
    await f.close();
  }
});
test('refresh rotates and replay revokes family including current access token', async () => {
  const f = await fixture();
  try {
    const a = await f.request.post('/api/v1/auth/register').send(buyer);
    assert.equal(a.status, 201);
    const r = await f.request
      .post('/api/v1/auth/refresh')
      .send({ refresh_token: a.body.refresh_token });
    assert.equal(r.status, 200);
    assert.notEqual(r.body.refresh_token, a.body.refresh_token);
    assert.equal(
      (await f.request.get('/api/v1/auth/me').auth(r.body.access_token, { type: 'bearer' })).status,
      200,
    );
    assert.equal(
      (await f.request.post('/api/v1/auth/refresh').send({ refresh_token: a.body.refresh_token }))
        .status,
      401,
    );
    assert.equal(
      (await f.request.get('/api/v1/auth/me').auth(r.body.access_token, { type: 'bearer' })).status,
      401,
    );
  } finally {
    await f.close();
  }
});
test('logout and exact access expiry invalidate credentials; login limit persists', async () => {
  const clock = new TestClock();
  const f = await fixture({ clock });
  try {
    const a = await f.request.post('/api/v1/auth/register').send(buyer);
    assert.equal(a.status, 201);
    clock.advance(15 * 60000);
    assert.equal(
      (await f.request.get('/api/v1/auth/me').auth(a.body.access_token, { type: 'bearer' })).status,
      401,
    );
    const b = await f.request
      .post('/api/v1/auth/login')
      .send({ email: buyer.email, password: buyer.password });
    assert.equal(b.status, 200);
    assert.equal(
      (await f.request.post('/api/v1/auth/logout').auth(b.body.access_token, { type: 'bearer' }))
        .status,
      204,
    );
    assert.equal(
      (await f.request.get('/api/v1/auth/me').auth(b.body.access_token, { type: 'bearer' })).status,
      401,
    );
    for (let n = 0; n < 4; n++)
      assert.equal(
        (
          await f.request
            .post('/api/v1/auth/login')
            .send({ email: buyer.email, password: 'incorrect-password' })
        ).status,
        401,
      );
    assert.equal(
      (
        await f.request
          .post('/api/v1/auth/login')
          .send({ email: buyer.email, password: 'incorrect-password' })
      ).status,
      429,
    );
  } finally {
    await f.close();
  }
});
