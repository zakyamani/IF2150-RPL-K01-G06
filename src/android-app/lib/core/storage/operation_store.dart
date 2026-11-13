import 'dart:convert';

import 'package:uuid/uuid.dart';

import '../../app_services.dart';
import '../api/api_error.dart';
import '../models/json.dart';

class OperationStore {
  final AppServices services;
  OperationStore(this.services);
  Object? _canonical(Object? value) => value is Map
      ? {
          for (final key
              in value.keys.map((e) => e.toString()).toList()..sort())
            key: _canonical(value[key]),
        }
      : value is List
      ? value.map(_canonical).toList()
      : value;
  Future<Json?> load(String operation, String resource) async {
    final actor = services.sessions.session?.user.id;
    if (actor == null) return null;
    Json? body;
    await services.sessions.runForUser(actor, () async {
      final raw = await services.sessions.storage.read(
        'private.operation.$actor.$operation.$resource',
      );
      if (raw != null) body = jsonObject(jsonObject(jsonDecode(raw))['body']);
    });
    return body;
  }

  Future<T> run<T>(
    String operation,
    String resource,
    Json body,
    Future<T> Function(String key) send,
  ) async {
    final actor = services.sessions.session!.user.id;
    final requestKey = await key(operation, resource, body);
    Future<void> clear() => services.sessions.runForUser(actor, () async {
      final storageKey = 'private.operation.$actor.$operation.$resource';
      final raw = await services.sessions.storage.read(storageKey);
      if (raw != null && jsonObject(jsonDecode(raw))['key'] == requestKey) {
        await services.sessions.storage.delete(storageKey);
      }
    });
    try {
      final result = await send(requestKey);
      await clear();
      return result;
    } on ApiError catch (e) {
      // These responses reject the mutation. Network/5xx/decoder failures
      // remain uncertain and must retain the exact body and original key.
      if ([400, 403, 404, 409, 410, 413, 415, 422, 429].contains(e.status) &&
          e.code != 'IDEMPOTENCY_CONFLICT') {
        await clear();
      }
      rethrow;
    }
  }

  Future<String> key(String operation, String resource, Json body) async {
    final actor = services.sessions.session!.user.id;
    final storageKey = 'private.operation.$actor.$operation.$resource';
    late String result;
    await services.sessions.runForUser(actor, () async {
      final storage = services.sessions.storage;
      final raw = await storage.read(storageKey);
      if (raw != null) {
        final record = jsonObject(jsonDecode(raw));
        if (jsonEncode(_canonical(record['body'])) !=
            jsonEncode(_canonical(body))) {
          throw const ApiError(
            'OPERATION_CHANGED',
            'Ada permintaan sebelumnya dengan data berbeda. Sinkronkan status sebelum mengubah permintaan.',
          );
        }
        result = text(record, 'key');
      } else {
        result = const Uuid().v4();
        await storage.write(
          storageKey,
          jsonEncode({'key': result, 'body': body}),
        );
      }
    });
    return result;
  }
}
