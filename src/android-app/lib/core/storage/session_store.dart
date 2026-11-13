import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../models/user.dart';
import '../models/json.dart';
import 'secure_store.dart';

class SessionScopeChanged implements Exception {}

class SessionStore extends ChangeNotifier {
  final SecureStore storage;
  final bool allowHttp;
  String _origin;
  SessionBundle? _session;
  int _epoch = 0;
  Future<void> _tail = Future.value();
  Future<T> _mutate<T>(Future<T> Function() action) {
    final result = _tail.then((_) => action());
    _tail = result.then<void>((_) {}, onError: (Object e, StackTrace s) {});
    return result;
  }

  SessionStore(
    this.storage, {
    required String initialOrigin,
    this.allowHttp = !kReleaseMode,
  }) : _origin = initialOrigin.isEmpty
           ? ''
           : normalizeOrigin(initialOrigin, allowHttp: allowHttp);
  String get origin => _origin;
  SessionBundle? get session => _session;
  int get epoch => _epoch;
  static String normalizeOrigin(String raw, {bool allowHttp = false}) {
    final uri = Uri.tryParse(raw.trim());
    if (uri == null ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment ||
        !['https', if (allowHttp) 'http'].contains(uri.scheme) ||
        !['', '/', '/api/v1', '/api/v1/'].contains(uri.path)) {
      throw const FormatException(
        'Gunakan URL HTTPS server yang valid tanpa query atau kredensial.',
      );
    }
    return '${uri.scheme}://${uri.authority}';
  }

  Future<void> restore() async {
    try {
      final saved = await storage.read('origin');
      if (saved != null) _origin = normalizeOrigin(saved, allowHttp: allowHttp);
      final raw = await storage.read('private.session');
      if (raw != null) {
        _session = SessionBundle.fromJson(jsonObject(jsonDecode(raw)));
      }
    } catch (_) {
      await _erasePrivate().catchError((_) {});
      _session = null;
    }
    _epoch++;
    notifyListeners();
  }

  Future<void> _erasePrivate() async {
    for (final key in (await storage.readAll()).keys.where(
      (k) => k.startsWith('private.'),
    )) {
      await storage.delete(key);
    }
  }

  Future<void> save(SessionBundle bundle, {int? expectedEpoch}) async {
    var scope = expectedEpoch ?? _epoch;
    if (scope != _epoch) throw SessionScopeChanged();
    if (_session != null && _session!.user.id != bundle.user.id) {
      await clear();
      scope++;
    }
    try {
      await _mutate(() async {
        if (scope != _epoch) throw SessionScopeChanged();
        await storage.write('private.session', jsonEncode(bundle.toJson()));
        if (scope != _epoch) throw SessionScopeChanged();
        _session = bundle;
        notifyListeners();
      });
    } on SessionScopeChanged {
      rethrow;
    } catch (_) {
      if (scope == _epoch) await clear().catchError((_) {});
      rethrow;
    }
  }

  Future<void> runForUser(String user, Future<void> Function() action) {
    final scope = _epoch;
    return _mutate(() async {
      if (scope != _epoch || _session?.user.id != user) {
        throw SessionScopeChanged();
      }
      await action();
      if (scope != _epoch || _session?.user.id != user) {
        throw SessionScopeChanged();
      }
    });
  }

  Future<void> clear() async {
    _session = null;
    _epoch++;
    notifyListeners();
    await _mutate(_erasePrivate);
  }

  Future<void> changeOrigin(String raw) async {
    final next = normalizeOrigin(raw, allowHttp: allowHttp);
    if (next == _origin) return;
    _origin = next;
    await clear();
    await _mutate(() => storage.write('origin', next));
    notifyListeners();
  }
}
