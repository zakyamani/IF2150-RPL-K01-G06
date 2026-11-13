import { Router } from 'express';
import { z } from 'zod';
import type { Dependencies } from '../../core/contracts.js';
import { authenticated, context } from '../../core/auth.js';
import { asyncRoute } from '../../core/http.js';
import { RateLimiter } from '../../core/rate-limit.js';
import { OrderService } from './service.js';
import { checkoutSchema, keySchema, orderQuerySchema, cancelSchema } from './schema.js';
export function orderRoutes(deps: Dependencies) {
  const r = Router();
  const s = new OrderService(deps);
  const limiter = new RateLimiter(deps);
  r.use(authenticated(deps));
  r.post(
    '/checkout',
    asyncRoute(async (req, res) => {
      const ctx = context(res, deps);
      await limiter.take(`checkout:${ctx.actor.id}`, 60, 60000);
      res
        .status(201)
        .json(
          await s.checkout(
            ctx,
            checkoutSchema.parse(req.body),
            keySchema.parse(req.get('Idempotency-Key')),
          ),
        );
    }),
  );
  r.get(
    '/',
    asyncRoute(async (req, res) =>
      res.json(await s.list(context(res, deps), orderQuerySchema.parse(req.query))),
    ),
  );
  r.get(
    '/:id',
    asyncRoute(async (req, res) =>
      res.json(await s.detail(context(res, deps), z.uuid().parse(req.params.id))),
    ),
  );
  r.post(
    '/:id/cancel',
    asyncRoute(async (req, res) =>
      res.json(
        await s.cancelBySeller(
          context(res, deps),
          z.uuid().parse(req.params.id),
          keySchema.parse(req.get('Idempotency-Key')),
          cancelSchema.parse(req.body ?? {}).reason,
        ),
      ),
    ),
  );
  return r;
}
