import type { ServiceContext, Tx } from '../../core/contracts.js';
export type MediaRecord = {
  id: string;
  user_id: string;
  kind: 'shop' | 'evidence';
  path: string;
  mime: string;
  sha256: string;
  bytes: number;
  state: 'staged' | 'attached';
  created_at: Date;
};
export class MediaRepository {
  async insert(tx: Tx, m: MediaRecord) {
    await tx.query(
      'INSERT INTO media_assets(id,user_id,kind,path,mime,sha256,bytes,state,created_at) VALUES($1,$2,$3,$4,$5,$6,$7,$8,$9)',
      [m.id, m.user_id, m.kind, m.path, m.mime, m.sha256, m.bytes, m.state, m.created_at],
    );
  }
  async authorized(tx: Tx, ctx: ServiceContext, id: string) {
    return (
      await tx.query<MediaRecord>(
        `SELECT m.* FROM media_assets m WHERE m.id=$1 AND (
 m.user_id=$2 OR (m.kind='shop' AND EXISTS(SELECT 1 FROM orders o WHERE o.buyer_id=$2 AND o.paid_at IS NOT NULL AND o.snapshot->'merchant'->>'photo_id'=m.id::text))
 OR (m.kind='evidence' AND EXISTS(SELECT 1 FROM complaint_media cm JOIN complaints c ON c.id=cm.complaint_id JOIN orders o ON o.id=c.order_id WHERE cm.media_id=m.id AND (o.buyer_id=$2 OR o.seller_id=$2)))
 )`,
        [id, ctx.actor.id],
      )
    ).rows[0];
  }
}
