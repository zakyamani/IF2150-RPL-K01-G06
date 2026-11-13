import { Router, raw } from 'express';
import { z } from 'zod';
import type { Dependencies } from '../../core/contracts.js';
import { authenticated, context } from '../../core/auth.js';
import { asyncRoute } from '../../core/http.js';
import { RateLimiter } from '../../core/rate-limit.js';
import { PaymentService } from './service.js';
import { demoSchema } from './demo-gateway.js';
export function paymentRoutes(deps: Dependencies) {
  const r = Router();
  const s = new PaymentService(deps);
  const limiter = new RateLimiter(deps);
  r.use(authenticated(deps));
  r.get(
    '/:id',
    asyncRoute(async (req, res) =>
      res.json(await s.detail(context(res, deps), z.uuid().parse(req.params.id))),
    ),
  );
  r.post(
    '/:id/demo-event',
    asyncRoute(async (req, res) => {
      const ctx = context(res, deps);
      await limiter.take(`demo-payment:${ctx.actor.id}`, 30, 60000);
      res.json(
        await s.demoEvent(ctx, z.uuid().parse(req.params.id), demoSchema.parse(req.body).outcome),
      );
    }),
  );
  return r;
}
export function gatewayRoutes(deps: Dependencies) {
  const r = Router();
  const s = new PaymentService(deps);
  const limit = new RateLimiter(deps);
  r.post(
    '/webhook',
    raw({ type: 'application/json', limit: '64kb' }),
    asyncRoute(async (req, res) => {
      await limit.take(`callback:${req.ip}`, 200, 60000);
      res.json(
        await s.handleWebhook(
          Buffer.isBuffer(req.body) ? req.body : Buffer.alloc(0),
          req.get('X-Gateway-Signature') ?? '',
        ),
      );
    }),
  );
  return r;
}
