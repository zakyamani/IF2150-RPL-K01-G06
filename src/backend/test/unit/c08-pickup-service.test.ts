import { test } from 'node:test';
import assert from 'node:assert/strict';
import type { Dependencies, ServiceContext, Tx } from '../../src/core/contracts.js';
import { encrypt, hash, secretToken } from '../../src/core/crypto.js';
import { PickupService } from '../../src/modules/pickup/service.js';
import type { OrderRecord } from '../../src/modules/orders/repository.js';

const now = new Date('2026-10-05T14:00:00Z');
const orderId = '550e8400-e29b-41d4-a716-446655440000';
const key = '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';
function order(): OrderRecord {
  return {
    id: orderId, code: 'SR-0123456789', invoice: 'INV-test', offer_id: '650e8400-e29b-41d4-a716-446655440000',
    buyer_id: 'buyer-1', seller_id: 'seller-1', status: 'paid', price: 40000, fee: 2000, fee_bps: 500,
    snapshot: { category: 'makanan_berat', allergens: [], normal_price: 100000, discount_price: 40000,
      merchant: { id: 'seller-1', name: 'Toko', address: 'Jl. Contoh', latitude: -6, longitude: 107, photo_id: null } },
    payment_deadline: new Date('2026-10-05T12:15:00Z'), pickup_start: new Date('2026-10-05T13:00:00Z'),
    pickup_end: new Date('2026-10-05T15:00:00Z'), safe_eat_until: new Date('2026-10-05T15:30:00Z'),
    paid_at: now, completed_at: null, created_at: now, updated_at: now,
  };
}
const seller: ServiceContext = { actor: { id: 'seller-1', role: 'seller', sessionId: 's1' }, clock: { now: () => now } };

function harness(options: { credential?: Record<string, unknown> | null; order?: OrderRecord } = {}) {
  const row = options.order ?? order();
  const statements: string[] = [];
  const token = secretToken();
  const credential = options.credential === undefined ? {
    order_id: orderId, token_hash: hash(token), encrypted_data: encrypt({ token, otp: '123456' }, key),
    used_at: null, disabled_at: null, attempts: 0, attempt_window: null,
  } : options.credential;
  const tx = {
    query: async (sql: string) => {
      statements.push(sql);
      if (sql.startsWith('SELECT id FROM orders')) return { rows: [{ id: orderId }], rowCount: 1 };
      if (sql.startsWith('SELECT offer_id FROM orders')) return { rows: [{ offer_id: row.offer_id }], rowCount: 1 };
      if (sql.startsWith('SELECT * FROM offers')) return { rows: [{}], rowCount: 1 };
      if (sql.startsWith('SELECT * FROM orders')) return { rows: [row], rowCount: 1 };
      if (sql.startsWith('SELECT * FROM pickup_credentials')) return { rows: credential ? [credential] : [], rowCount: credential ? 1 : 0 };
      if (sql.startsWith('SELECT encrypted_data FROM pickup_credentials')) return { rows: credential ? [{ encrypted_data: credential.encrypted_data }] : [], rowCount: credential ? 1 : 0 };
      if (sql.startsWith('INSERT INTO payout_entitlements')) return { rows: [{ id: 'payout-1' }], rowCount: 1 };
      if (sql.startsWith('INSERT INTO notifications')) return { rows: [{ id: 'notification-1' }], rowCount: 1 };
      return { rows: [], rowCount: 0 };
    },
  } as unknown as Tx;
  const deps = {
    db: { transaction: async (fn: (tx: Tx) => Promise<unknown>) => fn(tx) },
    config: { PICKUP_KEY: key }, clock: { now: () => now },
  } as unknown as Dependencies;
  return { service: new PickupService(deps), tx, statements, token };
}

test('C08-UT05 PickupService.issue stores hashed/encrypted one-time credential', async () => {
  const h = harness();
  const result = await h.service.issue(h.tx, orderId);
  assert.match(result.qr, new RegExp(`^sisarasa:v1:${orderId}:`));
  assert.match(result.otp, /^\d{6}$/);
  assert.ok(h.statements.some((sql) => sql.startsWith('INSERT INTO pickup_credentials')));
});

test('C08-UT06 PickupService.credential returns active credential or undefined', async () => {
  const h = harness();
  const result = await h.service.credential(h.tx, orderId);
  assert.equal(result?.qr, `sisarasa:v1:${orderId}:${h.token}`);
  assert.equal(result?.otp, '123456');
  const empty = harness({ credential: null });
  assert.equal(await empty.service.credential(empty.tx, orderId), undefined);
});

test('C08-UT07 PickupService.validate completes an order with valid QR and schedules payout', async () => {
  const h = harness();
  const result = await h.service.validate(seller, { order_id: orderId, kind: 'qr', value: `sisarasa:v1:${orderId}:${h.token}` });
  assert.equal(result.status, 'completed');
  assert.ok(h.statements.some((sql) => sql.includes("status='completed'")));
  assert.ok(h.statements.some((sql) => sql.startsWith('INSERT INTO payout_entitlements')));
});

test('C08-UT08 PickupService.validate rejects wrong seller, invalid QR, unavailable order and used credential', async () => {
  const h = harness();
  await assert.rejects(h.service.validate({ ...seller, actor: { ...seller.actor, id: 'other' } }, { order_id: orderId, kind: 'qr', value: `sisarasa:v1:${orderId}:${h.token}` }), { code: 'ORDER_NOT_FOUND' });
  await assert.rejects(h.service.validate(seller, { order_id: orderId, kind: 'qr', value: 'bad' }), { code: 'INVALID_QR' });
  await assert.rejects(harness({ order: orderWith({ status: 'completed' }) }).service.validate(seller, { order_id: orderId, kind: 'otp', value: '123456' }), { code: 'PICKUP_STATE_CONFLICT' });
  await assert.rejects(harness({ credential: { order_id: orderId, token_hash: 'x', encrypted_data: '', used_at: now, disabled_at: null, attempts: 0, attempt_window: null } }).service.validate(seller, { order_id: orderId, kind: 'otp', value: '123456' }), { code: 'PICKUP_DISABLED' });
});

function orderWith(overrides: Partial<OrderRecord>): OrderRecord { return { ...order(), ...overrides }; }
