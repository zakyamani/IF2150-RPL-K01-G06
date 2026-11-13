import { test } from 'node:test';
import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';
import sharp from 'sharp';
import { fixture } from '../helpers/fixture.js';
import { account } from '../helpers/accounts.js';
import { paidOrder } from '../helpers/orders.js';
import { TestClock } from '../../src/core/clock.js';
test('complaint holds payout, enforces evidence ownership, and approval refunds gross once', async () => {
  const f = await fixture();
  try {
    const { seller, buyer, order } = await paidOrder(f);
    const other = await account(f, 'buyer');
    const image = await sharp({ create: { width: 10, height: 10, channels: 3, background: 'red' } })
      .png()
      .toBuffer();
    const upload = await f.request
      .post('/api/v1/media')
      .auth(other.access_token, { type: 'bearer' })
      .field('kind', 'evidence')
      .attach('file', image, { filename: 'proof.png', contentType: 'image/png' });
    assert.equal(upload.status, 201);
    const open = (body: Record<string, unknown>, key: string = randomUUID()) =>
      f.request
        .post('/api/v1/complaints')
        .auth(buyer.access_token, { type: 'bearer' })
        .set('Idempotency-Key', key)
        .send({
          order_id: order.id,
          reason: 'unavailable',
          description: 'Paket tidak tersedia saat datang.',
          media_ids: [],
          ...body,
        });
    assert.equal((await open({ reason: 'dislike' })).status, 400);
    assert.equal((await open({ media_ids: [upload.body.id] })).status, 404);
    assert.equal(
      (await open({ media_ids: [randomUUID(), randomUUID(), randomUUID()] })).status,
      400,
    );
    const proof = await f.request
      .post('/api/v1/media')
      .auth(buyer.access_token, { type: 'bearer' })
      .field('kind', 'evidence')
      .attach('file', image, { filename: 'proof.png', contentType: 'image/png' });
    assert.equal(proof.status, 201);
    const evidence = { media_ids: [proof.body.id] };
    const complaint = await open(evidence, 'complaint-same');
    assert.equal(complaint.status, 201);
    assert.equal((await open(evidence, 'complaint-same')).body.id, complaint.body.id);
    assert.equal(
      (
        await f.request
          .get(`/api/v1/media/${proof.body.id}`)
          .auth(seller.access_token, { type: 'bearer' })
      ).status,
      200,
    );
    assert.equal(
      (
        await f.request
          .get(`/api/v1/media/${proof.body.id}`)
          .auth(other.access_token, { type: 'bearer' })
      ).status,
      404,
    );
    assert.equal((await f.db.query('SELECT status FROM orders')).rows[0].status, 'dispute');
    assert.equal(
      (await f.db.query('SELECT status FROM payout_entitlements')).rows[0].status,
      'held',
    );
    const approve = () =>
      f.request
        .post(`/api/v1/complaints/${complaint.body.id}/decision`)
        .auth(seller.access_token, { type: 'bearer' })
        .send({ approved: true, response: 'Disetujui, paket habis.' });
    assert.equal((await approve()).status, 200);
    assert.equal((await approve()).status, 200);
    assert.equal((await f.db.query('SELECT amount FROM refunds')).rows[0].amount, 40000);
    assert.equal((await f.db.query('SELECT count(*)::int AS n FROM refunds')).rows[0].n, 1);
    assert.equal(
      (await f.db.query("SELECT amount FROM ledger_entries WHERE kind='refund'")).rows[0].amount,
      40000,
    );
    assert.deepEqual(
      (await f.db.query('SELECT quota_available,quota_held,quota_sold FROM offers')).rows[0],
      { quota_available: 1, quota_held: 0, quota_sold: 0 },
    );
    assert.equal(
      (await f.db.query('SELECT status FROM payout_entitlements')).rows[0].status,
      'cancelled',
    );
  } finally {
    await f.close();
  }
});
test('rejected complaint after pickup deadline consistently becomes no-show', async () => {
  const clock = new TestClock();
  const f = await fixture({ clock });
  try {
    const { seller, buyer, order } = await paidOrder(f);
    const opened = await f.request
      .post('/api/v1/complaints')
      .auth(buyer.access_token, { type: 'bearer' })
      .set('Idempotency-Key', 'reject-late')
      .send({
        order_id: order.id,
        reason: 'allergen',
        description: 'Label alergen tidak sesuai.',
        media_ids: [],
      });
    assert.equal(opened.status, 201);
    const body = { approved: false, response: '' };
    assert.equal(
      (
        await f.request
          .post(`/api/v1/complaints/${opened.body.id}/decision`)
          .auth(seller.access_token, { type: 'bearer' })
          .send(body)
      ).status,
      400,
    );
    clock.set(new Date(order.pickup_end));
    const { ComplaintService } = await import('../../src/modules/complaints/service.js');
    const result = await new ComplaintService(f.deps).decide(seller.ctx, opened.body.id, {
      approved: false,
      response: 'Informasi paket sudah sesuai.',
    });
    assert.equal(result.status, 'rejected');
    assert.equal((await f.db.query('SELECT status FROM orders')).rows[0].status, 'no_show');
    assert.equal(
      (await f.db.query('SELECT status FROM payout_entitlements')).rows[0].status,
      'pending',
    );
    assert.equal((await f.db.query('SELECT count(*)::int AS n FROM refunds')).rows[0].n, 0);
  } finally {
    await f.close();
  }
});
test('scan racing complaint or seller cancel keeps one consistent terminal state', async () => {
  const f = await fixture();
  try {
    const { seller, buyer, order } = await paidOrder(f);
    const results = await Promise.all([
      f.request
        .post('/api/v1/pickup/validate')
        .auth(seller.access_token, { type: 'bearer' })
        .send({ order_id: order.id, kind: 'qr', value: order.pickup.qr }),
      f.request
        .post('/api/v1/complaints')
        .auth(buyer.access_token, { type: 'bearer' })
        .set('Idempotency-Key', 'race')
        .send({
          order_id: order.id,
          reason: 'unavailable',
          description: 'Paket belum tersedia.',
          media_ids: [],
        }),
      f.request
        .post(`/api/v1/orders/${order.id}/cancel`)
        .auth(seller.access_token, { type: 'bearer' })
        .set('Idempotency-Key', 'cancel-race')
        .send({ reason: 'Gerai tidak dapat melayani.' }),
    ]);
    const state = (await f.db.query('SELECT status FROM orders')).rows[0].status;
    assert.ok(['completed', 'refunded'].includes(state));
    assert.ok(results.every((r) => [200, 201, 409].includes(r.status)));
    if (state === 'completed') {
      assert.equal((await f.db.query('SELECT count(*)::int AS n FROM refunds')).rows[0].n, 0);
      assert.equal(
        (await f.db.query('SELECT status FROM payout_entitlements')).rows[0].status,
        'pending',
      );
    } else {
      assert.equal((await f.db.query('SELECT count(*)::int AS n FROM refunds')).rows[0].n, 1);
      assert.equal((await f.db.query('SELECT quota_sold FROM offers')).rows[0].quota_sold, 0);
    }
  } finally {
    await f.close();
  }
});
