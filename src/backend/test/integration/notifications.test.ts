import { test } from 'node:test';
import assert from 'node:assert/strict';
import WebSocket from 'ws';
import { setTimeout as sleep } from 'node:timers/promises';
import { fixture } from '../helpers/fixture.js';
import { account } from '../helpers/accounts.js';
import { paidOrder } from '../helpers/orders.js';
import { TestClock } from '../../src/core/clock.js';
import { createServer } from '../../src/app.js';
import request from 'supertest';
async function connect(server: any, ticket: string) {
  const ws = new WebSocket(
    `ws://127.0.0.1:${server.address().port}/ws?ticket=${encodeURIComponent(ticket)}`,
  );
  const messages: any[] = [];
  ws.on('message', (b) => messages.push(JSON.parse(b.toString())));
  ws.on('error', () => {});
  await new Promise<void>((resolve, reject) => {
    const timer = setTimeout(() => {
      ws.terminate();
      reject(new Error('Socket connection timed out'));
    }, 2000);
    ws.once('open', () => {
      clearTimeout(timer);
      resolve();
    });
    ws.once('error', (e) => {
      clearTimeout(timer);
      reject(e);
    });
  });
  return { ws, messages };
}
async function until(predicate: () => boolean) {
  for (let n = 0; n < 100; n++) {
    if (predicate()) return;
    await sleep(20);
  }
  assert.fail('Expected socket event within 2 seconds');
}
test('short-lived single-use socket ticket prevents reuse and expiry', async () => {
  const clock = new TestClock();
  const f = await fixture({ clock });
  let ws: WebSocket | undefined;
  try {
    const user = await account(f, 'buyer');
    const ticket = await f.request
      .post('/api/v1/notifications/ws-ticket')
      .auth(user.access_token, { type: 'bearer' })
      .send({ after: '0' });
    assert.equal(ticket.status, 200);
    assert.ok(!ticket.body.ticket.includes(user.access_token));
    ws = (await connect(f.server, ticket.body.ticket)).ws;
    await assert.rejects(connect(f.server, ticket.body.ticket));
    const second = await f.request
      .post('/api/v1/notifications/ws-ticket')
      .auth(user.access_token, { type: 'bearer' })
      .send({ after: '0' });
    assert.equal(second.status, 200);
    clock.advance(45000);
    await assert.rejects(connect(f.server, second.body.ticket));
    clock.advance(900000);
    await (f.server as any).sockets.checkSessions();
    await until(() => ws!.readyState === WebSocket.CLOSED);
  } finally {
    ws?.terminate();
    await f.close();
  }
});
test('durable inbox catches up disconnects; LISTEN/NOTIFY delivery dedupes and logout closes socket', async () => {
  const f = await fixture();
  let ws: WebSocket | undefined;
  try {
    const p = await paidOrder(f);
    const other = await account(f, 'buyer');
    const initial = await f.request
      .get('/api/v1/notifications?after=0')
      .auth(p.seller.access_token, { type: 'bearer' });
    assert.equal(initial.status, 200);
    assert.equal(initial.body.items.length, 1);
    const after = initial.body.last_cursor;
    const ticket = await f.request
      .post('/api/v1/notifications/ws-ticket')
      .auth(p.seller.access_token, { type: 'bearer' })
      .send({ after });
    assert.equal(ticket.status, 200);
    const conn = await connect(f.server, ticket.body.ticket);
    ws = conn.ws;
    const complaint = await f.request
      .post('/api/v1/complaints')
      .auth(p.buyer.access_token, { type: 'bearer' })
      .set('Idempotency-Key', 'notify-dispute')
      .send({
        order_id: p.order.id,
        reason: 'unavailable',
        description: 'Paket belum tersedia saat pickup.',
        media_ids: [],
      });
    assert.equal(complaint.status, 201);
    const { publishPending } = await import('../../src/modules/notifications/service.js');
    await publishPending(f.deps);
    await until(() => conn.messages.some((m) => m.type === 'complaint.opened'));
    const event = conn.messages.find((m) => m.type === 'complaint.opened');
    await publishPending(f.deps);
    await f.db.query("SELECT pg_notify('sisarasa_notifications',$1)", [p.seller.user.id]);
    await sleep(50);
    assert.equal(conn.messages.filter((m) => m.id === event.id).length, 1);
    assert.equal(
      (
        await f.request
          .post(`/api/v1/notifications/${event.id}/read`)
          .auth(other.access_token, { type: 'bearer' })
      ).status,
      404,
    );
    assert.equal(
      (
        await f.request
          .post(`/api/v1/notifications/${event.id}/read`)
          .auth(p.seller.access_token, { type: 'bearer' })
      ).status,
      200,
    );
    ws.terminate();
    await until(() => ws!.readyState === WebSocket.CLOSED);
    await f.request
      .post(`/api/v1/complaints/${complaint.body.id}/decision`)
      .auth(p.seller.access_token, { type: 'bearer' })
      .send({ approved: true, response: 'Refund disetujui.' });
    const catchup = await f.request
      .get(`/api/v1/notifications?after=${event.sequence}`)
      .auth(p.seller.access_token, { type: 'bearer' });
    assert.equal(catchup.status, 200);
    assert.ok(catchup.body.items.some((m: any) => m.type === 'order.refunded'));
    const reconnect = await f.request
      .post('/api/v1/notifications/ws-ticket')
      .auth(p.seller.access_token, { type: 'bearer' })
      .send({ after: event.sequence });
    ws = (await connect(f.server, reconnect.body.ticket)).ws;
    assert.equal(
      (await f.request.post('/api/v1/auth/logout').auth(p.seller.access_token, { type: 'bearer' }))
        .status,
      204,
    );
    await until(() => ws!.readyState === WebSocket.CLOSED);
  } finally {
    ws?.terminate();
    await f.close();
  }
});

