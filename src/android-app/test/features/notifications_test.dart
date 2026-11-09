import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sisarasa_app/app_services.dart';
import 'package:sisarasa_app/core/models/user.dart';
import 'package:sisarasa_app/core/models/notification.dart';
import 'package:sisarasa_app/core/api/socket_client.dart';
import 'package:sisarasa_app/features/notifications/notification_controller.dart';
import 'package:sisarasa_app/features/notifications/seller_monitor.dart';

import '../helpers/fake_http.dart';
import '../helpers/memory_store.dart';
import '../helpers/samples.dart';

Map<String, Object?> eventJson() => {
  'id': 'eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee',
  'sequence': '1',
  'type': 'payment.succeeded',
  'resource_id': orderJson()['id'],
  'summary': 'Pembayaran berhasil.',
  'occurred_at': '2026-10-06T07:00:00Z',
  'read_at': null,
};

class FakeSocket implements InboxSocket {
  final _events = StreamController<InboxEvent>.broadcast();
  final _states = StreamController<bool>.broadcast();
  int starts = 0, stops = 0;
  String cursor = '0';
  @override
  Stream<InboxEvent> get events => _events.stream;
  @override
  Stream<bool> get states => _states.stream;
  @override
  Future<void> start({String after = '0'}) async {
    starts++;
    cursor = after;
    _states.add(true);
  }

  @override
  void setCursor(String value) {
    cursor = value;
  }

  @override
  Future<void> stop() async {
    stops++;
  }

  void emit(InboxEvent event) => _events.add(event);
  void reconnect() => _states.add(true);
  @override
  Future<void> dispose() async {
    await _events.close();
    await _states.close();
  }
}

class FakeForeground implements MonitorPlatform {
  bool granted = true;
  int starts = 0, stops = 0;
  void Function(Object)? receiver;
  @override
  Future<void> initialize(void Function(Object) callback) async {
    receiver = callback;
  }

  @override
  Future<bool> requestPermission() async => granted;
  @override
  Future<void> start() async {
    starts++;
  }

  @override
  Future<void> stop() async {
    stops++;
  }

  @override
  Future<void> update(String text) async {}
  @override
  void send(Map<String, Object?> data) {}
  @override
  void dispose() {}
}

void main() {
  test(
    'duplicate REST/socket events form one inbox row and one resource action',
    () async {
      var supplied = false;
      final s = await AppServices.create(
        storage: MemoryStore(),
        initialOrigin: 'https://api.example.test',
        dio: Dio()
          ..httpClientAdapter = FakeHttp((r) async {
            final items = supplied ? [eventJson()] : [];
            return (
              200,
              {
                'items': items,
                'next_cursor': null,
                'last_cursor': supplied ? '1' : '0',
              },
            );
          }),
      );
      await s.sessions.save(SessionBundle.fromJson(sessionJson()));
      final socket = FakeSocket();
      final c = NotificationController(s, socket: socket);
      await c.start();
      final actions = <InboxEvent>[];
      final subscription = c.changes.listen(actions.add);
      supplied = true;
      socket.emit(InboxEvent.fromJson(eventJson()));
      socket.emit(InboxEvent.fromJson(eventJson()));
      await Future<void>.delayed(const Duration(milliseconds: 30));
      await c.catchUp();
      expect(c.items.length, 1);
      expect(actions.length, 1);
      expect(c.cursor, '1');
      await subscription.cancel();
      await c.disposeAsync();
      s.dispose();
    },
  );
  test(
    'reconnect fetches missed cursor and logout discards account state',
    () async {
      final queries = <Object?>[];
      final s = await AppServices.create(
        storage: MemoryStore(),
        initialOrigin: 'https://api.example.test',
        dio: Dio()
          ..httpClientAdapter = FakeHttp((r) async {
            queries.add(r.queryParameters['after']);
            return (
              200,
              {'items': [], 'next_cursor': null, 'last_cursor': '0'},
            );
          }),
      );
      await s.sessions.save(SessionBundle.fromJson(sessionJson()));
      final socket = FakeSocket();
      final c = NotificationController(s, socket: socket);
      await c.start();
      socket.emit(InboxEvent.fromJson(eventJson()));
      await Future<void>.delayed(const Duration(milliseconds: 30));
      socket.reconnect();
      await Future<void>.delayed(const Duration(milliseconds: 30));
      expect(queries, contains('1'));
      await s.sessions.clear();
      expect(c.items, isEmpty);
      expect(socket.stops, greaterThan(0));
      await c.disposeAsync();
      s.dispose();
    },
  );
  test('permission denial does not block inbox and stale account taps cannot route', () async {
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
    final platform = FakeForeground()..granted = false;
    final c = SellerMonitor(s, platform: platform);
    await c.initialize();
    expect(await c.start(), false);
    expect(platform.starts, 0);
    expect(c.error, contains('izin'));
    platform.granted = true;
    expect(await c.start(), true);
    final actor = s.sessions.session!.user.id, epoch = s.sessions.epoch;
    expect(
      c.acceptTap({
        'actor': actor,
        'epoch': epoch,
        'resource_id': orderJson()['id'],
      }),
      orderJson()['id'],
    );
    await s.sessions.clear();
    expect(
      c.acceptTap({
        'actor': actor,
        'epoch': epoch,
        'resource_id': orderJson()['id'],
      }),
      isNull,
    );
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(platform.stops, greaterThan(0));
    c.dispose();
    s.dispose();
  });
}
