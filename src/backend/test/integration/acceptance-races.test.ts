import { test } from 'node:test';
import assert from 'node:assert/strict';
import { fixture } from '../helpers/fixture.js';
import { pauseNextQuery } from '../helpers/barrier.js';
import { account } from '../helpers/accounts.js';
import { sellerOffer, offerInput } from '../helpers/offers.js';
import { paidOrder } from '../helpers/orders.js';
import { TestClock } from '../../src/core/clock.js';
import { OrderService } from '../../src/modules/orders/service.js';
import { OfferService } from '../../src/modules/offers/service.js';
import { PaymentService } from '../../src/modules/payments/service.js';
import { PickupService } from '../../src/modules/pickup/service.js';
import { runDueJobs } from '../../src/modules/jobs/service.js';

for (const winner of ['callback', 'worker']) {
  test(`exact payment deadline: ${winner} holds lock while the other waits`, async () => {
    const clock = new TestClock(),
      f = await fixture({ clock });
    let barrier: ReturnType<typeof pauseNextQuery> | undefined;
    try {
      const { offer } = await sellerOffer(f),
        buyer = await account(f, 'buyer');
      const c = await new OrderService(f.deps).checkout(
        buyer.ctx,
        { offer_id: offer.id },
        'expiry-race',
      );
      clock.set(new Date(c.payment_deadline));
      barrier = pauseNextQuery(f.db, 'SELECT * FROM orders WHERE id=$1 FOR UPDATE');
      const pay = () =>
        new PaymentService(f.deps).demoEvent(buyer.ctx, c.intent_id, 'succeeded').catch((e) => e);
      const work = () => runDueJobs(f.deps, { batchSize: 1 });
      const first = winner === 'callback' ? pay() : work();
      await barrier.ready();
      const second = winner === 'callback' ? work() : pay();
      await barrier.contenderBlocked();
      barrier.release();
      const results = await Promise.all([first, second]);
      assert.ok(results.some((r: any) => r.code === 'INVOICE_EXPIRED'));
      assert.equal((await f.db.query('SELECT status FROM orders')).rows[0].status, 'cancelled');
      assert.deepEqual(
        (await f.db.query('SELECT quota_available,quota_held,quota_sold FROM offers')).rows[0],
        { quota_available: 1, quota_held: 0, quota_sold: 0 },
      );
      assert.equal((await f.db.query('SELECT count(*)::int n FROM ledger_entries')).rows[0].n, 0);
      assert.equal(
        (await f.db.query("SELECT count(*)::int n FROM audit_logs WHERE action='payment.expired'"))
          .rows[0].n,
        1,
      );
    } finally {
      barrier?.restore();
      await f.close();
    }
  });
}
for (const action of ['edit', 'close'] as const) {
  for (const winner of ['checkout', 'seller', 'payment']) {
    test(`offer ${action} races ${winner} with locked inventory snapshots`, async () => {
      const f = await fixture();
      let barrier: ReturnType<typeof pauseNextQuery> | undefined;
      try {
        const { seller, offer } = await sellerOffer(f),
          buyer = await account(f, 'buyer');
        const orders = new OrderService(f.deps),
          offers = new OfferService(f.deps);
        const checkout = () =>
          orders.checkout(buyer.ctx, { offer_id: offer.id }, 'offer-race').catch((e) => e);
        const mutate = () =>
          (action === 'edit'
            ? offers.update(
                seller.ctx,
                offer.id,
                offerInput(f.clock.now(), { quota: 2, discount_price: 30000 }),
              )
            : offers.close(seller.ctx, offer.id)
          ).catch((e) => e);
        let c: any;
        if (winner === 'payment') c = await checkout();
        barrier = pauseNextQuery(
          f.db,
          winner === 'checkout'
            ? 'INSERT INTO checkout_reservations'
            : winner === 'payment'
              ? 'UPDATE offers SET quota_held=quota_held-1'
              : 'SELECT * FROM offers WHERE id=$1 FOR UPDATE',
        );
        const first =
          winner === 'seller'
            ? mutate()
            : winner === 'checkout'
              ? checkout()
              : new PaymentService(f.deps).demoEvent(buyer.ctx, c.intent_id, 'succeeded');
        await barrier.ready();
        const second = winner === 'seller' ? checkout() : mutate();
        await barrier.contenderBlocked();
        barrier.release();
        const [a, b] = await Promise.all([first, second]);
        if (winner !== 'seller') assert.equal((b as any).code, 'OFFER_RESERVED');
        else if (action === 'close') assert.equal((b as any).code, 'OFFER_UNAVAILABLE');
        else assert.equal((b as any).price, 30000);
        const stock = (
          await f.db.query(
            'SELECT quota_total,quota_available,quota_held,quota_sold,status FROM offers',
          )
        ).rows[0];
        assert.equal(
          stock.quota_total,
          stock.quota_available + stock.quota_held + stock.quota_sold,
        );
        assert.equal(stock.quota_sold, winner === 'payment' ? 1 : 0);
        assert.equal(
          stock.quota_held,
          winner === 'payment' || (winner === 'seller' && action === 'close') ? 0 : 1,
        );
        assert.equal(
          (await f.db.query("SELECT count(*)::int n FROM ledger_entries WHERE kind='funds_held'"))
            .rows[0].n,
          winner === 'payment' ? 1 : 0,
        );
        void a;
      } finally {
        barrier?.restore();
        await f.close();
      }
    });
  }
}
for (const winner of ['pickup', 'worker']) {
  test(`pickup versus no-show: ${winner} wins without duplicate payout or metric`, async () => {
    const clock = new TestClock(),
      f = await fixture({ clock });
    let barrier: ReturnType<typeof pauseNextQuery> | undefined;
    try {
      const { seller, order } = await paidOrder(f);
      clock.set(new Date(new Date(order.pickup_end).getTime() - (winner === 'pickup' ? 1 : 0)));
      barrier = pauseNextQuery(
        f.db,
        winner === 'pickup'
          ? "UPDATE orders SET status='completed'"
          : "UPDATE orders SET status='no_show'",
      );
      const scan = () =>
        new PickupService(f.deps)
          .validate(seller.ctx, { order_id: order.id, kind: 'qr', value: order.pickup.qr })
          .catch((e) => e);
      const first = winner === 'pickup' ? scan() : runDueJobs(f.deps);
      await barrier.ready();
      clock.set(new Date(order.pickup_end));
      const second = winner === 'pickup' ? runDueJobs(f.deps) : scan();
      await barrier.contenderBlocked();
      barrier.release();
      const results = await Promise.all([first, second]);
      const status = winner === 'pickup' ? 'completed' : 'no_show';
      assert.equal((await f.db.query('SELECT status FROM orders')).rows[0].status, status);
      assert.equal(
        (await f.db.query('SELECT count(*)::int n FROM payout_entitlements')).rows[0].n,
        1,
      );
      assert.equal((await f.db.query('SELECT count(*)::int n FROM payout_events')).rows[0].n, 1);
      assert.equal(
        (await f.db.query("SELECT count(*)::int n FROM orders WHERE status='completed'")).rows[0].n,
        winner === 'pickup' ? 1 : 0,
      );
      if (winner === 'worker')
        assert.ok(results.some((r: any) => r.code === 'PICKUP_STATE_CONFLICT'));
    } finally {
      barrier?.restore();
      await f.close();
    }
  });
}
test('expired worker lease is stolen during its uncommitted payout; stale effects roll back', async () => {
  const clock = new TestClock(),
    f = await fixture({ clock });
  let barrier: ReturnType<typeof pauseNextQuery> | undefined;
  try {
    const { seller, order } = await paidOrder(f);
    await new PickupService(f.deps).validate(seller.ctx, {
      order_id: order.id,
      kind: 'otp',
      value: order.pickup.otp,
    });
    clock.advance(3600000);
    await f.db.query("UPDATE jobs SET status='done' WHERE kind<>'settle_payout'");
    barrier = pauseNextQuery(f.db, "UPDATE payout_entitlements SET status='settled'");
    const old = runDueJobs(f.deps, { batchSize: 1 });
    await barrier.ready();
    const token = (await f.db.query("SELECT lease_token FROM jobs WHERE kind='settle_payout'"))
      .rows[0].lease_token;
    clock.advance(30001);
    const replacement = runDueJobs(f.deps, { batchSize: 1 });
    await barrier.contenderBlocked();
    assert.notEqual(
      (await f.db.query("SELECT lease_token FROM jobs WHERE kind='settle_payout'")).rows[0]
        .lease_token,
      token,
    );
    barrier.release();
    const [stale, current] = await Promise.all([old, replacement]);
    assert.equal(stale.succeeded, 0);
    assert.equal(stale.retried, 1);
    assert.equal(current.succeeded, 1);
    assert.equal(
      (await f.db.query("SELECT status,attempts FROM jobs WHERE kind='settle_payout'")).rows[0]
        .attempts,
      2,
    );
    assert.equal(
      (await f.db.query('SELECT status FROM payout_entitlements')).rows[0].status,
      'settled',
    );
    assert.equal(
      (await f.db.query("SELECT count(*)::int n FROM ledger_entries WHERE kind='payout_settled'"))
        .rows[0].n,
      1,
    );
    assert.equal(
      (await f.db.query("SELECT count(*)::int n FROM audit_logs WHERE action='payout.settled'"))
        .rows[0].n,
      1,
    );
    assert.equal(
      (await f.db.query("SELECT amount FROM ledger_entries WHERE kind='payout_settled'")).rows[0]
        .amount,
      38000,
    );
  } finally {
    barrier?.restore();
    await f.close();
  }
});
