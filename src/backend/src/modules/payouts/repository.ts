import type { Database } from '../../core/db.js';
export type PayoutRecord = {
  id: string;
  order_id: string;
  seller_id: string;
  gross: number;
  fee: number;
  net: number;
  status: 'pending' | 'held' | 'settled' | 'cancelled';
  due_at: Date;
  reason: string;
  settled_at: Date | null;
  created_at: Date;
  order_code: string;
};
export class PayoutRepository {
  constructor(private db: Database) {}
  async summary(id: string) {
    return (
      await this.db.query<{ status: PayoutRecord['status']; amount: string }>(
        'SELECT status,sum(net)::text AS amount FROM payout_entitlements WHERE seller_id=$1 GROUP BY status',
        [id],
      )
    ).rows;
  }
  async list(id: string, q: { at?: string; cursorId?: string; status?: string; limit: number }) {
    return (
      await this.db.query<PayoutRecord>(
        'SELECT p.*,o.code AS order_code FROM payout_entitlements p JOIN orders o ON o.id=p.order_id WHERE p.seller_id=$1 AND ($2::timestamptz IS NULL OR (p.created_at,p.id)<($2,$3::uuid)) AND ($4::text IS NULL OR p.status=$4) ORDER BY p.created_at DESC,p.id DESC LIMIT $5',
        [id, q.at, q.cursorId, q.status, q.limit],
      )
    ).rows;
  }
}
