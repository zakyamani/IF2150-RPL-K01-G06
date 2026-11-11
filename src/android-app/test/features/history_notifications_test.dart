import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sisarasa_app/app_services.dart';
import 'package:sisarasa_app/core/models/user.dart';
import 'package:sisarasa_app/features/orders/order_controller.dart';
import 'package:sisarasa_app/features/orders/order_repository.dart';

import '../helpers/memory_store.dart';
import '../helpers/samples.dart';
import '../helpers/fake_http.dart';
import 'notifications_test.dart' show eventJson;

void main() {
  test('paid inbox event refreshes an already-open empty seller order history once', () async {
    var paid = false;
    final s = await AppServices.create(
      storage: MemoryStore(),
      initialOrigin: 'https://api.example.test',
      dio: Dio()
        ..httpClientAdapter = FakeHttp(
          (r) async => r.path == '/notifications'
              ? (
                  200,
                  {
                    'items': [eventJson()],
                    'next_cursor': null,
                    'last_cursor': '1',
                  },
                )
              : (
                  200,
                  {
                    'items': paid ? [orderJson()] : [],
                    'next_cursor': null,
                  },
                ),
        ),
    );
    await s.sessions.save(
      SessionBundle.fromJson({
        ...sessionJson(),
        'user': userJson(role: 'seller'),
      }),
    );
    final c = HistoryController(OrderRepository(s));
    expect(await c.load(), true);
    expect(c.items, isEmpty);
    paid = true;
    await s.notifications.catchUp();
    await Future<void>.delayed(const Duration(milliseconds: 650));
    expect(c.items.single.status.wire, 'paid');
    c.dispose();
    s.dispose();
  });
}
