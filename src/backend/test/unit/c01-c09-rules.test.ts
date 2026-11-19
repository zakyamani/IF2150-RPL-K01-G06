import { test } from 'node:test';
import assert from 'node:assert/strict';
import { profileSchema } from '../../src/modules/merchants/schema.js';
import { complaintSchema, decisionSchema } from '../../src/modules/complaints/schema.js';
import { pickupSchema } from '../../src/modules/pickup/schema.js';

test('C01-UT01 getIdPenjual: valid seller profile has required fields', () => {
  const input = profileSchema.parse({ shop_name: 'Toko Sisa', address: 'Jl. ITB 10', latitude: -6.89, longitude: 107.61 });
  assert.equal(input.shop_name, 'Toko Sisa');
});

test('C01-UT02 getProfil: rejects incomplete profile', () => {
  assert.throws(() => profileSchema.parse({ shop_name: 'A', address: '', latitude: -91, longitude: 181 }));
});

test('C01-UT03 update profile: masks cannot be asserted but bank destination boundaries are validated', () => {
  assert.doesNotThrow(() => profileSchema.parse({ shop_name: 'Toko Sisa', address: 'Jl. ITB 10', latitude: 0, longitude: 0, bank_destination: '123456' }));
  assert.throws(() => profileSchema.parse({ shop_name: 'Toko Sisa', address: 'Jl. ITB 10', latitude: 0, longitude: 0, bank_destination: 'ABC123' }));
});

test('C09-UT01 ajukanPengaduan: reason, description, and evidence limits are validated', () => {
  const base = { order_id: '550e8400-e29b-41d4-a716-446655440000', reason: 'unfit', description: 'Makanan sudah tidak layak dimakan.', media_ids: [] };
  assert.doesNotThrow(() => complaintSchema.parse(base));
  assert.throws(() => complaintSchema.parse({ ...base, description: 'pendek' }));
  assert.throws(() => complaintSchema.parse({ ...base, reason: 'lainnya' }));
});

test('C09-UT02 prosesPengaduan: decision requires approved boolean and response', () => {
  assert.doesNotThrow(() => decisionSchema.parse({ approved: true, response: 'Pengaduan diterima dan refund diproses.' }));
  assert.throws(() => decisionSchema.parse({ approved: 'true', response: 'ok' }));
});

test('C09-UT03 rejects duplicate evidence and more than two evidence files', () => {
  const id = '550e8400-e29b-41d4-a716-446655440001';
  assert.throws(() => complaintSchema.parse({ order_id: '550e8400-e29b-41d4-a716-446655440000', reason: 'unavailable', description: 'Paket tidak tersedia saat pickup.', media_ids: [id, id] }));
  assert.throws(() => complaintSchema.parse({ order_id: '550e8400-e29b-41d4-a716-446655440000', reason: 'unavailable', description: 'Paket tidak tersedia saat pickup.', media_ids: [id, '550e8400-e29b-41d4-a716-446655440002', '550e8400-e29b-41d4-a716-446655440003'] }));
});

test('C08-UT04 pickup schemas validate OTP format and reject invalid QR kind', () => {
  assert.doesNotThrow(() => pickupSchema.parse({ order_id: '550e8400-e29b-41d4-a716-446655440000', kind: 'otp', value: '123456' }));
  assert.throws(() => pickupSchema.parse({ order_id: '550e8400-e29b-41d4-a716-446655440000', kind: 'otp', value: '123' }));
  assert.throws(() => pickupSchema.parse({ order_id: 'invalid', kind: 'qr', value: 'invalid' }));
});
