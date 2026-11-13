import sharp from 'sharp';
import { randomUUID } from 'node:crypto';
import type { Dependencies, ServiceContext, Tx } from '../../core/contracts.js';
import { ApiError, requireState } from '../../core/errors.js';
import { role } from '../../core/auth.js';
import { hash } from '../../core/crypto.js';
import { LocalMediaStorage, type MediaStorage } from '../../core/media-storage.js';
import { MediaRepository, type MediaRecord } from './repository.js';
export type PreparedMedia = MediaRecord;
export class MediaService {
  private repo = new MediaRepository();
  private storage: MediaStorage;
  constructor(
    private deps: Dependencies,
    storage?: MediaStorage,
  ) {
    this.storage = storage ?? new LocalMediaStorage(deps.config.MEDIA_DIR);
  }
  async prepareUpload(
    ctx: ServiceContext,
    kind: 'shop' | 'evidence',
    bytes: Buffer,
    mime?: string,
  ): Promise<PreparedMedia> {
    if (kind === 'shop') role(ctx, 'seller');
    else role(ctx, 'buyer');
    if (bytes.length > 2097152) throw new ApiError(413, 'MEDIA_TOO_LARGE', 'Foto maksimal 2 MB.');
    let output: Buffer;
    try {
      const image = sharp(bytes, { limitInputPixels: 16000000, failOn: 'warning' });
      const meta = await image.metadata();
      const actual =
        meta.format === 'jpeg'
          ? 'image/jpeg'
          : meta.format === 'png'
            ? 'image/png'
            : meta.format === 'webp'
              ? 'image/webp'
              : null;
      if (!actual || (mime && actual !== mime) || (meta.pages ?? 1) > 1)
        throw new Error('Invalid image');
      output = await image
        .rotate()
        .resize({ width: 1280, height: 1280, fit: 'inside', withoutEnlargement: true })
        .webp({ quality: 82 })
        .toBuffer();
    } catch {
      throw new ApiError(
        400,
        'INVALID_IMAGE',
        'Gunakan foto JPEG, PNG, atau WebP yang valid, maksimal 16 juta pixel.',
      );
    }
    const id = randomUUID();
    const path = `${id}.webp`;
    const temp = `${id}.tmp`;
    try {
      await this.storage.write(temp, output);
      await this.storage.commit(temp, path);
    } catch {
      await Promise.allSettled([this.storage.remove(temp), this.storage.remove(path)]);
      throw new ApiError(503, 'MEDIA_UNAVAILABLE', 'Penyimpanan foto sementara tidak tersedia.');
    }
    return {
      id,
      user_id: ctx.actor.id,
      kind,
      path,
      mime: 'image/webp',
      sha256: hash(output),
      bytes: output.length,
      state: 'staged',
      created_at: ctx.clock.now(),
    };
  }
  async upload(ctx: ServiceContext, kind: 'shop' | 'evidence', bytes: Buffer, mime?: string) {
    const prepared = await this.prepareUpload(ctx, kind, bytes, mime);
    try {
      await this.deps.db.transaction((tx) => this.repo.insert(tx, prepared));
      return { id: prepared.id, mime: prepared.mime, bytes: prepared.bytes };
    } catch (e) {
      await this.storage.remove(prepared.path).catch(() => {});
      throw e;
    }
  }
  async attach(
    tx: Tx,
    prepared: Pick<PreparedMedia, 'id' | 'user_id' | 'kind'>,
    _ownerResource: string,
  ) {
    const row = (
      await tx.query<MediaRecord>('SELECT * FROM media_assets WHERE id=$1 FOR UPDATE', [
        prepared.id,
      ])
    ).rows[0];
    requireState(
      row && row.user_id === prepared.user_id && row.kind === prepared.kind,
      'MEDIA_NOT_FOUND',
      'Foto tidak ditemukan.',
      404,
    );
    requireState(row.state === 'staged', 'MEDIA_ALREADY_ATTACHED', 'Foto sudah digunakan.');
    await tx.query("UPDATE media_assets SET state='attached' WHERE id=$1", [row.id]);
    return row.id;
  }
  async setShopPhoto(ctx: ServiceContext, id: string) {
    role(ctx, 'seller');
    return this.deps.db.transaction(async (tx) => {
      await tx.query('SELECT user_id FROM merchant_profiles WHERE user_id=$1 FOR UPDATE', [
        ctx.actor.id,
      ]);
      await this.attach(tx, { id, user_id: ctx.actor.id, kind: 'shop' }, ctx.actor.id);
      await tx.query('UPDATE merchant_profiles SET photo_id=$2,updated_at=$3 WHERE user_id=$1', [
        ctx.actor.id,
        id,
        ctx.clock.now(),
      ]);
      return { photo_id: id };
    });
  }
  async read(ctx: ServiceContext, id: string) {
    const row = await this.deps.db.transaction((tx) => this.repo.authorized(tx, ctx, id));
    if (!row) throw new ApiError(404, 'MEDIA_NOT_FOUND', 'Foto tidak ditemukan.');
    try {
      return { mime: row.mime, bytes: await this.storage.read(row.path) };
    } catch {
      throw new ApiError(503, 'MEDIA_UNAVAILABLE', 'Foto sementara tidak tersedia.');
    }
  }
  async cleanupOrphans(now: Date) {
    const cutoff = new Date(now.getTime() - 86400000);
    const deleted = await this.deps.db.transaction(async (tx) => {
      const rows = (
        await tx.query<MediaRecord>(
          "SELECT * FROM media_assets WHERE state='staged' AND created_at<$1 FOR UPDATE SKIP LOCKED",
          [cutoff],
        )
      ).rows;
      for (const r of rows) await tx.query('DELETE FROM media_assets WHERE id=$1', [r.id]);
      return rows;
    });
    for (const r of deleted) await this.storage.remove(r.path);
    const referenced = new Set(
      (await this.deps.db.query<{ path: string }>('SELECT path FROM media_assets')).rows.map(
        (r) => r.path,
      ),
    );
    for (const f of await this.storage.list())
      if (f.modified < cutoff && !referenced.has(f.name)) await this.storage.remove(f.name);
    return deleted.length;
  }
}
