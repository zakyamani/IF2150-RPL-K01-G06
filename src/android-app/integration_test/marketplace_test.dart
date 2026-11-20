import 'test_config.dart';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:sisarasa_app/app_services.dart';
import 'package:sisarasa_app/core/models/user.dart';
import 'package:sisarasa_app/core/storage/secure_store.dart';
import 'package:sisarasa_app/core/theme/app_theme.dart';
import 'package:sisarasa_app/features/auth/auth_controller.dart';
import 'package:sisarasa_app/features/buyer/catalog_screen.dart';
import 'package:sisarasa_app/features/orders/history_screen.dart';
import 'package:sisarasa_app/features/orders/order_repository.dart';
import 'package:sisarasa_app/features/orders/payment_screen.dart';
import 'package:sisarasa_app/features/seller/offer_form_screen.dart';
import 'package:sisarasa_app/features/seller/orders_screen.dart';
import 'package:sisarasa_app/features/seller/profile_screen.dart';
import 'package:sisarasa_app/features/orders/order_detail_screen.dart';
import 'package:sisarasa_app/features/seller/otp_screen.dart';

const nativeStorage = PlatformSecureStore(
  prefix: 'sisarasa.integration.marketplace.',
);
Future<void> captureM10(WidgetTester tester, String name) async {
  await tester.pumpAndSettle();
  debugPrint('M10_CAPTURE $name');
  await Future<void>.delayed(const Duration(seconds: 2));
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'native marketplace, review and seller cancellation UI against PostgreSQL',
    (tester) async {
      final buyer = await AppServices.create(
        storage: nativeStorage,
        initialOrigin: integrationApiOrigin,
      );
      await buyer.sessions.clear();
      final seller = await AppServices.create(
        storage: const PlatformSecureStore(
          prefix: 'sisarasa.integration.seller.',
        ),
        initialOrigin: integrationApiOrigin,
      );
      await seller.sessions.clear();
      final stamp = DateTime.now().microsecondsSinceEpoch;
      final buyAuth = AuthController(buyer), sellAuth = AuthController(seller);
      expect(
        await buyAuth.submit(
          email: 'native-b-$stamp@example.test',
          password: 'Native-Testing-2026',
          name: 'Pembeli Native',
          registering: true,
        ),
        true,
        reason: buyAuth.error,
      );
      expect(
        await sellAuth.submit(
          email: 'native-s-$stamp@example.test',
          password: 'Native-Testing-2026',
          name: 'Gerai Native',
          registering: true,
          role: Role.seller,
        ),
        true,
        reason: sellAuth.error,
      );
      await seller.api.patch('/merchant/profile', {
        'shop_name': 'Gerai Native',
        'address': 'Alamat pengujian Bandung',
        'latitude': -6.9,
        'longitude': 107.6,
      }, (j) => j);
      await tester.pumpWidget(
        MaterialApp(
          theme: appTheme(),
          home: ProfileScreen(services: seller),
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();
      expect(find.text('Gerai Native'), findsOneWidget);
      await captureM10(tester, 'int-tc12-profil-gerai');
      await tester.pumpWidget(
        MaterialApp(
          theme: appTheme(),
          home: OfferFormScreen(services: seller),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Penawaran baru'), findsOneWidget);
      await captureM10(tester, 'uc01-form-penawaran');
      await tester.pumpWidget(
        MaterialApp(
          theme: appTheme(),
          home: Scaffold(
            appBar: AppBar(title: const Text('Pesanan masuk')),
            body: SellerOrdersScreen(services: seller),
          ),
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();
      expect(find.text('Belum ada pesanan'), findsOneWidget);
      await captureM10(tester, 'uc04-tc02-pesanan-kosong');
      final now = DateTime.now().toUtc();
      final offer = await seller.api.post('/offers', {
        'category': 'campuran',
        'allergens': <String>[],
        'quota': 3,
        'normal_price': 100000,
        'discount_price': 40000,
        'pickup_start': now.add(const Duration(seconds: 2)).toIso8601String(),
        'pickup_end': now.add(const Duration(hours: 1)).toIso8601String(),
        'safe_eat_until': now.add(const Duration(hours: 2)).toIso8601String(),
        'fitness_confirmed': true,
      }, (j) => j);
      await tester.pumpWidget(
        MaterialApp(
          theme: appTheme(),
          home: Scaffold(body: CatalogScreen(services: buyer)),
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Rp40.000').first,
        220,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Gerai Native'), findsNothing);
      await captureM10(tester, 'uc02-katalog-anonim');
      final repo = OrderRepository(buyer);
      final checkout = await repo.checkout(offer['id'] as String);
      final paymentNav = GlobalKey<NavigatorState>();
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: paymentNav,
          theme: appTheme(),
          home: const Scaffold(body: Text('Pembayaran pembeli')),
        ),
      );
      final paymentResult = paymentNav.currentState!.push<bool>(
        MaterialPageRoute(
          builder: (_) => PaymentScreen(services: buyer, id: checkout.orderId),
        ),
      );
      await tester.pumpAndSettle();
      await Future<void>.delayed(const Duration(milliseconds: 500));
      await tester.scrollUntilVisible(
        find.text('Simulasikan berhasil'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await captureM10(tester, 'uc03-invoice-simulasi');
      await tester.tap(find.text('Simulasikan berhasil'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Jalankan simulasi'));
      await Future<void>.delayed(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();
      await Future<void>.delayed(const Duration(seconds: 3));
      expect(await paymentResult, true);
      final order = await repo.order(checkout.orderId);
      expect(order.pickup, isNotNull);
      expect(order.merchant?.name, 'Gerai Native');
      await tester.pumpWidget(
        MaterialApp(
          theme: appTheme(),
          home: Scaffold(
            appBar: AppBar(title: const Text('Pesanan masuk')),
            body: SellerOrdersScreen(services: seller),
          ),
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();
      expect(find.text(order.code), findsOneWidget);
      expect(find.text('Siap diambil'), findsOneWidget);
      expect(find.textContaining('Ambil sebelum'), findsOneWidget);
      await captureM10(tester, 'uc04-tc01-pesanan-masuk');
      await tester.pumpWidget(
        MaterialApp(
          theme: appTheme(),
          home: OrderDetailScreen(services: buyer, id: order.id),
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.byType(QrImageView),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pump();
      expect(find.byType(QrImageView), findsOneWidget);
      debugPrint('NATIVE_TICKET_READY');
      await Future<void>.delayed(const Duration(seconds: 3));
      await tester.scrollUntilVisible(
        find.text('Riwayat status'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Beri ulasan'), findsNothing);
      expect(order.allowedActions, isNot(contains('review')));
      await captureM10(tester, 'uc07-tc03-belum-selesai');
      final nav = GlobalKey<NavigatorState>();
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: nav,
          theme: appTheme(),
          home: const Scaffold(body: Text('Pesanan penjual')),
        ),
      );
      final pickup = nav.currentState!.push(
        MaterialPageRoute(
          builder: (_) => OtpScreen(services: seller, orderId: order.code),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).last, order.pickup!.otp);
      await tester.scrollUntilVisible(
        find.text('Konfirmasi pengambilan'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pump();
      await tester.tap(find.text('Konfirmasi pengambilan'));
      await tester.pumpAndSettle();
      expect(find.text('Serahkan paket?'), findsOneWidget);
      await captureM10(tester, 'uc05-konfirmasi-otp');
      await tester.tap(find.widgetWithText(FilledButton, 'Validasi OTP'));
      await Future<void>.delayed(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();
      expect(await pickup, isNotNull);
      expect((await repo.order(order.id)).status.wire, 'completed');
      await tester.pumpWidget(
        MaterialApp(
          key: const ValueKey('buyer-history'),
          theme: appTheme(),
          home: Scaffold(
            appBar: AppBar(title: const Text('Riwayat transaksi')),
            body: HistoryScreen(services: buyer),
          ),
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();
      expect(find.text(order.code), findsOneWidget);
      expect(find.text('Selesai'), findsOneWidget);
      await captureM10(tester, 'uc07-tc01-riwayat');
      await tester.tap(find.text(order.code));
      await Future<void>.delayed(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();
      final reviewButton = find.text('Beri ulasan');
      await tester.scrollUntilVisible(
        reviewButton,
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(reviewButton);
      await tester.pumpAndSettle();
      expect(find.text('Ulas paket'), findsOneWidget);
      await tester.tap(find.byTooltip('5 bintang'));
      const comment = 'Paket baik dan pengambilan lancar.';
      await tester.enterText(find.byType(TextField), comment);
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      final submitReview = find.text('Kirim ulasan');
      await tester.scrollUntilVisible(
        submitReview,
        160,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(submitReview);
      await Future<void>.delayed(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();
      expect(find.text('Ulasan berhasil disimpan.'), findsOneWidget);
      await tester.ensureVisible(find.text('Ulasan berhasil disimpan.'));
      await captureM10(tester, 'uc07-tc02-ulasan-tersimpan');
      final sellerId = seller.sessions.session!.user.id;
      final ratings = await seller.api.get(
        '/reviews/merchant/$sellerId',
        (j) => j,
      );
      expect(ratings['rating_count'], 1);
      expect((ratings['items'] as List).single['comment'], comment);
      final summary = await seller.api.get('/payouts/summary', (j) => j);
      expect(summary['pending'], 38000);
      expect(summary['simulation'], true);
      // Leave a second real paid ticket encrypted for a separate APK/process recovery test.
      await repo.newAttempt(offer['id'] as String);
      final second = await repo.checkout(offer['id'] as String);
      await repo.demoPayment(second.intentId, 'succeeded');
      await repo.order(second.orderId);
      await nativeStorage.write('integration.order_id', second.orderId);
      await repo.newAttempt(offer['id'] as String);
      final toCancel = await repo.checkout(offer['id'] as String);
      await repo.demoPayment(toCancel.intentId, 'succeeded');
      await tester.pumpWidget(
        MaterialApp(
          key: const ValueKey('seller-cancellation'),
          theme: appTheme(),
          home: OrderDetailScreen(services: seller, id: toCancel.orderId),
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();
      final cancelButton = find.text('Batalkan & refund simulasi');
      await tester.scrollUntilVisible(
        cancelButton,
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(cancelButton);
      await tester.pumpAndSettle();
      expect(cancelButton.hitTestable(), findsOneWidget);
      await tester.tap(cancelButton.hitTestable());
      await Future<void>.delayed(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();
      expect(find.text('Batalkan pesanan?'), findsOneWidget);
      await captureM10(tester, 'uc06-tc01-konfirmasi-refund');
      await tester.tap(find.text('Batalkan & refund'));
      await Future<void>.delayed(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();
      expect((await repo.order(toCancel.orderId)).status.wire, 'refunded');
      await tester.pumpWidget(const SizedBox());
      buyAuth.dispose();
      sellAuth.dispose();
      buyer.dispose();
      seller.dispose();
    },
  );
}
