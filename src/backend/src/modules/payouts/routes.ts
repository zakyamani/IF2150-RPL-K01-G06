import { Router } from 'express';
import { z } from 'zod';
import type { Dependencies } from '../../core/contracts.js';
import { authenticated, context } from '../../core/auth.js';
import { asyncRoute } from '../../core/http.js';
import { pageSchema } from '../../core/pagination.js';
import { PayoutService } from './service.js';
export function payoutRoutes(deps: Dependencies) {
  const r = Router();
  const s = new PayoutService(deps);
  r.use(authenticated(deps));
  r.get(
    '/summary',
    asyncRoute(async (_req, res) => res.json(await s.summary(context(res, deps)))),
  );
  r.get(
    '/',
    asyncRoute(async (req, res) =>
      res.json(
        await s.list(
          context(res, deps),
          pageSchema
            .extend({ status: z.enum(['pending', 'held', 'settled', 'cancelled']).optional() })
            .strict()
            .parse(req.query),
        ),
      ),
    ),
  );
  return r;
}
