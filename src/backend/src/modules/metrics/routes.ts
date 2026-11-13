import { Router } from 'express';
import type { Dependencies } from '../../core/contracts.js';
import { asyncRoute } from '../../core/http.js';
import { MetricsService } from './service.js';
export function metricsRoutes(deps: Dependencies) {
  const r = Router();
  r.get(
    '/',
    asyncRoute(async (_req, res) => res.json(await new MetricsService(deps).summary())),
  );
  return r;
}
