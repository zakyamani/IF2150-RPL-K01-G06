import { Router } from 'express';
import multer from 'multer';
import { z } from 'zod';
import type { Dependencies } from '../../core/contracts.js';
import { authenticated, context } from '../../core/auth.js';
import { asyncRoute } from '../../core/http.js';
import { ApiError } from '../../core/errors.js';
import { RateLimiter } from '../../core/rate-limit.js';
import { MediaService } from './service.js';
export const photoSchema = z.object({ media_id: z.uuid() }).strict();
export function mediaRoutes(deps: Dependencies) {
  const r = Router();
  const s = new MediaService(deps);
  const limit = new RateLimiter(deps);
  const upload = multer({
    storage: multer.memoryStorage(),
    limits: { fileSize: 2097152, files: 1, fields: 1, fieldSize: 20, parts: 2 },
  }).single('file');
  r.use(authenticated(deps));
  r.post(
    '/',
    asyncRoute(async (req, res, next) => {
      await limit.take(`upload:${res.locals.actor.id}`, 20, 60000);
      next();
    }),
    (req, res, next) =>
      upload(req, res, (e) =>
        next(
          e
            ? new ApiError(
                e.code === 'LIMIT_FILE_SIZE' ? 413 : 400,
                'INVALID_UPLOAD',
                'Foto maksimal 2 MB; unggah satu foto JPEG/PNG/WebP.',
              )
            : undefined,
        ),
      ),
    asyncRoute(async (req, res) => {
      const kind = z.enum(['shop', 'evidence']).parse(req.body.kind);
      if (!req.file) throw new ApiError(400, 'FILE_REQUIRED', 'Pilih foto terlebih dahulu.');
      res
        .status(201)
        .json(await s.upload(context(res, deps), kind, req.file.buffer, req.file.mimetype));
    }),
  );
  r.get(
    '/:id',
    asyncRoute(async (req, res) => {
      const media = await s.read(context(res, deps), z.uuid().parse(req.params.id));
      res.setHeader('Cache-Control', 'private, no-store');
      res.type(media.mime).send(media.bytes);
    }),
  );
  return r;
}
