import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:sisarasa_app/app_services.dart';
import 'package:sisarasa_app/core/models/order.dart';
import 'package:sisarasa_app/core/models/user.dart';
import 'package:sisarasa_app/core/storage/secure_store.dart';
import 'package:sisarasa_app/core/theme/app_theme.dart';
import 'package:sisarasa_app/features/orders/order_detail_screen.dart';

import '../test/helpers/fake_http.dart';
import '../test/helpers/samples.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'native encrypted ticket survives service restart without networking and logout erases it',
    (tester) async {
      const storage = PlatformSecureStore(
        prefix: 'sisarasa.integration.offline.',
      );
      final first = await AppServices.create(
        storage: storage,
        initialOrigin: 'https://offline.example.test',
      );
      await first.sessions.clear();
      await first.sessions.save(SessionBundle.fromJson(sessionJson()));
      await first.tickets.save(
        first.sessions.session!.user.id,
        Order.fromJson(orderJson()),
        syncedAt: DateTime.utc(2026, 10, 5, 12, 1),
      );
      first.dispose();
      final restored = await AppServices.create(
        storage: storage,
        initialOrigin: 'https://offline.example.test',
        dio: Dio()
          ..httpClientAdapter = FakeHttp((r) async {
            throw DioException(
              requestOptions: r,
              type: DioExceptionType.connectionError,
            );
          }),
      );
      final user = restored.sessions.session!.user.id;
      expect(
        (await restored.tickets.list(user)).single.order.pickup!.otp,
        '123456',
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: appTheme(),
          home: OrderDetailScreen(
            services: restored,
            id: orderJson()['id']! as String,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('123456'),
        180,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('123456'), findsOneWidget);
      expect(
        find.textContaining('Jadwal pengambilan telah berakhir'),
        findsWidgets,
      );
      await tester.pumpWidget(const SizedBox());
      await restored.sessions.clear();
      expect(await restored.tickets.list(user), isEmpty);
      restored.dispose();
    },
  );
}
