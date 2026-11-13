import { Router } from 'express';
import type { Dependencies } from '../../core/contracts.js';
import { asyncRoute } from '../../core/http.js';
import { authenticated, context } from '../../core/auth.js';
import { RateLimiter } from '../../core/rate-limit.js';
import { AuthService } from './service.js';
import { registerSchema, loginSchema, refreshSchema, allergenSchema } from './schema.js';
export function authRoutes(deps: Dependencies) {
  const r = Router();
  const service = new AuthService(deps);
  const limit = new RateLimiter(deps);
  r.post(
    '/register',
    asyncRoute(async (req, res) => {
      const input = registerSchema.parse(req.body);
      await limit.take(`register:${req.ip}`, 10, 900000);
      res.status(201).json(await service.register(input));
    }),
  );
  r.post(
    '/login',
    asyncRoute(async (req, res) => {
      const input = loginSchema.parse(req.body);
      await limit.take(`login-ip:${req.ip}`, 30, 900000);
      await limit.take(`login-email:${input.email}`, 5, 900000);
      res.json(await service.login(input));
    }),
  );
  r.post(
    '/refresh',
    asyncRoute(async (req, res) => {
      const input = refreshSchema.parse(req.body);
      await limit.take(`refresh:${req.ip}`, 60, 60000);
      res.json(await service.refresh(input.refresh_token));
    }),
  );
  r.use(authenticated(deps));
  r.get(
    '/me',
    asyncRoute(async (_req, res) => res.json(await service.me(context(res, deps)))),
  );
  r.patch(
    '/allergens',
    asyncRoute(async (req, res) =>
      res.json(
        await service.allergens(
          context(res, deps),
          allergenSchema.parse(req.body).allergen_filters,
        ),
      ),
    ),
  );
  r.post(
    '/logout',
    asyncRoute(async (_req, res) => {
      await service.logout(context(res, deps));
      res.sendStatus(204);
    }),
  );
  return r;
}
