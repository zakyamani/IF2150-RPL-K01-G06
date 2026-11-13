import { z } from 'zod';
import { ApiError } from './errors.js';
const cursorSchema = z.object({ at: z.iso.datetime({ offset: true }), id: z.uuid() }).strict();
export function decodeCursor(value?: string) {
  if (!value) return null;
  try {
    if (value.length > 512) throw new Error();
    return cursorSchema.parse(JSON.parse(Buffer.from(value, 'base64url').toString('utf8')));
  } catch {
    throw new ApiError(400, 'INVALID_CURSOR', 'Halaman tidak valid. Muat ulang daftar.');
  }
}
export const encodeCursor = (row: { created_at: Date; id: string }) =>
  Buffer.from(JSON.stringify({ at: row.created_at.toISOString(), id: row.id })).toString(
    'base64url',
  );
export const pageSchema = z.object({
  cursor: z.string().max(512).optional(),
  limit: z.coerce.number().int().min(1).max(50).default(20),
});
