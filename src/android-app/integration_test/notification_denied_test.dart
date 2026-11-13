import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:sisarasa_app/app_services.dart';
import 'package:sisarasa_app/core/models/user.dart';
import 'package:sisarasa_app/features/notifications/seller_monitor.dart';

import '../test/helpers/memory_store.dart';
import '../test/helpers/samples.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'native denied notification permission preserves account and disables foreground opt-in',
    (tester) async {
      final s = await AppServices.create(
        storage: MemoryStore(),
        initialOrigin: 'https://api.example.test',
      );
      await s.sessions.save(
        SessionBundle.fromJson({
          ...sessionJson(),
          'user': userJson(role: 'seller'),
        }),
      );
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: Text('Izin notifikasi ditolak')),
        ),
      );
      final monitor = SellerMonitor(s, platform: AndroidMonitorPlatform());
      await monitor.initialize();
      expect(await monitor.start(), false);
      expect(monitor.active, false);
      expect(monitor.error, contains('izin'));
      expect(s.sessions.session?.user.role, Role.seller);
      monitor.dispose();
      await tester.pumpWidget(const SizedBox());
      s.dispose();
    },
  );
}
