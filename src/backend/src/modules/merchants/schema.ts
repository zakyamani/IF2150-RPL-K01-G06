import { z } from 'zod';
export const profileSchema = z
  .object({
    shop_name: z.string().trim().min(2).max(100),
    address: z.string().trim().min(5).max(500),
    latitude: z.number().finite().min(-90).max(90),
    longitude: z.number().finite().min(-180).max(180),
    bank_destination: z
      .string()
      .regex(/^\d{6,30}$/)
      .optional(),
  })
  .strict();
export type ProfileInput = z.infer<typeof profileSchema>;
