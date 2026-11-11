import { Router } from 'express';
import type { Dependencies } from '../../core/contracts.js';
import { authenticated, context } from '../../core/auth.js';
import { asyncRoute } from '../../core/http.js';
import { RateLimiter } from '../../core/rate-limit.js';
import { PickupService } from './service.js';
import { pickupSchema } from './schema.js';
export function pickupRoutes(deps: Dependencies) {
  const r = Router();
  const s = new PickupService(deps);
  const limiter = new RateLimiter(deps);
  r.use(authenticated(deps));
  r.post(
    '/validate',
    asyncRoute(async (req, res) => {
      const ctx = context(res, deps);
      await limiter.take(`pickup-ip:${req.ip}`, 60, 60000);
      await limiter.take(`pickup-actor:${ctx.actor.id}`, 30, 60000);
      res.json(await s.validate(ctx, pickupSchema.parse(req.body)));
    }),
  );
  return r;
}
