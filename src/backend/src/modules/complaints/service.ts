import type { Dependencies, ServiceContext, Tx } from '../../core/contracts.js';
import { role } from '../../core/auth.js';
import { requireState } from '../../core/errors.js';
import { idempotent } from '../../core/idempotency.js';
import { orderEvent, scheduleJob } from '../../core/effects.js';
import { decodeCursor, encodeCursor } from '../../core/pagination.js';
import { OrderRepository, type OrderRecord } from '../orders/repository.js';
import { OrderService } from '../orders/service.js';
import { RefundService } from '../payments/refund-service.js';
import { MediaService } from '../media/service.js';
import { ComplaintRepository, type ComplaintRecord } from './repository.js';
import {
  complaintSchema,
  decisionSchema,
  type ComplaintInput,
  type DecisionInput,
} from './schema.js';
export class ComplaintService {
  private repo = new ComplaintRepository();
  constructor(private deps: Dependencies) {}
  async open(ctx: ServiceContext, value: ComplaintInput, key: string) {
    role(ctx, 'buyer');
    const input = complaintSchema.parse(value);
    return this.deps.db.transaction((tx) =>
      idempotent(tx, ctx.actor.id, 'complaint', key, input, async () => {
        const { order: o } = await new OrderRepository().lock(tx, input.order_id);
        requireState(
          o.buyer_id === ctx.actor.id,
          'ORDER_NOT_FOUND',
          'Pesanan tidak ditemukan.',
          404,
        );
        const now = ctx.clock.now();
        requireState(
          o.status === 'paid',
          'COMPLAINT_STATE_CONFLICT',
          'Pengaduan hanya untuk paket dibayar yang belum diambil.',
        );
        requireState(
          now < o.pickup_end,
          'COMPLAINT_EXPIRED',
          'Batas pengaduan sudah berakhir.',
          410,
        );
        if (input.reason === 'store_closed')
          requireState(
            now >= o.pickup_start,
            'PICKUP_NOT_STARTED',
            'Laporan toko tutup hanya selama jadwal pickup.',
          );
        const due = input.reason === 'store_closed' ? new Date(now.getTime() + 86400000) : null;
        const c = (
          await tx.query<ComplaintRecord>(
            "INSERT INTO complaints(order_id,buyer_id,reason,description,status,response_due,created_at) VALUES($1,$2,$3,$4,'open',$5,$6) RETURNING *",
            [o.id, ctx.actor.id, input.reason, input.description, due, now],
          )
        ).rows[0]!;
        for (const id of input.media_ids) {
          await new MediaService(this.deps).attach(
            tx,
            { id, user_id: ctx.actor.id, kind: 'evidence' },
            c.id,
          );
          await tx.query('INSERT INTO complaint_media(complaint_id,media_id) VALUES($1,$2)', [
            c.id,
            id,
          ]);
        }
        await tx.query("UPDATE orders SET status='dispute',updated_at=$2 WHERE id=$1", [o.id, now]);
        await tx.query(
          "INSERT INTO payout_entitlements(order_id,seller_id,gross,fee,net,status,due_at,reason,created_at) VALUES($1,$2,$3,$4,$5,'held',$6,'dispute',$7) ON CONFLICT(order_id) DO UPDATE SET status='held' WHERE payout_entitlements.status='pending'",
          [
            o.id,
            o.seller_id,
            o.price,
            o.fee,
            o.price - o.fee,
            new Date(o.pickup_end.getTime() + 3600000),
            now,
          ],
        );
        if (due) await scheduleJob(tx, 'closed_shop_refund', c.id, due);
        await orderEvent(
          tx,
          o,
          'complaint.opened',
          'Pengaduan dibuka. Payout simulasi ditahan sampai ada keputusan.',
          now,
          ctx.actor.id,
        );
        return (await this.repo.view(tx, c.id))!;
      }),
    );
  }
  async autoRefund(tx: Tx, c: ComplaintRecord, o: OrderRecord, now: Date) {
    if (
      c.status !== 'open' ||
      c.reason !== 'store_closed' ||
      !c.response_due ||
      now < c.response_due
    )
      return false;
    requireState(
      o.status === 'dispute',
      'COMPLAINT_STATE_CONFLICT',
      'Status pengaduan tidak konsisten.',
    );
    await new RefundService(this.deps).refund(tx, o, 'store_closed_timeout');
    await tx.query(
      "UPDATE complaints SET status='auto_refunded',response='Tidak ditanggapi selama 24 jam; refund penuh simulasi.',decided_at=$2 WHERE id=$1",
      [c.id, now],
    );
    return true;
  }
  async decide(ctx: ServiceContext, id: string, value: DecisionInput) {
    role(ctx, 'seller');
    const input = decisionSchema.parse(value);
    return this.deps.db.transaction(async (tx) => {
      const mapping = (
        await tx.query<{ order_id: string }>('SELECT order_id FROM complaints WHERE id=$1', [id])
      ).rows[0];
      requireState(mapping, 'COMPLAINT_NOT_FOUND', 'Pengaduan tidak ditemukan.', 404);
      const { order: o } = await new OrderRepository().lock(tx, mapping.order_id);
      requireState(
        o.seller_id === ctx.actor.id,
        'COMPLAINT_NOT_FOUND',
        'Pengaduan tidak ditemukan.',
        404,
      );
      const c = await this.repo.lock(tx, id);
      requireState(c, 'COMPLAINT_NOT_FOUND', 'Pengaduan tidak ditemukan.', 404);
      if (c.status !== 'open') {
        requireState(
          ((input.approved && c.status === 'approved') ||
            (!input.approved && c.status === 'rejected')) &&
            c.response === input.response,
          'COMPLAINT_ALREADY_DECIDED',
          'Pengaduan sudah diputuskan.',
        );
        return (await this.repo.view(tx, id))!;
      }
      const now = ctx.clock.now();
      if (await this.autoRefund(tx, c, o, now)) return (await this.repo.view(tx, id))!;
      requireState(
        o.status === 'dispute',
        'COMPLAINT_STATE_CONFLICT',
        'Pesanan tidak dalam pengaduan.',
      );
      await tx.query('UPDATE complaints SET status=$2,response=$3,decided_at=$4 WHERE id=$1', [
        id,
        input.approved ? 'approved' : 'rejected',
        input.response,
        now,
      ]);
      if (input.approved)
        await new RefundService(this.deps).refund(tx, o, 'complaint_approved', ctx.actor.id);
      else {
        await tx.query("UPDATE orders SET status='paid',updated_at=$2 WHERE id=$1", [o.id, now]);
        await tx.query(
          "UPDATE payout_entitlements SET status='pending',reason='awaiting_pickup' WHERE order_id=$1 AND status='held'",
          [o.id],
        );
        await new OrderService(this.deps).processNoShow(tx, { ...o, status: 'paid' }, now);
      }
      await orderEvent(
        tx,
        o,
        input.approved ? 'complaint.approved' : 'complaint.rejected',
        input.approved
          ? 'Pengaduan disetujui; refund penuh simulasi.'
          : 'Pengaduan ditolak. Periksa jadwal dan status pesanan.',
        now,
        ctx.actor.id,
      );
      return (await this.repo.view(tx, id))!;
    });
  }
  async detail(ctx: ServiceContext, id: string) {
    return this.deps.db.transaction(async (tx) => {
      const c = (await tx.query<ComplaintRecord>('SELECT * FROM complaints WHERE id=$1', [id]))
        .rows[0];
      requireState(c, 'COMPLAINT_NOT_FOUND', 'Pengaduan tidak ditemukan.', 404);
      const o = (await tx.query<OrderRecord>('SELECT * FROM orders WHERE id=$1', [c.order_id]))
        .rows[0]!;
      requireState(
        o.buyer_id === ctx.actor.id || o.seller_id === ctx.actor.id,
        'COMPLAINT_NOT_FOUND',
        'Pengaduan tidak ditemukan.',
        404,
      );
      return (await this.repo.view(tx, id))!;
    });
  }
  async list(ctx: ServiceContext, q: { cursor?: string; limit?: number; status?: string }) {
    const c = decodeCursor(q.cursor);
    const limit = q.limit ?? 20;
    const rows = (
      await this.deps.db.query<ComplaintRecord & { order_code: string }>(
        `SELECT c.*,o.code AS order_code FROM complaints c JOIN orders o ON o.id=c.order_id WHERE ${ctx.actor.role === 'buyer' ? 'o.buyer_id' : 'o.seller_id'}=$1 AND ($2::timestamptz IS NULL OR (c.created_at,c.id)<($2,$3::uuid)) AND ($4::text IS NULL OR c.status=$4) ORDER BY c.created_at DESC,c.id DESC LIMIT $5`,
        [ctx.actor.id, c?.at, c?.id, q.status, limit + 1],
      )
    ).rows;
    const items = rows.slice(0, limit);
    return {
      items,
      next_cursor: rows.length > limit ? encodeCursor(items[items.length - 1]!) : null,
    };
  }
}
