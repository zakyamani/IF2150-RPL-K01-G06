import type { Tx } from './contracts.js';
import { hash } from './crypto.js';
import { requireState } from './errors.js';
export function canonical(value: unknown): string {
  if (Array.isArray(value)) return '[' + value.map(canonical).join(',') + ']';
  if (value !== null && typeof value === 'object')
    return (
      '{' +
      Object.entries(value)
        .sort(([a], [b]) => a.localeCompare(b))
        .map(([k, v]) => JSON.stringify(k) + ':' + canonical(v))
        .join(',') +
      '}'
    );
  return JSON.stringify(value);
}
export async function idempotent<T>(
  tx: Tx,
  actor: string,
  operation: string,
  key: string,
  input: unknown,
  fn: () => Promise<T>,
): Promise<T> {
  const payloadHash = hash(canonical(input));
  await tx.query(
    'INSERT INTO idempotency_keys(actor_id,operation,key,payload_hash) VALUES($1,$2,$3,$4) ON CONFLICT DO NOTHING',
    [actor, operation, key, payloadHash],
  );
  const row = (
    await tx.query(
      'SELECT * FROM idempotency_keys WHERE actor_id=$1 AND operation=$2 AND key=$3 FOR UPDATE',
      [actor, operation, key],
    )
  ).rows[0];
  requireState(
    row.payload_hash === payloadHash,
    'IDEMPOTENCY_CONFLICT',
    'Kunci permintaan sudah digunakan untuk transaksi berbeda.',
  );
  if (row.response !== null) return row.response as T;
  const result = await fn();
  await tx.query(
    'UPDATE idempotency_keys SET response=$4 WHERE actor_id=$1 AND operation=$2 AND key=$3',
    [actor, operation, key, result],
  );
  return result;
}
