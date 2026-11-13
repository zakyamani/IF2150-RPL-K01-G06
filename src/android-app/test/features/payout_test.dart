import 'package:flutter/material.dart';
import 'package:sisarasa_app/features/seller/seller_shell.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sisarasa_app/app_services.dart';
import 'package:sisarasa_app/core/models/user.dart';
import 'package:sisarasa_app/features/seller/payout_controller.dart';

import '../helpers/fake_http.dart';
import '../helpers/memory_store.dart';
import '../helpers/samples.dart';

void main() {
  testWidgets('seller navigation exposes finance and full profile separately', (
    tester,
  ) async {
    late AppServices services;
    await tester.runAsync(() async {
      services = await AppServices.create(
        storage: MemoryStore(),
        initialOrigin: 'https://api.example.test',
        dio: Dio()
          ..httpClientAdapter = FakeHttp(
            (r) async => (
              200,
              r.path == '/merchant/profile'
                  ? merchantJson()
                  : r.path == '/metrics'
                  ? {'packages_saved': 1}
                  : r.path == '/payouts/summary'
                  ? {
                      'pending': 0,
                      'held': 0,
                      'settled': 0,
                      'cancelled': 0,
                      'simulation': true,
                    }
                  : {'items': [], 'next_cursor': null},
            ),
          ),
      );
      await services.sessions.save(
        SessionBundle.fromJson({
          ...sessionJson(),
          'user': userJson(role: 'seller'),
        }),
      );
      await tester.pumpWidget(
        MaterialApp(home: SellerShell(services: services)),
      );
      await Future<void>.delayed(const Duration(milliseconds: 80));
    });
    await tester.pumpAndSettle();
    expect(find.text('Keuangan'), findsOneWidget);
    await tester.runAsync(() async {
      await tester.tap(find.text('Keuangan'));
      await Future<void>.delayed(const Duration(milliseconds: 80));
    });
    await tester.pumpAndSettle();
    expect(find.text('Keuangan simulasi'), findsWidgets);
    await tester.tap(find.text('Profil'));
    await tester.pumpAndSettle();
    expect(find.text('Kelola profil gerai'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    services.dispose();
  });

  test('finance uses exact snapshots and retains pending held settled cancelled states', () async {
    final row = {
      'id': 'p',
      'order_id': orderJson()['id'],
      'order_code': 'SR-ABCDEFGHJK',
      'gross': 40000,
      'fee': 2000,
      'net': 38000,
      'reason': 'completed',
      'due_at': '2026-10-06T08:00:00Z',
      'settled_at': null,
      'simulation': true,
    };
    final s = await AppServices.create(
      storage: MemoryStore(),
      initialOrigin: 'https://api.example.test',
      dio: Dio()
        ..httpClientAdapter = FakeHttp(
          (r) async => (
            200,
            r.path.endsWith('/summary')
                ? {
                    'pending': 38000,
                    'held': 38000,
                    'settled': 38000,
                    'cancelled': 38000,
                    'simulation': true,
                  }
                : {
                    'items': [
                      'pending',
                      'held',
                      'settled',
                      'cancelled',
                    ].map((v) => {...row, 'status': v}).toList(),
                    'next_cursor': null,
                    'simulation': true,
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
    final c = PayoutController(s);
    expect(await c.load(), true);
    expect(c.items.first.gross, 40000);
    expect(c.items.first.fee, 2000);
    expect(c.items.first.net, 38000);
    expect(
      c.items.map((p) => p.status),
      containsAll(['pending', 'held', 'settled', 'cancelled']),
    );
    c.dispose();
    s.dispose();
  });
}
