import 'dart:convert';

import '../models/order.dart';
import '../models/json.dart';
import 'secure_store.dart';
import 'session_store.dart';

class CachedTicket {
  final Order order;
  final DateTime syncedAt;
  const CachedTicket(this.order, this.syncedAt);
  bool expiredAt(DateTime at) => !at.toUtc().isBefore(order.pickupEnd);
}

class TicketCache {
  final SecureStore storage;
  final SessionStore? sessions;
  const TicketCache(this.storage, {this.sessions});
  String _key(String user, String id) => 'private.ticket.$user.$id';
  Future<void> save(String user, Order order, {DateTime? syncedAt}) async {
    await _guard(user, () async {
      if (order.status != OrderStatus.paid || order.pickup == null) {
        await storage.delete(_key(user, order.id));
        return;
      }
      await storage.write(
        _key(user, order.id),
        jsonEncode({
          'schema': 1,
          'user_id': user,
          'synced_at': (syncedAt ?? DateTime.now().toUtc()).toIso8601String(),
          'order': order.toJson(),
        }),
      );
    });
  }

  Future<CachedTicket?> read(String user, String id) async {
    final key = _key(user, id);
    try {
      final raw = await storage.read(key);
      if (raw == null) return null;
      final j = jsonObject(jsonDecode(raw));
      if (j['schema'] != 1 || j['user_id'] != user) {
        throw const FormatException();
      }
      final order = Order.fromJson(jsonObject(j['order']));
      if (order.id != id ||
          order.status != OrderStatus.paid ||
          order.pickup == null) {
        throw const FormatException();
      }
      return CachedTicket(order, instant(j, 'synced_at'));
    } catch (_) {
      await storage.delete(key).catchError((_) {});
      return null;
    }
  }

  Future<List<CachedTicket>> list(String user) async {
    try {
      final prefix = 'private.ticket.$user.';
      final result = <CachedTicket>[];
      for (final key in (await storage.readAll()).keys.where(
        (k) => k.startsWith(prefix),
      )) {
        final entry = await read(user, key.substring(prefix.length));
        if (entry != null) result.add(entry);
      }
      result.sort((a, b) => a.order.pickupEnd.compareTo(b.order.pickupEnd));
      return List.unmodifiable(result);
    } catch (_) {
      return const [];
    }
  }

  Future<void> _guard(String user, Future<void> Function() action) =>
      sessions?.runForUser(user, action) ?? action();
  Future<void> remove(String user, String id) =>
      _guard(user, () => storage.delete(_key(user, id)));
  Future<void> clearForUser(String user) async {
    for (final key in (await storage.readAll()).keys.where(
      (k) => k.startsWith('private.ticket.$user.'),
    )) {
      await storage.delete(key);
    }
  }
}
