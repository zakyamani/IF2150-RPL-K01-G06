import { Router } from 'express';
import { z } from 'zod';
import type { Dependencies } from '../../core/contracts.js';
import { authenticated, context } from '../../core/auth.js';
import { asyncRoute } from '../../core/http.js';
import { keySchema } from '../orders/schema.js';
import { ComplaintService } from './service.js';
import { complaintSchema, decisionSchema, complaintQuerySchema } from './schema.js';
export function complaintRoutes(deps: Dependencies) {
  const r = Router();
  const s = new ComplaintService(deps);
  r.use(authenticated(deps));
  r.post(
    '/',
    asyncRoute(async (req, res) =>
      res
        .status(201)
        .json(
          await s.open(
            context(res, deps),
            complaintSchema.parse(req.body),
            keySchema.parse(req.get('Idempotency-Key')),
          ),
        ),
    ),
  );
  r.get(
    '/',
    asyncRoute(async (req, res) =>
      res.json(await s.list(context(res, deps), complaintQuerySchema.parse(req.query))),
    ),
  );
  r.get(
    '/:id',
    asyncRoute(async (req, res) =>
      res.json(await s.detail(context(res, deps), z.uuid().parse(req.params.id))),
    ),
  );
  r.post(
    '/:id/decision',
    asyncRoute(async (req, res) =>
      res.json(
        await s.decide(
          context(res, deps),
          z.uuid().parse(req.params.id),
          decisionSchema.parse(req.body),
        ),
      ),
    ),
  );
  return r;
}
