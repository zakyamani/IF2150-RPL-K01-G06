import type {Tx} from '../../core/contracts.js';
import type {OfferInput} from './schema.js';
export type OfferRecord = {
  id: string;
  seller_id: string;
  category: string;
  allergens: string[];
  status: 'active' | 'closed';
  quota_total: number;
  quota_available: number;
  quota_held: number;
  quota_sold: number;
  normal_price: number;
  discount_price: number;
  pickup_start: Date;
  pickup_end: Date;
  safe_eat_until: Date;
  fitness_confirmed: boolean;
  created_at: Date;
};
export class OfferRepository {
  async create(tx: Tx, seller: string, input: OfferInput, now: Date) {
    return (
      await tx.query<OfferRecord>(
        `INSERT INTO offers(seller_id,category,allergens,quota_total,quota_available,normal_price,discount_price,pickup_start,pickup_end,safe_eat_until,fitness_confirmed,created_at) VALUES($1,$2,$3,$4,$4,$5,$6,$7,$8,$9,true,$10) RETURNING *`,
        [
          seller,
          input.category,
          input.allergens,
          input.quota,
          input.normal_price,
          input.discount_price,
          input.pickup_start,
          input.pickup_end,
          input.safe_eat_until,
          now,
        ],
      )
    ).rows[0]!;
  }
  async lock(tx: Tx, id: string) {
    return (await tx.query<OfferRecord>('SELECT * FROM offers WHERE id=$1 FOR UPDATE', [id]))
      .rows[0];
  }
  async update(tx: Tx, id: string, input: OfferInput) {
    return (
      await tx.query<OfferRecord>(
        'UPDATE offers SET category=$2,allergens=$3,quota_total=$4,quota_available=$4,normal_price=$5,discount_price=$6,pickup_start=$7,pickup_end=$8,safe_eat_until=$9 WHERE id=$1 RETURNING *',
        [
          id,
          input.category,
          input.allergens,
          input.quota,
          input.normal_price,
          input.discount_price,
          input.pickup_start,
          input.pickup_end,
          input.safe_eat_until,
        ],
      )
    ).rows[0]!;
  }
  async audit(tx: Tx, actor: string, id: string, action: string, now: Date) {
    await tx.query(
      'INSERT INTO audit_logs(actor_id,resource_id,action,occurred_at) VALUES($1,$2,$3,$4)',
      [actor, id, action, now],
    );
  }
}