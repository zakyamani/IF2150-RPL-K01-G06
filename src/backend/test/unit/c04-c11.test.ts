import { test } from 'node:test';
import assert from 'node:assert/strict';
import type { Dependencies, ServiceContext, Tx } from '../../src/core/contracts.js';
import { OrderRepository, type OrderRecord } from '../../src/modules/orders/repository.js';
import { OrderService } from '../../src/modules/orders/service.js';
import { MetricsService } from '../../src/modules/metrics/service.js';
import { encodeCursor } from '../../src/core/pagination.js';

const orderId = '550e8400-e29b-41d4-a716-446655440000';
const createdAt = new Date('2026-10-05T12:00:00Z');

function order(overrides: Partial<OrderRecord> = {}): OrderRecord {
  return {
    id: orderId,
    code: 'SR-0123456789',
    invoice: 'INV-test',
    offer_id: '650e8400-e29b-41d4-a716-446655440000',
    buyer_id: 'buyer-1',
    seller_id: 'seller-1',
    status: 'paid',
    price: 40000,
    fee: 2000,
    fee_bps: 500,
    snapshot: {
      category: 'makanan_berat',
      allergens: [],
      normal_price: 100000,
      discount_price: 40000,
      merchant: {
        id: 'seller-1',
        name: 'Gerai Contoh',
        address: 'Jl. Contoh 1',
        latitude: -6.9,
        longitude: 107.6,
        photo_id: null,
      },
    },
    payment_deadline: new Date('2026-10-05T12:15:00Z'),
    pickup_start: new Date('2026-10-05T13:00:00Z'),
    pickup_end: new Date('2026-10-05T15:00:00Z'),
    safe_eat_until: new Date('2026-10-05T15:30:00Z'),
    paid_at: null,
    completed_at: null,
    created_at: createdAt,
    updated_at: createdAt,
    ...overrides,
  };
}

const context = (role: 'buyer' | 'seller', id: string, now = createdAt): ServiceContext => ({
  actor: { id, role, sessionId: 'session-1' },
  clock: { now: () => now },
});

function txForOrder(row: OrderRecord, options: { complaintCount?: number; reviewCount?: number } = {}) {
  return {
    query: async (sql: string) => {
      if (sql.startsWith('SELECT * FROM orders')) return { rows: [row], rowCount: 1 };
      if (sql.includes('FROM payment_intents')) return { rows: [], rowCount: 0 };
      if (sql.includes('FROM audit_logs')) return { rows: [], rowCount: 0 };
      if (sql.includes('FROM complaints'))
        return { rows: [], rowCount: options.complaintCount ?? 0 };
      if (sql.includes('FROM reviews')) return { rows: [], rowCount: options.reviewCount ?? 0 };
      if (sql.includes('FROM checkout_reservations')) return { rows: [], rowCount: 0 };
      if (sql.includes('INSERT INTO payout_entitlements'))
        return { rows: [{ id: 'payout-1' }], rowCount: 1 };
      if (sql.includes('INSERT INTO notifications'))
        return { rows: [{ id: 'notification-1' }], rowCount: 1 };
      return { rows: [], rowCount: 0 };
    },
  } as unknown as Tx;
}

function dependencies(tx: Tx): Dependencies {
  return {
    db: {
      transaction: async (fn: (tx: Tx) => Promise<unknown>) => fn(tx),
      query: async () => ({ rows: [], rowCount: 0 }),
    } as unknown as Dependencies['db'],
    config: {} as Dependencies['config'],
    clock: { now: () => createdAt },
  };
}

test('C04-UT01 OrderRepository.read returns an order or undefined', async () => {
  const row = order();
  const tx = {
    query: async () => ({ rows: [row] }),
  } as unknown as Tx;
  assert.equal(await new OrderRepository().read(tx, orderId), row);

  const emptyTx = { query: async () => ({ rows: [] }) } as unknown as Tx;
  assert.equal(await new OrderRepository().read(emptyTx, orderId), undefined);
});

test('C04-UT02 OrderRepository.release updates inventory only when a held reservation exists', async () => {
  const sql: string[] = [];
  const txWithHeld = {
    query: async (statement: string) => {
      sql.push(statement);
      return { rowCount: statement.startsWith('UPDATE checkout_reservations') ? 1 : 0, rows: [] };
    },
  } as unknown as Tx;
  await new OrderRepository().release(txWithHeld, order());
  assert.equal(sql.length, 2);
  assert.match(sql[1]!, /quota_held=quota_held-1/);

  let inventoryUpdated = false;
  const txWithoutHeld = {
    query: async (statement: string) => {
      if (statement.startsWith('UPDATE offers')) inventoryUpdated = true;
      return { rowCount: 0, rows: [] };
    },
  } as unknown as Tx;
  await new OrderRepository().release(txWithoutHeld, order());
  assert.equal(inventoryUpdated, false);
});

