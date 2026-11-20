import { test } from 'node:test';
import assert from 'node:assert/strict';
import type { Dependencies, ServiceContext, Tx } from '../../src/core/contracts.js';
import { OfferService } from '../../src/modules/offers/service.js';
import type { OfferRecord } from '../../src/modules/offers/repository.js';

const now = new Date('2026-10-05T12:00:00Z');
const offerId = '650e8400-e29b-41d4-a716-446655440000';

function input(overrides: Record<string, unknown> = {}) {
  return {
    category: 'makanan_berat', allergens: [], quota: 10, normal_price: 100000,
    discount_price: 40000, pickup_start: '2026-10-05T13:00:00Z',
    pickup_end: '2026-10-05T15:00:00Z', safe_eat_until: '2026-10-05T15:30:00Z',
    fitness_confirmed: true, ...overrides,
  };
}
function record(overrides: Partial<OfferRecord> = {}): OfferRecord {
  return {
    id: offerId, seller_id: 'seller-1', category: 'makanan_berat', allergens: [],
    status: 'active', quota_total: 10, quota_available: 10, quota_held: 0, quota_sold: 0,
    normal_price: 100000, discount_price: 40000,
    pickup_start: new Date('2026-10-05T13:00:00Z'), pickup_end: new Date('2026-10-05T15:00:00Z'),
    safe_eat_until: new Date('2026-10-05T15:30:00Z'), fitness_confirmed: true, created_at: now,
    ...overrides,
  };
}
const seller: ServiceContext = { actor: { id: 'seller-1', role: 'seller', sessionId: 's1' }, clock: { now: () => now } };

function harness(options: { offer?: OfferRecord; profile?: unknown; paid?: number; list?: OfferRecord[] } = {}) {
  let current = options.offer ?? record();
  const statements: string[] = [];
  const parameters: unknown[][] = [];
  const tx = {
    query: async (sql: string, values: unknown[] = []) => {
      statements.push(sql);
      parameters.push(values);
      if (sql.includes('merchant_profiles')) return { rows: [options.profile ?? { shop_name: 'Toko', address: 'Jl. Contoh', latitude: -6, longitude: 107 }], rowCount: 1 };
      if (sql.startsWith('SELECT * FROM offers')) return { rows: [current], rowCount: 1 };
      if (sql.includes('SELECT id FROM orders')) return { rows: [], rowCount: options.paid ?? 0 };
      if (sql.startsWith('INSERT INTO offers') || sql.startsWith('UPDATE offers')) return { rows: [current], rowCount: 1 };
      return { rows: [], rowCount: 1 };
    },
  } as unknown as Tx;
  const deps = {
    db: {
      transaction: async (fn: (tx: Tx) => Promise<unknown>) => fn(tx),
      query: async (sql: string, values: unknown[] = []) => {
        statements.push(sql);
        parameters.push(values);
        return { rows: options.list ?? [current], rowCount: (options.list ?? [current]).length };
      },
    },
    config: {}, clock: { now: () => now },
  } as unknown as Dependencies;
  return { service: new OfferService(deps), statements, parameters, setOffer: (value: OfferRecord) => { current = value; } };
}

test('C03-UT06 OfferService.create requires complete seller profile and creates/audits offer', async () => {
  const h = harness();
  const result = await h.service.create(seller, input());
  assert.equal(result.id, offerId);
  assert.ok(h.statements.some((sql) => sql.startsWith('INSERT INTO offers')));
  assert.ok(h.statements.some((sql) => sql.includes('INSERT INTO audit_logs')));
});

test('C03-UT07 OfferService.create rejects incomplete profile and wrong role', async () => {
  await assert.rejects(harness({ profile: { shop_name: null, address: null, latitude: null, longitude: null } }).service.create(seller, input()), { code: 'PROFILE_INCOMPLETE' });
  await assert.rejects(harness().service.create({ ...seller, actor: { ...seller.actor, role: 'buyer' } }, input()), { code: 'FORBIDDEN' });
});

test('C03-UT08 OfferService.update enforces mutable active offer then updates it', async () => {
  const h = harness();
  const result = await h.service.update(seller, offerId, input({ quota: 12 }));
  assert.equal(result.id, offerId);
  assert.ok(h.statements.some((sql) => sql.startsWith('UPDATE offers')));
  const auditIndex = h.statements.findIndex((sql) => sql.startsWith('INSERT INTO audit_logs'));
  assert.notEqual(auditIndex, -1);
  assert.equal(h.parameters[auditIndex]?.[2], 'offer.updated');
});

test('C03-UT09 OfferService.update rejects reserved, previously paid, closed, and missing offers', async () => {
  await assert.rejects(harness({ offer: record({ quota_held: 1 }) }).service.update(seller, offerId, input()), { code: 'OFFER_RESERVED' });
  await assert.rejects(harness({ paid: 1 }).service.update(seller, offerId, input()), { code: 'OFFER_PAID' });
  await assert.rejects(harness({ offer: record({ status: 'closed' }) }).service.update(seller, offerId, input()), { code: 'OFFER_CLOSED' });
  const missing = harness();
  missing.setOffer(undefined as unknown as OfferRecord);
  await assert.rejects(missing.service.update(seller, offerId, input()), { code: 'OFFER_NOT_FOUND' });
});

test('C03-UT10 OfferService.close closes active offers and leaves already-closed offers unchanged', async () => {
  const h = harness();
  assert.equal((await h.service.close(seller, offerId)).status, 'closed');
  assert.ok(h.statements.some((sql) => sql.includes("SET status='closed'")));
  const closed = harness({ offer: record({ status: 'closed' }) });
  assert.equal((await closed.service.close(seller, offerId)).status, 'closed');
  assert.equal(closed.statements.some((sql) => sql.includes("SET status='closed'")), false);
});

test('C03-UT11 OfferService.list paginates and detail enforces seller scope', async () => {
  const rows = [record(), record({ id: '650e8400-e29b-41d4-a716-446655440001' })];
  const h = harness({ list: rows });
  const page = await h.service.list(seller, { limit: 1 });
  assert.equal(page.items.length, 1);
  assert.ok(page.next_cursor);
  assert.equal((await h.service.detail(seller, offerId)).id, offerId);
  const missing = harness({ list: [] });
  await assert.rejects(missing.service.detail(seller, offerId), { code: 'OFFER_NOT_FOUND' });
});
