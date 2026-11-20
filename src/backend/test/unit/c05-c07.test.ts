import { test } from 'node:test';
import assert from 'node:assert/strict';
import { hmac } from '../../src/core/crypto.js';
import {
  DemoPaymentGateway,
  demoSchema,
  eventSchema,
} from '../../src/modules/payments/demo-gateway.js';

const invoice = {
  id: '550e8400-e29b-41d4-a716-446655440000',
  order_id: '650e8400-e29b-41d4-a716-446655440000',
  amount: 40000,
  currency: 'IDR',
} as const;
const secret = 'unit-test-gateway-signature-only';

test('C05-UT01 the simulation signs events with matching invoice values', () => {
  const { raw, signature } = new DemoPaymentGateway(secret).signedEvent(invoice, 'succeeded');
  const event = eventSchema.parse(JSON.parse(raw.toString('utf8')));
  assert.equal(signature, hmac(raw, secret));
  assert.equal(event.intent_id, invoice.id);
  assert.equal(event.order_id, invoice.order_id);
  assert.equal(event.amount, invoice.amount);
  assert.equal(event.currency, invoice.currency);
  assert.equal(event.outcome, 'succeeded');
});

test('C05-UT02 the simulation rejects an unsupported outcome and invalid amount', () => {
  assert.equal(demoSchema.safeParse({ outcome: 'unknown' }).success, false);
  const { raw } = new DemoPaymentGateway(secret).signedEvent(invoice, 'failed');
  const event = JSON.parse(raw.toString('utf8'));
  assert.equal(eventSchema.safeParse({ ...event, amount: 0 }).success, false);
});
