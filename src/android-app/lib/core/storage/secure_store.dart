import 'package:flutter_secure_storage/flutter_secure_storage.dart';

abstract interface class SecureStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
  Future<Map<String, String>> readAll();
}

class PlatformSecureStore implements SecureStore {
  final FlutterSecureStorage storage;
  final String prefix;
  const PlatformSecureStore({
    this.storage = const FlutterSecureStorage(),
    this.prefix = 'sisarasa.v2.',
  });
  @override
  Future<String?> read(String key) => storage.read(key: '$prefix$key');
  @override
  Future<void> write(String key, String value) =>
      storage.write(key: '$prefix$key', value: value);
  @override
  Future<void> delete(String key) => storage.delete(key: '$prefix$key');
  @override
  Future<Map<String, String>> readAll() async {
    final all = await storage.readAll();
    return {
      for (final entry in all.entries)
        if (entry.key.startsWith(prefix))
          entry.key.substring(prefix.length): entry.value,
    };
  }
}
