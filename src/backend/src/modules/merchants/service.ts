import type { Dependencies, ServiceContext } from '../../core/contracts.js';
import { role } from '../../core/auth.js';
import { MerchantRepository, type MerchantProfile } from './repository.js';
import type { ProfileInput } from './schema.js';
export class MerchantService {
  private repo = new MerchantRepository();
  constructor(private deps: Dependencies) {}
  async update(ctx: ServiceContext, input: ProfileInput) {
    role(ctx, 'seller');
    return this.deps.db.transaction((tx) =>
      this.repo.update(
        tx,
        ctx.actor.id,
        {
          ...input,
          bank_masked: input.bank_destination
            ? '••••' + input.bank_destination.slice(-4)
            : undefined,
        },
        ctx.clock.now(),
      ),
    );
  }
  async me(ctx: ServiceContext) {
    role(ctx, 'seller');
    return (
      await this.deps.db.query<MerchantProfile>(
        'SELECT * FROM merchant_profiles WHERE user_id=$1',
        [ctx.actor.id],
      )
    ).rows[0]!;
  }
}
