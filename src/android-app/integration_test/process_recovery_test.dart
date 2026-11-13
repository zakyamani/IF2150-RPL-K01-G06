import 'test_config.dart';

import 'dart:io';

import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:sisarasa_app/app_services.dart';
import 'package:sisarasa_app/core/theme/app_theme.dart';
import 'package:sisarasa_app/features/orders/order_detail_screen.dart';

import 'marketplace_test.dart' show nativeStorage;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'paid ticket survives Android force-stop and separate APK invocation with network blocked',
    (tester) async {
      final dio = Dio()
        ..httpClientAdapter = IOHttpClientAdapter(
          createHttpClient: () => HttpClient()
            ..connectionFactory = (uri, proxyHost, proxyPort) =>
                Future<ConnectionTask<Socket>>.error(
                  const SocketException(
                    'Network blocked for recovery evidence',
                  ),
                ),
        );
      final s = await AppServices.create(
        storage: nativeStorage,
        initialOrigin: integrationApiOrigin,
        dio: dio,
      );
      final id = await nativeStorage.read('integration.order_id');
      expect(id, isNotNull);
      expect(s.sessions.session, isNotNull);
      final cached = await s.tickets.read(s.sessions.session!.user.id, id!);
      expect(cached?.order.pickup, isNotNull);
      await tester.pumpWidget(
        MaterialApp(
          theme: appTheme(),
          home: OrderDetailScreen(services: s, id: id),
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
      expect(find.textContaining('OFFLINE'), findsOneWidget);
      debugPrint('NATIVE_OFFLINE_READY');
      await Future<void>.delayed(const Duration(seconds: 3));
      final actor = s.sessions.session!.user.id;
      await s.sessions.clear();
      expect(await s.tickets.list(actor), isEmpty);
      await tester.pumpWidget(const SizedBox());
      s.dispose();
    },
  );
}
