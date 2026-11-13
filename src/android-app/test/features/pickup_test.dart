import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sisarasa_app/app_services.dart';
import 'package:sisarasa_app/core/models/user.dart';
import 'package:sisarasa_app/features/seller/scan_controller.dart';
import 'package:sisarasa_app/features/seller/scan_screen.dart';

import '../helpers/fake_http.dart';
import '../helpers/memory_store.dart';
import '../helpers/samples.dart';

void main() {
  test(
    'malformed QR rejects locally and repeated camera callback sends once',
    () async {
      final gate = Completer<void>();
      var calls = 0;
      final s = await AppServices.create(
        storage: MemoryStore(),
        initialOrigin: 'https://api.example.test',
        dio: Dio()
          ..httpClientAdapter = FakeHttp((r) async {
            calls++;
            await gate.future;
            return (
              200,
              {
                'order_id': orderJson()['id'],
                'code': 'SR-ABCDEFGHJK',
                'status': 'completed',
                'completed_at': '2026-10-06T07:00:00Z',
              },
            );
          }),
      );
      await s.sessions.save(
        SessionBundle.fromJson({
          ...sessionJson(),
          'user': userJson(role: 'seller'),
        }),
      );
      final c = ScanController(s);
      expect(await c.qr('bank-qris'), false);
      expect(c.error, isNotNull);
      final payload = (orderJson()['pickup'] as Map)['qr'] as String;
      final first = c.qr(payload);
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(await c.qr(payload), false);
      gate.complete();
      expect(await first, true);
      expect(await c.qr(payload), false);
      expect(calls, 1);
      c.dispose();
      s.dispose();
    },
  );
  test('OTP validates six digits and explains persistent rate limit', () async {
    final s = await AppServices.create(
      storage: MemoryStore(),
      initialOrigin: 'https://api.example.test',
      dio: Dio()
        ..httpClientAdapter = FakeHttp(
          (r) async => (
            429,
            {
              'code': 'OTP_RATE_LIMIT',
              'message': 'Terlalu banyak percobaan. Tunggu 15 menit.',
            },
          ),
        ),
    );
    await s.sessions.save(
      SessionBundle.fromJson({
        ...sessionJson(),
        'user': userJson(role: 'seller'),
      }),
    );
    final c = ScanController(s);
    expect(await c.otp('SR-ABCDEFGHJK', '12'), false);
    expect(c.fields['otp'], isNotNull);
    expect(await c.otp('SR-ABCDEFGHJK', '123456'), false);
    expect(c.error, contains('15 menit'));
    c.dispose();
    s.dispose();
  });
  testWidgets('camera denied screen keeps manual OTP available', (
    tester,
  ) async {
    final s = await AppServices.create(
      storage: MemoryStore(),
      initialOrigin: 'https://api.example.test',
    );
    await tester.pumpWidget(
      MaterialApp(
        home: ScanScreen(services: s, cameraError: 'Izin kamera ditolak'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Gunakan OTP'), findsOneWidget);
    await tester.tap(find.text('Gunakan OTP'));
    await tester.pumpAndSettle();
    expect(find.text('OTP 6 digit'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    s.dispose();
  });
}
