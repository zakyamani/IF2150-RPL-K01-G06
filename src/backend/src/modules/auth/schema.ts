import { z } from 'zod';
import { allergens } from '../../core/labels.js';
const email = z.string().trim().toLowerCase().email().max(254);
const password = z
  .string()
  .min(12)
  .max(72)
  .refine((s) => Buffer.byteLength(s, 'utf8') <= 72, 'Password maksimal 72 byte.');
export const registerSchema = z
  .object({
    email,
    password,
    name: z.string().trim().min(2).max(100),
    role: z.enum(['buyer', 'seller']),
  })
  .strict();
export const loginSchema = z.object({ email, password: z.string().min(1).max(72) }).strict();
export const refreshSchema = z.object({ refresh_token: z.string().min(40).max(100) }).strict();
export const allergenSchema = z
  .object({
    allergen_filters: z
      .array(z.enum(allergens))
      .max(8)
      .refine((a) => new Set(a).size === a.length),
  })
  .strict();
export type RegisterInput = z.infer<typeof registerSchema>;
export type LoginInput = z.infer<typeof loginSchema>;
