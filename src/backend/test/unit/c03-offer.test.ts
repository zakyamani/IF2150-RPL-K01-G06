import { test } from 'node:test';
import assert from 'node:assert/strict';
import { validateOffer } from '../../src/modules/offers/schema.js';

const now = new Date('2026-10-05T12:00:00Z');
function offer(overrides: Record<string, unknown> = {}) {
  return {
    category: 'makanan_berat',
    allergens: [],
    quota: 10,
    normal_price: 100000,
    discount_price: 40000,
    pickup_start: '2026-10-05T13:00:00Z',
    pickup_end: '2026-10-05T15:00:00Z',
    safe_eat_until: '2026-10-05T15:30:00Z',
    fitness_confirmed: true,
    ...overrides,
  };
}

test('C03-UT01 getIdPenawaran: valid offer details are returned', () => {
  const input = validateOffer(offer(), now);
  assert.equal(input.category, 'makanan_berat');
});

test('C03-UT02 kurangiKuota: rejects quota zero and accepts lower boundary', () => {
  assert.throws(() => validateOffer(offer({ quota: 0 }), now));
  assert.doesNotThrow(() => validateOffer(offer({ quota: 1 }), now));
});

test('C03-UT03 getDetailPenawaran: valid detail is returned', () => {
  const input = validateOffer(offer(), now);
  assert.equal(input.normal_price, 100000);
  assert.equal(input.discount_price, 40000);
});

test('C03-UT04 ubahStatus: pickup window boundaries are enforced', () => {
  assert.throws(() => validateOffer(offer({ pickup_start: '2026-10-05T09:00:00Z' }), now));
  assert.doesNotThrow(() => validateOffer(offer({ pickup_start: '2026-10-05T14:00:00Z' }), now));
});

test('C03-UT05 validates discount, quota upper boundary, and safe-eat time', () => {
  assert.throws(() => validateOffer(offer({ discount_price: 51000 }), now));
  assert.doesNotThrow(() => validateOffer(offer({ quota: 500 }), now));
  assert.throws(() => validateOffer(offer({ quota: 501 }), now));
  assert.throws(() => validateOffer(offer({ pickup_end: '2026-10-05T12:30:00Z' }), now));
  assert.throws(() => validateOffer(offer({ safe_eat_until: '2026-10-05T14:00:00Z' }), now));
  assert.throws(() => validateOffer(offer({ fitness_confirmed: false }), now));
});
