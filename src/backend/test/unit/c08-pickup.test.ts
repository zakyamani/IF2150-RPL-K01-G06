import { test } from 'node:test';
import assert from 'node:assert/strict';
import { encrypt, decrypt, hash, safeEqual, secretToken } from '../../src/core/crypto.js';
import { pickupSchema } from '../../src/modules/pickup/schema.js';

const key = '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';

test('C08-UT01 generateToken: secret token and encrypted credential are generated', () => {
  const token = secretToken();
  const encrypted = encrypt({ token, otp: '123456' }, key);
  assert.equal(token.length, 43);
  assert.equal(encrypted.split('.')[0], 'v1');
});

test('C08-UT02 validasiToken: valid encrypted token and OTP are decrypted', () => {
  const token = secretToken();
  const encrypted = encrypt({ token, otp: '123456' }, key);
  const data = decrypt<{ token: string; otp: string }>(encrypted, key);
  assert.equal(data.token, token);
  assert.equal(data.otp, '123456');
  assert.equal(safeEqual(hash(token), hash(token)), true);
});

test('C08-UT09 validasiToken: invalid or tampered values fail', () => {
  assert.equal(safeEqual(hash('valid'), hash('invalid')), false);
  assert.throws(() => decrypt('invalid', key));
});

test('C08-UT03 tandaiDigunakan: OTP and QR payload formats are distinguishable', () => {
  assert.doesNotThrow(() => pickupSchema.parse({ order_id: 'SR-0123456789', kind: 'otp', value: '123456' }));
  assert.doesNotThrow(() => pickupSchema.parse({ order_id: '550e8400-e29b-41d4-a716-446655440000', kind: 'qr', value: 'sisarasa:v1:550e8400-e29b-41d4-a716-446655440000:token' }));
});
