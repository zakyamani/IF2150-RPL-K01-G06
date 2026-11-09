import 'dart:async';

import 'features/notifications/notification_controller.dart';
import 'features/notifications/seller_monitor.dart';

import 'package:dio/dio.dart';

import 'core/api/api_client.dart';
import 'core/storage/session_store.dart';
import 'core/storage/secure_store.dart';
import 'core/storage/ticket_cache.dart';

class AppServices {
  final SessionStore sessions;
  final ApiClient api;
  final TicketCache tickets;
  final bool runtimeEnabled;
  late final NotificationController notifications;
  late final SellerMonitor monitor;
  StreamSubscription? _notificationMonitor;
  AppServices._(this.sessions, this.api, this.tickets, this.runtimeEnabled);
  static Future<AppServices> create({
    required SecureStore storage,
    required String initialOrigin,
    Dio? dio,
    bool? allowHttp,
    bool runtimeEnabled = false,
  }) async {
    final sessions = allowHttp == null
        ? SessionStore(storage, initialOrigin: initialOrigin)
        : SessionStore(
            storage,
            initialOrigin: initialOrigin,
            allowHttp: allowHttp,
          );
    await sessions.restore();
    final services = AppServices._(
      sessions,
      ApiClient(sessions, dio: dio),
      TicketCache(storage, sessions: sessions),
      runtimeEnabled,
    );
    services.notifications = NotificationController(
      services,
      enabled: runtimeEnabled,
    );
    services.monitor = SellerMonitor(services);
    if (runtimeEnabled) {
      unawaited(services.monitor.initialize());
      unawaited(services.notifications.start());
      services._notificationMonitor = services.notifications.changes.listen(
        (event) => unawaited(services.monitor.publish(event)),
      );
    }
    return services;
  }

  void dispose() {
    _notificationMonitor?.cancel();
    monitor.dispose();
    notifications.dispose();
    api.dispose();
    sessions.dispose();
  }
}
