import assert from 'node:assert/strict';
import { test } from 'node:test';
import type { Dependencies, ServiceContext, Tx } from '../../src/core/contracts.js';
import { ReviewService } from '../../src/modules/reviews/service.js';

const orderId = '550e8400-e29b-41d4-a716-446655440000';
const now = new Date('2026-11-20T08:00:00Z');
const buyer: ServiceContext = {
  actor: { id: 'buyer-1', role: 'buyer', sessionId: 'session-1' },
  clock: { now: () => now },
};

function scenario(status: 'completed' | 'paid') {
  const writes: unknown[][] = [];
  const tx = {
    async query(sql: string, values: unknown[]) {
      if (sql.startsWith('SELECT offer_id')) return { rows: [{ offer_id: 'offer-1' }] };
      if (sql.startsWith('SELECT * FROM offers')) return { rows: [{ id: 'offer-1' }] };
      if (sql.startsWith('SELECT * FROM orders')) {
        return { rows: [{ id: orderId, buyer_id: buyer.actor.id, seller_id: 'seller-1', status }] };
      }
      if (sql.startsWith('INSERT INTO reviews')) {
        writes.push(values);
        return {
          rows: [
            {
              id: 'review-1',
              order_id: values[0],
              rating: values[3],
              comment: values[4],
              created_at: now,
            },
          ],
        };
      }
      if (sql.startsWith('INSERT INTO audit_logs')) {
        writes.push(values);
        return { rows: [] };
      }
      throw new Error('Unexpected query: ' + sql);
    },
  } as unknown as Tx;
  const deps = {
    db: { transaction: async (run: (tx: Tx) => Promise<unknown>) => run(tx) },
  } as Dependencies;
  return { service: new ReviewService(deps), writes };
}

test('C10-UT01 ReviewService.create saves a completed order review and audits it', async () => {
  const { service, writes } = scenario('completed');
  const review = await service.create(buyer, {
    order_id: orderId,
    rating: 5,
    comment: '  Paket baik.  ',
  });
  assert.equal(review.rating, 5);
  assert.equal(review.comment, 'Paket baik.');
  assert.deepEqual(writes[0], [orderId, buyer.actor.id, 'seller-1', 5, 'Paket baik.', now]);
  assert.equal(writes[1]?.[2], 'review.created');
});

test('C10-UT02 ReviewService.create rejects an order awaiting pickup without writing a review', async () => {
  const { service, writes } = scenario('paid');
  await assert.rejects(service.create(buyer, { order_id: orderId, rating: 5, comment: '' }), {
    code: 'REVIEW_NOT_ELIGIBLE',
  });
  assert.deepEqual(writes, []);
});
