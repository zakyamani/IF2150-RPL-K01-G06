import type { Tx } from '../../core/contracts.js';
import type { OfferRecord } from '../offers/repository.js';
import { requireState } from '../../core/errors.js';
export type OrderSnapshot = {
  category: string;
  allergens: string[];
  normal_price: number;
  discount_price: number;
  merchant: {
    id: string;
    name: string;
    address: string;
    latitude: number;
    longitude: number;
    photo_id: string | null;
  };
};
export type OrderRecord = {
  id: string;
  code: string;
  invoice: string;
  offer_id: string;
  buyer_id: string;
  seller_id: string;
  status:
    'pending_payment' | 'paid' | 'cancelled' | 'completed' | 'dispute' | 'refunded' | 'no_show';
  price: number;
  fee: number;
  fee_bps: number;
  snapshot: OrderSnapshot;
  payment_deadline: Date;
  pickup_start: Date;
  pickup_end: Date;
  safe_eat_until: Date;
  paid_at: Date | null;
  completed_at: Date | null;
  created_at: Date;
  updated_at: Date;
};
export class OrderRepository {
  async lock(tx: Tx, id: string): Promise<{ order: OrderRecord; offer: OfferRecord }> {
    const mapping = (
      await tx.query<{ offer_id: string }>('SELECT offer_id FROM orders WHERE id=$1', [id])
    ).rows[0];
    requireState(mapping, 'ORDER_NOT_FOUND', 'Pesanan tidak ditemukan.', 404);
    const offer = (
      await tx.query<OfferRecord>('SELECT * FROM offers WHERE id=$1 FOR UPDATE', [mapping.offer_id])
    ).rows[0]!;
    const order = (await tx.query<OrderRecord>('SELECT * FROM orders WHERE id=$1 FOR UPDATE', [id]))
      .rows[0]!;
    return { order, offer };
  }
  async read(tx: Tx, id: string) {
    return (await tx.query<OrderRecord>('SELECT * FROM orders WHERE id=$1', [id])).rows[0];
  }
  async release(tx: Tx, order: OrderRecord) {
    const r = await tx.query(
      "UPDATE checkout_reservations SET status='released' WHERE order_id=$1 AND status='held' RETURNING order_id",
      [order.id],
    );
    if (r.rowCount)
      await tx.query(
        'UPDATE offers SET quota_held=quota_held-1,quota_available=quota_available+1 WHERE id=$1',
        [order.offer_id],
      );
  }
}
