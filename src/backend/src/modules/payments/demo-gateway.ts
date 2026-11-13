import { randomUUID } from 'node:crypto';
import { z } from 'zod';
import { hmac } from '../../core/crypto.js';
import { PaymentRepository } from './repository.js';
import type { Tx } from '../../core/contracts.js';
import type { OrderRecord } from '../orders/repository.js';
export const eventSchema = z
  .object({
    id: z.uuid(),
    intent_id: z.uuid(),
    order_id: z.uuid(),
    amount: z.number().int().positive().max(2000000000),
    currency: z.literal('IDR'),
    outcome: z.enum(['succeeded', 'failed']),
  })
  .strict();
export const demoSchema = z.object({ outcome: z.enum(['succeeded', 'failed']) }).strict();
export class DemoPaymentGateway {
  constructor(private secret: string) {}
  authorize(tx: Tx, order: OrderRecord) {
    return new PaymentRepository().authorize(tx, order);
  }
  signedEvent(
    intent: { id: string; order_id: string; amount: number; currency: 'IDR' },
    outcome: 'succeeded' | 'failed',
  ) {
    const raw = Buffer.from(
      JSON.stringify({
        id: randomUUID(),
        intent_id: intent.id,
        order_id: intent.order_id,
        amount: intent.amount,
        currency: intent.currency,
        outcome,
      }),
    );
    return { raw, signature: hmac(raw, this.secret) };
  }
}