test('C04-UT03 OrderService.list applies buyer scope and returns next cursor when more rows exist', async () => {
  const rows = [order(), order({ id: '550e8400-e29b-41d4-a716-446655440001' }), order({ id: '550e8400-e29b-41d4-a716-446655440002' })];
  let statement = '';
  let parameters: unknown[] = [];
  const deps = {
    db: {
      query: async (sql: string, values: unknown[]) => {
        statement = sql;
        parameters = values;
        return { rows };
      },
    },
  } as unknown as Dependencies;
  const result = await new OrderService(deps).list(context('buyer', 'buyer-1'), { limit: 2, status: 'paid' });

  assert.match(statement, /buyer_id/);
  assert.equal(parameters[0], 'buyer-1');
  assert.equal(parameters[3], 'paid');
  assert.equal(result.items.length, 2);
  assert.ok(result.next_cursor);
});

test('C04-UT04 OrderService.list applies seller scope and returns null cursor on final page', async () => {
  let statement = '';
  const deps = {
    db: {
      query: async (sql: string) => {
        statement = sql;
        return { rows: [order()] };
      },
    },
  } as unknown as Dependencies;
  const result = await new OrderService(deps).list(context('seller', 'seller-1'), {});

  assert.match(statement, /seller_id/);
  assert.equal(result.items[0]?.id, orderId);
  assert.equal(result.next_cursor, null);
});

test('C11-UT01 MetricsService.summary delegates to repository and returns definition', async () => {
  let statement = '';
  const deps = {
    db: {
      query: async (sql: string) => {
        statement = sql;
        return { rows: [{ n: 7 }] };
      },
    },
  } as unknown as Dependencies;
  const result = await new MetricsService(deps).summary();

  assert.match(statement, /status='completed'/);
  assert.deepEqual(result, {
    packages_saved: 7,
    definition: 'Paket yang telah diserahkan melalui validasi pickup.',
  });
});

test('C11-UT02 OrderService.list decodes history cursor and encodes cursor for a following page', async () => {
  const previous = order({ id: '550e8400-e29b-41d4-a716-446655440003' });
  const cursor = encodeCursor({ created_at: previous.created_at, id: previous.id });
  const rows = [order(), order({ id: '550e8400-e29b-41d4-a716-446655440001' }), order({ id: '550e8400-e29b-41d4-a716-446655440002' })];
  let parameters: unknown[] = [];
  const deps = {
    db: {
      query: async (_sql: string, values: unknown[]) => {
        parameters = values;
        return { rows };
      },
    },
  } as unknown as Dependencies;
  const result = await new OrderService(deps).list(context('buyer', 'buyer-1'), { cursor, limit: 2 });

  assert.equal(parameters[1], previous.created_at.toISOString());
  assert.equal(parameters[2], previous.id);
  assert.equal(result.items.length, 2);
  assert.equal(result.next_cursor, encodeCursor({ created_at: rows[1]!.created_at, id: rows[1]!.id }));
});

test('C04-UT05 OrderService.detail exposes buyer payment action without revealing unpaid merchant', async () => {
  const row = order({ status: 'pending_payment', paid_at: null });
  const service = new OrderService(dependencies(txForOrder(row)));
  const detail = await service.detail(context('buyer', row.buyer_id), row.id);

  assert.equal(detail.status, 'pending_payment');
  assert.deepEqual(detail.allowed_actions, ['pay']);
  assert.equal('merchant' in detail, false);
  assert.equal(detail.payment, null);
});

test('C04-UT06 OrderService.detail exposes seller pickup/cancel actions and paid merchant details', async () => {
  const row = order({ paid_at: createdAt });
  const service = new OrderService(dependencies(txForOrder(row)));
  const detail = await service.detail(
    context('seller', row.seller_id, new Date('2026-10-05T14:00:00Z')),
    row.id,
  );

  assert.deepEqual(detail.allowed_actions, ['cancel', 'pickup']);
  assert.equal(detail.merchant?.name, 'Gerai Contoh');
});

test('C04-UT07 OrderService.detail offers review for completed buyer order', async () => {
  const row = order({ status: 'completed', paid_at: createdAt, completed_at: createdAt });
  const detail = await new OrderService(dependencies(txForOrder(row))).detail(
    context('buyer', row.buyer_id),
    row.id,
  );

  assert.deepEqual(detail.allowed_actions, ['review']);
  assert.equal(detail.merchant?.name, 'Gerai Contoh');
});

test('C04-UT08 OrderService.detail rejects access by unrelated user', async () => {
  const row = order();
  await assert.rejects(
    new OrderService(dependencies(txForOrder(row))).detail(context('buyer', 'other-buyer'), row.id),
    { code: 'ORDER_NOT_FOUND' },
  );
});

