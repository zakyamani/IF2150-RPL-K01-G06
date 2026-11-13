import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sisarasa_app/app.dart';
import 'package:sisarasa_app/app_services.dart';
import 'package:sisarasa_app/features/auth/auth_controller.dart';

import '../helpers/memory_store.dart';
import '../helpers/fake_http.dart';
import '../helpers/samples.dart';

void main() {
  test(
    'invalid credentials never issue HTTP and server field errors survive',
    () async {
      final adapter = FakeHttp(
        (r) async => (
          400,
          {
            'code': 'VALIDATION_ERROR',
            'message': 'Periksa data',
            'field_errors': {
              'email': ['Email sudah digunakan.'],
            },
          },
        ),
      );
      final services = await AppServices.create(
        storage: MemoryStore(),
        initialOrigin: 'https://api.example.test',
        dio: Dio()..httpClientAdapter = adapter,
      );
      final controller = AuthController(services);
      expect(
        await controller.submit(
          email: 'bad',
          password: '',
          name: '',
          registering: false,
        ),
        false,
      );
      expect(adapter.calls, isEmpty);
      expect(
        await controller.submit(
          email: 'ayu@example.test',
          password: 'long-password-123',
          name: 'Ayu',
          registering: true,
        ),
        false,
      );
      expect(controller.fields['email'], ['Email sudah digunakan.']);
      controller.dispose();
      services.dispose();
    },
  );
  testWidgets(
    'login preserves input on failure and fits 320px scaled keyboard',
    (tester) async {
      tester.view.physicalSize = const Size(320, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final services = await AppServices.create(
        storage: MemoryStore(),
        initialOrigin: 'https://api.example.test',
        dio: Dio()
          ..httpClientAdapter = FakeHttp(
            (r) async => (
              401,
              {
                'code': 'INVALID_CREDENTIALS',
                'message': 'Email atau password salah.',
              },
            ),
          ),
      );
      await tester.pumpWidget(
        SisaRasaApp(services: services, textScaler: const TextScaler.linear(2)),
      );
      await tester.scrollUntilVisible(find.byKey(const Key('auth-email')), 180);
      await tester.enterText(
        find.byKey(const Key('auth-email')),
        'ayu@example.test',
      );
      await tester.scrollUntilVisible(
        find.byKey(const Key('auth-password')),
        180,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.enterText(
        find.byKey(const Key('auth-password')),
        'long-password-123',
      );
      tester.view.viewInsets = const FakeViewPadding(bottom: 280);
      addTearDown(tester.view.resetViewInsets);
      await tester.pump();
      await tester.scrollUntilVisible(
        find.byKey(const Key('auth-submit')),
        120,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.runAsync(() async {
        await tester.tap(find.byKey(const Key('auth-submit')));
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
      await tester.pumpAndSettle();
      expect(find.text('Email atau password salah.'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.byKey(const Key('auth-email')),
        -180,
        scrollable: find.byType(Scrollable).first,
      );
      final emailField = tester.widget<TextField>(
        find.byKey(const Key('auth-email'), skipOffstage: false),
      );
      expect(emailField.controller!.text, 'ayu@example.test');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      services.dispose();
    },
  );
  testWidgets('seller session opens seller home', (tester) async {
    final data = sessionJson();
    data['user'] = userJson(role: 'seller');
    final storage = MemoryStore();
    storage.values['private.session'] = jsonEncode(data);
    final services = await AppServices.create(
      storage: storage,
      initialOrigin: 'https://api.example.test',
      dio: Dio()
        ..httpClientAdapter = FakeHttp(
          (r) async => (
            200,
            r.path == '/merchant/profile'
                ? merchantJson()
                : r.path == '/metrics'
                ? {'packages_saved': 4}
                : {'items': [], 'next_cursor': null},
          ),
        ),
    );
    await tester.runAsync(() async {
      await tester.pumpWidget(SisaRasaApp(services: services));
      await Future<void>.delayed(const Duration(milliseconds: 80));
    });
    await tester.pumpAndSettle();
    expect(find.text('Penawaran'), findsWidgets);
    await tester.pumpWidget(const SizedBox());
    services.dispose();
  });
}
