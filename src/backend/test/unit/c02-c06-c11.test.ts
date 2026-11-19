import { test } from 'node:test';
import assert from 'node:assert/strict';
import { complaintSchema } from '../../src/modules/complaints/schema.js';

test('C09 additional: complaint can be submitted without evidence files', () => {
  const complaint = complaintSchema.parse({
    order_id: '550e8400-e29b-41d4-a716-446655440000',
    reason: 'unfit',
    description: 'Deskripsi pengaduan yang cukup panjang.',
    media_ids: [],
  });
  assert.deepEqual(complaint.media_ids, []);
});
