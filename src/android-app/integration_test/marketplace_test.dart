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
import 'package:sisarasa_app/features/orders/order_repository.dart';
import 'package:sisarasa_app/features/orders/order_detail_screen.dart';
import 'package:sisarasa_app/features/seller/otp_screen.dart';

const nativeStorage = PlatformSecureStore(
  prefix: 'sisarasa.integration.marketplace.',
);
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'native buyer paid QR, seller OTP confirmation and review against real PostgreSQL backend',
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
      final repo = OrderRepository(buyer);
      final checkout = await repo.checkout(offer['id'] as String);
      await repo.demoPayment(checkout.intentId, 'succeeded');
      await Future<void>.delayed(const Duration(seconds: 3));
      final order = await repo.order(checkout.orderId);
      expect(order.pickup, isNotNull);
      expect(order.merchant?.name, 'Gerai Native');
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
      await tester.tap(find.widgetWithText(FilledButton, 'Validasi OTP'));
      await Future<void>.delayed(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();
      expect(await pickup, isNotNull);
      expect((await repo.order(order.id)).status.wire, 'completed');
      await buyer.api.post('/reviews', {
        'order_id': order.id,
        'rating': 5,
        'comment': 'Pengambilan native berhasil.',
      }, (j) => j);
      final summary = await seller.api.get('/payouts/summary', (j) => j);
      expect(summary['pending'], 38000);
      expect(summary['simulation'], true);
      // Leave a second real paid ticket encrypted for a separate APK/process recovery test.
      await repo.newAttempt(offer['id'] as String);
      final second = await repo.checkout(offer['id'] as String);
      await repo.demoPayment(second.intentId, 'succeeded');
      await repo.order(second.orderId);
      await nativeStorage.write('integration.order_id', second.orderId);
      await tester.pumpWidget(const SizedBox());
      buyAuth.dispose();
      sellAuth.dispose();
      buyer.dispose();
      seller.dispose();
    },
  );
}