test('C04-UT09 OrderService.processNoShow skips ineligible orders and open complaints', async () => {
  const service = new OrderService(dependencies(txForOrder(order())));
  assert.equal(await service.processNoShow({} as Tx, order({ status: 'pending_payment' }), createdAt), false);
  assert.equal(
    await service.processNoShow({} as Tx, order(), new Date('2026-10-05T14:00:00Z')),
    false,
  );

  const tx = txForOrder(order(), { complaintCount: 1 });
  assert.equal(
    await service.processNoShow(tx, order(), new Date('2026-10-05T16:00:00Z')),
    false,
  );
});

test('C04-UT10 OrderService.processNoShow closes expired paid order and schedules payout', async () => {
  const row = order();
  const statements: string[] = [];
  const tx = {
    query: async (sql: string) => {
      statements.push(sql);
      if (sql.startsWith('SELECT * FROM orders')) return { rows: [row], rowCount: 1 };
      if (sql.includes('INSERT INTO payout_entitlements'))
        return { rows: [{ id: 'payout-1' }], rowCount: 1 };
      if (sql.includes('INSERT INTO notifications'))
        return { rows: [{ id: 'notification-1' }], rowCount: 1 };
      return { rows: [], rowCount: 0 };
    },
  } as unknown as Tx;

  assert.equal(
    await new OrderService(dependencies(tx)).processNoShow(
      tx,
      row,
      new Date('2026-10-05T16:00:00Z'),
    ),
    true,
  );
  assert.ok(statements.some((sql) => sql.includes("status='no_show'")));
  assert.ok(statements.some((sql) => sql.includes("'no_show'")));
});

function checkoutHarness(options: { unavailable?: boolean; allergenConflict?: boolean } = {}) {
  const statements: string[] = [];
  const valuesSeen: unknown[][] = [];
  const createdOrder = order({ status: 'pending_payment' });
  const offer = {
    id: createdOrder.offer_id,
    seller_id: createdOrder.seller_id,
    category: 'makanan_berat',
    allergens: options.allergenConflict ? ['kacang'] : [],
    status: options.unavailable ? 'closed' : 'active',
    quota_total: 5,
    quota_available: 5,
    quota_held: 0,
    quota_sold: 0,
    normal_price: 100000,
    discount_price: 40000,
    pickup_start: createdOrder.pickup_start,
    pickup_end: createdOrder.pickup_end,
    safe_eat_until: createdOrder.safe_eat_until,
    fitness_confirmed: true,
    created_at: createdAt,
  };
  const tx = {
    query: async (sql: string, values: unknown[] = []) => {
      statements.push(sql);
      valuesSeen.push(values);
      if (sql.startsWith('INSERT INTO idempotency_keys')) return { rows: [], rowCount: 1 };
      if (sql.startsWith('SELECT * FROM idempotency_keys')) return { rows: [{ payload_hash: valuesSeen.find((v, i) => statements[i]?.startsWith('INSERT INTO idempotency_keys'))?.[3], response: null }], rowCount: 1 };
      if (sql.startsWith('SELECT * FROM offers')) return { rows: [offer], rowCount: 1 };
      if (sql.startsWith('SELECT allergen_filters FROM users')) return { rows: [{ allergen_filters: options.allergenConflict ? ['kacang'] : [] }], rowCount: 1 };
      if (sql.startsWith('SELECT * FROM merchant_profiles')) return { rows: [{ shop_name: 'Gerai Contoh', address: 'Jl. Contoh 1', latitude: -6.9, longitude: 107.6, photo_id: null }], rowCount: 1 };
      if (sql.startsWith('INSERT INTO orders')) return { rows: [createdOrder], rowCount: 1 };
      if (sql.startsWith('INSERT INTO payment_intents')) return { rows: [{ id: 'intent-1', order_id: createdOrder.id, amount: createdOrder.price, currency: 'IDR', status: 'pending', created_at: createdAt }], rowCount: 1 };
      return { rows: [], rowCount: 1 };
    },
  } as unknown as Tx;
  const deps = {
    db: { transaction: async (fn: (value: Tx) => Promise<unknown>) => fn(tx) },
    config: { FEE_BPS: 500 },
    clock: { now: () => createdAt },
  } as unknown as Dependencies;
  return { service: new OrderService(deps), statements, valuesSeen };
}

