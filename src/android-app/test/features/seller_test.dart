import 'dart:typed_data';

import 'package:sisarasa_app/features/seller/seller_repository.dart';
import 'package:sisarasa_app/features/seller/seller_shell.dart';
import 'package:sisarasa_app/features/seller/profile_screen.dart';
import 'package:sisarasa_app/features/orders/order_controller.dart';
import 'package:sisarasa_app/features/orders/order_repository.dart';
import 'package:sisarasa_app/core/models/order.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sisarasa_app/app_services.dart';
import 'package:sisarasa_app/core/models/user.dart';
import 'package:sisarasa_app/features/seller/offer_form_controller.dart';
import 'package:sisarasa_app/features/seller/offer_form_screen.dart';

import '../helpers/fake_http.dart';
import '../helpers/memory_store.dart';
import '../helpers/samples.dart';

void main() {
  test('shop upload attaches documented photo response and reloads its visible profile', () async {
    final paths = <String>[];
    final s = await AppServices.create(
      storage: MemoryStore(),
      initialOrigin: 'https://api.example.test',
      dio: Dio()
        ..httpClientAdapter = FakeHttp((r) async {
          paths.add(r.path);
          if (r.path == '/media') return (201, {'id': 'new-photo'});
          if (r.path == '/merchant/photo') {
            return (200, {'photo_id': 'new-photo'});
          }
          return (200, {...merchantJson(), 'photo_id': 'new-photo'});
        }),
    );
    await s.sessions.save(
      SessionBundle.fromJson({
        ...sessionJson(),
        'user': userJson(role: 'seller'),
      }),
    );
    final repo = SellerRepository(s);
    final id = await repo.upload(
      Uint8List.fromList([255, 216, 255, 0]),
      'shop',
    );
    final profile = await repo.setPhoto(id);
    expect(profile.photoId, 'new-photo');
    expect(paths, ['/media', '/merchant/photo', '/merchant/profile']);
    s.dispose();
  });
  test(
    'all seller order states remain available in paginated history',
    () async {
      final s = await AppServices.create(
        storage: MemoryStore(),
        initialOrigin: 'https://api.example.test',
        dio: Dio()
          ..httpClientAdapter = FakeHttp(
            (r) async => (
              200,
              {
                'items': OrderStatus.values
                    .map((status) => {...orderJson(), 'status': status.wire})
                    .toList(),
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
      await c.load();
      expect(c.items.map((o) => o.status), containsAll(OrderStatus.values));
      c.dispose();
      s.dispose();
    },
  );
  testWidgets('closing offer requires explicit dialog confirmation', (
    tester,
  ) async {
    var closes = 0;
    late AppServices services;
    await tester.runAsync(() async {
      services = await AppServices.create(
        storage: MemoryStore(),
        initialOrigin: 'https://api.example.test',
        dio: Dio()
          ..httpClientAdapter = FakeHttp((r) async {
            if (r.path.endsWith('/close')) {
              closes++;
              return (200, {...sellerOfferJson(), 'status': 'closed'});
            }
            return (
              200,
              r.path == '/merchant/profile'
                  ? merchantJson()
                  : r.path == '/metrics'
                  ? {'packages_saved': 4}
                  : {
                      'items': [sellerOfferJson()],
                      'next_cursor': null,
                    },
            );
          }),
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
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Tutup'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tutup'));
    await tester.pumpAndSettle();
    expect(closes, 0);
    await tester.tap(find.text('Batal'));
    await tester.pumpAndSettle();
    expect(closes, 0);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tutup'));
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      await tester.tap(find.text('Tutup penawaran'));
      await Future<void>.delayed(const Duration(milliseconds: 80));
    });
    await tester.pumpAndSettle();
    expect(closes, 1);
    await tester.pumpWidget(const SizedBox());
    services.dispose();
  });
  testWidgets(
    'profile network failure shows retry and photo failure remains recoverable',
    (tester) async {
      var failed = true;
      late AppServices services;
      await tester.runAsync(() async {
        services = await AppServices.create(
          storage: MemoryStore(),
          initialOrigin: 'https://api.example.test',
          dio: Dio()
            ..httpClientAdapter = FakeHttp(
              (r) async => r.path.startsWith('/media/')
                  ? (
                      403,
                      {
                        'code': 'MEDIA_DENIED',
                        'message': 'Foto belum tersedia.',
                      },
                    )
                  : failed
                  ? (
                      503,
                      {
                        'code': 'UNAVAILABLE',
                        'message': 'Gerai belum dapat dimuat.',
                      },
                    )
                  : (200, {...merchantJson(), 'photo_id': 'photo'}),
            ),
        );
        await services.sessions.save(
          SessionBundle.fromJson({
            ...sessionJson(),
            'user': userJson(role: 'seller'),
          }),
        );
        await tester.pumpWidget(
          MaterialApp(home: ProfileScreen(services: services)),
        );
        await Future<void>.delayed(const Duration(milliseconds: 80));
      });
      await tester.pumpAndSettle();
      expect(find.text('Gerai belum dapat dimuat.'), findsOneWidget);
      failed = false;
      await tester.runAsync(() async {
        await tester.tap(find.text('Coba lagi'));
        await Future<void>.delayed(const Duration(milliseconds: 80));
      });
      await tester.pumpAndSettle();
      expect(find.text('Kedai Hijau'), findsOneWidget);
      expect(find.text('Foto belum tersedia.'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      services.dispose();
    },
  );

  test(
    'fitness unchecked and two hour boundary use integer prices and UTC dates',
    () async {
      final s = await AppServices.create(
        storage: MemoryStore(),
        initialOrigin: 'https://api.example.test',
      );
      final c = OfferFormController(s, now: () => DateTime.utc(2026, 10, 6, 7));
      c.normalPrice = '100000';
      c.discountPrice = '40000';
      c.quota = '3';
      c.start = DateTime.parse('2026-10-06T16:00:00+07:00');
      c.end = DateTime.parse('2026-10-06T17:00:00+07:00');
      c.safe = DateTime.parse('2026-10-06T18:00:00+07:00');
      expect(c.fitness, false);
      expect(c.validate(), false);
      c.fitness = true;
      expect(c.validate(), true);
      expect(c.payload['pickup_start'], '2026-10-06T09:00:00.000Z');
      c.start = c.start.add(const Duration(milliseconds: 1));
      expect(c.validate(), false);
      expect(c.fields['pickup_start'], isNotNull);
      c.dispose();
      s.dispose();
    },
  );
  test(
    'offer conflict preserves draft and explains held or previously paid state',
    () async {
      final s = await AppServices.create(
        storage: MemoryStore(),
        initialOrigin: 'https://api.example.test',
        dio: Dio()
          ..httpClientAdapter = FakeHttp(
            (r) async => (
              409,
              {
                'code': 'OFFER_PAID',
                'message': 'Paket pernah dibayar dan tidak dapat diubah.',
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
      final c = OfferFormController(
        s,
        offerId: 'offer',
        now: () => DateTime.utc(2026, 10, 6, 7),
      );
      c.normalPrice = '100000';
      c.discountPrice = '40000';
      c.quota = '3';
      c.fitness = true;
      expect(await c.save(), false);
      expect(c.discountPrice, '40000');
      expect(c.error, contains('pernah dibayar'));
      c.dispose();
      s.dispose();
    },
  );
  testWidgets(
    'offer form has date selectors and unchecked fitness at 320px scale 2 with keyboard',
    (tester) async {
      tester.view.physicalSize = const Size(320, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final s = await AppServices.create(
        storage: MemoryStore(),
        initialOrigin: 'https://api.example.test',
      );
      await tester.pumpWidget(
        MaterialApp(
          builder: (c, child) => MediaQuery(
            data: MediaQuery.of(c)
                .copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
          home: OfferFormScreen(services: s),
        ),
      );
      await tester.enterText(find.byType(TextFormField).first, '3');
      tester.view.viewInsets = const FakeViewPadding(bottom: 280);
      addTearDown(tester.view.resetViewInsets);
      await tester.pump();
      await tester.scrollUntilVisible(
        find.byKey(const Key('fitness')),
        180,
        scrollable: find.byType(Scrollable).first,
      );
      expect(
        tester.widget<CheckboxListTile>(find.byKey(const Key('fitness'))).value,
        false,
      );
      expect(find.byKey(const Key('pickup-start')), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      s.dispose();
    },
  );
}
