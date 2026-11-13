import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sisarasa_app/app_services.dart';
import 'package:sisarasa_app/core/models/user.dart';
import 'package:sisarasa_app/core/models/order.dart';
import 'package:sisarasa_app/features/orders/complaint_controller.dart';
import 'package:sisarasa_app/features/orders/review_controller.dart';

import '../helpers/fake_http.dart';
import '../helpers/memory_store.dart';
import '../helpers/samples.dart';

void main() {
  for (final committed in [false, true]) {
    test(
      'reopened complaint restores exact request and media after ${committed ? "lost response" : "pre-server failure"}',
      () async {
        final store = MemoryStore();
        final bodies = <Object?>[], keys = <Object?>[];
        var calls = 0, created = 0;
        Future<AppServices> services() async => AppServices.create(
          storage: store,
          initialOrigin: 'https://api.example.test',
          dio: Dio()
            ..httpClientAdapter = FakeHttp((r) async {
              calls++;
              bodies.add(r.data);
              keys.add(r.headers['Idempotency-Key']);
              if (calls == 1) {
                if (committed) created++;
                throw DioException(
                  requestOptions: r,
                  type: DioExceptionType.connectionError,
                );
              }
              if (created == 0) created++;
              return (
                201,
                {
                  'id': 'original-complaint',
                  'order_id': orderJson()['id'],
                  'reason': 'unfit',
                  'description': 'Paket berbau dan tidak layak dikonsumsi.',
                  'status': 'open',
                  'response': null,
                  'response_due': null,
                  'created_at': '2026-10-05T12:01:00Z',
                  'media_ids': ['original-evidence'],
                },
              );
            }),
        );
        var s = await services();
        await s.sessions.save(SessionBundle.fromJson(sessionJson()));
        var c = ComplaintFormController(
          s,
          Order.fromJson(orderJson()),
          serverNow: DateTime.utc(2026, 10, 5, 12, 1),
        );
        c.description = 'Paket berbau dan tidak layak dikonsumsi.';
        c.mediaIds.add('original-evidence');
        expect(await c.submit(), false);
        c.dispose();
        s.dispose();
        s = await services(); // AppServices restores the same encrypted-store/session contract.
        c = ComplaintFormController(
          s,
          Order.fromJson(orderJson()),
          serverNow: committed
              ? DateTime.utc(2026, 10, 6)
              : DateTime.utc(2026, 10, 5, 12, 1),
        );
        await Future<void>.delayed(const Duration(milliseconds: 20));
        expect(c.description, 'Paket berbau dan tidak layak dikonsumsi.');
        expect(c.mediaIds, ['original-evidence']);
        expect(c.uncertain, true);
        expect(await c.submit(), true);
        expect(created, 1);
        expect(bodies.last, bodies.first);
        expect(keys.last, keys.first);
        expect(
          store.values.keys.where((k) => k.contains('.operation.')),
          isEmpty,
        );
        c.dispose();
        s.dispose();
      },
    );
  }
  test(
    'seller decision persists approved and rejected responses from server',
    () async {
      var approved = true;
      final row = {
        'id': 'complaint',
        'order_id': orderJson()['id'],
        'reason': 'unfit',
        'description': 'Paket tidak layak dikonsumsi.',
        'status': 'open',
        'response': null,
        'response_due': null,
        'created_at': '2026-10-06T07:00:00Z',
        'media_ids': <String>[],
      };
      final s = await AppServices.create(
        storage: MemoryStore(),
        initialOrigin: 'https://api.example.test',
        dio: Dio()
          ..httpClientAdapter = FakeHttp((r) async {
            if (r.method == 'POST') {
              expect((r.data as Map)['approved'], approved);
              return (
                200,
                {
                  ...row,
                  'status': approved ? 'approved' : 'rejected',
                  'response': (r.data as Map)['response'],
                },
              );
            }
            return (200, row);
          }),
      );
      await s.sessions.save(
        SessionBundle.fromJson({
          ...sessionJson(),
          'user': userJson(role: 'seller'),
        }),
      );
      final c = ComplaintDetailController(s, 'complaint');
      await c.load();
      expect(await c.decide(true, 'Kami menyetujui refund penuh.'), true);
      expect(c.item!.status, 'approved');
      expect(c.item!.response, contains('refund'));
      approved = false;
      c.dispose();
      final rejected = ComplaintDetailController(s, 'complaint-rejected');
      await rejected.load();
      expect(
        await rejected.decide(false, 'Paket sudah sesuai keterangan.'),
        true,
      );
      expect(rejected.item!.status, 'rejected');
      rejected.dispose();
      s.dispose();
    },
  );

  test(
    'complaint requires meaningful description and max two staged images',
    () async {
      final s = await AppServices.create(
        storage: MemoryStore(),
        initialOrigin: 'https://api.example.test',
      );
      final c = ComplaintFormController(
        s,
        Order.fromJson(orderJson()),
        serverNow: DateTime.utc(2026, 10, 5, 12, 1),
      );
      c.description = 'bad';
      expect(c.validate(), false);
      c.description = 'Paket berbau dan tidak layak dikonsumsi.';
      c.mediaIds.addAll(['a', 'b', 'c']);
      expect(c.validate(), false);
      c.mediaIds.removeLast();
      expect(c.validate(), true);
      c.dispose();
      s.dispose();
    },
  );
  test('uncertain complaint retries same durable request and post-completion denial is explicit', () async {
    var calls = 0;
    final keys = <Object?>[];
    final http = FakeHttp((r) async {
      calls++;
      keys.add(r.headers['Idempotency-Key']);
      if (calls == 1) {
        throw DioException(
          requestOptions: r,
          type: DioExceptionType.connectionError,
        );
      }
      return (
        409,
        {
          'code': 'COMPLAINT_NOT_ELIGIBLE',
          'message': 'Pengaduan tidak tersedia setelah pickup selesai.',
        },
      );
    });
    final s = await AppServices.create(
      storage: MemoryStore(),
      initialOrigin: 'https://api.example.test',
      dio: Dio()..httpClientAdapter = http,
    );
    await s.sessions.save(SessionBundle.fromJson(sessionJson()));
    final c = ComplaintFormController(
      s,
      Order.fromJson(orderJson()),
      serverNow: DateTime.utc(2026, 10, 5, 12, 1),
    );
    c.description = 'Paket berbau dan tidak layak dikonsumsi.';
    expect(await c.submit(), false);
    expect(await c.submit(), false);
    expect(keys.first, keys.last);
    expect(c.error, contains('pickup selesai'));
    expect(c.uncertain, false);
    expect(
      (await s.sessions.storage.readAll()).keys.where(
        (k) => k.contains('.operation.'),
      ),
      isEmpty,
    );
    c.description = 'Draft diperbaiki setelah penolakan definitif.';
    expect(await c.submit(), false);
    expect(keys.last, isNot(keys.first));
    c.dispose();
    s.dispose();
  });
  test('duplicate review acknowledged rather than offered again', () async {
    final s = await AppServices.create(
      storage: MemoryStore(),
      initialOrigin: 'https://api.example.test',
      dio: Dio()
        ..httpClientAdapter = FakeHttp(
          (r) async =>
              (409, {'code': 'CONFLICT', 'message': 'Data sudah digunakan.'}),
        ),
    );
    await s.sessions.save(SessionBundle.fromJson(sessionJson()));
    final c = ReviewController(s, orderJson()['id']! as String);
    c.rating = 5;
    expect(await c.submit(), true);
    expect(c.duplicate, true);
    c.dispose();
    s.dispose();
  });
}
