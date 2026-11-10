import {Router } from 'express';
import {z } from 'zod';
import type {Dependencies} from '../../core/contracts.js';
import {authenticated, context} from '../../core/auth.js';
import {asyncRoute} from '../../core/http.js';
import {pageSchema} from '../../core/pagination.js';
import {categories} from '../../core/labels.js';
import {CatalogService} from './service.js';
const coord = z
  .string()
  .regex(/^-?\d+(\.\d+)?$/)
  .transform(Number);
export const catalogQuerySchema = pageSchema
  .extend({
    lat: coord.pipe(z.number().finite().min(-90).max(90)).optional(),
    lng: coord.pipe(z.number().finite().min(-180).max(180)).optional(),
    category: z.enum(categories).optional(),
  })
  .strict()
  .refine(
    (q) => (q.lat === undefined) === (q.lng === undefined),
    'Berikan latitude dan longitude bersama.',
  );
export function catalogRoutes(deps: Dependencies) {
  const r = Router();
  const s = new CatalogService(deps);
  r.use(authenticated(deps));
  r.get(
    '/',
    asyncRoute(async (req, res) =>
      res.json(await s.list(context(res, deps), catalogQuerySchema.parse(req.query))),
    ),
  );
  r.get(
    '/:id',
    asyncRoute(async (req, res) =>
      res.json(
        await s.detail(
          context(res, deps),
          z.uuid().parse(req.params.id),
          catalogQuerySchema.parse(req.query),
        ),
      ),
    ),
  );
  return r;
}