import type { Database } from '../../core/db.js';
export class MetricsRepository {
  constructor(private db: Database) {}
  async packagesSaved() {
    return (
      await this.db.query<{ n: number }>(
        "SELECT count(*)::int AS n FROM orders WHERE status='completed'",
      )
    ).rows[0]!.n;
  }
}
