import 'package:sisarasa_app/features/orders/complaint_form_screen.dart';
import 'package:sisarasa_app/features/orders/complaint_detail_screen.dart';
import 'package:sisarasa_app/features/seller/scan_screen.dart';
import 'package:sisarasa_app/features/seller/payout_screen.dart';
import 'package:sisarasa_app/features/seller/seller_shell.dart';
import 'package:sisarasa_app/features/seller/offer_form_screen.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:sisarasa_app/features/orders/order_detail_screen.dart';
import 'package:sisarasa_app/features/orders/checkout_screen.dart';
import 'package:sisarasa_app/core/models/order.dart';
import 'package:sisarasa_app/core/models/user.dart';
import 'package:flutter/services.dart';

import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sisarasa_app/app.dart';
import 'package:sisarasa_app/app_services.dart';
import 'package:sisarasa_app/core/models/offer.dart';
import 'package:sisarasa_app/core/theme/app_theme.dart';
import 'package:sisarasa_app/features/buyer/offer_detail_screen.dart';

import 'helpers/capture.dart';
import 'helpers/memory_store.dart';
import 'helpers/samples.dart';
import 'helpers/fake_http.dart';

void main() {
  testWidgets('render auth catalog and offer evidence', (tester) async {
    final font = FontLoader('Lato')
      ..addFont(rootBundle.load('assets/fonts/Lato-Regular.ttf'))
      ..addFont(rootBundle.load('assets/fonts/Lato-Bold.ttf'));
    final icons = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await font.load();
    await (FontLoader(
          'Liberation Serif',
        )..addFont(rootBundle.load('assets/fonts/LiberationSerif-Regular.ttf')))
        .load();
    await icons.load();
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final s = await AppServices.create(
      storage: MemoryStore(),
      initialOrigin: 'https://api.example.test',
    );
    await tester.pumpWidget(RepaintBoundary(child: SisaRasaApp(services: s)));
    await tester.pumpAndSettle();
    await capture(tester, 'login');
    await tester.pumpWidget(const SizedBox());
    s.dispose();
    final offer = {
      'id': 'ffffffff-ffff-4fff-8fff-ffffffffffff',
      'category': 'campuran',
      'allergens': ['susu'],
      'quota_available': 4,
      'normal_price': 100000,
      'discount_price': 40000,
      'discount_percent': 60,
      'pickup_start': '2026-10-06T07:00:00Z',
      'pickup_end': '2026-10-06T08:00:00Z',
      'safe_eat_until': '2026-10-06T09:00:00Z',
      'distance_km': 1.2,
    };
    final storage = MemoryStore();
    storage.values['private.session'] = jsonEncode(sessionJson());
    final buyer = await AppServices.create(
      storage: storage,
      initialOrigin: 'https://api.example.test',
      dio: Dio()
        ..httpClientAdapter = FakeHttp(
          (r) async => (
            200,
            {
              'items': [offer],
              'next_cursor': null,
            },
          ),
        ),
    );
    await tester.runAsync(() async {
      await tester.pumpWidget(
        RepaintBoundary(child: SisaRasaApp(services: buyer)),
      );
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pumpAndSettle(const Duration(milliseconds: 20));
    await capture(tester, 'catalog');
    await tester.pumpWidget(const SizedBox());
    buyer.dispose();
    await tester.pumpWidget(
      RepaintBoundary(
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: appTheme(),
          home: OfferDetailScreen(offer: Offer.fromJson(offer)),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await capture(tester, 'offer-detail');
  });
  testWidgets('render checkout and cached ticket evidence at 320px scale 2', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    late AppServices services;
    await tester.runAsync(() async {
      services = await AppServices.create(
        storage: MemoryStore(),
        initialOrigin: 'https://offline.example.test',
        dio: Dio()
          ..httpClientAdapter = FakeHttp((r) async {
            throw DioException(
              requestOptions: r,
              type: DioExceptionType.connectionError,
            );
          }),
      );
      await services.sessions.save(SessionBundle.fromJson(sessionJson()));
      await services.tickets.save(
        services.sessions.session!.user.id,
        Order.fromJson(orderJson()),
      );
    });
    Widget wrap(Widget child) => RepaintBoundary(
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: appTheme(),
        builder: (c, child) => MediaQuery(
          data: MediaQuery.of(c)
              .copyWith(textScaler: const TextScaler.linear(2)),
          child: child!,
        ),
        home: child,
      ),
    );
    final order = Order.fromJson(orderJson());
    final offer = Offer(
      id: 'offer',
      category: order.category,
      allergens: order.allergens,
      available: 1,
      normalPrice: 100000,
      discountPrice: 40000,
      discountPercent: 60,
      pickupStart: order.pickupStart,
      pickupEnd: order.pickupEnd,
      safeEatUntil: order.safeEatUntil,
    );
    await tester.runAsync(() async {
      await tester.pumpWidget(
        wrap(CheckoutScreen(services: services, offer: offer)),
      );
      await Future<void>.delayed(const Duration(milliseconds: 60));
    });
    await tester.pumpAndSettle();
    await capture(tester, 'checkout-large-text');
    await tester.runAsync(() async {
      await tester.pumpWidget(
        wrap(OrderDetailScreen(services: services, id: order.id)),
      );
      await Future<void>.delayed(const Duration(milliseconds: 60));
    });
    await tester.pump(const Duration(milliseconds: 20));
    await tester.scrollUntilVisible(
      find.text('Gerai Uji'),
      180,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pump();
    await capture(tester, 'ticket-offline-merchant');
    await tester.scrollUntilVisible(
      find.byType(QrImageView),
      120,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pump();
    await capture(tester, 'ticket-offline-qr-code');
    await tester.scrollUntilVisible(
      find.text('123456'),
      120,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pump();
    await capture(tester, 'ticket-offline-qr');
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    services.dispose();
  });
  testWidgets('render seller dashboard form and order evidence', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
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
                  ? {'packages_saved': 42}
                  : r.path.startsWith('/orders/')
                  ? {
                      ...orderJson(),
                      'pickup': null,
                      'allowed_actions': ['pickup', 'cancel'],
                    }
                  : {
                      'items': [sellerOfferJson()],
                      'next_cursor': null,
                    },
            ),
          ),
      );
      await services.sessions.save(
        SessionBundle.fromJson({
          ...sessionJson(),
          'user': userJson(role: 'seller'),
        }),
      );
    });
    Widget wrap(Widget home, {double scale = 1}) => RepaintBoundary(
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: appTheme(),
        builder: (c, child) => MediaQuery(
          data: MediaQuery.of(c).copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: home,
      ),
    );
    await tester.runAsync(() async {
      await tester.pumpWidget(wrap(SellerShell(services: services)));
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pumpAndSettle();
    await capture(tester, 'seller-dashboard');
    tester.view.physicalSize = const Size(320, 900);
    await tester.pumpWidget(
      wrap(OfferFormScreen(services: services), scale: 2),
    );
    await tester.pumpAndSettle();
    await capture(tester, 'seller-form-large-text');
    await tester.scrollUntilVisible(
      find.byKey(const Key('fitness')),
      180,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pump();
    await capture(tester, 'seller-fitness-large-text');
    await tester.runAsync(() async {
      await tester.pumpWidget(
        wrap(
          OrderDetailScreen(
            services: services,
            id: orderJson()['id']! as String,
          ),
          scale: 2,
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 80));
    });
    await tester.pump(const Duration(milliseconds: 20));
    await capture(tester, 'seller-order-large-text');
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    services.dispose();
  });
  testWidgets('render complaint scanner fallback and finance evidence', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final complaint = {
      'id': 'complaint',
      'order_id': orderJson()['id'],
      'reason': 'store_closed',
      'description': 'Gerai tutup saat jadwal pengambilan.',
      'status': 'open',
      'response': null,
      'response_due': '2026-10-07T07:00:00Z',
      'created_at': '2026-10-06T07:00:00Z',
      'media_ids': <String>[],
    };
    final payout = {
      'id': 'payout',
      'order_id': orderJson()['id'],
      'order_code': 'SR-ABCDEFGHJK',
      'gross': 40000,
      'fee': 2000,
      'net': 38000,
      'reason': 'completed',
      'due_at': '2026-10-06T08:00:00Z',
      'settled_at': null,
      'status': 'pending',
      'simulation': true,
    };
    late AppServices services;
    await tester.runAsync(() async {
      services = await AppServices.create(
        storage: MemoryStore(),
        initialOrigin: 'https://api.example.test',
        dio: Dio()
          ..httpClientAdapter = FakeHttp(
            (r) async => (
              200,
              r.path == '/payouts/summary'
                  ? {
                      'pending': 38000,
                      'held': 0,
                      'settled': 0,
                      'cancelled': 0,
                      'simulation': true,
                    }
                  : r.path.startsWith('/complaints/')
                  ? complaint
                  : {
                      'items': [payout],
                      'next_cursor': null,
                      'simulation': true,
                    },
            ),
          ),
      );
      await services.sessions.save(
        SessionBundle.fromJson({
          ...sessionJson(),
          'user': userJson(role: 'seller'),
        }),
      );
    });
    Widget wrap(Widget home, {double scale = 2}) => RepaintBoundary(
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: appTheme(),
        builder: (c, child) => MediaQuery(
          data: MediaQuery.of(c).copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: home,
      ),
    );
    await tester.pumpWidget(
      wrap(
        ScanScreen(
          services: services,
          cameraError: 'Izin kamera belum diberikan.',
        ),
      ),
    );
    await tester.pumpAndSettle();
    await capture(tester, 'scanner-otp-fallback');
    await tester.runAsync(() async {
      await tester.pumpWidget(
        wrap(
          ComplaintFormScreen(
            services: services,
            order: Order.fromJson(orderJson()),
            serverNow: DateTime.utc(2026, 10, 5, 12, 1),
          ),
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 80));
    });
    await tester.pumpAndSettle();
    await capture(tester, 'complaint-form-large-text');
    await tester.runAsync(() async {
      await tester.pumpWidget(
        wrap(ComplaintDetailScreen(services: services, id: 'complaint')),
      );
      await Future<void>.delayed(const Duration(milliseconds: 80));
    });
    await tester.pumpAndSettle();
    await capture(tester, 'complaint-detail-large-text');
    await tester.runAsync(() async {
      await tester.pumpWidget(
        wrap(
          Scaffold(
            appBar: AppBar(title: const Text('Keuangan simulasi')),
            body: PayoutScreen(services: services),
          ),
          scale: 1,
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 80));
    });
    await tester.pumpAndSettle();
    await capture(tester, 'payout-summary');
    await tester.scrollUntilVisible(
      find.text('Dana bersih (net)'),
      180,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pump();
    await capture(tester, 'payout-detail');
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    services.dispose();
  });
}
