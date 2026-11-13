import { randomUUID } from 'node:crypto';
import type { fixture } from './fixture.js';
import { AuthService } from '../../src/modules/auth/service.js';
export type Fixture = Awaited<ReturnType<typeof fixture>>;
export async function account(f: Fixture, role: 'buyer' | 'seller') {
  const bundle = await new AuthService(f.deps).register({
    email: `${randomUUID()}@example.test`,
    password: 'Testing-password-2026',
    name: role === 'seller' ? 'Gerai Uji' : 'Pembeli Uji',
    role,
  });
  return {
    ...bundle,
    actor: {
      id: bundle.user.id,
      role,
      sessionId: (await new AuthService(f.deps).authenticate(bundle.access_token)).sessionId,
    },
    ctx: { actor: await new AuthService(f.deps).authenticate(bundle.access_token), clock: f.clock },
  };
}
