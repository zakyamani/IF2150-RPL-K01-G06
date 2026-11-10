import type {Dependencies, ServiceContext, Tx} from '../../core/contracts.js';
import {role} from '../../core/auth.js';
import {requireState} from '../../core/errors.js';
import {decodeCursor, encodeCursor} from '../../core/pagination.js';
import {OfferRepository, type OfferRecord} from './repository.js';
import {validateOffer} from './schema.js';
export class OfferService {
  private repo = new OfferRepository();
  constructor(private deps: Dependencies) {}
  async create(ctx: ServiceContext, value: unknown) {
    role(ctx, 'seller');
    const input = validateOffer(value, ctx.clock.now());
    return this.deps.db.transaction(async (tx) => {
      const p = (
        await tx.query('SELECT * FROM merchant_profiles WHERE user_id=$1 FOR SHARE', [ctx.actor.id])
      ).rows[0];
      requireState(
        p?.shop_name && p?.address && p.latitude !== null && p.longitude !== null,
        'PROFILE_INCOMPLETE',
        'Lengkapi profil gerai sebelum menerbitkan paket.',
      );
      const o = await this.repo.create(tx, ctx.actor.id, input, ctx.clock.now());
      await this.repo.audit(tx, ctx.actor.id, o.id, 'offer.created', ctx.clock.now());
      return o;
    });
  }
  private async mutable(tx: Tx, ctx: ServiceContext, id: string) {
    const o = await this.repo.lock(tx, id);
    requireState(
      o && o.seller_id === ctx.actor.id,
      'OFFER_NOT_FOUND',
      'Paket tidak ditemukan.',
      404,
    );
    requireState(
      o.quota_held === 0 && o.quota_sold === 0,
      'OFFER_RESERVED',
      'Paket sedang dipesan atau sudah dibayar.',
    );
    const paid = await tx.query(
      'SELECT id FROM orders WHERE offer_id=$1 AND paid_at IS NOT NULL LIMIT 1',
      [id],
    );
    requireState(!paid.rowCount, 'OFFER_PAID', 'Paket pernah dibayar dan tidak dapat diubah.');
    return o;
  }
  async update(ctx: ServiceContext, id: string, value: unknown) {
    role(ctx, 'seller');
    const input = validateOffer(value, ctx.clock.now());
    return this.deps.db.transaction(async (tx) => {
      const o = await this.mutable(tx, ctx, id);
      requireState(o.status === 'active', 'OFFER_CLOSED', 'Paket sudah ditutup.');
      const updated = await this.repo.update(tx, id, input);
      await this.repo.audit(tx, ctx.actor.id, id, 'offer.updated', ctx.clock.now());
      return updated;
    });
  }
  async close(ctx: ServiceContext, id: string) {
    role(ctx, 'seller');
    return this.deps.db.transaction(async (tx) => {
      const o = await this.mutable(tx, ctx, id);
      if (o.status === 'active') {
        await tx.query("UPDATE offers SET status='closed' WHERE id=$1", [id]);
        await this.repo.audit(tx, ctx.actor.id, id, 'offer.closed', ctx.clock.now());
      }
      return { ...o, status: 'closed' };
    });
  }
  async list(ctx: ServiceContext, query: { cursor?: string; limit?: number }) {
    role(ctx, 'seller');
    const c = decodeCursor(query.cursor);
    const limit = query.limit ?? 20;
    const rows = (
      await this.deps.db.query<OfferRecord>(
        'SELECT * FROM offers WHERE seller_id=$1 AND ($2::timestamptz IS NULL OR (created_at,id)<($2,$3::uuid)) ORDER BY created_at DESC,id DESC LIMIT $4',
        [ctx.actor.id, c?.at, c?.id, limit + 1],
      )
    ).rows;
    const items = rows.slice(0, limit);
    return {
      items,
      next_cursor: rows.length > limit ? encodeCursor(items[items.length - 1]!) : null,
    };
  }
  async detail(ctx: ServiceContext, id: string) {
    role(ctx, 'seller');
    const o = (
      await this.deps.db.query<OfferRecord>('SELECT * FROM offers WHERE id=$1 AND seller_id=$2', [
        id,
        ctx.actor.id,
      ])
    ).rows[0];
    requireState(o, 'OFFER_NOT_FOUND', 'Paket tidak ditemukan.', 404);
    return o;
  }
}