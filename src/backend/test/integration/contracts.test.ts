import { test } from 'node:test';
import assert from 'node:assert/strict';
import { responseSchemas as s } from '../../src/core/response-schemas.js';
import { fixture } from '../helpers/fixture.js';
import { paidOrder } from '../helpers/orders.js';
import { account } from '../helpers/accounts.js';
test('HTTP responses conform to the contract consumed by Android', async () => {
  const f = await fixture();
  try {
    const registered = await f.request
      .post('/api/v1/auth/register')
      .send({
        email: 'contracts@example.test',
        password: 'Contracts-password-2026',
        name: 'Pembeli Kontrak',
        role: 'buyer',
      });
    assert.equal(registered.status, 201);
    s.register.parse(registered.body);
    const p = await paidOrder(f, { quota: 2 });
    const buyer = await account(f, 'buyer');
    const get = async (path: string, token: string) => {
      const r = await f.request.get(`/api/v1${path}`).auth(token, { type: 'bearer' });
      assert.equal(r.status, 200);
      return r.body;
    };
    s.me.parse(await get('/auth/me', buyer.access_token));
    s.merchantProfile.parse(await get('/merchant/profile', p.seller.access_token));
    s.catalog.parse(await get('/catalog', buyer.access_token));
    s.catalogDetail.parse(await get(`/catalog/${p.offer.id}`, buyer.access_token));
    s.sellerOffers.parse(await get('/offers', p.seller.access_token));
    s.sellerOffer.parse(await get(`/offers/${p.offer.id}`, p.seller.access_token));
    s.checkout.parse(p.checkout);
    s.order.parse(await get(`/orders/${p.order.id}`, p.buyer.access_token));
    s.orders.parse(await get('/orders', p.buyer.access_token));
    s.paymentIntent.parse(await get(`/payments/${p.checkout.intent_id}`, p.buyer.access_token));
    s.notifications.parse(await get('/notifications', p.buyer.access_token));
    s.metrics.parse(await get('/metrics', p.buyer.access_token));
    const complaint = await f.request
      .post('/api/v1/complaints')
      .auth(p.buyer.access_token, { type: 'bearer' })
      .set('Idempotency-Key', 'contract-complaint')
      .send({
        order_id: p.order.id,
        reason: 'unfit',
        description: 'Paket tidak layak diambil.',
        media_ids: [],
      });
    assert.equal(complaint.status, 201);
    s.openComplaint.parse(complaint.body);
    s.complaint.parse(await get(`/complaints/${complaint.body.id}`, p.seller.access_token));
    s.complaints.parse(await get('/complaints', p.seller.access_token));
    s.payouts.parse(await get('/payouts', p.seller.access_token));
    s.payoutSummary.parse(await get('/payouts/summary', p.seller.access_token));
  } finally {
    await f.close();
  }
});
