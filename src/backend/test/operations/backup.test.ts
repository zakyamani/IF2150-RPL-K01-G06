import test from 'node:test';
import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { mkdtempSync, readFileSync, writeFileSync, existsSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join, resolve } from 'node:path';
import { randomUUID } from 'node:crypto';
import sharp from 'sharp';

test(
  'operator backup restores paid credentials/media and recovers original services on failure',
  { timeout: 240000 },
  async () => {
    const root = resolve('..'),
      temp = mkdtempSync(join(tmpdir(), 'sisarasa-ops-test-'));
    const env = {
      ...process.env,
      SISARASA_ENV_FILE: join(temp, '.env'),
      SISARASA_PROJECT: 'sisarasa-ops-test-' + randomUUID().slice(0, 8),
      API_HOST_PORT: '3311',
      DB_HOST_PORT: '0',
      MEDIA_PATH: join(temp, 'uploads'),
    };
    function op(name: string, args: string[] = [], extra: Record<string, string> = {}) {
      const p = spawnSync('bash', [join(root, 'scripts', name + '.sh'), ...args], {
        env: { ...env, ...extra },
        encoding: 'utf8',
        timeout: 180000,
      });
      assert.equal(p.status, 0, `${name}: ${p.stderr}\n${p.stdout}`);
      return p.stdout.trim();
    }
    function dc(args: string[]) {
      return spawnSync(
        'docker',
        [
          'compose',
          '--project-directory',
          root,
          '--env-file',
          env.SISARASA_ENV_FILE,
          '-p',
          env.SISARASA_PROJECT,
          '-f',
          join(root, 'compose.yaml'),
          ...args,
        ],
        { env, encoding: 'utf8' },
      );
    }
    try {
      op('setup');
      const gateway = spawnSync(
        'docker',
        [
          'network',
          'inspect',
          env.SISARASA_PROJECT + '_default',
          '--format',
          '{{(index .IPAM.Config 0).Gateway}}',
        ],
        { encoding: 'utf8' },
      ).stdout.trim();
      assert.ok(
        readFileSync(env.SISARASA_ENV_FILE, 'utf8').includes(
          'TRUST_PROXY=loopback,' + gateway + '/32',
        ),
        'Operator must trust the exact local Docker gateway, so Cloudflare clients do not share one IP bucket',
      );
      op('start');
      async function api(path: string, body?: unknown, token?: string, key?: string) {
        const response = await fetch('http://127.0.0.1:3311/api/v1' + path, {
          method: body ? 'POST' : 'GET',
          headers: {
            'content-type': 'application/json',
            connection: 'close',
            ...(token ? { authorization: 'Bearer ' + token } : {}),
            ...(key ? { 'Idempotency-Key': key } : {}),
          },
          body: body ? JSON.stringify(body) : undefined,
        });
        const value = (await response.json()) as any;
        assert.ok(response.ok, JSON.stringify(value));
        return value;
      }
      const seller = await api('/auth/register', {
        email: 'seller@example.test',
        password: 'Testing-password-2026',
        name: 'Gerai Test',
        role: 'seller',
      });
      const buyer = await api('/auth/register', {
        email: 'buyer@example.test',
        password: 'Testing-password-2026',
        name: 'Pembeli Test',
        role: 'buyer',
      });
      const image = await sharp({
        create: { width: 4, height: 4, channels: 3, background: 'green' },
      })
        .png()
        .toBuffer();
      const form = new FormData();
      form.append('file', new Blob([image], { type: 'image/png' }), 'photo.png');
      form.append('kind', 'shop');
      const upload = await fetch('http://127.0.0.1:3311/api/v1/media', {
        method: 'POST',
        headers: { authorization: 'Bearer ' + seller.access_token },
        body: form,
      });
      const media = (await upload.json()) as any;
      assert.equal(upload.status, 201, JSON.stringify(media));
      for (const [path, body] of [
        [
          '/merchant/profile',
          { shop_name: 'Gerai Test', address: 'Jalan Test 12', latitude: -6.9, longitude: 107.6 },
        ],
        ['/merchant/photo', { media_id: media.id }],
      ] as const) {
        const r = await fetch('http://127.0.0.1:3311/api/v1' + path, {
          method: 'PATCH',
          headers: {
            authorization: 'Bearer ' + seller.access_token,
            'content-type': 'application/json',
            connection: 'close',
          },
          body: JSON.stringify(body),
        });
        assert.equal(r.status, 200, await r.text());
      }
      const now = Date.now();
      const offer = await api(
        '/offers',
        {
          category: 'campuran',
          allergens: [],
          quota: 1,
          normal_price: 100000,
          discount_price: 40000,
          pickup_start: new Date(now + 60000).toISOString(),
          pickup_end: new Date(now + 3600000).toISOString(),
          safe_eat_until: new Date(now + 7200000).toISOString(),
          fitness_confirmed: true,
        },
        seller.access_token,
      );
      const checkout = await api(
        '/orders/checkout',
        { offer_id: offer.id },
        buyer.access_token,
        randomUUID(),
      );
      await api(
        '/payments/' + checkout.intent_id + '/demo-event',
        { outcome: 'succeeded' },
        buyer.access_token,
      );
      const before = await api('/orders/' + checkout.order_id, undefined, buyer.access_token);
      assert.equal(before.status, 'paid');
      const backup = op('backup', [join(temp, 'backups')])
        .split('\n')
        .at(-1)!;
      assert.ok(existsSync(join(backup, 'manifest.json')));
      assert.equal(
        readFileSync(join(backup, 'recovery.env'), 'utf8'),
        readFileSync(env.SISARASA_ENV_FILE, 'utf8'),
      );
      const restored = JSON.parse(op('restore', [backup, '--test']));
      assert.equal(restored.paid_orders, 1);
      assert.equal(restored.credentials, 1);
      assert.equal(restored.decryptable_credentials, 1);
      assert.equal(restored.media_files, 1);
      const after = await api('/orders/' + checkout.order_id, undefined, buyer.access_token);
      assert.deepEqual(after.pickup, before.pickup);
      dc(['stop', 'worker']);
      for (const failure of ['dump', 'archive']) {
        const failed = spawnSync('bash', [join(root, 'scripts/backup.sh'), join(temp, 'backups')], {
          env: { ...env, SISARASA_BACKUP_FAIL: failure },
          encoding: 'utf8',
        });
        assert.notEqual(failed.status, 0);
        const running = dc(['ps', '--status', 'running', '--services']).stdout;
        assert.match(running, /api/);
        assert.doesNotMatch(running, /worker/);
      }
      op('stop');
      op('start');
      assert.equal(
        (await api('/orders/' + checkout.order_id, undefined, buyer.access_token)).status,
        'paid',
      );
      writeFileSync(join(backup, 'media.tar.gz'), 'corrupt');
      const corrupt = spawnSync('bash', [join(root, 'scripts/restore.sh'), backup, '--test'], {
        env,
        encoding: 'utf8',
      });
      assert.notEqual(corrupt.status, 0);
      assert.match(corrupt.stderr, /checksum/i);
      const dangerous = spawnSync('bash', [join(root, 'scripts/restore.sh'), backup], {
        env,
        encoding: 'utf8',
      });
      assert.notEqual(dangerous.status, 0);
      assert.match(dangerous.stderr, /--test/);
    } finally {
      if (existsSync(env.SISARASA_ENV_FILE)) dc(['down', '--volumes']);
    }
  },
);
