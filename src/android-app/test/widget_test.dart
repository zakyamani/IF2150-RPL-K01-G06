import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sisarasa_app/app.dart';
import 'package:sisarasa_app/app_services.dart';

import 'helpers/memory_store.dart';

void main() {
  testWidgets('application shell renders SisaRasa', (tester) async {
    final services = await AppServices.create(
      storage: MemoryStore(),
      initialOrigin: 'https://api.example.test',
    );
    await tester.pumpWidget(SisaRasaApp(services: services));
    expect(find.text('sisarasa'), findsWidgets);
    await tester.pumpWidget(const SizedBox.shrink());
    services.dispose();
  });
}
