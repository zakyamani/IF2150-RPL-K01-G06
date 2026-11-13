import type { RequestHandler, Response } from 'express';
import type { Dependencies, ServiceContext } from './contracts.js';
import { ApiError } from './errors.js';
import { AuthService } from '../modules/auth/service.js';
export function authenticated(deps: Dependencies): RequestHandler {
  const service = new AuthService(deps);
  return (req, res, next) => {
    const match = /^Bearer ([A-Za-z0-9._-]+)$/.exec(req.headers.authorization ?? '');
    if (!match) {
      next(new ApiError(401, 'UNAUTHORIZED', 'Silakan masuk terlebih dahulu.'));
      return;
    }
    service.authenticate(match[1]!).then((actor) => {
      res.locals.actor = actor;
      next();
    }, next);
  };
}
export function context(res: Response, deps: Dependencies): ServiceContext {
  return { actor: res.locals.actor, clock: deps.clock };
}
export function role(ctx: ServiceContext, expected: 'buyer' | 'seller') {
  if (ctx.actor.role !== expected)
    throw new ApiError(403, 'FORBIDDEN', 'Akun Anda tidak berhak menjalankan tindakan ini.');
}
