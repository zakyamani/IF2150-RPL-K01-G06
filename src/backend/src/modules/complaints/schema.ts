import { z } from 'zod';
import { pageSchema } from '../../core/pagination.js';
export const complaintSchema = z
  .object({
    order_id: z.uuid(),
    reason: z.enum(['unfit', 'unavailable', 'allergen', 'store_closed']),
    description: z.string().trim().min(10).max(2000),
    media_ids: z
      .array(z.uuid())
      .max(2)
      .refine((ids) => new Set(ids).size === ids.length)
      .default([]),
  })
  .strict();
export const decisionSchema = z
  .object({ approved: z.boolean(), response: z.string().trim().min(5).max(2000) })
  .strict();
export const complaintQuerySchema = pageSchema
  .extend({ status: z.enum(['open', 'approved', 'rejected', 'auto_refunded']).optional() })
  .strict();
export type ComplaintInput = z.infer<typeof complaintSchema>;
export type DecisionInput = z.infer<typeof decisionSchema>;
