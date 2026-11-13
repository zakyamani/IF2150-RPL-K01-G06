import type { Dependencies, Tx } from '../../core/contracts.js';
import { ApiError, requireState } from '../../core/errors.js';
import { ledger, orderEvent, scheduleJob } from '../../core/effects.js';
import { OrderRepository } from '../orders/repository.js';
import { OrderService } from '../orders/service.js';
import { PaymentService } from '../payments/service.js';
import { ComplaintService } from '../complaints/service.js';
import { ComplaintRepository } from '../complaints/repository.js';
import { MediaService } from '../media/service.js';
import { JobRepository, type JobRecord } from './repository.js';
export type JobSummary = { claimed: number; succeeded: number; retried: number; failed: number };
async function effect(deps: Dependencies, tx: Tx, job: JobRecord): Promise<Date | undefined> {
  const now = deps.clock.now();
  if (job.kind === 'cleanup') {
    await tx.query('DELETE FROM rate_buckets WHERE window_start<$1', [
      new Date(now.getTime() - 172800000),
    ]);
    await tx.query('DELETE FROM ws_tickets WHERE expires_at<$1', [
      new Date(now.getTime() - 86400000),
    ]);
    await tx.query('DELETE FROM idempotency_keys WHERE created_at<$1', [
      new Date(now.getTime() - 30 * 86400000),
    ]);
    await tx.query('DELETE FROM outbox WHERE published_at<$1', [
      new Date(now.getTime() - 7 * 86400000),
    ]);
    return new Date(now.getTime() + 86400000);
  }
  const orders = new OrderRepository();
  let orderId = job.resource_id;
  if (job.kind === 'closed_shop_refund') {
    const c = (
      await tx.query<{ order_id: string }>('SELECT order_id FROM complaints WHERE id=$1', [
        job.resource_id,
      ])
    ).rows[0];
    if (!c) return;
    orderId = c.order_id;
  }
  const { order: o } = await orders.lock(tx, orderId);
  switch (job.kind) {
    case 'expire_payment':
      if (now >= o.payment_deadline) await new PaymentService(deps).expire(tx, o, now);
      break;
    case 'no_show':
      await new OrderService(deps).processNoShow(tx, o, now);
      break;
    case 'closed_shop_refund': {
      const c = await new ComplaintRepository().lock(tx, job.resource_id);
      if (c) await new ComplaintService(deps).autoRefund(tx, c, o, now);
      break;
    }
    case 'settle_payout': {
      const p = (
        await tx.query('SELECT * FROM payout_entitlements WHERE order_id=$1 FOR UPDATE', [o.id])
      ).rows[0];
      if (!p || p.status !== 'pending' || !['completed', 'no_show'].includes(o.status)) break;
      if (now < p.due_at) return p.due_at;
      if (
        (await tx.query("SELECT id FROM complaints WHERE order_id=$1 AND status='open'", [o.id]))
          .rowCount
      )
        break;
      await tx.query("UPDATE payout_entitlements SET status='settled',settled_at=$2 WHERE id=$1", [
        p.id,
        now,
      ]);
      await tx.query(
        "INSERT INTO payout_events(entitlement_id,kind,created_at) VALUES($1,'settled',$2) ON CONFLICT DO NOTHING",
        [p.id, now],
      );
      await ledger(tx, o.id, 'payout_settled', p.net, now);
      await orderEvent(
        tx,
        o,
        'payout.settled',
        'Payout simulasi telah diselesaikan. Tidak ada transfer bank sungguhan.',
        now,
      );
      break;
    }
    default:
      throw new ApiError(503, 'UNKNOWN_JOB', 'Jenis pekerjaan tidak dikenal.');
  }
}
export async function ensureMaintenance(deps: Dependencies) {
  await deps.db.transaction((tx) =>
    scheduleJob(
      tx,
      'cleanup',
      '00000000-0000-4000-8000-000000000001',
      new Date(deps.clock.now().getTime() + 86400000),
    ),
  );
}
export async function runDueJobs(
  deps: Dependencies,
  options: { batchSize?: number; signal?: AbortSignal } = {},
): Promise<JobSummary> {
  const batch = options.batchSize ?? 25;
  requireState(
    Number.isInteger(batch) && batch >= 1 && batch <= 100,
    'INVALID_BATCH',
    'Ukuran batch tidak valid.',
    400,
  );
  const repo = new JobRepository(deps.db);
  const result: JobSummary = { claimed: 0, succeeded: 0, retried: 0, failed: 0 };
  for (let n = 0; n < batch && !options.signal?.aborted; n++) {
    const job = await repo.claim(deps.clock.now());
    if (!job) break;
    result.claimed++;
    try {
      // Filesystem cleanup is replay-safe and precedes transactional acknowledgement.
      if (job.kind === 'cleanup') await new MediaService(deps).cleanupOrphans(deps.clock.now());
      await deps.db.transaction(async (tx) => {
        const next = await effect(deps, tx, job);
        requireState(
          await repo.acknowledge(tx, job, next),
          'JOB_LEASE_LOST',
          'Lease pekerjaan telah berpindah.',
          503,
        );
      });
      result.succeeded++;
    } catch (e) {
      const code =
        e instanceof ApiError
          ? e.code
          : typeof (e as { code?: unknown }).code === 'string'
            ? (e as { code: string }).code
            : 'JOB_FAILED';
      if (await repo.retry(job, deps.clock.now(), code)) result.failed++;
      else result.retried++;
    }
  }
  return result;
}
