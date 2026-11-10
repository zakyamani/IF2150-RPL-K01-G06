import type {Dependencies, ServiceContext} from '../../core/contracts.js';
import {role} from '../../core/auth.js';
import {requireState} from '../../core/errors.js';
import {decodeCursor, encodeCursor} from '../../core/pagination.js';
import {disclaimer} from '../../core/labels.js';
import {CatalogRepository, type CatalogRecord} from './repository.js';
export type CatalogQuery = {
  cursor?: string;
  limit?: number;
  lat?: number;
  lng?: number;
  category?: string;
};
function distance(lat: number, lng: number, r: CatalogRecord) {
  const radians = (n: number) => (n * Math.PI) / 180;
  const a =
    Math.sin(radians(r.latitude - lat) / 2) ** 2 +
    Math.cos(radians(lat)) *
      Math.cos(radians(r.latitude)) *
      Math.sin(radians(r.longitude - lng) / 2) ** 2;
  return Math.round(6371 * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(Math.max(0, 1 - a))) * 10) / 10;
}
function view(o: CatalogRecord, q: CatalogQuery) {
  return {
    id: o.id,
    category: o.category,
    allergens: o.allergens,
    quota_available: o.quota_available,
    normal_price: o.normal_price,
    discount_price: o.discount_price,
    discount_percent: Math.round((1 - o.discount_price / o.normal_price) * 1000) / 10,
    pickup_start: o.pickup_start,
    pickup_end: o.pickup_end,
    safe_eat_until: o.safe_eat_until,
    distance_km: q.lat !== undefined && q.lng !== undefined ? distance(q.lat, q.lng, o) : null,
    disclaimer,
    created_at: o.created_at,
  };
}
export class CatalogService {
  private repo = new CatalogRepository();
  constructor(private deps: Dependencies) {}
  async list(ctx: ServiceContext, q: CatalogQuery) {
    role(ctx, 'buyer');
    const c = decodeCursor(q.cursor);
    const limit = q.limit ?? 20;
    const rows = await this.deps.db.transaction((tx) =>
      this.repo.read(tx, ctx.actor.id, ctx.clock.now(), {
        at: c?.at,
        cursorId: c?.id,
        limit: limit + 1,
        category: q.category,
      }),
    );
    const items = rows.slice(0, limit);
    return {
      items: items.map((o) => view(o, q)),
      next_cursor: rows.length > limit ? encodeCursor(items[items.length - 1]!) : null,
      disclaimer,
    };
  }
  async detail(ctx: ServiceContext, id: string, q: CatalogQuery) {
    role(ctx, 'buyer');
    const rows = await this.deps.db.transaction((tx) =>
      this.repo.read(tx, ctx.actor.id, ctx.clock.now(), { id, limit: 1 }),
    );
    requireState(
      rows[0],
      'OFFER_NOT_FOUND',
      'Paket tidak tersedia atau tersembunyi oleh filter alergen.',
      404,
    );
    return view(rows[0], q);
  }
}