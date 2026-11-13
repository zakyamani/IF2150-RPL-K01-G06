import { z } from 'zod';
import { allergens, categories } from './labels.js';
import { orderStates } from '../modules/orders/schema.js';
const id = z.uuid(),
  at = z.iso.datetime({ offset: true }),
  money = z.number().int().nonnegative();
const user = z
  .object({
    id,
    email: z.email(),
    name: z.string(),
    role: z.enum(['buyer', 'seller']),
    allergen_filters: z.array(z.enum(allergens)),
  })
  .strict();
const session = z
  .object({ access_token: z.string(), refresh_token: z.string(), user, expires_at: at })
  .strict();
const merchant = z
  .object({
    id,
    name: z.string(),
    address: z.string(),
    latitude: z.number(),
    longitude: z.number(),
    photo_id: id.nullable(),
  })
  .strict();
const profile = z
  .object({
    user_id: id,
    shop_name: z.string(),
    address: z.string(),
    latitude: z.number().nullable(),
    longitude: z.number().nullable(),
    photo_id: id.nullable(),
    bank_masked: z.string(),
    updated_at: at,
  })
  .strict();
const offer = z
  .object({
    id,
    seller_id: id,
    category: z.enum(categories),
    allergens: z.array(z.enum(allergens)),
    status: z.enum(['active', 'closed']),
    quota_total: z.number().int(),
    quota_available: z.number().int().nonnegative(),
    quota_held: z.number().int().nonnegative(),
    quota_sold: z.number().int().nonnegative(),
    normal_price: money,
    discount_price: money,
    pickup_start: at,
    pickup_end: at,
    safe_eat_until: at,
    fitness_confirmed: z.literal(true),
    created_at: at,
  })
  .strict();
const catalog = z
  .object({
    id,
    category: z.enum(categories),
    allergens: z.array(z.enum(allergens)),
    quota_available: z.number().int().nonnegative(),
    normal_price: money,
    discount_price: money,
    discount_percent: z.number().min(50).max(70),
    pickup_start: at,
    pickup_end: at,
    safe_eat_until: at,
    distance_km: z.number().nullable(),
    disclaimer: z.string(),
    created_at: at,
  })
  .strict();
const checkout = z
  .object({
    order_id: id,
    code: z.string(),
    invoice: z.string(),
    intent_id: id,
    status: z.literal('pending_payment'),
    price: money,
    fee: money,
    payment_deadline: at,
    simulation: z.literal(true),
  })
  .strict();
const payment = z
  .object({
    id,
    order_id: id,
    amount: money,
    currency: z.literal('IDR'),
    status: z.enum(['pending', 'succeeded', 'failed', 'expired']),
    simulation: z.literal(true),
  })
  .strict();
const complaintSummary = z
  .object({
    id,
    reason: z.enum(['unfit', 'unavailable', 'allergen', 'store_closed']),
    description: z.string(),
    status: z.enum(['open', 'approved', 'rejected', 'auto_refunded']),
    response: z.string().nullable(),
    response_due: at.nullable(),
    created_at: at,
    decided_at: at.nullable(),
  })
  .strict();
const complaint = complaintSummary
  .extend({ order_id: id, buyer_id: id, media_ids: z.array(id), simulation: z.literal(true) })
  .strict();
const complaintItem = complaintSummary
  .extend({ order_id: id, buyer_id: id, order_code: z.string() })
  .strict();
const orderSummary = z
  .object({
    id,
    code: z.string(),
    status: z.enum(orderStates),
    price: money,
    fee: money,
    category: z.enum(categories),
    pickup_start: at,
    pickup_end: at,
    safe_eat_until: at,
    created_at: at,
  })
  .strict();
const order = orderSummary
  .extend({
    invoice: z.string(),
    fee_bps: z.number().int(),
    allergens: z.array(z.enum(allergens)),
    normal_price: money,
    payment_deadline: at,
    payment: payment.nullable(),
    merchant: merchant.optional(),
    pickup: z
      .object({ qr: z.string(), otp: z.string().regex(/^\d{6}$/) })
      .strict()
      .optional(),
    complaint: complaintSummary.nullable(),
    allowed_actions: z.array(z.enum(['pay', 'complain', 'cancel', 'pickup', 'review'])),
    history: z.array(z.object({ action: z.string(), occurred_at: at }).strict()),
    server_time: at,
    simulation: z.literal(true),
  })
  .strict();
const payout = z
  .object({
    id,
    order_id: id,
    seller_id: id,
    order_code: z.string(),
    gross: money,
    fee: money,
    net: money,
    status: z.enum(['pending', 'held', 'settled', 'cancelled']),
    due_at: at,
    reason: z.string(),
    settled_at: at.nullable(),
    created_at: at,
    simulation: z.literal(true),
  })
  .strict();
const payoutSummary = z
  .object({
    pending: money,
    held: money,
    settled: money,
    cancelled: money,
    simulation: z.literal(true),
  })
  .strict();
const review = z
  .object({
    id,
    order_id: id,
    rating: z.number().int().min(1).max(5),
    comment: z.string(),
    created_at: at,
  })
  .strict();
const reviewItem = review.omit({ order_id: true }).extend({ reviewer_name: z.string() }).strict();
const notification = z
  .object({
    id,
    sequence: z.string().regex(/^\d+$/),
    type: z.string(),
    resource_id: id,
    summary: z.string(),
    read_at: at.nullable(),
    occurred_at: at,
  })
  .strict();
const page = (item: z.ZodType) =>
  z.object({ items: z.array(item), next_cursor: z.string().nullable() }).strict();
export const responseSchemas = {
  register: session,
  login: session,
  refresh: session,
  me: user,
  allergens: user,
  merchantProfile: profile,
  updateMerchantProfile: profile,
  updateMerchantPhoto: z.object({ photo_id: id }).strict(),
  uploadMedia: z
    .object({ id, mime: z.literal('image/webp'), bytes: z.number().int().positive() })
    .strict(),
  sellerOffers: page(offer),
  sellerOffer: offer,
  createOffer: offer,
  updateOffer: offer,
  closeOffer: offer,
  catalog: page(catalog).extend({ disclaimer: z.string() }),
  catalogDetail: catalog,
  checkout,
  orders: page(orderSummary),
  order,
  paymentIntent: payment,
  demoPayment: payment,
  gatewayWebhook: payment,
  validatePickup: z
    .object({ order_id: id, code: z.string(), status: z.literal('completed'), completed_at: at })
    .strict(),
  cancelOrder: z
    .object({
      order_id: id,
      status: z.literal('refunded'),
      refund: z.object({ id, amount: money, reason: z.string() }).strict(),
      simulation: z.literal(true),
    })
    .strict(),
  openComplaint: complaint,
  complaint,
  decideComplaint: complaint,
  complaints: page(complaintItem),
  payouts: page(payout).extend({ simulation: z.literal(true) }),
  payoutSummary,
  createReview: review,
  merchantReviews: page(reviewItem).extend({
    rating_average: z.number().nullable(),
    rating_count: z.number().int().nonnegative(),
  }),
  notifications: page(notification).extend({ last_cursor: z.string() }),
  readNotification: z.object({ id, read_at: at }).strict(),
  socketTicket: z.object({ ticket: z.string(), expires_at: at }).strict(),
  metrics: z
    .object({ packages_saved: z.number().int().nonnegative(), definition: z.string() })
    .strict(),
};
export type OrderView = z.infer<typeof order>;
export type CatalogOfferView = z.infer<typeof catalog>;
