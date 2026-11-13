import { Router } from 'express';
import { z } from 'zod';
import type { Dependencies } from '../../core/contracts.js';
import { authenticated, context } from '../../core/auth.js';
import { asyncRoute } from '../../core/http.js';
import { pageSchema } from '../../core/pagination.js';
import { ReviewService } from './service.js';
import { reviewSchema } from './schema.js';
export function reviewRoutes(deps: Dependencies) {
  const r = Router();
  const s = new ReviewService(deps);
  r.use(authenticated(deps));
  r.post(
    '/',
    asyncRoute(async (req, res) =>
      res.status(201).json(await s.create(context(res, deps), reviewSchema.parse(req.body))),
    ),
  );
  r.get(
    '/merchant/:id',
    asyncRoute(async (req, res) =>
      res.json(
        await s.listRevealed(
          context(res, deps),
          z.uuid().parse(req.params.id),
          pageSchema.strict().parse(req.query),
        ),
      ),
    ),
  );
  return r;
}
