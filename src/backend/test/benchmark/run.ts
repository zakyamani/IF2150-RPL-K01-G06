/** Local profiling uses a disposable PostgreSQL database; no hosted service/account required. */
import { performance } from 'node:perf_hooks';
import { mkdirSync, writeFileSync } from 'node:fs';
import { cpus, totalmem } from 'node:os';
import { randomUUID } from 'node:crypto';
import bcrypt from 'bcrypt';
import { fixture } from '../helpers/fixture.js';
import { account } from '../helpers/accounts.js';
import { sellerOffer } from '../helpers/offers.js';

const f = await fixture();
const serverTimes: number[] = [];
f.server.prependListener('request', (req, res) => {
  if (req.url !== '/api/v1/pickup/validate') return;
  const start = performance.now();
  res.once('finish', () => serverTimes.push(performance.now() - start));
});
function stats(x: number[]) {
  const sorted = [...x].sort((a, b) => a - b);
  const at = (percentile: number) => Math.round(sorted[Math.ceil(sorted.length * percentile) - 1]! * 100) / 100;
  return { samples: sorted.length, p50_ms: at(.5), p95_ms: at(.95), max_ms: at(1) };
}
try {
  const startHash = performance.now();
  const passwordHash = await bcrypt.hash('Benchmark-Password-2026', 12);
  const hashMs = performance.now() - startHash;
  await f.db.query("INSERT INTO users(email,password_hash,name,role) SELECT 'benchmark-'||i||'@example.test',$1,'Dataset pilot',CASE WHEN i<=300 THEN 'seller' ELSE 'buyer' END FROM generate_series(1,1000)i", [passwordHash]);
  await f.db.query("INSERT INTO merchant_profiles(user_id,shop_name,address,latitude,longitude) SELECT id,'Dataset merchant','Bandung',-6.9,107.6 FROM users WHERE role='seller'");
  await f.db.query("INSERT INTO offers(seller_id,category,quota_total,quota_available,normal_price,discount_price,pickup_start,pickup_end,safe_eat_until,fitness_confirmed) SELECT u.id,'campuran',20,20,100000,40000,$1,$1::timestamptz+interval '1h',$1::timestamptz+interval '2h',true FROM (SELECT id,row_number() OVER(ORDER BY id) n FROM users WHERE role='seller')u JOIN generate_series(1,5000)i ON u.n=((i-1)%300)+1", [f.clock.now()]);
  const { seller, offer } = await sellerOffer(f, { quota: 100 });
  const buyers = await Promise.all(Array.from({ length: 4 }, () => account(f, 'buyer')));
  const values: number[] = [];
  let failures = 0;
  const origin = `http://127.0.0.1:${(f.server.address() as { port: number }).port}`;
  for (let i = 0; i < 30; i++) {
    const buyer = buyers[i % buyers.length]!;
    const checkout = await f.request.post('/api/v1/orders/checkout')
      .auth(buyer.access_token, { type: 'bearer' }).set('Idempotency-Key', randomUUID()).send({ offer_id: offer.id });
    if (checkout.status !== 201) throw Error('Checkout setup failed: ' + checkout.status);
    const payment = await f.request.post(`/api/v1/payments/${checkout.body.intent_id}/demo-event`)
      .auth(buyer.access_token, { type: 'bearer' }).send({ outcome: 'succeeded' });
    if (payment.status !== 200) throw Error('Payment setup failed: ' + payment.status);
    const order = await f.request.get(`/api/v1/orders/${checkout.body.order_id}`).auth(buyer.access_token, { type: 'bearer' });
    if (order.status !== 200) throw Error('Order setup failed: ' + order.status);
    const start = performance.now();
    const response = await fetch(origin + '/api/v1/pickup/validate', {
      method: 'POST', headers: { 'content-type': 'application/json', authorization: 'Bearer ' + seller.access_token },
      body: JSON.stringify({ kind: 'qr', order_id: order.body.id, value: order.body.pickup.qr }),
      signal: AbortSignal.timeout(15000),
    });
    await response.arrayBuffer();
    values.push(performance.now() - start);
    if (!response.ok) failures++;
  }
  await f.db.query('ANALYZE offers');
  const queryPlan = (await f.db.query("EXPLAIN (ANALYZE,BUFFERS) SELECT id FROM offers WHERE status='active' AND quota_available>0 AND pickup_end>$1 ORDER BY created_at DESC,id DESC LIMIT 20", [f.clock.now()])).rows;
  const result = {
    measured_at: new Date().toISOString(),
    environment: { node: process.version, cpu: cpus()[0]?.model, cpus: cpus().length,
      ram_gib: Math.round(totalmem() / 1024 ** 3), postgres: 15, process_rss_bytes: process.memoryUsage().rss },
    seeded_dataset: { users: 1000, merchants: 300, offers: 5000 },
    bcrypt_cost12_ms: Math.round(hashMs),
    latency: { local: { end_to_end: stats(values), server: stats(serverTimes), failures } },
    query_plan: queryPlan,
    limits: '30 sequential local HTTP pickup requests against real disposable PostgreSQL. Excludes camera, mobile UI, internet/3G, concurrent load and physical-device latency.',
  };
  mkdirSync('../artifacts', { recursive: true });
  writeFileSync('../artifacts/benchmark.json', JSON.stringify(result, null, 2) + '\n');
  console.log(JSON.stringify(result));
  if (failures || serverTimes.length !== 30) throw Error('Pickup benchmark failed or missing samples');
} finally {
  await f.close();
}
