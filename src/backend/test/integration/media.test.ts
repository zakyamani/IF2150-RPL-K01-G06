import { test } from 'node:test';
import assert from 'node:assert/strict';
import sharp from 'sharp';
import { randomUUID } from 'node:crypto';
import { fixture } from '../helpers/fixture.js';
import { account } from '../helpers/accounts.js';

test('disk-full failure returns unavailable without a committed media reference', async () => {
  const f = await fixture();
  try {
    const { MediaService } = await import('../../src/modules/media/service.js');
    const { LocalMediaStorage } = await import('../../src/core/media-storage.js');
    const buyer = await account(f, 'buyer');
    class FullDisk extends LocalMediaStorage {
      override async write(_name: string, _data: Buffer): Promise<void> {
        throw Object.assign(new Error('Full'), { code: 'ENOSPC' });
      }
    }
    const s = new MediaService(f.deps, new FullDisk(f.config.MEDIA_DIR));
    const bytes = await sharp({ create: { width: 10, height: 10, channels: 3, background: 'red' } })
      .webp()
      .toBuffer();
    await assert.rejects(
      s.upload(buyer.ctx, 'evidence', bytes, 'image/webp'),
      (e: any) => e.status === 503,
    );
    assert.equal((await f.db.query('SELECT count(*)::int AS n FROM media_assets')).rows[0].n, 0);
  } finally {
    await f.close();
  }
});

test('private shop images normalize metadata and require paid reveal rights', async () => {
  const f = await fixture();
  try {
    const seller = await account(f, 'seller');
    const buyer = await account(f, 'buyer');
    const other = await account(f, 'buyer');
    const image = await sharp({
      create: { width: 1600, height: 800, channels: 3, background: '#ffbb44' },
    })
      .jpeg()
      .withMetadata()
      .toBuffer();
    const upload = await f.request
      .post('/api/v1/media')
      .auth(seller.access_token, { type: 'bearer' })
      .field('kind', 'shop')
      .attach('file', image, { filename: '../../photo.jpg', contentType: 'image/jpeg' });
    assert.equal(upload.status, 201);
    const id = upload.body.id;
    assert.equal(
      (
        await f.request
          .patch('/api/v1/merchant/photo')
          .auth(seller.access_token, { type: 'bearer' })
          .send({ media_id: id })
      ).status,
      200,
    );
    const own = await f.request
      .get(`/api/v1/media/${id}`)
      .auth(seller.access_token, { type: 'bearer' });
    assert.equal(own.status, 200);
    const meta = await sharp(own.body).metadata();
    assert.equal(meta.width, 1280);
    assert.equal(meta.height, 640);
    assert.equal(meta.exif, undefined);
    assert.equal(
      (await f.request.get(`/api/v1/media/${id}`).auth(buyer.access_token, { type: 'bearer' }))
        .status,
      404,
    );
    const offer = (
      await f.db.query(
        `INSERT INTO offers(seller_id,category,quota_total,quota_available,normal_price,discount_price,pickup_start,pickup_end,safe_eat_until,fitness_confirmed) VALUES($1,'campuran',1,1,100000,40000,$2,$3,$3,true) RETURNING id`,
        [seller.user.id, f.clock.now(), new Date(f.clock.now().getTime() + 3600000)],
      )
    ).rows[0];
    await f.db.query(
      `INSERT INTO orders(code,invoice,offer_id,buyer_id,seller_id,status,price,fee,fee_bps,snapshot,payment_deadline,pickup_start,pickup_end,safe_eat_until,paid_at) VALUES($1,$2,$3,$4,$5,'paid',40000,2000,500,$6,$7,$7,$8,$8,$7)`,
      [
        'SR-MEDIA12345',
        randomUUID(),
        offer.id,
        buyer.user.id,
        seller.user.id,
        { merchant: { photo_id: id } },
        f.clock.now(),
        new Date(f.clock.now().getTime() + 3600000),
      ],
    );
    assert.equal(
      (await f.request.get(`/api/v1/media/${id}`).auth(buyer.access_token, { type: 'bearer' }))
        .status,
      200,
    );
    assert.equal(
      (await f.request.get(`/api/v1/media/${id}`).auth(other.access_token, { type: 'bearer' }))
        .status,
      404,
    );
  } finally {
    await f.close();
  }
});
test('upload rejects spoofed MIME, SVG, huge bytes/pixels and foreign evidence', async () => {
  const f = await fixture();
  try {
    const buyer = await account(f, 'buyer');
    const other = await account(f, 'buyer');
    const png = await sharp({ create: { width: 20, height: 20, channels: 3, background: 'red' } })
      .png()
      .toBuffer();
    const post = (bytes: Buffer, mime: string) =>
      f.request
        .post('/api/v1/media')
        .auth(buyer.access_token, { type: 'bearer' })
        .field('kind', 'evidence')
        .attach('file', bytes, { filename: 'image', contentType: mime });
    assert.equal((await post(png, 'image/jpeg')).status, 400);
    assert.equal(
      (
        await post(
          Buffer.from('<svg xmlns="http://www.w3.org/2000/svg" width="10" height="10"/>'),
          'image/svg+xml',
        )
      ).status,
      400,
    );
    assert.equal((await post(Buffer.alloc(2097153), 'image/png')).status, 413);
    const huge = await sharp({
      create: { width: 4001, height: 4001, channels: 3, background: 'blue' },
    })
      .png()
      .toBuffer();
    assert.equal((await post(huge, 'image/png')).status, 400);
    const good = await post(png, 'image/png');
    assert.equal(good.status, 201);
    assert.equal(
      (
        await f.request
          .get(`/api/v1/media/${good.body.id}`)
          .auth(other.access_token, { type: 'bearer' })
      ).status,
      404,
    );
    assert.equal(
      (
        await f.request
          .get('/api/v1/media/..%2F..%2F.env')
          .auth(buyer.access_token, { type: 'bearer' })
      ).status,
      400,
    );
  } finally {
    await f.close();
  }
});

test('PNG/WebP normalize successfully and staged orphans are retained for 24 hours', async () => {
  const { MediaService } = await import('../../src/modules/media/service.js');
  const f = await fixture();
  try {
    const buyer = await account(f, 'buyer');
    const service = new MediaService(f.deps);
    for (const format of ['png', 'webp'] as const) {
      const bytes = await sharp({
        create: { width: 40, height: 20, channels: 3, background: 'green' },
      })
        [format]()
        .toBuffer();
      const media = await service.upload(buyer.ctx, 'evidence', bytes, `image/${format}`);
      const actual = await service.read(buyer.ctx, media.id);
      const meta = await sharp(actual.bytes).metadata();
      assert.equal(meta.format, 'webp');
      assert.equal(meta.width, 40);
    }
    assert.equal(await service.cleanupOrphans(new Date(f.clock.now().getTime() + 23 * 3600000)), 0);
    assert.equal(await service.cleanupOrphans(new Date(f.clock.now().getTime() + 25 * 3600000)), 2);
    assert.equal((await f.db.query('SELECT count(*)::int AS n FROM media_assets')).rows[0].n, 0);
  } finally {
    await f.close();
  }
});
