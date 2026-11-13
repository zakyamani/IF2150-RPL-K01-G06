import { z } from 'zod';
export const reviewSchema = z
  .object({
    order_id: z.uuid(),
    rating: z.number().int().min(1).max(5),
    comment: z.string().trim().max(1000).default(''),
  })
  .strict();
export type ReviewInput = z.infer<typeof reviewSchema>;
