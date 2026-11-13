import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sisarasa_app/app_services.dart';
import 'package:sisarasa_app/core/models/order.dart';
import 'package:sisarasa_app/core/models/user.dart';
import 'package:sisarasa_app/features/orders/order_actions.dart';

import '../helpers/fake_http.dart';
import '../helpers/memory_store.dart';
import '../helpers/samples.dart';

void main() {
  testWidgets(
    'reopened cancellation restores custom reason and replays the original key',
    (tester) async {
      final store = MemoryStore(), keys = <Object?>[], bodies = <Object?>[];
      late AppServices services;
      var calls = 0;
      await tester.runAsync(() async {
        services = await AppServices.create(
          storage: store,
          initialOrigin: 'https://api.example.test',
          dio: Dio()
            ..httpClientAdapter = FakeHttp((r) async {
              calls++;
              keys.add(r.headers['Idempotency-Key']);
              bodies.add(r.data);
              if (calls == 1) {
                throw DioException(
                  requestOptions: r,
                  type: DioExceptionType.connectionError,
                );
              }
              return (200, {'status': 'refunded'});
            }),
        );
        await services.sessions.save(
          SessionBundle.fromJson({
            ...sessionJson(),
            'user': userJson(role: 'seller'),
          }),
        );
      });
      final order = Order.fromJson({
        ...orderJson(),
        'pickup': null,
        'allowed_actions': ['cancel'],
      });
      Widget screen() => MaterialApp(
        home: Scaffold(
          body: OrderActions(
            services: services,
            order: order,
            offline: false,
            serverNow: order.serverTime,
            onChanged: () {},
          ),
        ),
      );
      await tester.pumpWidget(screen());
      Future<void> open() async {
        await tester.runAsync(() async {
          await tester.tap(find.text('Batalkan & refund simulasi'));
          await Future<void>.delayed(const Duration(milliseconds: 50));
        });
        await tester.pumpAndSettle();
      }

      var sends = 0;
      Future<void> send() async {
        sends++;
        await tester.runAsync(() async {
          await tester.tap(find.text('Batalkan & refund'));
          for (var n = 0; n < 200 && calls < sends; n++) {
            await Future<void>.delayed(const Duration(milliseconds: 10));
          }
          expect(calls, sends);
          if (sends == 2) {
            for (
              var n = 0;
              n < 200 &&
                  store.values.keys.any((k) => k.contains('.operation.'));
              n++
            ) {
              await Future<void>.delayed(const Duration(milliseconds: 10));
            }
          }
          await Future<void>.delayed(const Duration(milliseconds: 20));
        });
        await tester.pumpAndSettle();
      }

      await open();
      await tester.enterText(
        find.byType(TextField),
        'Dapur mengalami gangguan listrik.',
      );
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      await send();
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(screen());
      await open();
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'Dapur mengalami gangguan listrik.',
      );
      await send();
      expect(calls, 2);
      expect(keys.last, keys.first);
      expect(bodies.last, bodies.first);
      expect(
        store.values.keys.where((k) => k.contains('.operation.')),
        isEmpty,
      );
      await tester.pumpWidget(const SizedBox());
      services.dispose();
    },
  );
  testWidgets(
    'seller cancel action disables while its idempotent request is pending',
    (tester) async {
      final gate = Completer<void>();
      late AppServices services;
      await tester.runAsync(() async {
        services = await AppServices.create(
          storage: MemoryStore(),
          initialOrigin: 'https://api.example.test',
          dio: Dio()
            ..httpClientAdapter = FakeHttp((r) async {
              await gate.future;
              return (200, {'status': 'refunded'});
            }),
        );
        await services.sessions.save(
          SessionBundle.fromJson({
            ...sessionJson(),
            'user': userJson(role: 'seller'),
          }),
        );
      });
      final order = Order.fromJson({
        ...orderJson(),
        'pickup': null,
        'allowed_actions': ['cancel'],
      });
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OrderActions(
              services: services,
              order: order,
              offline: false,
              serverNow: order.serverTime,
              onChanged: () {},
            ),
          ),
        ),
      );
      await tester.runAsync(() async {
        await tester.tap(find.text('Batalkan & refund simulasi'));
        await Future<void>.delayed(const Duration(milliseconds: 50));
      });
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        await tester.tap(find.text('Batalkan & refund'));
        await Future<void>.delayed(const Duration(milliseconds: 50));
      });
      await tester.pump(const Duration(milliseconds: 350));
      expect(
        tester
            .widget<OutlinedButton>(
              find.widgetWithText(OutlinedButton, 'Batalkan & refund simulasi'),
            )
            .onPressed,
        isNull,
      );
      gate.complete();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 20));
      }
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      services.dispose();
      await tester.pump(const Duration(milliseconds: 20));
    },
  );
}
