import {
  createHash,
  randomBytes,
  createHmac,
  timingSafeEqual,
  createCipheriv,
  createDecipheriv,
} from 'node:crypto';
export const hash = (value: string | Buffer) => createHash('sha256').update(value).digest('hex');
export const secretToken = () => randomBytes(32).toString('base64url');
export const hmac = (value: string | Buffer, key: string) =>
  createHmac('sha256', key).update(value).digest('hex');
export function safeEqual(a: string, b: string) {
  const x = Buffer.from(a);
  const y = Buffer.from(b);
  return x.length === y.length && timingSafeEqual(x, y);
}
export function encrypt(value: unknown, keyHex: string) {
  const iv = randomBytes(12);
  const cipher = createCipheriv('aes-256-gcm', Buffer.from(keyHex, 'hex'), iv);
  const encrypted = Buffer.concat([cipher.update(JSON.stringify(value), 'utf8'), cipher.final()]);
  return [
    'v1',
    iv.toString('base64url'),
    cipher.getAuthTag().toString('base64url'),
    encrypted.toString('base64url'),
  ].join('.');
}
export function decrypt<T>(value: string, keyHex: string): T {
  const [version, iv, tag, data] = value.split('.');
  if (version !== 'v1' || !iv || !tag || !data) throw new Error('Invalid encrypted data');
  const cipher = createDecipheriv(
    'aes-256-gcm',
    Buffer.from(keyHex, 'hex'),
    Buffer.from(iv, 'base64url'),
  );
  cipher.setAuthTag(Buffer.from(tag, 'base64url'));
  return JSON.parse(
    Buffer.concat([cipher.update(Buffer.from(data, 'base64url')), cipher.final()]).toString('utf8'),
  ) as T;
}
