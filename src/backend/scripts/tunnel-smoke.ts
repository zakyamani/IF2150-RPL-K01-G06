import { randomUUID } from 'node:crypto';
import WebSocket from 'ws';
const origin = process.argv[2];
if (!origin?.startsWith('https://')) throw Error('HTTPS origin required');
async function api(path: string, body?: unknown, token?: string, key?: string) {
  const r = await fetch(origin + '/api/v1' + path, {
    method: body ? 'POST' : 'GET',
    headers: {
      'content-type': 'application/json',
      ...(token ? { authorization: 'Bearer ' + token } : {}),
      ...(key ? { 'Idempotency-Key': key } : {}),
    },
    body: body ? JSON.stringify(body) : undefined,
  });
  const j = (await r.json()) as any;
  if (!r.ok) throw Error(JSON.stringify(j));
  return j;
}
const buyer = await api('/auth/register', {
  email: `tunnel-${randomUUID()}@example.test`,
  password: randomUUID() + 'Aa1',
  name: 'Pembeli Uji Tunnel',
  role: 'buyer',
});
const { ticket } = await api('/notifications/ws-ticket', { after: '0' }, buyer.access_token);
const ws = new WebSocket(
  origin.replace('https:', 'wss:') + '/ws?ticket=' + encodeURIComponent(ticket),
);
await new Promise<void>((resolve, reject) => {
  ws.once('open', resolve);
  ws.once('error', reject);
});
const received = new Promise<string>((resolve, reject) => {
  const t = setTimeout(() => reject(Error('Missing durable event over Tunnel')), 15000);
  ws.on('message', (b) => {
    const e = JSON.parse(b.toString());
    clearTimeout(t);
    resolve(e.type);
  });
});
const offers = await api('/catalog',undefined,buyer.access_token);
if (!offers.items.length) throw Error('No active demo offer; seed first');
const checkout = await api(
  '/orders/checkout',
  { offer_id: offers.items[0].id },
  buyer.access_token,
  randomUUID(),
);
await api(
  '/payments/' + checkout.intent_id + '/demo-event',
  { outcome: 'succeeded' },
  buyer.access_token,
);
const order = await api('/orders/' + checkout.order_id, undefined, buyer.access_token);
const event = await received;
ws.close();
console.log(
  JSON.stringify({
    origin,
    health: 'ready',
    order_status: order.status,
    websocket_event: event,
    authenticated_flow: true,
  }),
);
