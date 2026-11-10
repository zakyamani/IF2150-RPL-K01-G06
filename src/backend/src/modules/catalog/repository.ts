import type {Tx} from '../../core/contracts.js';
import type {OfferRecord} from '../offers/repository.js';
export type CatalogRecord = OfferRecord & { latitude: number; longitude: number };
export class CatalogRepository {
  async read(
    tx: Tx,
    buyerId: string,
    now: Date,
    query: { id?: string; at?: string; cursorId?: string; limit: number; category?: string },
  ) {
    return (
      await tx.query<CatalogRecord>(
        `SELECT o.*,p.latitude,p.longitude FROM offers o JOIN merchant_profiles p ON p.user_id=o.seller_id JOIN users u ON u.id=$1 WHERE o.status='active' AND o.pickup_end>$2 AND o.quota_available>0 AND NOT(o.allergens && u.allergen_filters) AND ($3::uuid IS NULL OR o.id=$3) AND ($4::timestamptz IS NULL OR (o.created_at,o.id)<($4,$5::uuid)) AND ($6::text IS NULL OR o.category=$6) ORDER BY o.created_at DESC,o.id DESC LIMIT $7`,
        [buyerId, now, query.id, query.at, query.cursorId, query.category, query.limit],
      )
    ).rows;
  }
}