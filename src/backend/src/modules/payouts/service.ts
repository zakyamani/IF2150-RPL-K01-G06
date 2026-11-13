import type { Dependencies, Tx, ServiceContext } from '../../core/contracts.js';
import type { OrderRecord } from '../orders/repository.js';
import { ledger, scheduleJob } from '../../core/effects.js';
import { requireState } from '../../core/errors.js';
import { role } from '../../core/auth.js';
import { decodeCursor, encodeCursor } from '../../core/pagination.js';
import { PayoutRepository } from './repository.js';
export class PayoutService {
  constructor(private deps: Dependencies) {}
  async schedule(tx: Tx, orderId: string, reason: string, at: Date) {
    const o = (await tx.query<OrderRecord>('SELECT * FROM orders WHERE id=$1', [orderId])).rows[0];
    requireState(o, 'ORDER_NOT_FOUND', 'Pesanan tidak ditemukan.', 404);
    const due = new Date(at.getTime() + 3600000);
    const p = (
      await tx.query(
        `INSERT INTO payout_entitlements(order_id,seller_id,gross,fee,net,status,due_at,reason,created_at) VALUES($1,$2,$3,$4,$5,'pending',$6,$7,$8) ON CONFLICT(order_id) DO UPDATE SET status='pending',due_at=EXCLUDED.due_at,reason=EXCLUDED.reason WHERE payout_entitlements.status IN ('held','pending') RETURNING id`,
        [o.id, o.seller_id, o.price, o.fee, o.price - o.fee, due, reason, at],
      )
    ).rows[0];
    requireState(p, 'PAYOUT_STATE_CONFLICT', 'Payout tidak dapat dijadwalkan.');
    await tx.query(
      "INSERT INTO payout_events(entitlement_id,kind,created_at) VALUES($1,'scheduled',$2) ON CONFLICT DO NOTHING",
      [p.id, at],
    );
    await ledger(tx, o.id, 'fee', o.fee, at);
    await ledger(tx, o.id, 'payout_scheduled', o.price - o.fee, at);
    await scheduleJob(tx, 'settle_payout', o.id, due);
    return p;
  }
  async summary(ctx: ServiceContext) {
    role(ctx, 'seller');
    const result = { pending: 0, held: 0, settled: 0, cancelled: 0, simulation: true };
    for (const row of await new PayoutRepository(this.deps.db).summary(ctx.actor.id)) {
      const amount = Number(row.amount);
      requireState(
        Number.isSafeInteger(amount),
        'AMOUNT_OVERFLOW',
        'Total saldo terlalu besar untuk ditampilkan dengan aman.',
        503,
      );
      result[row.status] = amount;
    }
    return result;
  }
  async list(ctx: ServiceContext, q: { cursor?: string; limit?: number; status?: string }) {
    role(ctx, 'seller');
    const c = decodeCursor(q.cursor);
    const limit = q.limit ?? 20;
    const rows = await new PayoutRepository(this.deps.db).list(ctx.actor.id, {
      at: c?.at,
      cursorId: c?.id,
      status: q.status,
      limit: limit + 1,
    });
    const items = rows.slice(0, limit);
    return {
      items: items.map((r) => ({ ...r, simulation: true })),
      next_cursor: rows.length > limit ? encodeCursor(items[items.length - 1]!) : null,
      simulation: true,
    };
  }
}
