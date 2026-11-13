import type { Dependencies, ServiceContext } from '../../core/contracts.js';
import { role } from '../../core/auth.js';
import { requireState } from '../../core/errors.js';
import { audit } from '../../core/effects.js';
import { decodeCursor, encodeCursor } from '../../core/pagination.js';
import { OrderRepository } from '../orders/repository.js';
import { reviewSchema, type ReviewInput } from './schema.js';
import { ReviewRepository, type ReviewRecord } from './repository.js';
export class ReviewService {
  constructor(private deps: Dependencies) {}
  async create(ctx: ServiceContext, value: ReviewInput) {
    role(ctx, 'buyer');
    const input = reviewSchema.parse(value);
    return this.deps.db.transaction(async (tx) => {
      const { order: o } = await new OrderRepository().lock(tx, input.order_id);
      requireState(o.buyer_id === ctx.actor.id, 'ORDER_NOT_FOUND', 'Pesanan tidak ditemukan.', 404);
      requireState(
        o.status === 'completed',
        'REVIEW_NOT_ELIGIBLE',
        'Ulasan tersedia setelah pickup selesai.',
      );
      const r = (
        await tx.query<ReviewRecord>(
          'INSERT INTO reviews(order_id,buyer_id,seller_id,rating,comment,created_at) VALUES($1,$2,$3,$4,$5,$6) RETURNING *',
          [o.id, ctx.actor.id, o.seller_id, input.rating, input.comment, ctx.clock.now()],
        )
      ).rows[0]!;
      await audit(tx, ctx.actor.id, o.id, 'review.created', ctx.clock.now());
      return {
        id: r.id,
        order_id: r.order_id,
        rating: r.rating,
        comment: r.comment,
        created_at: r.created_at,
      };
    });
  }
  async listRevealed(
    ctx: ServiceContext,
    seller: string,
    q: { cursor?: string; limit?: number } = {},
  ) {
    return this.deps.db.transaction(async (tx) => {
      const owns = ctx.actor.role === 'seller' && ctx.actor.id === seller;
      const paid = (
        await tx.query(
          'SELECT id FROM orders WHERE buyer_id=$1 AND seller_id=$2 AND paid_at IS NOT NULL LIMIT 1',
          [ctx.actor.id, seller],
        )
      ).rowCount;
      requireState(
        owns || paid,
        'MERCHANT_HIDDEN',
        'Profil ulasan gerai tersedia setelah pembayaran.',
        403,
      );
      const c = decodeCursor(q.cursor);
      const limit = q.limit ?? 20;
      const repo = new ReviewRepository();
      const rows = await repo.list(tx, seller, { at: c?.at, id: c?.id, limit: limit + 1 });
      const stats = await repo.stats(tx, seller);
      const items = rows.slice(0, limit);
      return {
        items: items.map((r) => ({
          id: r.id,
          rating: r.rating,
          comment: r.comment,
          reviewer_name: r.reviewer_name,
          created_at: r.created_at,
        })),
        rating_average: stats.average === null ? null : Math.round(Number(stats.average) * 10) / 10,
        rating_count: stats.n,
        next_cursor: rows.length > limit ? encodeCursor(items[items.length - 1]!) : null,
      };
    });
  }
}
