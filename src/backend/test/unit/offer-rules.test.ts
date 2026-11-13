import { test } from 'node:test';
import assert from 'node:assert/strict';
import { offerInput } from '../helpers/offers.js';
test('integer discount and UTC time boundaries', async () => {
  const { validateOffer } = await import('../../src/modules/offers/schema.js');
  const now = new Date('2026-10-05T12:00:00Z');
  for (const [price, allowed] of [
    [51000, false],
    [50000, true],
    [30000, true],
    [29000, false],
  ] as const) {
    if (allowed)
      assert.doesNotThrow(() => validateOffer(offerInput(now, { discount_price: price }), now));
    else assert.throws(() => validateOffer(offerInput(now, { discount_price: price }), now));
  }
  for (const [quota, allowed] of [
    [0, false],
    [1, true],
    [500, true],
    [501, false],
  ] as const) {
    if (allowed) assert.doesNotThrow(() => validateOffer(offerInput(now, { quota }), now));
    else assert.throws(() => validateOffer(offerInput(now, { quota }), now));
  }
  assert.doesNotThrow(() =>
    validateOffer(offerInput(now, { pickup_start: '2026-10-05T19:00:00+07:00' }), now),
  );
  assert.throws(() => validateOffer(offerInput(now, { pickup_end: now.toISOString() }), now));
  assert.throws(() => validateOffer(offerInput(now, { fitness_confirmed: false }), now));
});
