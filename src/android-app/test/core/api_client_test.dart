import 'dart:convert';
import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sisarasa_app/core/api/api_client.dart';
import 'package:sisarasa_app/core/models/user.dart';
import 'package:sisarasa_app/core/storage/session_store.dart';

import '../helpers/memory_store.dart';
import '../helpers/samples.dart';

class Adapter implements HttpClientAdapter {
  final Future<ResponseBody> Function(RequestOptions) respond;
  Adapter(this.respond);
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? stream,
    Future<void>? cancelFuture,
  ) => respond(options);
  @override
  void close({bool force = false}) {}
}

ResponseBody jsonBody(Object data, int status) => ResponseBody.fromString(
  jsonEncode(data),
  status,
  headers: {
    Headers.contentTypeHeader: ['application/json'],
  },
);
void main() {
  test(
    'host change cannot reuse an old refresh or clear a newer refresh flight',
    () async {
      final session = SessionStore(
        MemoryStore(),
        initialOrigin: 'https://first.example.test',
      );
      await session.save(SessionBundle.fromJson(sessionJson()));
      final started = Completer<void>();
      final oldRefresh = Completer<ResponseBody>();
      var refreshes = 0;
      final dio = Dio();
      const otherId = 'eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee';
      dio.httpClientAdapter = Adapter((o) async {
        if (o.path == '/auth/refresh') {
          refreshes++;
          if (o.uri.host == 'first.example.test') {
            started.complete();
            return oldRefresh.future;
          }
          await Future<void>.delayed(const Duration(milliseconds: 60));
          return jsonBody(sessionJson(access: 'new-token', id: otherId), 200);
        }
        if (o.headers['Authorization'] == 'Bearer old-token') {
          return jsonBody({
            'code': 'UNAUTHORIZED',
            'message': 'Sesi berakhir.',
            'request_id': 'ffffffff-ffff-4fff-8fff-ffffffffffff',
          }, 401);
        }
        return jsonBody(userJson(id: otherId), 200);
      });
      final api = ApiClient(session, dio: dio);
      final old = api
          .get('/auth/me', User.fromJson)
          .then<Object?>((u) => u, onError: (Object e) => e);
      await started.future;
      await session.changeOrigin('https://second.example.test');
      await session.save(SessionBundle.fromJson(sessionJson(id: otherId)));
      final first = api.get('/auth/me', User.fromJson);
      final late = Future<void>.delayed(const Duration(milliseconds: 30))
          .then((_) => api.get('/auth/me', User.fromJson));
      Timer(
        const Duration(milliseconds: 10),
        () => oldRefresh.complete(
          jsonBody(sessionJson(access: 'old-host-new-token'), 200),
        ),
      );
      final values = await Future.wait([first, late]);
      expect(values.every((u) => u.id == otherId), isTrue);
      expect(refreshes, 2);
      expect(await old, isA<ApiError>());
      expect(session.session!.user.id, otherId);
      api.dispose();
    },
  );
  test('binary authorization failure stays unauthorized rather than network unavailable', () async {
    final session = SessionStore(
      MemoryStore(),
      initialOrigin: 'https://api.example.test',
    );
    await session.save(SessionBundle.fromJson(sessionJson()));
    final dio = Dio();
    dio.httpClientAdapter = Adapter(
      (o) async => o.path == '/auth/refresh'
          ? jsonBody(sessionJson(access: 'new-token'), 200)
          : jsonBody({
              'code': 'UNAUTHORIZED',
              'message': 'Sesi dicabut.',
              'request_id': 'ffffffff-ffff-4fff-8fff-ffffffffffff',
            }, 401),
    );
    final api = ApiClient(session, dio: dio);
    await expectLater(
      api.bytes('/media/bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb'),
      throwsA(predicate((e) => e is ApiError && e.code == 'UNAUTHORIZED')),
    );
    expect(session.session, isNull);
    api.dispose();
  });
  test(
    'five simultaneous unauthorized requests rotate refresh exactly once',
    () async {
      final session = SessionStore(
        MemoryStore(),
        initialOrigin: 'https://api.example.test',
      );
      await session.save(SessionBundle.fromJson(sessionJson()));
      var refreshes = 0;
      final dio = Dio();
      dio.httpClientAdapter = Adapter((options) async {
        if (options.path == '/auth/refresh') {
          refreshes++;
          await Future<void>.delayed(const Duration(milliseconds: 20));
          return jsonBody(sessionJson(access: 'new-token'), 200);
        }
        if (options.headers['Authorization'] == 'Bearer old-token') {
          return jsonBody({
            'code': 'UNAUTHORIZED',
            'message': 'Sesi berakhir.',
            'request_id': 'ffffffff-ffff-4fff-8fff-ffffffffffff',
          }, 401);
        }
        return jsonBody(userJson(), 200);
      });
      final api = ApiClient(session, dio: dio);
      final values = await Future.wait(
        List.generate(5, (_) => api.get('/auth/me', User.fromJson)),
      );
      expect(values.length, 5);
      expect(refreshes, 1);
      expect(session.session!.accessToken, 'new-token');
      api.dispose();
    },
  );
  test(
    'revoked refresh clears local private state and reports unauthorized',
    () async {
      final storage = MemoryStore();
      final session = SessionStore(
        storage,
        initialOrigin: 'https://api.example.test',
      );
      await session.save(SessionBundle.fromJson(sessionJson()));
      await storage.write('private.ticket.any', 'secret');
      final dio = Dio();
      dio.httpClientAdapter = Adapter(
        (_) async => jsonBody({
          'code': 'UNAUTHORIZED',
          'message': 'Sesi dicabut.',
          'request_id': 'ffffffff-ffff-4fff-8fff-ffffffffffff',
        }, 401),
      );
      final api = ApiClient(session, dio: dio);
      await expectLater(
        api.get('/auth/me', User.fromJson),
        throwsA(predicate((e) => e is ApiError && e.code == 'UNAUTHORIZED')),
      );
      expect(session.session, isNull);
      expect(
        storage.values.keys.where((k) => k.startsWith('private.')),
        isEmpty,
      );
      api.dispose();
    },
  );
  test('POST authentication retry preserves idempotency key', () async {
    final session = SessionStore(
      MemoryStore(),
      initialOrigin: 'https://api.example.test',
    );
    await session.save(SessionBundle.fromJson(sessionJson()));
    final keys = <String>[];
    final dio = Dio();
    dio.httpClientAdapter = Adapter((o) async {
      if (o.path == '/auth/refresh') {
        return jsonBody(sessionJson(access: 'new-token'), 200);
      }
      keys.add(o.headers['Idempotency-Key'] as String);
      if (o.headers['Authorization'] == 'Bearer old-token') {
        return jsonBody({
          'code': 'UNAUTHORIZED',
          'message': 'Sesi berakhir.',
          'request_id': 'ffffffff-ffff-4fff-8fff-ffffffffffff',
        }, 401);
      }
      return jsonBody({
        'order_id': 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',
      }, 201);
    });
    final api = ApiClient(session, dio: dio);
    final result = await api.post(
      '/orders/checkout',
      {'offer_id': 'dddddddd-dddd-4ddd-8ddd-dddddddddddd'},
      (j) => j['order_id'] as String,
      key: 'stable-key',
    );
    expect(result, 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb');
    expect(keys, ['stable-key', 'stable-key']);
    api.dispose();
  });
}
