import 'package:flutter/material.dart';

import 'app.dart';
import 'core/config/app_config.dart';
import 'app_services.dart';
import 'core/storage/secure_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final services = await AppServices.create(
    runtimeEnabled: true,
    storage: const PlatformSecureStore(),
    initialOrigin: AppConfig.apiOrigin,
  );
  runApp(SisaRasaApp(services: services));
}
