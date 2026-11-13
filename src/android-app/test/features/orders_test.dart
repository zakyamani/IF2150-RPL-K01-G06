import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sisarasa_app/app_services.dart';
import 'package:sisarasa_app/core/models/order.dart';
import 'package:sisarasa_app/core/models/user.dart';
import 'package:sisarasa_app/features/orders/order_controller.dart';
import 'package:sisarasa_app/features/orders/order_repository.dart';
import 'package:sisarasa_app/features/orders/order_detail_screen.dart';

import '../helpers/fake_http.dart';
import '../helpers/memory_store.dart';
import '../helpers/samples.dart';

const checkout = {
  'order_id': 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',
  'intent_id': 'cccccccc-cccc-4ccc-8ccc-cccccccccccc',
  'code': 'SR-ABCDEFGHJK',
  'invoice': 'INV-test',
  'price': 40000,
  'fee': 2000,
  'payment_deadline': '2026-10-05T12:15:00Z',
};
void main() {
  testWidgets('invoice without server pay action exposes no payment button', (
    tester,
  ) async {
    final j = {
      ...orderJson(),
      'status': 'pending_payment',
      'merchant': null,
      'pickup': null,
      'allowed_actions': <String>[],
      'payment': {...(orderJson()['payment'] as Map), 'status': 'pending'},
    };
    late AppServices services;
    await tester.runAsync(() async {
      services = await AppServices.create(
        storage: MemoryStore(),
        initialOrigin: 'https://api.example.test',
        dio: Dio()..httpClientAdapter = FakeHttp((r) async => (200, j)),
      );
      await services.sessions.save(SessionBundle.fromJson(sessionJson()));
      await tester.pumpWidget(
        MaterialApp(
          home: OrderDetailScreen(services: services, id: j['id']! as String),
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 80));
    });
    await tester.pump();
    expect(find.text('Lanjutkan pembayaran simulasi'), findsNothing);
    await tester.pumpWidget(const SizedBox());
    services.dispose();
  });

  test('double tap and lost response reuse one durable checkout key across controller restart', () async {
    final gate = Completer<void>();
    var attempts = 0;
    final keys = <Object?>[];
    final http = FakeHttp((r) async {
      keys.add(r.headers['Idempotency-Key']);
      attempts++;
      if (attempts == 1) {
        await gate.future;
        throw DioException(
          requestOptions: r,
          type: DioExceptionType.connectionError,
        );
      }
      return (201, checkout);
    });
    final s = await AppServices.create(
      storage: MemoryStore(),
      initialOrigin: 'https://api.example.test',
      dio: Dio()..httpClientAdapter = http,
    );
    await s.sessions.save(SessionBundle.fromJson(sessionJson()));
    final c = CheckoutController(s, 'offer');
    final first = c.checkout();
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(await c.checkout(), false);
    gate.complete();
    expect(await first, false);
    c.dispose();
    final restored = CheckoutController(s, 'offer');
    expect(await restored.checkout(), true);
    expect(keys.length, 2);
    expect(keys[0], keys[1]);
    expect(restored.result!.orderId, checkout['order_id']);
    restored.dispose();
    s.dispose();
  });
  test('offline fresh controller restores encrypted ticket and terminal reconciliation invalidates it', () async {
    final storage = MemoryStore();
    final s = await AppServices.create(
      storage: storage,
      initialOrigin: 'https://api.example.test',
      dio: Dio()
        ..httpClientAdapter = FakeHttp((r) async {
          throw DioException(
            requestOptions: r,
            type: DioExceptionType.connectionError,
          );
        }),
    );
    await s.sessions.save(SessionBundle.fromJson(sessionJson()));
    await s.tickets.save(
      s.sessions.session!.user.id,
      Order.fromJson(orderJson()),
      syncedAt: DateTime.utc(2026, 10, 5, 12, 1),
    );
    final c = OrderController(
      OrderRepository(s),
      checkout['order_id']! as String,
    );
    expect(await c.load(), true);
    expect(c.offline, true);
    expect(c.order!.pickup!.otp, '123456');
    expect(c.ticketExpired, true);
    c.dispose();
    s.api.dio.httpClientAdapter = FakeHttp(
      (r) async => (
        200,
        {
          ...orderJson(),
          'status': 'completed',
          'pickup': null,
          'allowed_actions': [],
        },
      ),
    );
    final online = OrderController(
      OrderRepository(s),
      checkout['order_id']! as String,
    );
    expect(await online.load(), true);
    expect(await s.tickets.list(s.sessions.session!.user.id), isEmpty);
    online.dispose();
    s.dispose();
  });
  testWidgets(
    'paid ticket shows reveal OTP and offline label at 320px text scale 2',
    (tester) async {
      tester.view.physicalSize = const Size(320, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final storage = MemoryStore();
      late AppServices s;
      await tester.runAsync(() async {
        s = await AppServices.create(
          storage: storage,
          initialOrigin: 'https://api.example.test',
          dio: Dio()
            ..httpClientAdapter = FakeHttp((r) async {
              throw DioException(
                requestOptions: r,
                type: DioExceptionType.connectionError,
              );
            }),
        );
        await s.sessions.save(SessionBundle.fromJson(sessionJson()));
        await s.tickets.save(
          s.sessions.session!.user.id,
          Order.fromJson(orderJson()),
        );
      });
      await tester.runAsync(() async {
        await tester.pumpWidget(
          MaterialApp(
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: const TextScaler.linear(2)),
              child: child!,
            ),
            home: OrderDetailScreen(
              services: s,
              id: checkout['order_id']! as String,
            ),
          ),
        );
        await Future<void>.delayed(const Duration(milliseconds: 60));
      });
      await tester.pump(const Duration(milliseconds: 30));
      await tester.scrollUntilVisible(
        find.text('Gerai Uji'),
        180,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Gerai Uji'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('123456'),
        180,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('123456'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      s.dispose();
    },
  );
  test('pending payment resumes from order and failed payment never reveals merchant', () async {
    final j = {
      ...orderJson(),
      'status': 'pending_payment',
      'merchant': null,
      'pickup': null,
      'allowed_actions': ['pay'],
      'payment': {...(orderJson()['payment'] as Map), 'status': 'pending'},
    };
    final s = await AppServices.create(
      storage: MemoryStore(),
      initialOrigin: 'https://api.example.test',
      dio: Dio()
        ..httpClientAdapter = FakeHttp((r) async {
          if (r.method == 'POST') {
            expect((r.data as Map)['outcome'], 'failed');
            j['status'] = 'cancelled';
            j['allowed_actions'] = [];
            j['payment'] = {...(j['payment'] as Map), 'status': 'failed'};
            return (200, {'status': 'cancelled'});
          }
          return (200, j);
        }),
    );
    await s.sessions.save(SessionBundle.fromJson(sessionJson()));
    final c = OrderController(
      OrderRepository(s),
      checkout['order_id']! as String,
    );
    await c.load();
    expect(c.order!.payment!.id, checkout['intent_id']);
    expect(await c.pay('failed'), true);
    expect(c.order!.status, OrderStatus.cancelled);
    expect(c.order!.merchant, isNull);
    expect(c.order!.pickup, isNull);
    c.dispose();
    s.dispose();
  });
}
