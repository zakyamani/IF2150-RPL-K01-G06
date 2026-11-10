import {z} from 'zod';
import {allergens, categories} from '../../core/labels.js';
import {ApiError} from '../../core/errors.js';
export const offerSchema = z
  .object({
    category: z.enum(categories),
    allergens: z
      .array(z.enum(allergens))
      .max(8)
      .refine((a) => new Set(a).size === a.length),
    quota: z.number().int().min(1).max(500),
    normal_price: z.number().int().min(1).max(2000000000),
    discount_price: z.number().int().min(1).max(2000000000),
    pickup_start: z.iso.datetime({ offset: true }),
    pickup_end: z.iso.datetime({ offset: true }),
    safe_eat_until: z.iso.datetime({ offset: true }),
    fitness_confirmed: z.literal(true),
  })
  .strict();
export type OfferInput = z.infer<typeof offerSchema>;
export function validateOffer(value: unknown, now: Date): OfferInput {
  const input = offerSchema.parse(value);
  const fields: Record<string, string[]> = {};
  if (
    input.discount_price * 100 < input.normal_price * 30 ||
    input.discount_price * 100 > input.normal_price * 50
  )
    fields.discount_price = ['Diskon wajib 50–70% dari harga normal.'];
  const start = Date.parse(input.pickup_start),
    end = Date.parse(input.pickup_end),
    safe = Date.parse(input.safe_eat_until);
  if (start < now.getTime() || start > now.getTime() + 7200000)
    fields.pickup_start = ['Mulai pickup antara sekarang dan dua jam ke depan.'];
  if (end <= start) fields.pickup_end = ['Selesai pickup harus setelah waktu mulai.'];
  if (safe < end) fields.safe_eat_until = ['Batas konsumsi tidak boleh sebelum pickup selesai.'];
  if (Object.keys(fields).length)
    throw new ApiError(400, 'INVALID_OFFER', 'Periksa harga dan jadwal paket.', fields);
  return input;
}