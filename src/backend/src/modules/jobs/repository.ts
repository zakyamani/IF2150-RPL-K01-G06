import { randomUUID } from 'node:crypto';
import type { Database } from '../../core/db.js';
import type { Tx } from '../../core/contracts.js';
export type JobRecord = {
  id: string;
  kind: string;
  resource_id: string;
  due_at: Date;
  status: 'pending' | 'running' | 'done' | 'failed';
  attempts: number;
  lease_until: Date | null;
  lease_token: string;
};
export class JobRepository {
  constructor(private db: Database) {}
  async claim(now: Date) {
    return this.db.transaction(
      async (tx) =>
        (
          await tx.query<JobRecord>(
            `WITH due AS (SELECT id FROM jobs WHERE (status='pending' AND due_at<=$1) OR (status='running' AND lease_until<=$1) ORDER BY due_at,id FOR UPDATE SKIP LOCKED LIMIT 1) UPDATE jobs j SET status='running',attempts=j.attempts+1,lease_until=$2,lease_token=$3 FROM due WHERE j.id=due.id RETURNING j.*`,
            [now, new Date(now.getTime() + 30000), randomUUID()],
          )
        ).rows[0],
    );
  }
  async acknowledge(tx: Tx, job: JobRecord, reschedule?: Date) {
    return (
      (
        await tx.query(
          "UPDATE jobs SET status=$3,lease_until=NULL,lease_token=NULL,last_error=NULL,due_at=COALESCE($4,due_at) WHERE id=$1 AND lease_token=$2 AND status='running' RETURNING id",
          [job.id, job.lease_token, reschedule ? 'pending' : 'done', reschedule],
        )
      ).rowCount === 1
    );
  }
  async retry(job: JobRecord, now: Date, errorCode: string) {
    const failed = job.attempts >= 10;
    const delay = Math.min(300000, 5000 * 2 ** (job.attempts - 1));
    await this.db.query(
      'UPDATE jobs SET status=$3,due_at=$4,lease_until=NULL,lease_token=NULL,last_error=$5 WHERE id=$1 AND lease_token=$2',
      [
        job.id,
        job.lease_token,
        failed ? 'failed' : 'pending',
        new Date(now.getTime() + delay),
        errorCode.slice(0, 100),
      ],
    );
    return failed;
  }
}
