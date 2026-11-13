import type { Dependencies, Tx } from '../../core/contracts.js';
import { requireState } from '../../core/errors.js';
import { ledger, orderEvent } from '../../core/effects.js';
import type { OrderRecord } from '../orders/repository.js';
export class RefundService {
  constructor(private deps: Dependencies) {}
  async refund(tx: Tx, order: OrderRecord, reason: string, actor: string | null = null) {
    const existing = (
      await tx.query('SELECT id,amount,reason FROM refunds WHERE order_id=$1', [order.id])
    ).rows[0];
    if (existing) return existing;
    requireState(
      ['paid', 'dispute'].includes(order.status),
      'REFUND_STATE_CONFLICT',
      'Pesanan tidak dapat direfund.',
    );
    const now = this.deps.clock.now();
    const refund = (
      await tx.query(
        'INSERT INTO refunds(order_id,amount,reason,created_at) VALUES($1,$2,$3,$4) RETURNING id,amount,reason',
        [order.id, order.price, reason, now],
      )
    ).rows[0]!;
    const sold = await tx.query(
      "UPDATE checkout_reservations SET status='released' WHERE order_id=$1 AND status='sold' RETURNING order_id",
      [order.id],
    );
    requireState(sold.rowCount === 1, 'REFUND_RESERVATION_CONFLICT', 'Reservasi tidak konsisten.');
    await tx.query(
      'UPDATE offers SET quota_sold=quota_sold-1,quota_available=quota_available+1 WHERE id=$1',
      [order.offer_id],
    );
    await tx.query("UPDATE orders SET status='refunded',updated_at=$2 WHERE id=$1", [
      order.id,
      now,
    ]);
    await tx.query('UPDATE pickup_credentials SET disabled_at=$2 WHERE order_id=$1', [
      order.id,
      now,
    ]);
    const p = (
      await tx.query(
        "UPDATE payout_entitlements SET status='cancelled' WHERE order_id=$1 AND status IN ('held','pending') RETURNING id",
        [order.id],
      )
    ).rows[0];
    if (p)
      await tx.query(
        "INSERT INTO payout_events(entitlement_id,kind,created_at) VALUES($1,'cancelled',$2) ON CONFLICT DO NOTHING",
        [p.id, now],
      );
    await ledger(tx, order.id, 'refund', order.price, now);
    await orderEvent(
      tx,
      order,
      'order.refunded',
      'Refund penuh simulasi sudah dicatat. Tidak ada uang sungguhan dipindahkan.',
      now,
      actor,
    );
    return refund;
  }
}
