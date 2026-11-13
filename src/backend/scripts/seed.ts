import 'dotenv/config';
import { Database } from '../src/core/db.js';
import { loadConfig } from '../src/core/config.js';
import { systemClock } from '../src/core/clock.js';
import { AuthService } from '../src/modules/auth/service.js';
import { OfferService } from '../src/modules/offers/service.js';
const password = process.env.DEMO_SEED_PASSWORD;
if (!password || password.length < 16)
  throw new Error('Explicit DEMO_SEED_PASSWORD (>=16 chars) required');
const config = loadConfig();
const db = new Database(config.DATABASE_URL);
try {
  const deps = { config, db, clock: systemClock };
  const auth = new AuthService(deps);
  for (const [email, role, name] of [
    ['buyer@demo.sisarasa.invalid', 'buyer', 'Pembeli Demo'],
    ['seller@demo.sisarasa.invalid', 'seller', 'Dapur Demo SisaRasa'],
  ] as const) {
    if ((await db.query('SELECT id FROM users WHERE email=$1', [email])).rowCount) {
      console.log(`${email}: already exists; preserved`);
      continue;
    }
    const b = await auth.register({ email, role, name, password });
    if (role === 'seller') {
      await db.query(
        'UPDATE merchant_profiles SET shop_name=$2,address=$3,latitude=$4,longitude=$5 WHERE user_id=$1',
        [b.user.id, name, 'Alamat demonstrasi, Bandung', -6.917, 107.619],
      );
      const actor = await auth.authenticate(b.access_token);
      const now = Date.now();
      for (const category of ['campuran', 'roti_kudapan', 'makanan_berat', 'buah_sayur'] as const)
        await new OfferService(deps).create(
          { actor, clock: systemClock },
          {
            category,
            allergens: category === 'roti_kudapan' ? ['gluten', 'susu'] : [],
            quota: 20,
            normal_price: 100000,
            discount_price: 40000,
            pickup_start: new Date(now + 60000).toISOString(),
            pickup_end: new Date(now + 7200000).toISOString(),
            safe_eat_until: new Date(now + 10800000).toISOString(),
            fitness_confirmed: true,
          },
        );
    }
    console.log(`${email}: created (${role})`);
  }
} finally {
  await db.close();
}
