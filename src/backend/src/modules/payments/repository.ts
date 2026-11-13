import type { Tx } from '../../core/contracts.js';
import type { OrderRecord } from '../orders/repository.js';
export type PaymentIntent = {
  id: string;
  order_id: string;
  amount: number;
  currency: 'IDR';
  status: 'pending' | 'succeeded' | 'failed' | 'expired';
  created_at: Date;
};
export class PaymentRepository {
  async authorize(tx: Tx, order: OrderRecord) {
    return (
      await tx.query<PaymentIntent>(
        "INSERT INTO payment_intents(order_id,amount,currency,created_at) VALUES($1,$2,'IDR',$3) RETURNING *",
        [order.id, order.price, order.created_at],
      )
    ).rows[0]!;
  }
  async forOrder(tx: Tx, id: string) {
    return (await tx.query<PaymentIntent>('SELECT * FROM payment_intents WHERE order_id=$1', [id]))
      .rows[0]!;
  }
  async lock(tx: Tx, id: string) {
    return (
      await tx.query<PaymentIntent>('SELECT * FROM payment_intents WHERE id=$1 FOR UPDATE', [id])
    ).rows[0];
  }
}
