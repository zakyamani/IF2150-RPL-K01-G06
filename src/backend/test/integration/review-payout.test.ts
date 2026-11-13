import { test } from 'node:test';
import assert from 'node:assert/strict';
import { fixture } from '../helpers/fixture.js';
import { account } from '../helpers/accounts.js';
import { paidOrder } from '../helpers/orders.js';
test('review is completed-only, unique, and merchant reviews require reveal rights', async () => {
  const f = await fixture();
  try {
    const { seller, buyer, order } = await paidOrder(f);
    const other = await account(f, 'buyer');
    const review = () =>
      f.request
        .post('/api/v1/reviews')
        .auth(buyer.access_token, { type: 'bearer' })
        .send({ order_id: order.id, rating: 5, comment: 'Paket baik dan pickup lancar.' });
    assert.equal((await review()).status, 409);
    assert.equal(
      (
        await f.request
          .get(`/api/v1/reviews/merchant/${seller.user.id}`)
          .auth(other.access_token, { type: 'bearer' })
      ).status,
      403,
    );
    await f.request
      .post('/api/v1/pickup/validate')
      .auth(seller.access_token, { type: 'bearer' })
      .send({ order_id: order.id, kind: 'otp', value: order.pickup.otp });
    assert.equal((await review()).status, 201);
    assert.equal((await review()).status, 409);
    const ratings = await f.request
      .get(`/api/v1/reviews/merchant/${seller.user.id}`)
      .auth(buyer.access_token, { type: 'bearer' });
    assert.equal(ratings.status, 200);
    assert.equal(ratings.body.rating_average, 5);
    assert.equal(ratings.body.rating_count, 1);
    const finance = await f.request
      .get('/api/v1/payouts/summary')
      .auth(seller.access_token, { type: 'bearer' });
    assert.equal(finance.status, 200);
    assert.equal(finance.body.pending, 38000);
    assert.equal(finance.body.simulation, true);
    const payouts = await f.request
      .get('/api/v1/payouts')
      .auth(seller.access_token, { type: 'bearer' });
    assert.equal(payouts.body.items[0].fee, 2000);
    assert.equal(payouts.body.items[0].gross, 40000);
    assert.equal(payouts.body.items[0].net, 38000);
    assert.equal(
      (await f.request.get('/api/v1/payouts').auth(buyer.access_token, { type: 'bearer' })).status,
      403,
    );
    const complaint = await f.request
      .post('/api/v1/complaints')
      .auth(buyer.access_token, { type: 'bearer' })
      .set('Idempotency-Key', 'post-complete')
      .send({
        order_id: order.id,
        reason: 'unfit',
        description: 'Keluhan setelah selesai.',
        media_ids: [],
      });
    assert.equal(complaint.status, 409);
  } finally {
    await f.close();
  }
});
