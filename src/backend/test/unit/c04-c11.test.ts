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

const context = (role: 'buyer' | 'seller', id: string): ServiceContext => ({
  actor: { id, role, sessionId: 'session-1' },
  clock: { now: () => createdAt },
});

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

  // decodeCursor returns the ISO timestamp string encoded in the cursor.
  assert.equal(parameters[1], previous.created_at.toISOString());
  assert.equal(parameters[2], previous.id);
  assert.equal(result.items.length, 2);
  assert.equal(result.next_cursor, encodeCursor({ created_at: rows[1]!.created_at, id: rows[1]!.id }));
});
