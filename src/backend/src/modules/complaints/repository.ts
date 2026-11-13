import type { Tx } from '../../core/contracts.js';
export type ComplaintRecord = {
  id: string;
  order_id: string;
  buyer_id: string;
  reason: 'unfit' | 'unavailable' | 'allergen' | 'store_closed';
  description: string;
  status: 'open' | 'approved' | 'rejected' | 'auto_refunded';
  response: string | null;
  response_due: Date | null;
  created_at: Date;
  decided_at: Date | null;
};
export class ComplaintRepository {
  async lock(tx: Tx, id: string) {
    return (
      await tx.query<ComplaintRecord>('SELECT * FROM complaints WHERE id=$1 FOR UPDATE', [id])
    ).rows[0];
  }
  async view(tx: Tx, id: string) {
    const c = (await tx.query<ComplaintRecord>('SELECT * FROM complaints WHERE id=$1', [id]))
      .rows[0];
    if (!c) return undefined;
    const media = (
      await tx.query<{ media_id: string }>(
        'SELECT media_id FROM complaint_media WHERE complaint_id=$1 ORDER BY media_id',
        [id],
      )
    ).rows.map((r) => r.media_id);
    return { ...c, media_ids: media, simulation: true };
  }
}
