import { performance } from 'node:perf_hooks';
import { setTimeout as sleep } from 'node:timers/promises';
import WebSocket from 'ws';
import { fixture } from '../helpers/fixture.js';
import { account } from '../helpers/accounts.js';
import { sellerOffer } from '../helpers/offers.js';
import { publishPending } from '../../src/modules/notifications/service.js';

function stats(values: number[]) {
  const sorted = [...values].sort((a, b) => a - b);
  const at = (p: number) =>
    Math.round(sorted[Math.ceil(sorted.length * p) - 1]! * 100) / 100;
  return {
    samples: sorted.length,
    p50_ms: at(0.5),
    p95_ms: at(0.95),
    max_ms: at(1),
  };
}

const f = await fixture();
let ws: WebSocket | undefined;

try {
  const { seller, offer } = await sellerOffer(f, { quota: 50 });
  const buyer = await account(f, 'buyer');

  const ticketRes = await f.request
    .post('/api/v1/notifications/ws-ticket')
    .auth(seller.access_token, { type: 'bearer' })
    .send({ after: '0' });

  const port = (f.server.address() as { port: number }).port;
  ws = new WebSocket(
    `ws://127.0.0.1:${port}/ws?ticket=${encodeURIComponent(ticketRes.body.ticket)}`,
  );

  const waiters = new Map<string, () => void>();
  ws.on('message', (raw) => {
    const msg = JSON.parse(raw.toString());
    if (msg.type === 'payment.succeeded' && waiters.has(msg.resource_id)) {
      waiters.get(msg.resource_id)!();
      waiters.delete(msg.resource_id);
    }
  });

  await new Promise<void>((resolve, reject) => {
    ws!.once('open', () => resolve());
    ws!.once('error', reject);
  });

  const e2eLatencies: number[] = [];
  const pushLatencies: number[] = [];
  let failures = 0;

  for (let i = 0; i < 30; i++) {
    const checkout = await f.request
      .post('/api/v1/orders/checkout')
      .auth(buyer.access_token, { type: 'bearer' })
      .set('Idempotency-Key', `knf05-bench-${i}`)
      .send({ offer_id: offer.id });

    const orderId: string = checkout.body.order_id;
    const intentId: string = checkout.body.intent_id;

    let resolveMsg!: () => void;
    const received = new Promise<void>((resolve, reject) => {
      const timer = setTimeout(() => reject(new Error('WS timeout')), 5000);
      resolveMsg = () => {
        clearTimeout(timer);
        resolve();
      };
    });
    waiters.set(orderId, resolveMsg);

    try {
      const t0 = performance.now();
      await f.request
        .post(`/api/v1/payments/${intentId}/demo-event`)
        .auth(buyer.access_token, { type: 'bearer' })
        .send({ outcome: 'succeeded' });

      const tPush0 = performance.now();
      await publishPending(f.deps);
      await received;
      const tEnd = performance.now();

      e2eLatencies.push(tEnd - t0);
      pushLatencies.push(tEnd - tPush0);
    } catch {
      failures++;
    }
    await sleep(10);
  }

  console.log(
    JSON.stringify(
      {
        test_id: 'KF05-PERF01',
        push_outbox_to_ws: stats(pushLatencies),
        end_to_end_order_to_ws: stats(e2eLatencies),
        failures,
      },
      null,
      2,
    ),
  );
} finally {
  ws?.terminate();
  await f.close();
}