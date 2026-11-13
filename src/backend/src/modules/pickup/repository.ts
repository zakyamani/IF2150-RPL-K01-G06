import type { Tx } from '../../core/contracts.js';
export type CredentialRecord = {
  order_id: string;
  token_hash: string;
  encrypted_data: string;
  used_at: Date | null;
  disabled_at: Date | null;
  attempts: number;
  attempt_window: Date | null;
};
export class PickupRepository {
  async lock(tx: Tx, id: string) {
    return (
      await tx.query<CredentialRecord>(
        'SELECT * FROM pickup_credentials WHERE order_id=$1 FOR UPDATE',
        [id],
      )
    ).rows[0];
  }
  async wrongAttempt(tx: Tx, id: string, attempts: number, start: Date) {
    await tx.query(
      'UPDATE pickup_credentials SET attempts=$2,attempt_window=$3 WHERE order_id=$1',
      [id, attempts, start],
    );
  }
}
