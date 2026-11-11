import { z } from 'zod';
export const pickupSchema = z
  .object({
    order_id: z.union([z.uuid(), z.string().regex(/^SR-[0-9A-HJKMNP-TV-Z]{10}$/)]),
    kind: z.enum(['qr', 'otp']),
    value: z.string().min(1).max(200),
  })
  .strict()
  .superRefine((i, ctx) => {
    if (i.kind === 'otp' && !/^\d{6}$/.test(i.value))
      ctx.addIssue({ code: 'custom', path: ['value'], message: 'OTP harus enam angka.' });
  });
export type PickupInput = z.infer<typeof pickupSchema>;
