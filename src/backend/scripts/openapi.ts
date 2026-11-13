import { writeFile } from 'node:fs/promises';
import { z } from 'zod';
import {
  registerSchema,
  loginSchema,
  refreshSchema,
  allergenSchema,
} from '../src/modules/auth/schema.js';
import { profileSchema } from '../src/modules/merchants/schema.js';
import { photoSchema } from '../src/modules/media/routes.js';
import { offerSchema } from '../src/modules/offers/schema.js';
import { checkoutSchema, cancelSchema } from '../src/modules/orders/schema.js';
import { demoSchema, eventSchema } from '../src/modules/payments/demo-gateway.js';
import { pickupSchema } from '../src/modules/pickup/schema.js';
import { complaintSchema, decisionSchema } from '../src/modules/complaints/schema.js';
import { reviewSchema } from '../src/modules/reviews/schema.js';
import { ticketSchema } from '../src/modules/notifications/service.js';
import { responseSchemas } from '../src/core/response-schemas.js';
type Operation = {
  path: string;
  method: string;
  name: string;
  body?: z.ZodType;
  public?: boolean;
  status?: number;
};
const operations: Operation[] = [
  {
    path: '/auth/register',
    method: 'post',
    name: 'register',
    body: registerSchema,
    public: true,
    status: 201,
  },
  { path: '/auth/login', method: 'post', name: 'login', body: loginSchema, public: true },
  { path: '/auth/refresh', method: 'post', name: 'refresh', body: refreshSchema, public: true },
  { path: '/auth/logout', method: 'post', name: 'logout', status: 204 },
  { path: '/auth/me', method: 'get', name: 'me' },
  { path: '/auth/allergens', method: 'patch', name: 'allergens', body: allergenSchema },
  { path: '/merchant/profile', method: 'get', name: 'merchantProfile' },
  {
    path: '/merchant/profile',
    method: 'patch',
    name: 'updateMerchantProfile',
    body: profileSchema,
  },
  { path: '/merchant/photo', method: 'patch', name: 'updateMerchantPhoto', body: photoSchema },
  { path: '/media/{id}', method: 'get', name: 'privateMedia' },
  { path: '/offers', method: 'get', name: 'sellerOffers' },
  { path: '/offers', method: 'post', name: 'createOffer', body: offerSchema, status: 201 },
  { path: '/offers/{id}', method: 'get', name: 'sellerOffer' },
  { path: '/offers/{id}', method: 'patch', name: 'updateOffer', body: offerSchema },
  { path: '/offers/{id}/close', method: 'post', name: 'closeOffer' },
  { path: '/catalog', method: 'get', name: 'catalog' },
  { path: '/catalog/{id}', method: 'get', name: 'catalogDetail' },
  { path: '/orders/checkout', method: 'post', name: 'checkout', body: checkoutSchema, status: 201 },
  { path: '/orders', method: 'get', name: 'orders' },
  { path: '/orders/{id}', method: 'get', name: 'order' },
  { path: '/payments/{id}', method: 'get', name: 'paymentIntent' },
  { path: '/payments/{id}/demo-event', method: 'post', name: 'demoPayment', body: demoSchema },
  {
    path: '/gateway/webhook',
    method: 'post',
    name: 'gatewayWebhook',
    body: eventSchema,
    public: true,
  },
  { path: '/pickup/validate', method: 'post', name: 'validatePickup', body: pickupSchema },
  { path: '/metrics', method: 'get', name: 'metrics', public: true },
  { path: '/orders/{id}/cancel', method: 'post', name: 'cancelOrder', body: cancelSchema },
  {
    path: '/complaints',
    method: 'post',
    name: 'openComplaint',
    body: complaintSchema,
    status: 201,
  },
  { path: '/complaints', method: 'get', name: 'complaints' },
  { path: '/complaints/{id}', method: 'get', name: 'complaint' },
  {
    path: '/complaints/{id}/decision',
    method: 'post',
    name: 'decideComplaint',
    body: decisionSchema,
  },
  { path: '/payouts', method: 'get', name: 'payouts' },
  { path: '/payouts/summary', method: 'get', name: 'payoutSummary' },
  { path: '/reviews', method: 'post', name: 'createReview', body: reviewSchema, status: 201 },
  { path: '/reviews/merchant/{id}', method: 'get', name: 'merchantReviews' },
  { path: '/notifications', method: 'get', name: 'notifications' },
  { path: '/notifications/ws-ticket', method: 'post', name: 'socketTicket', body: ticketSchema },
  { path: '/notifications/{id}/read', method: 'post', name: 'readNotification' },
];
const paths: Record<string, Record<string, unknown>> = {};
for (const o of operations) {
  const parameters = [...o.path.matchAll(/\{([^}]+)\}/g)].map((m) => ({
    name: m[1],
    in: 'path',
    required: true,
    schema: { type: 'string', format: 'uuid' },
  }));
  paths[o.path] ??= {};
  paths[o.path]![o.method] = {
    operationId: o.name,
    security: o.public ? [] : [{ bearerAuth: [] }],
    ...(parameters.length ? { parameters } : {}),
    ...(o.body
      ? {
          requestBody: {
            required: true,
            content: {
              'application/json': {
                schema: z.toJSONSchema(o.body, { io: 'input', unrepresentable: 'any' }),
              },
            },
          },
        }
      : {}),
    responses: {
      [o.status ?? 200]: { description: 'Success' },
      default: {
        description: 'Error',
        content: { 'application/json': { schema: { $ref: '#/components/schemas/ApiError' } } },
      },
    },
  };
  if (['checkout', 'openComplaint', 'cancelOrder'].includes(o.name))
    (paths[o.path]![o.method] as any).parameters = [
      ...parameters,
      {
        name: 'Idempotency-Key',
        in: 'header',
        required: true,
        schema: { type: 'string', minLength: 1, maxLength: 128 },
      },
    ];
  if (o.name === 'gatewayWebhook')
    (paths[o.path]![o.method] as any).parameters = [
      {
        name: 'X-Gateway-Signature',
        in: 'header',
        required: true,
        schema: { type: 'string', pattern: '^[a-f0-9]{64}$' },
        description: 'HMAC-SHA256 over the exact raw body using a server-only callback secret.',
      },
    ];
  const response = responseSchemas[o.name as keyof typeof responseSchemas];
  if (response)
    (paths[o.path]![o.method] as any).responses[o.status ?? 200].content = {
      'application/json': { schema: z.toJSONSchema(response) },
    };
  if (o.name === 'privateMedia')
    (paths[o.path]![o.method] as any).responses[200].content = {
      'image/webp': { schema: { type: 'string', format: 'binary' } },
    };
  if (
    [
      'sellerOffers',
      'catalog',
      'orders',
      'complaints',
      'payouts',
      'merchantReviews',
      'notifications',
    ].includes(o.name)
  ) {
    const op = paths[o.path]![o.method] as any;
    op.parameters = [
      ...parameters,
      { name: 'cursor', in: 'query', schema: { type: 'string' } },
      {
        name: 'limit',
        in: 'query',
        schema: { type: 'integer', minimum: 1, maximum: 50, default: 20 },
      },
    ];
    if (o.name === 'catalog')
      op.parameters.push(
        { name: 'lat', in: 'query', schema: { type: 'number', minimum: -90, maximum: 90 } },
        { name: 'lng', in: 'query', schema: { type: 'number', minimum: -180, maximum: 180 } },
        {
          name: 'category',
          in: 'query',
          schema: {
            type: 'string',
            enum: ['makanan_berat', 'roti_kudapan', 'buah_sayur', 'campuran'],
          },
        },
      );
    if (o.name === 'notifications')
      op.parameters.push({
        name: 'after',
        in: 'query',
        schema: { type: 'string', pattern: '^\\d+$' },
        description:
          'Ascending catch-up after sequence; mutually exclusive with descending history cursor.',
      });
  }
}
const document = {
  openapi: '3.1.0',
  info: { title: 'SisaRasa API', version: '2.0.0' },
  servers: [{ url: '/api/v1' }],
  paths,
  components: {
    securitySchemes: { bearerAuth: { type: 'http', scheme: 'bearer', bearerFormat: 'JWT' } },
    schemas: {
      ApiError: {
        type: 'object',
        required: ['code', 'message', 'request_id'],
        properties: {
          code: { type: 'string' },
          message: { type: 'string' },
          request_id: { type: 'string', format: 'uuid' },
          field_errors: {
            type: 'object',
            additionalProperties: { type: 'array', items: { type: 'string' } },
          },
        },
      },
    },
  },
};
paths['/media'] = {
  post: {
    operationId: 'uploadMedia',
    security: [{ bearerAuth: [] }],
    requestBody: {
      required: true,
      content: {
        'multipart/form-data': {
          schema: {
            type: 'object',
            required: ['kind', 'file'],
            properties: {
              kind: { type: 'string', enum: ['shop', 'evidence'] },
              file: { type: 'string', format: 'binary' },
            },
          },
        },
      },
    },
    responses: {
      201: { description: 'Staged normalized image' },
      413: { description: 'File exceeds 2 MB' },
    },
  },
};
(paths['/media']!.post as any).responses[201].content = {
  'application/json': { schema: z.toJSONSchema(responseSchemas.uploadMedia) },
};
await writeFile(
  new URL('../openapi.yaml', import.meta.url),
  JSON.stringify(document, null, 2) + '\n',
);
