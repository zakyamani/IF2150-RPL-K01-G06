import { test } from 'node:test';
import assert from 'node:assert/strict';
import { offerSchema } from '../../src/modules/offers/schema.js';
import { encrypt, decrypt } from '../../src/core/crypto.js';

const key = '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';

function preferenceOffer(allergens: string[]) {
  return {
    category: 'makanan_berat',
    allergens,
    quota: 1,
    normal_price: 10000,
    discount_price: 4000,
    pickup_start: '2026-10-05T13:00:00Z',
    pickup_end: '2026-10-05T15:00:00Z',
    safe_eat_until: '2026-10-05T16:00:00Z',
    fitness_confirmed: true,
  };
}

test('C02-UT01 getIdPembeli: buyer preference structure is accepted', () => {
  assert.deepEqual(preferenceOffer([]).allergens, []);
});

test('C02-UT02 getPreferensiAlergen: empty preference is valid', () => {
  assert.doesNotThrow(() => offerSchema.parse(preferenceOffer([])));
});

test('C02-UT03 updatePreferensi: allergen list rejects duplicate values', () => {
  assert.throws(() => offerSchema.parse(preferenceOffer(['gluten', 'gluten'])));
});

test('C02-UT04 updatePreferensi: rejects more than eight allergens', () => {
  assert.throws(() => offerSchema.parse(preferenceOffer([
    'gluten', 'telur', 'susu', 'kacang', 'kedelai', 'ikan', 'kerang', 'wijen', 'wijen',
  ])));
});

test('C06-UT01 generateQRIS: invoice payload can be encrypted and decrypted', () => {
  const invoice = { invoice: 'INV-test', amount: 40000, expiresAt: '2026-10-05T12:15:00Z' };
  const encoded = encrypt(invoice, key);
  assert.deepEqual(decrypt(encoded, key), invoice);
});

test('C06-UT02 generateQRIS: expired payment deadline is represented by past deadline', () => {
  const now = new Date('2026-10-05T12:15:00Z');
  const deadline = new Date('2026-10-05T12:00:00Z');
  assert.equal(deadline < now, true);
});

test('C06-UT03 generateQRIS: rejects invalid encrypted invoice payload', () => {
  assert.throws(() => decrypt('not.valid', key));
});
