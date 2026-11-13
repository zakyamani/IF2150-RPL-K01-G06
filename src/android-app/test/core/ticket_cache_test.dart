import 'package:flutter_test/flutter_test.dart';
import 'package:sisarasa_app/core/models/order.dart';
import 'package:sisarasa_app/core/storage/ticket_cache.dart';
import 'package:sisarasa_app/core/storage/session_store.dart';
import 'package:sisarasa_app/core/models/user.dart';

import '../helpers/memory_store.dart';
import '../helpers/samples.dart';

void main() {
  test(
    'malformed versioned QR never survives encrypted cache decoding',
    () async {
      final broken = orderJson();
      broken['pickup'] = {'qr': 'sisarasa:v1:not-a-ticket', 'otp': '123456'};
      expect(() => Order.fromJson(broken), throwsFormatException);
    },
  );
  test(
    'ticket survives cache reconstruction but account B cannot read A',
    () async {
      final storage = MemoryStore();
      final cache = TicketCache(storage);
      const user = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
      await cache.save(
        user,
        Order.fromJson(orderJson()),
        syncedAt: DateTime.utc(2026, 10, 5, 12, 1),
      );
      final restored = TicketCache(storage);
      expect((await restored.list(user)).single.order.pickup!.otp, '123456');
      expect(await restored.list('other-account'), isEmpty);
      await storage.write('private.ticket.$user.corrupt', 'bad-json');
      expect((await restored.list(user)).length, 1);
      expect(
        storage.values.containsKey('private.ticket.$user.corrupt'),
        isFalse,
      );
    },
  );
  test('logout and account switch erase cached tickets', () async {
    final storage = MemoryStore();
    final session = SessionStore(
      storage,
      initialOrigin: 'https://api.example.test',
    );
    final cache = TicketCache(storage);
    const id = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
    await session.save(SessionBundle.fromJson(sessionJson()));
    await cache.save(id, Order.fromJson(orderJson()));
    await session.clear();
    expect(await cache.list(id), isEmpty);
    await session.save(SessionBundle.fromJson(sessionJson()));
    await cache.save(id, Order.fromJson(orderJson()));
    await session.save(
      SessionBundle.fromJson(
        sessionJson(id: 'eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee'),
      ),
    );
    expect(await cache.list(id), isEmpty);
  });
}
