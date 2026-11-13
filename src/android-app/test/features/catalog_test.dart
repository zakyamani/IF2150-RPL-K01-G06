import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sisarasa_app/app_services.dart';
import 'package:sisarasa_app/core/models/user.dart';
import 'package:sisarasa_app/core/models/offer.dart';
import 'package:sisarasa_app/core/theme/app_theme.dart';
import 'package:sisarasa_app/features/buyer/catalog_controller.dart';
import 'package:sisarasa_app/features/buyer/offer_detail_screen.dart';

import '../helpers/memory_store.dart';
import '../helpers/fake_http.dart';
import '../helpers/samples.dart';

void main() {
  test(
    'location denial retains usable catalog and category pagination',
    () async {
      final http = FakeHttp(
        (r) async =>
            (200, {'items': [], 'next_cursor': null, 'disclaimer': 'alergen'}),
      );
      final s = await AppServices.create(
        storage: MemoryStore(),
        initialOrigin: 'https://api.example.test',
        dio: Dio()..httpClientAdapter = http,
      );
      await s.sessions.save(SessionBundle.fromJson(sessionJson()));
      final c = CatalogController(
        s,
        locate: () async => throw StateError('denied'),
      );
      await c.locate();
      await c.load(category: 'campuran');
      expect(c.error, isNull);
      expect(c.locationMessage, isNotNull);
      expect(http.calls.last.queryParameters['category'], 'campuran');
      expect(http.calls.last.queryParameters.containsKey('lat'), isFalse);
      c.dispose();
      s.dispose();
    },
  );
  testWidgets(
    'anonymous detail shows complete safety information at 320px scale 2',
    (tester) async {
      tester.view.physicalSize = const Size(320, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final offer = Offer(
        id: 'offer',
        category: 'campuran',
        allergens: ['susu'],
        available: 1,
        normalPrice: 100000,
        discountPrice: 40000,
        discountPercent: 60,
        pickupStart: DateTime.utc(2026, 10, 5, 12),
        pickupEnd: DateTime.utc(2026, 10, 5, 13),
        safeEatUntil: DateTime.utc(2026, 10, 5, 14),
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: appTheme(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
          home: OfferDetailScreen(offer: offer),
        ),
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.textContaining('Identitas toko'),
        160,
      );
      expect(find.textContaining('Identitas toko'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('susu'), 160);
      expect(find.text('susu'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.textContaining('Batas konsumsi'),
        -160,
      );
      expect(find.textContaining('Batas konsumsi'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
