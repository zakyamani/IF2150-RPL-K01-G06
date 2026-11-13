import type { Tx } from './contracts.js';
export async function audit(
  tx: Tx,
  actor: string | null,
  resource: string,
  action: string,
  now: Date,
  details: Record<string, unknown> = {},
) {
  await tx.query(
    'INSERT INTO audit_logs(actor_id,resource_id,action,occurred_at,details) VALUES($1,$2,$3,$4,$5)',
    [actor, resource, action, now, details],
  );
}
export async function notify(
  tx: Tx,
  user: string,
  resource: string,
  type: string,
  summary: string,
  now: Date,
) {
  // A cursor must follow commit visibility, not just bigserial allocation.
  // Keep this recipient's writers serialized until the enclosing transaction commits.
  await tx.query('SELECT pg_advisory_xact_lock(hashtextextended($1,0))', [`inbox:${user}`]);
  const row = (
    await tx.query<{ id: string }>(
      'INSERT INTO notifications(user_id,resource_id,type,summary,occurred_at) VALUES($1,$2,$3,$4,$5) RETURNING id',
      [user, resource, type, summary, now],
    )
  ).rows[0]!;
  await tx.query('INSERT INTO outbox(notification_id,next_attempt) VALUES($1,$2)', [row.id, now]);
}
export async function orderEvent(
  tx: Tx,
  order: { id: string; buyer_id: string; seller_id: string },
  type: string,
  summary: string,
  now: Date,
  actor: string | null = null,
) {
  // Acquire all recipient locks in a stable order before either insert.
  for (const user of [...new Set([order.buyer_id, order.seller_id])].sort()) {
    await tx.query('SELECT pg_advisory_xact_lock(hashtextextended($1,0))', [`inbox:${user}`]);
  }
  await audit(tx, actor, order.id, type, now);
  await notify(tx, order.buyer_id, order.id, type, summary, now);
  await notify(tx, order.seller_id, order.id, type, summary, now);
}
export async function scheduleJob(tx: Tx, kind: string, id: string, due: Date) {
  await tx.query(
    'INSERT INTO jobs(kind,resource_id,due_at) VALUES($1,$2,$3) ON CONFLICT(kind,resource_id) DO NOTHING',
    [kind, id, due],
  );
}
export async function ledger(tx: Tx, order: string, kind: string, amount: number, now: Date) {
  await tx.query(
    'INSERT INTO ledger_entries(order_id,kind,amount,created_at) VALUES($1,$2,$3,$4) ON CONFLICT(order_id,kind) DO NOTHING',
    [order, kind, amount, now],
  );
}
