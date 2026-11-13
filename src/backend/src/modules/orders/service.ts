import { randomBytes, randomUUID } from 'node:crypto';
import type { Dependencies, ServiceContext, Tx } from '../../core/contracts.js';
import { role } from '../../core/auth.js';
import { requireState } from '../../core/errors.js';
import { idempotent } from '../../core/idempotency.js';
import { audit, scheduleJob, orderEvent } from '../../core/effects.js';
import { decodeCursor, encodeCursor } from '../../core/pagination.js';
import type { OfferRecord } from '../offers/repository.js';
import { PaymentService, paymentView } from '../payments/service.js';
import { PaymentRepository } from '../payments/repository.js';
import { PickupService } from '../pickup/service.js';
import { OrderRepository, type OrderRecord, type OrderSnapshot } from './repository.js';
import { RefundService } from '../payments/refund-service.js';
import { PayoutService } from '../payouts/service.js';
const alphabet = '0123456789ABCDEFGHJKMNPQRSTVWXYZ';
function orderCode() {
  return 'SR-' + Array.from(randomBytes(10), (b) => alphabet[b % 32]).join('');
}
export class OrderService {
  private repo = new OrderRepository();
  constructor(private deps: Dependencies) {}
  async checkout(ctx: ServiceContext, input: { offer_id: string }, key: string) {
    role(ctx, 'buyer');
    return this.deps.db.transaction((tx) =>
      idempotent(tx, ctx.actor.id, 'checkout', key, input, async () => {
        const offer = (
          await tx.query<OfferRecord>('SELECT * FROM offers WHERE id=$1 FOR UPDATE', [
            input.offer_id,
          ])
        ).rows[0];
        requireState(offer, 'OFFER_NOT_FOUND', 'Paket tidak ditemukan.', 404);
        const now = ctx.clock.now();
        requireState(
          offer.status === 'active' && offer.pickup_end > now && offer.quota_available > 0,
          'OFFER_UNAVAILABLE',
          'Paket habis atau sudah ditutup.',
        );
        const filters = (
          await tx.query<{ allergen_filters: string[] }>(
            'SELECT allergen_filters FROM users WHERE id=$1',
            [ctx.actor.id],
          )
        ).rows[0]!.allergen_filters;
        requireState(
          !offer.allergens.some((a) => filters.includes(a)),
          'ALLERGEN_CONFLICT',
          'Paket tersembunyi oleh filter alergen Anda.',
        );
        const merchant = (
          await tx.query('SELECT * FROM merchant_profiles WHERE user_id=$1 FOR SHARE', [
            offer.seller_id,
          ])
        ).rows[0];
        const snapshot: OrderSnapshot = {
          category: offer.category,
          allergens: offer.allergens,
          normal_price: offer.normal_price,
          discount_price: offer.discount_price,
          merchant: {
            id: offer.seller_id,
            name: merchant.shop_name,
            address: merchant.address,
            latitude: merchant.latitude,
            longitude: merchant.longitude,
            photo_id: merchant.photo_id,
          },
        };
        const deadline = new Date(Math.min(now.getTime() + 900000, offer.pickup_end.getTime()));
        const fee = Math.floor((offer.discount_price * this.deps.config.FEE_BPS) / 10000);
        // Unique code collision is retried inside a savepoint without losing inventory locks.
        let order: OrderRecord | undefined;
        for (let attempt = 0; attempt < 5; attempt++) {
          await tx.query('SAVEPOINT order_identifier');
          try {
            order = (
              await tx.query<OrderRecord>(
                `INSERT INTO orders(code,invoice,offer_id,buyer_id,seller_id,status,price,fee,fee_bps,snapshot,payment_deadline,pickup_start,pickup_end,safe_eat_until,created_at,updated_at) VALUES($1,$2,$3,$4,$5,'pending_payment',$6,$7,$8,$9,$10,$11,$12,$13,$14,$14) RETURNING *`,
                [
                  orderCode(),
                  `INV-${randomUUID()}`,
                  offer.id,
                  ctx.actor.id,
                  offer.seller_id,
                  offer.discount_price,
                  fee,
                  this.deps.config.FEE_BPS,
                  snapshot,
                  deadline,
                  offer.pickup_start,
                  offer.pickup_end,
                  offer.safe_eat_until,
                  now,
                ],
              )
            ).rows[0]!;
            await tx.query('RELEASE SAVEPOINT order_identifier');
            break;
          } catch (e) {
            await tx.query('ROLLBACK TO SAVEPOINT order_identifier');
            if ((e as { code?: string }).code !== '23505' || attempt === 4) throw e;
          }
        }
        requireState(order, 'ORDER_UNAVAILABLE', 'Tidak dapat membuat nomor pesanan.');
        await tx.query(
          'UPDATE offers SET quota_available=quota_available-1,quota_held=quota_held+1 WHERE id=$1',
          [offer.id],
        );
        await tx.query(
          "INSERT INTO checkout_reservations(order_id,status,expires_at) VALUES($1,'held',$2)",
          [order.id, deadline],
        );
        const intent = await new PaymentService(this.deps).authorize(tx, order);
        await scheduleJob(tx, 'expire_payment', order.id, deadline);
        await audit(tx, ctx.actor.id, order.id, 'order.created', now);
        return {
          order_id: order.id,
          code: order.code,
          invoice: order.invoice,
          intent_id: intent.id,
          status: order.status,
          price: order.price,
          fee: order.fee,
          payment_deadline: deadline.toISOString(),
          simulation: true,
        };
      }),
    );
  }
  async detail(ctx: ServiceContext, id: string) {
    return this.deps.db.transaction(async (tx) => {
      const o = await this.repo.read(tx, id);
      requireState(
        o && (o.buyer_id === ctx.actor.id || o.seller_id === ctx.actor.id),
        'ORDER_NOT_FOUND',
        'Pesanan tidak ditemukan.',
        404,
      );
      const payment = await new PaymentRepository().forOrder(tx, id);
      const history = (
        await tx.query(
          'SELECT action,occurred_at FROM audit_logs WHERE resource_id=$1 ORDER BY id',
          [id],
        )
      ).rows;
      const now = ctx.clock.now();
      const isBuyer = o.buyer_id === ctx.actor.id;
      const actions: string[] = [];
      if (isBuyer && o.status === 'pending_payment' && now < o.payment_deadline)
        actions.push('pay');
      if (
        isBuyer &&
        o.status === 'paid' &&
        now < o.pickup_end &&
        !(await tx.query('SELECT id FROM complaints WHERE order_id=$1', [id])).rowCount
      )
        actions.push('complain');
      if (!isBuyer && ['paid', 'dispute'].includes(o.status)) actions.push('cancel');
      if (!isBuyer && o.status === 'paid' && now >= o.pickup_start && now < o.pickup_end)
        actions.push('pickup');
      if (
        isBuyer &&
        o.status === 'completed' &&
        !(await tx.query('SELECT id FROM reviews WHERE order_id=$1', [id])).rowCount
      )
        actions.push('review');
      const reveal = !!o.paid_at;
      const pickup =
        isBuyer && o.status === 'paid' && now < o.pickup_end
          ? await new PickupService(this.deps).credential(tx, id)
          : undefined;
      const complaint = (
        await tx.query(
          'SELECT id,reason,description,status,response,response_due,created_at,decided_at FROM complaints WHERE order_id=$1',
          [id],
        )
      ).rows[0];
      return {
        id: o.id,
        code: o.code,
        invoice: o.invoice,
        status: o.status,
        price: o.price,
        fee: o.fee,
        fee_bps: o.fee_bps,
        category: o.snapshot.category,
        allergens: o.snapshot.allergens,
        normal_price: o.snapshot.normal_price,
        pickup_start: o.pickup_start,
        pickup_end: o.pickup_end,
        safe_eat_until: o.safe_eat_until,
        payment_deadline: o.payment_deadline,
        payment: payment ? paymentView(payment) : null,
        ...(reveal ? { merchant: o.snapshot.merchant } : {}),
        ...(pickup ? { pickup } : {}),
        complaint: complaint ?? null,
        allowed_actions: actions,
        history,
        created_at: o.created_at,
        server_time: now,
        simulation: true,
      };
    });
  }
  async list(ctx: ServiceContext, query: { cursor?: string; limit?: number; status?: string }) {
    const c = decodeCursor(query.cursor);
    const limit = query.limit ?? 20;
    const rows = (
      await this.deps.db.query<OrderRecord>(
        `SELECT * FROM orders WHERE ${ctx.actor.role === 'buyer' ? 'buyer_id' : 'seller_id'}=$1 AND ($2::timestamptz IS NULL OR (created_at,id)<($2,$3::uuid)) AND ($4::text IS NULL OR status=$4) ORDER BY created_at DESC,id DESC LIMIT $5`,
        [ctx.actor.id, c?.at, c?.id, query.status, limit + 1],
      )
    ).rows;
    const items = rows.slice(0, limit);
    return {
      items: items.map((o) => ({
        id: o.id,
        code: o.code,
        status: o.status,
        price: o.price,
        fee: o.fee,
        category: o.snapshot.category,
        pickup_start: o.pickup_start,
        pickup_end: o.pickup_end,
        safe_eat_until: o.safe_eat_until,
        created_at: o.created_at,
      })),
      next_cursor: rows.length > limit ? encodeCursor(items[items.length - 1]!) : null,
    };
  }
  async cancelBySeller(
    ctx: ServiceContext,
    id: string,
    key: string,
    reason = 'Dibatalkan penjual.',
  ) {
    role(ctx, 'seller');
    return this.deps.db.transaction((tx) =>
      idempotent(tx, ctx.actor.id, 'seller_cancel', key, { id, reason }, async () => {
        const { order: o } = await this.repo.lock(tx, id);
        requireState(
          o.seller_id === ctx.actor.id,
          'ORDER_NOT_FOUND',
          'Pesanan tidak ditemukan.',
          404,
        );
        requireState(
          ['paid', 'dispute', 'refunded'].includes(o.status),
          'CANCEL_STATE_CONFLICT',
          'Pesanan tidak dapat dibatalkan.',
        );
        const refund = await new RefundService(this.deps).refund(
          tx,
          o,
          'seller_cancel',
          ctx.actor.id,
        );
        await tx.query(
          "UPDATE complaints SET status='approved',response=$2,decided_at=$3 WHERE order_id=$1 AND status='open'",
          [id, reason, ctx.clock.now()],
        );
        return { order_id: id, status: 'refunded', refund, simulation: true };
      }),
    );
  }
  async processNoShow(tx: Tx, o: OrderRecord, now: Date) {
    if (o.status !== 'paid' || now < o.pickup_end) return false;
    if (
      (await tx.query("SELECT id FROM complaints WHERE order_id=$1 AND status='open'", [o.id]))
        .rowCount
    )
      return false;
    await tx.query("UPDATE orders SET status='no_show',updated_at=$2 WHERE id=$1", [o.id, now]);
    await tx.query('UPDATE pickup_credentials SET disabled_at=$2 WHERE order_id=$1', [o.id, now]);
    await new PayoutService(this.deps).schedule(tx, o.id, 'no_show', now);
    await orderEvent(
      tx,
      o,
      'order.no_show',
      'Jadwal pickup berakhir. Payout simulasi dijadwalkan sesuai ketentuan.',
      now,
    );
    return true;
  }
}
