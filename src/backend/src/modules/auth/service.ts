import bcrypt from 'bcrypt';
import jwt from 'jsonwebtoken';
import { randomUUID } from 'node:crypto';
import type { Actor, Dependencies, ServiceContext, Tx } from '../../core/contracts.js';
import { ApiError } from '../../core/errors.js';
import { hash, secretToken } from '../../core/crypto.js';
import { AuthRepository, userView, type UserRecord, type UserView } from './repository.js';
import type { RegisterInput, LoginInput } from './schema.js';
export type SessionBundle = {
  access_token: string;
  refresh_token: string;
  user: UserView;
  expires_at: string;
};
const unauthorized = () =>
  new ApiError(
    401,
    'UNAUTHORIZED',
    'Sesi berakhir atau kredensial tidak valid. Silakan masuk kembali.',
  );
export class AuthService {
  private repo = new AuthRepository();
  constructor(private deps: Dependencies) {}
  private async bundle(tx: Tx, u: UserRecord, family = randomUUID()): Promise<SessionBundle> {
    const now = this.deps.clock.now();
    const token = secretToken();
    const session = await this.repo.createSession(
      tx,
      u.id,
      family,
      hash(token),
      new Date(now.getTime() + 30 * 86400000),
      now,
    );
    const iat = Math.floor(now.getTime() / 1000);
    const access = jwt.sign(
      { sub: u.id, sid: session, iat, exp: iat + 900 },
      this.deps.config.ACCESS_SECRET,
      { algorithm: 'HS256', issuer: 'sisarasa', audience: 'sisarasa-app' },
    );
    return {
      access_token: access,
      refresh_token: token,
      user: userView(u),
      expires_at: new Date((iat + 900) * 1000).toISOString(),
    };
  }
  async register(input: RegisterInput) {
    const passwordHash = await bcrypt.hash(input.password, 12);
    return this.deps.db.transaction(async (tx) => {
      const u = await this.repo.createUser(tx, { ...input, hash: passwordHash });
      if (u.role === 'seller')
        await tx.query('INSERT INTO merchant_profiles(user_id) VALUES($1)', [u.id]);
      return this.bundle(tx, u);
    });
  }
  async login(input: LoginInput) {
    const u = (
      await this.deps.db.query<UserRecord>('SELECT * FROM users WHERE email=$1', [input.email])
    ).rows[0];
    // A valid cost-12 dummy hash keeps missing-account verification on the slow-hash path.
    const valid = await bcrypt.compare(
      input.password,
      u?.password_hash ?? '$2b$12$eImiTXuWVxfM37uY4JANjOa7BcuCtHiHPhSvCDGH6Slgn8Ro.uWem',
    );
    if (!u || !valid) throw unauthorized();
    return this.deps.db.transaction((tx) => this.bundle(tx, u));
  }
  async refresh(token: string) {
    const result = await this.deps.db.transaction(async (tx) => {
      // Serialize the entire family before locking one token: racing replay cannot
      // revoke an old family snapshot while a different member inserts a live session.
      const found = (
        await tx.query('SELECT family_id FROM sessions WHERE refresh_hash=$1', [hash(token)])
      ).rows[0];
      if (!found) return null;
      await tx.query('SELECT pg_advisory_xact_lock(hashtextextended($1,0))', [found.family_id]);
      const s = (
        await tx.query('SELECT * FROM sessions WHERE refresh_hash=$1 FOR UPDATE', [hash(token)])
      ).rows[0];
      const now = this.deps.clock.now();
      if (s.consumed_at || s.revoked_at || s.expires_at <= now) {
        await tx.query('UPDATE sessions SET revoked_at=$2 WHERE family_id=$1', [s.family_id, now]);
        await tx.query("SELECT pg_notify('sisarasa_sessions',$1)", [s.user_id]);
        return null;
      }
      await tx.query('UPDATE sessions SET consumed_at=$2 WHERE id=$1', [s.id, now]);
      const u = (await tx.query<UserRecord>('SELECT * FROM users WHERE id=$1', [s.user_id]))
        .rows[0]!;
      return this.bundle(tx, u, s.family_id);
    });
    // Reuse revocation must commit; throwing inside the transaction undoes it.
    if (!result) throw unauthorized();
    return result;
  }
  async authenticate(token: string): Promise<Actor> {
    let payload: jwt.JwtPayload;
    try {
      const result = jwt.verify(token, this.deps.config.ACCESS_SECRET, {
        algorithms: ['HS256'],
        issuer: 'sisarasa',
        audience: 'sisarasa-app',
        clockTimestamp: Math.floor(this.deps.clock.now().getTime() / 1000),
      });
      if (typeof result === 'string') throw unauthorized();
      payload = result;
    } catch {
      throw unauthorized();
    }
    if (typeof payload.sid !== 'string' || typeof payload.sub !== 'string') throw unauthorized();
    const row = (
      await this.deps.db.query(
        `SELECT u.id,u.role FROM sessions s JOIN users u ON u.id=s.user_id WHERE s.id=$1 AND s.user_id=$2 AND s.revoked_at IS NULL AND s.expires_at>$3`,
        [payload.sid, payload.sub, this.deps.clock.now()],
      )
    ).rows[0];
    if (!row) throw unauthorized();
    return { id: row.id, role: row.role, sessionId: payload.sid };
  }
  async logout(ctx: ServiceContext) {
    await this.deps.db.transaction(async (tx) => {
      const s = (
        await tx.query('SELECT family_id FROM sessions WHERE id=$1', [ctx.actor.sessionId])
      ).rows[0];
      if (s) {
        await tx.query('SELECT pg_advisory_xact_lock(hashtextextended($1,0))', [s.family_id]);
        await tx.query('UPDATE sessions SET revoked_at=$2 WHERE family_id=$1', [
          s.family_id,
          this.deps.clock.now(),
        ]);
        await tx.query("SELECT pg_notify('sisarasa_sessions',$1)", [ctx.actor.id]);
      }
    });
  }
  async me(ctx: ServiceContext) {
    return userView(
      (await this.deps.db.query<UserRecord>('SELECT * FROM users WHERE id=$1', [ctx.actor.id]))
        .rows[0]!,
    );
  }
  async allergens(ctx: ServiceContext, filters: string[]) {
    await this.deps.db.query('UPDATE users SET allergen_filters=$2 WHERE id=$1', [
      ctx.actor.id,
      filters,
    ]);
    return this.me(ctx);
  }
}
