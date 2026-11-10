import {Router} from 'express';
import {z} from 'zod';
import type {Dependencies} from '../../core/contracts.js';
import {authenticated, context} from '../../core/auth.js';
import {asyncRoute} from '../../core/http.js';
import {pageSchema} from '../../core/pagination.js';
import {OfferService} from './service.js';
export function offerRoutes(deps: Dependencies) {
  const r = Router();
  const s = new OfferService(deps);
  r.use(authenticated(deps));
  r.get(
    '/',
    asyncRoute(async (req, res) =>
      res.json(await s.list(context(res, deps), pageSchema.strict().parse(req.query))),
    ),
  );
  r.post(
    '/',
    asyncRoute(async (req, res) =>
      res.status(201).json(await s.create(context(res, deps), req.body)),
    ),
  );
  r.get(
    '/:id',
    asyncRoute(async (req, res) =>
      res.json(await s.detail(context(res, deps), z.uuid().parse(req.params.id))),
    ),
  );
  r.patch(
    '/:id',
    asyncRoute(async (req, res) =>
      res.json(await s.update(context(res, deps), z.uuid().parse(req.params.id), req.body)),
    ),
  );
  r.post(
    '/:id/close',
    asyncRoute(async (req, res) =>
      res.json(await s.close(context(res, deps), z.uuid().parse(req.params.id))),
    ),
  );
  return r;
}