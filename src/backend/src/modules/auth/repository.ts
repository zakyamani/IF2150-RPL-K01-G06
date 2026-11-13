import type { Tx } from '../../core/contracts.js';
export type UserRecord = {
  id: string;
  email: string;
  password_hash: string;
  role: 'buyer' | 'seller';
  name: string;
  allergen_filters: string[];
  created_at: Date;
};
export type UserView = Omit<UserRecord, 'password_hash' | 'created_at'>;
export function userView(u: UserRecord): UserView {
  return {
    id: u.id,
    email: u.email,
    role: u.role,
    name: u.name,
    allergen_filters: u.allergen_filters,
  };
}
export class AuthRepository {
  async createUser(tx: Tx, input: { email: string; hash: string; name: string; role: string }) {
    return (
      await tx.query<UserRecord>(
        'INSERT INTO users(email,password_hash,name,role) VALUES($1,$2,$3,$4) RETURNING *',
        [input.email, input.hash, input.name, input.role],
      )
    ).rows[0]!;
  }
  async createSession(
    tx: Tx,
    userId: string,
    familyId: string,
    tokenHash: string,
    expires: Date,
    now: Date,
  ) {
    return (
      await tx.query<{ id: string }>(
        'INSERT INTO sessions(user_id,family_id,refresh_hash,expires_at,created_at) VALUES($1,$2,$3,$4,$5) RETURNING id',
        [userId, familyId, tokenHash, expires, now],
      )
    ).rows[0]!.id;
  }
}
