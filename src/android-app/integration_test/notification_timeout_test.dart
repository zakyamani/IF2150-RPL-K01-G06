import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:integration_test/integration_test.dart';
import 'package:sisarasa_app/app_services.dart';
import 'package:sisarasa_app/core/models/user.dart';
import 'package:sisarasa_app/features/notifications/seller_monitor.dart';

import '../test/helpers/memory_store.dart';
import '../test/helpers/samples.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'Android 15 background screen-off dataSync timeout stops service and explains recovery',
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
          home: Scaffold(body: Text('Pemantauan Android background')),
        ),
      );
      final monitor = SellerMonitor(s, platform: AndroidMonitorPlatform());
      await monitor.initialize();
      expect(await monitor.start(), true, reason: monitor.error);
      await Future<void>.delayed(const Duration(seconds: 1));
      expect(await FlutterForegroundTask.isRunningService, true);
      debugPrint('NATIVE_MONITOR_READY');
      for (var n = 0; n < 120 && monitor.active; n++) {
        await Future<void>.delayed(const Duration(milliseconds: 250));
      }
      expect(await FlutterForegroundTask.isRunningService, false);
      expect(monitor.active, false);
      expect(monitor.error, contains('Batas pemantauan Android'));
      expect(s.sessions.session, isNotNull);
      monitor.dispose();
      await tester.pumpWidget(const SizedBox());
      s.dispose();
    },
  );
}
