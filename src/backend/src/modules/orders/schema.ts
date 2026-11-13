import { z } from 'zod';
import { pageSchema } from '../../core/pagination.js';
export const checkoutSchema = z.object({ offer_id: z.uuid() }).strict();
export const cancelSchema = z
  .object({ reason: z.string().trim().min(5).max(500).default('Dibatalkan penjual.') })
  .strict();
export const keySchema = z
  .string()
  .min(1)
  .max(128)
  .regex(/^[A-Za-z0-9:_-]+$/);
export const orderStates = [
  'pending_payment',
  'paid',
  'cancelled',
  'completed',
  'dispute',
  'refunded',
  'no_show',
] as const;
export const orderQuerySchema = pageSchema
  .extend({ status: z.enum(orderStates).optional() })
  .strict();
