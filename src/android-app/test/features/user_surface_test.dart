import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:sisarasa_app/app_services.dart';
import 'package:sisarasa_app/core/models/user.dart';
import 'package:sisarasa_app/core/theme/app_theme.dart';
import 'package:sisarasa_app/features/auth/login_screen.dart';
import 'package:sisarasa_app/features/settings/account_screen.dart';
import 'package:sisarasa_app/features/settings/server_settings_screen.dart';
import 'package:sisarasa_app/features/orders/order_detail_screen.dart';

import '../helpers/memory_store.dart';
import '../helpers/samples.dart';
import '../helpers/fake_http.dart';

void main() {
  testWidgets(
    'normal sign-in has no server or network configuration controls',
    (tester) async {
      final s = await AppServices.create(
        storage: MemoryStore(),
        initialOrigin: 'https://api.example.test',
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: appTheme(),
          home: LoginScreen(services: s),
        ),
      );
      expect(find.byTooltip('Alamat server'), findsNothing);
      expect(find.textContaining('api.example.test'), findsNothing);
      expect(find.text('Masuk'), findsWidgets);
      await tester.pumpWidget(const SizedBox());
      s.dispose();
    },
  );
  for (final role in ['buyer', 'seller']) {
    testWidgets(
      '$role account hides infrastructure but keeps logout and complaints',
      (tester) async {
        final s = await AppServices.create(
          storage: MemoryStore(),
          initialOrigin: 'https://api.example.test',
        );
        await s.sessions.save(
          SessionBundle.fromJson({
            ...sessionJson(),
            'user': userJson(role: role),
          }),
        );
        await tester.pumpWidget(
          MaterialApp(
            theme: appTheme(),
            home: Scaffold(body: AccountScreen(services: s)),
          ),
        );
        expect(find.text('Alamat server'), findsNothing);
        expect(find.textContaining('api.example.test'), findsNothing);
        expect(find.text('Riwayat pengaduan'), findsOneWidget);
        expect(find.text('Keluar'), findsOneWidget);
        await tester.pumpWidget(const SizedBox());
        s.dispose();
      },
    );
  }
  testWidgets('developer screen is guarded even when opened directly', (
    tester,
  ) async {
    final s = await AppServices.create(
      storage: MemoryStore(),
      initialOrigin: 'https://api.example.test',
    );
    await tester.pumpWidget(
      MaterialApp(home: ServerSettingsScreen(services: s)),
    );
    expect(find.byType(TextField), findsNothing);
    expect(find.textContaining('api.example.test'), findsNothing);
    await tester.pumpWidget(const SizedBox());
    s.dispose();
  });
  testWidgets(
    'paid ticket shows QR and OTP early without raw identifiers or coordinates',
    (tester) async {
      tester.view.physicalSize = const Size(412, 916);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final order = orderJson();
      late AppServices s;
      await tester.runAsync(() async {
        s = await AppServices.create(
          storage: MemoryStore(),
          initialOrigin: 'https://api.example.test',
          dio: Dio()..httpClientAdapter = FakeHttp((r) async => (200, order)),
        );
        await s.sessions.save(SessionBundle.fromJson(sessionJson()));
        await tester.pumpWidget(
          MaterialApp(
            theme: appTheme(),
            home: OrderDetailScreen(services: s, id: order['id']! as String),
          ),
        );
        await Future<void>.delayed(const Duration(milliseconds: 80));
      });
      await tester.pump();
      expect(find.byType(QrImageView), findsOneWidget);
      expect(tester.getBottomRight(find.text('123456')).dy, lessThan(916));
      expect(find.text('ID pesanan'), findsNothing);
      expect(find.text('Koordinat'), findsNothing);
      expect(find.text(order['id']! as String), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      s.dispose();
    },
  );
}
