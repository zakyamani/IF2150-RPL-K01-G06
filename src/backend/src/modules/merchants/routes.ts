import { Router } from 'express';
import type { Dependencies } from '../../core/contracts.js';
import { authenticated, context } from '../../core/auth.js';
import { asyncRoute } from '../../core/http.js';
import { MerchantService } from './service.js';
import { profileSchema } from './schema.js';
import { MediaService } from '../media/service.js';
import { photoSchema } from '../media/routes.js';
export function merchantRoutes(deps: Dependencies) {
  const r = Router();
  const s = new MerchantService(deps);
  r.use(authenticated(deps));
  r.get(
    '/profile',
    asyncRoute(async (_req, res) => res.json(await s.me(context(res, deps)))),
  );
  r.patch(
    '/profile',
    asyncRoute(async (req, res) =>
      res.json(await s.update(context(res, deps), profileSchema.parse(req.body))),
    ),
  );
  r.patch(
    '/photo',
    asyncRoute(async (req, res) =>
      res.json(
        await new MediaService(deps).setShopPhoto(
          context(res, deps),
          photoSchema.parse(req.body).media_id,
        ),
      ),
    ),
  );
  return r;
}
