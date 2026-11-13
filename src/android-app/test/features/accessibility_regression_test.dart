import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sisarasa_app/app_services.dart';
import 'package:sisarasa_app/core/models/order.dart';
import 'package:sisarasa_app/features/seller/offer_form_screen.dart';
import 'package:sisarasa_app/features/orders/complaint_form_screen.dart';
import 'package:sisarasa_app/features/seller/scan_screen.dart';

import '../helpers/memory_store.dart';
import '../helpers/samples.dart';

void main() {
  testWidgets(
    'selected category and complaint reason remain readable at 320px and twice text size',
    (tester) async {
      tester.view.physicalSize = const Size(320, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final s = await AppServices.create(
        storage: MemoryStore(),
        initialOrigin: 'https://api.example.test',
      );
      for (final screen in [
        OfferFormScreen(services: s),
        ComplaintFormScreen(services: s, order: Order.fromJson(orderJson())),
      ]) {
        await tester.pumpWidget(
          MaterialApp(
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(2)),
              child: child!,
            ),
            home: screen,
          ),
        );
        await tester.pump();
        final dropdown = find.byType(DropdownButtonFormField<String>);
        await tester.scrollUntilVisible(
          dropdown,
          200,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pump();
        final text = find
            .descendant(of: dropdown, matching: find.byType(Text))
            .first;
        final paragraph = tester.renderObject<RenderParagraph>(text);
        expect(
          paragraph.size.height,
          greaterThanOrEqualTo(
            paragraph.getMaxIntrinsicHeight(paragraph.size.width) - .1,
          ),
        );
        expect(tester.takeException(), isNull);
      }
      await tester.pumpWidget(const SizedBox());
      s.dispose();
    },
  );
  testWidgets(
    'real camera error fallback fits its bounded scanner viewport at large text',
    (tester) async {
      tester.view.physicalSize = const Size(320, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final s = await AppServices.create(
        storage: MemoryStore(),
        initialOrigin: 'https://api.example.test',
      );
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(2)),
            child: child!,
          ),
          home: ScanScreen(services: s),
        ),
      );
      await tester.scrollUntilVisible(
        find.text('Aktifkan kamera'),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Aktifkan kamera'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      final scanner = tester.widget<MobileScanner>(find.byType(MobileScanner));
      final fallback = scanner.errorBuilder!(
        tester.element(find.byType(MobileScanner)),
        MobileScannerException(
          errorCode: MobileScannerErrorCode.permissionDenied,
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MediaQuery(
              data: const MediaQueryData(textScaler: TextScaler.linear(2)),
              child: Center(
                child: SizedBox(width: 280, height: 280, child: fallback),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      s.dispose();
    },
  );
}