test('recreated API delivers committed inbox/outbox without loss', async () => {
  const f = await fixture();
  let server: ReturnType<typeof createServer> | undefined;
  let ws: WebSocket | undefined;
  try {
    const p = await paidOrder(f);
    const stored = (
      await f.db.query('SELECT id FROM notifications WHERE user_id=$1', [p.buyer.user.id])
    ).rows[0].id;
    await f.server.sockets.stop();
    await new Promise<void>((resolve) => f.server.close(() => resolve()));
    assert.ok((await f.db.query('SELECT id FROM outbox WHERE published_at IS NULL')).rowCount! > 0);
    server = createServer(f.deps);
    await server.sockets.ready;
    await new Promise<void>((resolve) => server!.listen(0, '127.0.0.1', resolve));
    const api = request(server);
    const ticket = await api
      .post('/api/v1/notifications/ws-ticket')
      .auth(p.buyer.access_token, { type: 'bearer' })
      .send({ after: '0' });
    assert.equal(ticket.status, 200);
    const conn = await connect(server, ticket.body.ticket);
    ws = conn.ws;
    const { publishPending } = await import('../../src/modules/notifications/service.js');
    await publishPending(f.deps);
    await until(() => conn.messages.some((m) => m.id === stored));
    assert.equal(conn.messages.filter((m) => m.id === stored).length, 1);
    const inbox = await api
      .get('/api/v1/notifications')
      .auth(p.buyer.access_token, { type: 'bearer' });
    assert.ok(inbox.body.items.some((m: any) => m.id === stored));
  } finally {
    ws?.terminate();
    if (server) {
      await server.sockets.stop();
      server.closeAllConnections();
      if (server.listening) await new Promise<void>((resolve) => server!.close(() => resolve()));
    }
    await f.close();
  }
});

test('recipient cursor cannot skip an earlier transaction when a later writer overtakes it', async () => {
  const f = await fixture();
  let ws: WebSocket | undefined;
  let release!: () => void;
  const gate = new Promise<void>((resolve) => {
    release = resolve;
  });
  let first: Promise<void> | undefined;
  let second: Promise<void> | undefined;
  try {
    const { notify } = await import('../../src/core/effects.js');
    const user = await account(f, 'buyer');
    let allocated!: () => void;
    const ready = new Promise<void>((resolve) => {
      allocated = resolve;
    });
    const a = '00000000-0000-4000-8000-000000000001';
    const b = '00000000-0000-4000-8000-000000000002';
    first = f.db.transaction(async (tx) => {
      await notify(tx, user.user.id, a, 'test.first', 'First', f.clock.now());
      allocated();
      await gate;
    });
    await ready;
    let overtook = false;
    second = f.db
      .transaction(async (tx) => {
        await notify(tx, user.user.id, b, 'test.second', 'Second', f.clock.now());
      })
      .then(() => {
        overtook = true;
      });
    // Observe either the unsafe commit or the safe transaction lock, not a timing guess.
    let blocked = false;
    for (let n = 0; n < 100 && !overtook && !blocked; n++) {
      blocked = !!(
        await f.db.query(
          "SELECT pid FROM pg_stat_activity WHERE datname=current_database() AND wait_event='advisory' AND state='active'",
        )
      ).rowCount;
      if (!blocked && !overtook) await sleep(20);
    }
    assert.ok(overtook || blocked, 'second writer must commit or wait on the first');
    const early = await f.request
      .get('/api/v1/notifications?after=0')
      .auth(user.access_token, { type: 'bearer' });
    assert.equal(early.status, 200);
    const ticket = await f.request
      .post('/api/v1/notifications/ws-ticket')
      .auth(user.access_token, { type: 'bearer' })
      .send({ after: early.body.last_cursor });
    const conn = await connect(f.server, ticket.body.ticket);
    ws = conn.ws;
    release();
    await Promise.all([first, second]);
    const later = await f.request
      .get(`/api/v1/notifications?after=${early.body.last_cursor}`)
      .auth(user.access_token, { type: 'bearer' });
    assert.equal(later.status, 200);
    assert.deepEqual(
      [...early.body.items, ...later.body.items].map((m: any) => m.resource_id).sort(),
      [a, b],
    );
    const { publishPending } = await import('../../src/modules/notifications/service.js');
    await publishPending(f.deps);
    await until(
      () =>
        conn.messages.some((m) => m.resource_id === a) &&
        conn.messages.some((m) => m.resource_id === b),
    );
    assert.ok(conn.messages.some((m) => m.resource_id === b));
  } finally {
    release();
    await Promise.allSettled([first, second]);
    ws?.terminate();
    await f.close();
  }
});
