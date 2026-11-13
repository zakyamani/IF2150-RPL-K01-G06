import type { Dependencies, ServiceContext, Tx } from '../../core/contracts.js';
import { role } from '../../core/auth.js';
import { hash, hmac, safeEqual } from '../../core/crypto.js';
import { ApiError, requireState } from '../../core/errors.js';
import { ledger, orderEvent, scheduleJob } from '../../core/effects.js';
import { OrderRepository, type OrderRecord } from '../orders/repository.js';
import { PickupService } from '../pickup/service.js';
import { PaymentRepository, type PaymentIntent } from './repository.js';
import { DemoPaymentGateway, eventSchema } from './demo-gateway.js';
export function paymentView(p: PaymentIntent) {
  return {
    id: p.id,
    order_id: p.order_id,
    amount: p.amount,
    currency: p.currency,
    status: p.status,
    simulation: true,
  };
}
export class PaymentService {
  private repo = new PaymentRepository();
  private orders = new OrderRepository();
  private gateway: DemoPaymentGateway;
  constructor(private deps: Dependencies) {
    this.gateway = new DemoPaymentGateway(deps.config.CALLBACK_SECRET);
  }
  authorize(tx: Tx, order: OrderRecord) {
    return this.gateway.authorize(tx, order);
  }
  async detail(ctx: ServiceContext, id: string) {
    role(ctx, 'buyer');
    const p = (
      await this.deps.db.query<PaymentIntent>(
        'SELECT p.* FROM payment_intents p JOIN orders o ON o.id=p.order_id WHERE p.id=$1 AND o.buyer_id=$2',
        [id, ctx.actor.id],
      )
    ).rows[0];
    requireState(p, 'PAYMENT_NOT_FOUND', 'Pembayaran tidak ditemukan.', 404);
    return paymentView(p);
  }
  async demoEvent(ctx: ServiceContext, id: string, outcome: 'succeeded' | 'failed') {
    role(ctx, 'buyer');
    const p = (
      await this.deps.db.query<PaymentIntent>(
        'SELECT p.* FROM payment_intents p JOIN orders o ON o.id=p.order_id WHERE p.id=$1 AND o.buyer_id=$2',
        [id, ctx.actor.id],
      )
    ).rows[0];
    requireState(p, 'PAYMENT_NOT_FOUND', 'Pembayaran tidak ditemukan.', 404);
    const event = this.gateway.signedEvent(p, outcome);
    return this.handleWebhook(event.raw, event.signature);
  }
  async expire(tx: Tx, order: OrderRecord, now: Date) {
    if (order.status !== 'pending_payment') return;
    await this.orders.release(tx, order);
    await tx.query("UPDATE orders SET status='cancelled',updated_at=$2 WHERE id=$1", [
      order.id,
      now,
    ]);
    await tx.query("UPDATE payment_intents SET status='expired' WHERE order_id=$1", [order.id]);
    await orderEvent(
      tx,
      order,
      'payment.expired',
      'Invoice simulasi kedaluwarsa; stok sudah dilepas.',
      now,
    );
  }
  async handleWebhook(raw: Buffer, signature: string) {
    requireState(
      /^[a-f0-9]{64}$/.test(signature) &&
        safeEqual(hmac(raw, this.deps.config.CALLBACK_SECRET), signature),
      'INVALID_SIGNATURE',
      'Signature callback tidak valid.',
      401,
    );
    let value: unknown;
    try {
      value = JSON.parse(raw.toString('utf8'));
    } catch {
      throw new ApiError(400, 'INVALID_JSON', 'JSON callback tidak valid.');
    }
    const event = eventSchema.parse(value);
    const payloadHash = hash(raw);
    const result = await this.deps.db.transaction(async (tx) => {
      const mapping = (
        await tx.query<{ order_id: string }>('SELECT order_id FROM payment_intents WHERE id=$1', [
          event.intent_id,
        ])
      ).rows[0];
      requireState(mapping, 'PAYMENT_NOT_FOUND', 'Pembayaran tidak ditemukan.', 404);
      const { order } = await this.orders.lock(tx, mapping.order_id);
      const p = await this.repo.lock(tx, event.intent_id);
      requireState(p, 'PAYMENT_NOT_FOUND', 'Pembayaran tidak ditemukan.', 404);
      requireState(
        order.id === event.order_id && p.amount === event.amount && p.currency === event.currency,
        'INVALID_PAYMENT_EVENT',
        'Identitas atau nominal callback tidak sesuai.',
        400,
      );
      const old = (
        await tx.query('SELECT payload_hash FROM payment_events WHERE id=$1', [event.id])
      ).rows[0];
      if (old) {
        requireState(
          old.payload_hash === payloadHash,
          'EVENT_CONFLICT',
          'Event ID memiliki isi berbeda.',
        );
        return { payment: paymentView(p), expired: p.status === 'expired' };
      }
      const now = this.deps.clock.now();
      if (
        p.status === 'expired' ||
        (order.status === 'pending_payment' && now >= order.payment_deadline)
      ) {
        await this.expire(tx, order, now);
        return { payment: { ...paymentView(p), status: 'expired' }, expired: true };
      }
      if (p.status === 'succeeded') return { payment: paymentView(p), expired: false };
      requireState(
        order.status === 'pending_payment' && p.status === 'pending',
        'PAYMENT_CLOSED',
        'Invoice tidak bisa dibayar lagi.',
      );
      await tx.query(
        'INSERT INTO payment_events(id,intent_id,payload_hash,outcome,created_at) VALUES($1,$2,$3,$4,$5)',
        [event.id, p.id, payloadHash, event.outcome, now],
      );
      if (event.outcome === 'succeeded') {
        const reserved = await tx.query(
          "UPDATE checkout_reservations SET status='sold' WHERE order_id=$1 AND status='held' RETURNING order_id",
          [order.id],
        );
        requireState(reserved.rowCount === 1, 'RESERVATION_CLOSED', 'Reservasi tidak tersedia.');
        await tx.query(
          'UPDATE offers SET quota_held=quota_held-1,quota_sold=quota_sold+1 WHERE id=$1',
          [order.offer_id],
        );
        await tx.query("UPDATE orders SET status='paid',paid_at=$2,updated_at=$2 WHERE id=$1", [
          order.id,
          now,
        ]);
        await tx.query("UPDATE payment_intents SET status='succeeded' WHERE id=$1", [p.id]);
        await new PickupService(this.deps).issue(tx, order.id);
        await ledger(tx, order.id, 'funds_held', order.price, now);
        await scheduleJob(tx, 'no_show', order.id, order.pickup_end);
        await orderEvent(
          tx,
          order,
          'payment.succeeded',
          'Pembayaran simulasi berhasil. Paket siap diambil sesuai jadwal.',
          now,
          order.buyer_id,
        );
      } else {
        await this.orders.release(tx, order);
        await tx.query("UPDATE orders SET status='cancelled',updated_at=$2 WHERE id=$1", [
          order.id,
          now,
        ]);
        await tx.query("UPDATE payment_intents SET status='failed' WHERE id=$1", [p.id]);
        await orderEvent(
          tx,
          order,
          'payment.failed',
          'Pembayaran simulasi gagal; stok sudah dilepas.',
          now,
          order.buyer_id,
        );
      }
      return { payment: { ...paymentView(p), status: event.outcome }, expired: false };
    });
    if (result.expired)
      throw new ApiError(
        410,
        'INVOICE_EXPIRED',
        'Invoice kedaluwarsa. Buat pesanan baru jika paket masih tersedia.',
      );
    return result.payment;
  }
}
