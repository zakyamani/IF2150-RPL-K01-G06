import type { Fixture } from './accounts.js';
import { account } from './accounts.js';
export function offerInput(now: Date, extra: Record<string, unknown> = {}) {
  return {
    category: 'campuran',
    allergens: [],
    quota: 1,
    normal_price: 100000,
    discount_price: 40000,
    pickup_start: now.toISOString(),
    pickup_end: new Date(now.getTime() + 3600000).toISOString(),
    safe_eat_until: new Date(now.getTime() + 7200000).toISOString(),
    fitness_confirmed: true,
    ...extra,
  };
}
export async function sellerOffer(f: Fixture, extra: Record<string, unknown> = {}) {
  const seller = await account(f, 'seller');
  await f.request
    .patch('/api/v1/merchant/profile')
    .auth(seller.access_token, { type: 'bearer' })
    .send({
      shop_name: 'Gerai Rahasia',
      address: 'Jalan Uji Bandung 12',
      latitude: -6.9,
      longitude: 107.6,
    });
  const result = await f.request
    .post('/api/v1/offers')
    .auth(seller.access_token, { type: 'bearer' })
    .send(offerInput(f.clock.now(), extra));
  if (result.status !== 201)
    throw new Error(`Offer creation failed: ${result.status} ${JSON.stringify(result.body)}`);
  return { seller, offer: result.body };
}