test('C04-UT11 OrderService.checkout creates order, reserves quota and authorizes payment', async () => {
  const h = checkoutHarness();
  const result = await h.service.checkout(context('buyer', 'buyer-1'), { offer_id: order().offer_id }, 'checkout-key');

  assert.equal(result.order_id, orderId);
  assert.equal(result.intent_id, 'intent-1');
  assert.equal(result.status, 'pending_payment');
  assert.ok(h.statements.some((sql) => sql.startsWith('INSERT INTO orders')));
  assert.ok(h.statements.some((sql) => sql.includes("INSERT INTO checkout_reservations(order_id,status,expires_at) VALUES($1,'held',$2)")));
  assert.ok(h.statements.some((sql) => sql.startsWith('INSERT INTO payment_intents')));
  assert.ok(h.statements.some((sql) => sql.startsWith('INSERT INTO jobs')));
  assert.ok(h.valuesSeen.some((values) => values.includes('order.created')));
});

test('C04-UT12 OrderService.checkout rejects wrong role, unavailable offers, and allergen conflicts', async () => {
  await assert.rejects(checkoutHarness().service.checkout(context('seller', 'seller-1'), { offer_id: order().offer_id }, 'key'), { code: 'FORBIDDEN' });
  await assert.rejects(checkoutHarness({ unavailable: true }).service.checkout(context('buyer', 'buyer-1'), { offer_id: order().offer_id }, 'key'), { code: 'OFFER_UNAVAILABLE' });
  await assert.rejects(checkoutHarness({ allergenConflict: true }).service.checkout(context('buyer', 'buyer-1'), { offer_id: order().offer_id }, 'key'), { code: 'ALLERGEN_CONFLICT' });
});

function cancelHarness(row: OrderRecord) {
  const statements: string[] = [];
  const parameters: unknown[][] = [];
  const tx = {
    query: async (sql: string, values: unknown[] = []) => {
      statements.push(sql);
      parameters.push(values);
      if (sql.startsWith('INSERT INTO idempotency_keys')) return { rows: [], rowCount: 1 };
      if (sql.startsWith('SELECT * FROM idempotency_keys')) return { rows: [{ payload_hash: parameters.find((v, i) => statements[i]?.startsWith('INSERT INTO idempotency_keys'))?.[3], response: null }], rowCount: 1 };
      if (sql.startsWith('SELECT offer_id FROM orders')) return { rows: [{ offer_id: row.offer_id }], rowCount: 1 };
      if (sql.startsWith('SELECT * FROM offers')) return { rows: [{}], rowCount: 1 };
      if (sql.startsWith('SELECT * FROM orders')) return { rows: [row], rowCount: 1 };
      if (sql.startsWith('SELECT id,amount,reason FROM refunds')) return { rows: [], rowCount: 0 };
      if (sql.startsWith('INSERT INTO refunds')) return { rows: [{ id: 'refund-1', amount: row.price, reason: values[2] }], rowCount: 1 };
      if (sql.startsWith('UPDATE checkout_reservations')) return { rows: [{ order_id: row.id }], rowCount: 1 };
      if (sql.startsWith('UPDATE payout_entitlements')) return { rows: [], rowCount: 0 };
      if (sql.startsWith('INSERT INTO notifications')) return { rows: [{ id: 'notification-1' }], rowCount: 1 };
      return { rows: [], rowCount: 1 };
    },
  } as unknown as Tx;
  const deps = {
    db: { transaction: async (fn: (value: Tx) => Promise<unknown>) => fn(tx) },
    config: {},
    clock: { now: () => createdAt },
  } as unknown as Dependencies;
  return { service: new OrderService(deps), statements, parameters };
}

test('C04-UT13 OrderService.cancelBySeller refunds eligible paid order', async () => {
  const h = cancelHarness(order({ status: 'paid' }));
  const result = await h.service.cancelBySeller(context('seller', 'seller-1'), orderId, 'cancel-key', 'Stok rusak.');

  assert.equal(result.status, 'refunded');
  assert.equal(result.refund.id, 'refund-1');
  assert.ok(h.statements.some((sql) => sql.startsWith('INSERT INTO refunds')));
  assert.ok(h.statements.some((sql) => sql.includes("UPDATE orders SET status='refunded'")));
  assert.ok(h.statements.some((sql) => sql.includes("UPDATE complaints SET status='approved'")));
});

test('C04-UT14 OrderService.cancelBySeller rejects wrong role, non-owner, and invalid state', async () => {
  await assert.rejects(cancelHarness(order()).service.cancelBySeller(context('buyer', 'buyer-1'), orderId, 'key'), { code: 'FORBIDDEN' });
  await assert.rejects(cancelHarness(order()).service.cancelBySeller(context('seller', 'other-seller'), orderId, 'key'), { code: 'ORDER_NOT_FOUND' });
  await assert.rejects(cancelHarness(order({ status: 'completed' })).service.cancelBySeller(context('seller', 'seller-1'), orderId, 'key'), { code: 'CANCEL_STATE_CONFLICT' });
});
