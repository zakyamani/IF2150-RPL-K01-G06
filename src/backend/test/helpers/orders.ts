import { randomUUID } from 'node:crypto';
import type { Fixture } from './accounts.js';
import { account } from './accounts.js';
import { sellerOffer } from './offers.js';
export async function paidOrder(f: Fixture, extra: Record<string, unknown> = {}) {
  const { seller, offer } = await sellerOffer(f, extra);
  const buyer = await account(f, 'buyer');
  const c = await f.request
    .post('/api/v1/orders/checkout')
    .auth(buyer.access_token, { type: 'bearer' })
    .set('Idempotency-Key', randomUUID())
    .send({ offer_id: offer.id });
  if (c.status !== 201) throw new Error(`Checkout failed: ${c.status}`);
  const payment = await f.request
    .post(`/api/v1/payments/${c.body.intent_id}/demo-event`)
    .auth(buyer.access_token, { type: 'bearer' })
    .send({ outcome: 'succeeded' });
  if (payment.status !== 200) throw new Error(`Payment failed: ${payment.status}`);
  const view = await f.request
    .get(`/api/v1/orders/${c.body.order_id}`)
    .auth(buyer.access_token, { type: 'bearer' });
  return { seller, buyer, offer, checkout: c.body, order: view.body };
}
