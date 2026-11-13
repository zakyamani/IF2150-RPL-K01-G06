import type { Tx } from '../../core/contracts.js';
export type ReviewRecord = {
  id: string;
  order_id: string;
  buyer_id: string;
  seller_id: string;
  rating: number;
  comment: string;
  created_at: Date;
};
export class ReviewRepository {
  async list(tx: Tx, seller: string, c: { at?: string; id?: string; limit: number }) {
    return (
      await tx.query<ReviewRecord & { reviewer_name: string }>(
        'SELECT r.*,u.name AS reviewer_name FROM reviews r JOIN users u ON u.id=r.buyer_id WHERE r.seller_id=$1 AND ($2::timestamptz IS NULL OR (r.created_at,r.id)<($2,$3::uuid)) ORDER BY r.created_at DESC,r.id DESC LIMIT $4',
        [seller, c.at, c.id, c.limit],
      )
    ).rows;
  }
  async stats(tx: Tx, seller: string) {
    return (
      await tx.query<{ average: string | null; n: number }>(
        'SELECT avg(rating)::text AS average,count(*)::int AS n FROM reviews WHERE seller_id=$1',
        [seller],
      )
    ).rows[0]!;
  }
}
