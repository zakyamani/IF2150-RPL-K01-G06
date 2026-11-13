import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sisarasa_app/app_services.dart';
import 'package:sisarasa_app/core/models/user.dart';
import 'package:sisarasa_app/core/models/order.dart';
import 'package:sisarasa_app/features/auth/auth_controller.dart';
import 'package:sisarasa_app/features/orders/order_controller.dart';
import 'package:sisarasa_app/features/orders/order_repository.dart';

import '../helpers/memory_store.dart';
import '../helpers/samples.dart';
import '../helpers/fake_http.dart';

void main() {
  test('late logout completion preserves a newly selected account', () async {
    const other = 'dddddddd-dddd-4ddd-8ddd-dddddddddddd';
    final dio = Dio()..httpClientAdapter = FakeHttp((r) async => (204, {}));
    final s = await AppServices.create(
      storage: MemoryStore(),
      initialOrigin: 'https://api.example.test',
      dio: dio,
    );
    await s.sessions.save(SessionBundle.fromJson(sessionJson()));
    dio.interceptors.add(
      InterceptorsWrapper(
        onResponse: (response, handler) async {
          await s.sessions.changeOrigin('https://new.example.test');
          await s.sessions.save(SessionBundle.fromJson(sessionJson(id: other)));
          handler.next(response);
        },
      ),
    );
    final c = AuthController(s);
    await c.logout();
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(s.sessions.session?.user.id, other);
    c.dispose();
    s.dispose();
  });
  test(
    'stale unauthorized callback cannot erase the replacement server session',
    () async {
      final dio = Dio()
        ..httpClientAdapter = FakeHttp(
          (r) async => (
            401,
            {
              'code': 'UNAUTHORIZED',
              'message': 'Sesi lama',
              'request_id': 'test',
            },
          ),
        );
      final s = await AppServices.create(
        storage: MemoryStore(),
        initialOrigin: 'https://old.example.test',
        dio: dio,
      );
      await s.sessions.save(SessionBundle.fromJson(sessionJson()));
      const other = 'dddddddd-dddd-4ddd-8ddd-dddddddddddd';
      var replaced = false;
      dio.interceptors.add(
        InterceptorsWrapper(
          onError: (error, handler) async {
            if (!replaced) {
              replaced = true;
              await s.sessions.changeOrigin('https://new.example.test');
              await s.sessions.save(
                SessionBundle.fromJson(sessionJson(id: other)),
              );
            }
            handler.next(error);
          },
        ),
      );
      await s.api
          .get('/auth/me', User.fromJson)
          .catchError((Object e) => throw e)
          .then<void>((_) {}, onError: (Object e) {});
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(s.sessions.session?.user.id, other);
      s.dispose();
    },
  );
  test('cached paid ticket is visible before an unresponsive network request completes', () async {
    final gate = Completer<void>();
    final s = await AppServices.create(
      storage: MemoryStore(),
      initialOrigin: 'https://api.example.test',
      dio: Dio()
        ..httpClientAdapter = FakeHttp((r) async {
          await gate.future;
          throw DioException(
            requestOptions: r,
            type: DioExceptionType.connectionError,
          );
        }),
    );
    await s.sessions.save(SessionBundle.fromJson(sessionJson()));
    final order = Order.fromJson(orderJson());
    await s.tickets.save(s.sessions.session!.user.id, order);
    final c = OrderController(OrderRepository(s), order.id);
    final pending = c.load();
    await Future<void>.delayed(const Duration(milliseconds: 40));
    expect(c.order?.id, order.id);
    expect(c.offline, true);
    gate.complete();
    await pending;
    c.dispose();
    s.dispose();
  });
}
