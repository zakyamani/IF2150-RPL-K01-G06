import type { Dependencies } from './contracts.js';
import { ApiError } from './errors.js';
import { hmac } from './crypto.js';
export class RateLimiter {
  constructor(private deps: Dependencies) {}
  async take(key: string, limit: number, windowMs: number) {
    const now = this.deps.clock.now().getTime();
    const start = new Date(Math.floor(now / windowMs) * windowMs);
    const result = await this.deps.db.query(
      `INSERT INTO rate_buckets(key,window_start,attempts) VALUES($1,$2,1) ON CONFLICT(key,window_start) DO UPDATE SET attempts=rate_buckets.attempts+1 RETURNING attempts`,
      [hmac(key, this.deps.config.ACCESS_SECRET), start],
    );
    if (result.rows[0].attempts > limit)
      throw new ApiError(
        429,
        'RATE_LIMITED',
        'Terlalu banyak percobaan. Tunggu sebelum mencoba kembali.',
      );
  }
}
