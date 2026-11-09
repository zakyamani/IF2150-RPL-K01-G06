import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sisarasa_app/app_services.dart';
import 'package:sisarasa_app/core/models/user.dart';
import 'package:sisarasa_app/core/api/socket_client.dart';

import '../helpers/fake_http.dart';
import '../helpers/memory_store.dart';
import '../helpers/samples.dart';
import '../features/notifications_test.dart' show eventJson;

void main() {
  test('expired socket reconnect requests new single-use ticket bound to last cursor', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final sockets = <WebSocket>[];
    var tickets = 0;
    final cursors = <Object?>[], urls = <Uri>[];
    final done = Completer<void>();
    final serverSub = server.listen((request) async {
      final ws = await WebSocketTransformer.upgrade(request);
      sockets.add(ws);
      if (sockets.length == 1) {
        ws.add(jsonEncode(eventJson()));
        await Future<void>.delayed(const Duration(milliseconds: 60));
        await ws.close(1008, 'Ticket/session expired');
      } else if (!done.isCompleted) {
        done.complete();
      }
    });
    final services = await AppServices.create(
      storage: MemoryStore(),
      initialOrigin: 'https://api.example.test',
      dio: Dio()
        ..httpClientAdapter = FakeHttp((r) async {
          tickets++;
          cursors.add((r.data as Map)['after']);
          return (
            200,
            {
              'ticket': 'single-use-$tickets',
              'expires_at': DateTime.now()
                  .add(const Duration(seconds: 45))
                  .toUtc()
                  .toIso8601String(),
            },
          );
        }),
    );
    await services.sessions.save(SessionBundle.fromJson(sessionJson()));
    final socket = SocketClient(
      services,
      connect: (uri) {
        urls.add(Uri.parse(uri));
        return WebSocket.connect('ws://127.0.0.1:${server.port}/ws');
      },
      delay: (_) => const Duration(milliseconds: 20),
    );
    final events = socket.events.listen(
      (event) => socket.setCursor(event.sequence),
    );
    await socket.start();
    await done.future.timeout(const Duration(seconds: 3));
    expect(tickets, 2);
    expect(cursors, ['0', '1']);
    expect(urls[0].queryParameters.keys, ['ticket']);
    expect(
      urls[0].queryParameters['ticket'],
      isNot(urls[1].queryParameters['ticket']),
    );
    expect(urls.every((u) => !u.toString().contains('old-token')), true);
    await events.cancel();
    await socket.dispose();
    for (final ws in sockets) {
      await ws.close();
    }
    await serverSub.cancel();
    await server.close(force: true);
    services.dispose();
  });
}
