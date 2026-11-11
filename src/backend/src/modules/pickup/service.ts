import { randomInt } from 'node:crypto';
import type { Dependencies, Tx, ServiceContext } from '../../core/contracts.js';
import { encrypt, decrypt, secretToken, hash, safeEqual } from '../../core/crypto.js';
import { role } from '../../core/auth.js';
import { ApiError, requireState } from '../../core/errors.js';
import { orderEvent } from '../../core/effects.js';
import { OrderRepository } from '../orders/repository.js';
import { PayoutService } from '../payouts/service.js';
import { PickupRepository } from './repository.js';
import { pickupSchema, type PickupInput } from './schema.js';
export type PickupCredential = { qr: string; otp: string };
export class PickupService {
  constructor(private deps: Dependencies) {}
  async issue(tx: Tx, orderId: string): Promise<PickupCredential> {
    const token = secretToken();
    const otp = randomInt(0, 1000000).toString().padStart(6, '0');
    await tx.query(
      'INSERT INTO pickup_credentials(order_id,token_hash,encrypted_data) VALUES($1,$2,$3)',
      [orderId, hash(token), encrypt({ token, otp }, this.deps.config.PICKUP_KEY)],
    );
    return { qr: `sisarasa:v1:${orderId}:${token}`, otp };
  }
  async credential(tx: Tx, id: string) {
    const row = (
      await tx.query(
        'SELECT encrypted_data FROM pickup_credentials WHERE order_id=$1 AND used_at IS NULL AND disabled_at IS NULL',
        [id],
      )
    ).rows[0];
    if (!row) return undefined;
    const data = decrypt<{ token: string; otp: string }>(
      row.encrypted_data,
      this.deps.config.PICKUP_KEY,
    );
    return { qr: `sisarasa:v1:${id}:${data.token}`, otp: data.otp };
  }
  async validate(
    ctx: ServiceContext,
    value: PickupInput,
  ): Promise<{ order_id: string; code: string; status: 'completed'; completed_at: Date }> {
    role(ctx, 'seller');
    const input = pickupSchema.parse(value);
    let qr: RegExpExecArray | null = null;
    if (input.kind === 'qr') {
      qr = /^sisarasa:v1:([a-f0-9-]{36}):([A-Za-z0-9_-]{43})$/.exec(input.value);
      requireState(qr, 'INVALID_QR', 'QR pickup tidak valid.', 400);
    }
    const result = await this.deps.db.transaction(async (tx) => {
      const found = (
        await tx.query<{ id: string }>('SELECT id FROM orders WHERE id::text=$1 OR code=$1', [
          input.order_id,
        ])
      ).rows[0];
      requireState(found, 'ORDER_NOT_FOUND', 'Pesanan tidak ditemukan.', 404);
      const { order: o } = await new OrderRepository().lock(tx, found.id);
      requireState(
        o.seller_id === ctx.actor.id,
        'ORDER_NOT_FOUND',
        'Pesanan tidak ditemukan.',
        404,
      );
      requireState(
        o.status === 'paid',
        'PICKUP_STATE_CONFLICT',
        'Pesanan tidak dapat diambil atau sudah tervalidasi.',
      );
      const now = ctx.clock.now();
      requireState(now >= o.pickup_start, 'PICKUP_NOT_STARTED', 'Jadwal pickup belum dimulai.');
      requireState(now < o.pickup_end, 'PICKUP_EXPIRED', 'Jadwal pickup sudah berakhir.', 410);
      const repo = new PickupRepository();
      const credential = await repo.lock(tx, o.id);
      requireState(
        credential && !credential.used_at && !credential.disabled_at,
        'PICKUP_DISABLED',
        'Kode pickup tidak dapat digunakan.',
      );
      if (input.kind === 'otp') {
        const reset =
          !credential.attempt_window ||
          now.getTime() - credential.attempt_window.getTime() >= 900000;
        const attempts = reset ? 0 : credential.attempts;
        const start = reset ? now : credential.attempt_window!;
        if (attempts >= 5)
          return {
            error: new ApiError(
              429,
              'OTP_LOCKED',
              'Batas percobaan OTP tercapai. Tunggu 15 menit atau gunakan QR.',
            ),
          };
        const data = decrypt<{ token: string; otp: string }>(
          credential.encrypted_data,
          this.deps.config.PICKUP_KEY,
        );
        if (!safeEqual(data.otp, input.value)) {
          await repo.wrongAttempt(tx, o.id, attempts + 1, start);
          return { error: new ApiError(400, 'INVALID_PICKUP', 'Kode pickup tidak valid.') };
        }
      } else
        requireState(
          qr![1] === o.id && safeEqual(hash(qr![2]!), credential.token_hash),
          'INVALID_PICKUP',
          'Kode pickup tidak valid.',
          400,
        );
      await tx.query('UPDATE pickup_credentials SET used_at=$2 WHERE order_id=$1', [o.id, now]);
      await tx.query(
        "UPDATE orders SET status='completed',completed_at=$2,updated_at=$2 WHERE id=$1",
        [o.id, now],
      );
      await new PayoutService(this.deps).schedule(tx, o.id, 'completed', now);
      await orderEvent(
        tx,
        o,
        'pickup.completed',
        'Paket telah diserahkan; payout simulasi dijadwalkan.',
        now,
        ctx.actor.id,
      );
      return {
        value: { order_id: o.id, code: o.code, status: 'completed' as const, completed_at: now },
      };
    });
    if (result.error) throw result.error;
    return result.value!;
  }
}
