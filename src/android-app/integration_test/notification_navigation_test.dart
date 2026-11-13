import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:integration_test/integration_test.dart';
import 'package:sisarasa_app/app_services.dart';
import 'package:sisarasa_app/core/models/user.dart';
import 'package:sisarasa_app/core/models/notification.dart';
import 'package:sisarasa_app/core/theme/app_theme.dart';
import 'package:sisarasa_app/features/notifications/seller_monitor.dart';

import '../test/helpers/memory_store.dart';
import '../test/helpers/samples.dart';
import '../test/helpers/fake_http.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'Android dataSync foreground opt-in stops on logout and rejects stale notification navigation',
    (tester) async {
      final services = await AppServices.create(
        storage: MemoryStore(),
        initialOrigin: 'https://api.example.test',
        dio: Dio()
          ..httpClientAdapter = FakeHttp((r) async => (200, orderJson())),
      );
      await services.sessions.save(
        SessionBundle.fromJson({
          ...sessionJson(),
          'user': userJson(role: 'seller'),
        }),
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: appTheme(),
          home: const Scaffold(
            body: Center(child: Text('Pengujian pemantau SisaRasa')),
          ),
        ),
      );
      final monitor = SellerMonitor(
        services,
        platform: AndroidMonitorPlatform(),
      );
      await monitor.initialize();
      expect(monitor.active, false);
      expect(await monitor.start(), true, reason: monitor.error);
      await Future<void>.delayed(const Duration(milliseconds: 700));
      expect(await FlutterForegroundTask.isRunningService, true);
      final actor = services.sessions.session!.user.id,
          epoch = services.sessions.epoch,
          resource = orderJson()['id'];
      await monitor.publish(
        InboxEvent(
          id: 'eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee',
          sequence: '1',
          type: 'payment.succeeded',
          resourceId: resource! as String,
          summary: 'Pembayaran simulasi berhasil. Periksa pesanan.',
          occurredAt: DateTime.now().toUtc(),
        ),
      );
      expect(
        monitor.acceptTap({
          'actor': actor,
          'epoch': epoch,
          'resource_id': resource,
        }),
        resource,
      );
      await services.sessions.clear();
      await monitor.stop();
      for (
        var i = 0;
        i < 20 && await FlutterForegroundTask.isRunningService;
        i++
      ) {
        await Future<void>.delayed(const Duration(milliseconds: 100));
      }
      expect(await FlutterForegroundTask.isRunningService, false);
      expect(
        monitor.acceptTap({
          'actor': actor,
          'epoch': epoch,
          'resource_id': resource,
        }),
        isNull,
      );
      await services.sessions.save(
        SessionBundle.fromJson({
          ...sessionJson(id: 'dddddddd-dddd-4ddd-8ddd-dddddddddddd'),
          'user': userJson(
            id: 'dddddddd-dddd-4ddd-8ddd-dddddddddddd',
            role: 'seller',
          ),
        }),
      );
      expect(
        monitor.acceptTap({
          'actor': actor,
          'epoch': epoch,
          'resource_id': resource,
        }),
        isNull,
      );
      monitor.dispose();
      await tester.pumpWidget(const SizedBox());
      services.dispose();
    },
  );
}
