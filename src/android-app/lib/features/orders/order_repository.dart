import 'dart:convert';

import 'package:uuid/uuid.dart';

import '../../app_services.dart';
import '../../core/api/api_error.dart';
import '../../core/models/json.dart';
import '../../core/models/order.dart';
import '../../core/models/payment.dart';
import '../../core/storage/ticket_cache.dart';

class OrderRepository {
  final AppServices services;
  bool cacheAvailable = true;
  OrderRepository(this.services);
  String get user => services.sessions.session!.user.id;
  String attemptKey(String offer) => 'private.checkout.$user.$offer';
  Future<Json?> attempt(String offer) async {
    final raw = await services.sessions.storage.read(attemptKey(offer));
    if (raw == null) return null;
    try {
      final data = jsonObject(jsonDecode(raw));
      if (data['key'] is! String) throw const FormatException();
      return data;
    } catch (_) {
      throw const ApiError(
        'CHECKOUT_STATE_CORRUPT',
        'Status checkout tersimpan rusak. Periksa Pesanan sebelum membuat pembelian baru.',
      );
    }
  }

  Future<Checkout> checkout(String offer) async {
    final actor = user;
    final keyName = attemptKey(offer);
    late Json record;
    await services.sessions.runForUser(actor, () async {
      final previous = await attempt(offer);
      record = previous ?? {'key': const Uuid().v4()};
      if (previous == null) {
        await services.sessions.storage.write(keyName, jsonEncode(record));
      }
    });
    if (record['result'] != null) {
      return Checkout.fromJson(jsonObject(record['result']));
    }
    final response = await services.api.post(
      '/orders/checkout',
      {'offer_id': offer},
      (j) => j,
      key: record['key'] as String,
    );
    final result = Checkout.fromJson(response);
    await services.sessions.runForUser(
      actor,
      () => services.sessions.storage.write(
        keyName,
        jsonEncode({...record, 'result': response}),
      ),
    );
    return result;
  }

  Future<void> newAttempt(String offer) async {
    final previous = await attempt(offer);
    if (previous != null && previous['result'] == null) {
      throw const ApiError(
        'CHECKOUT_UNCERTAIN',
        'Pulihkan checkout sebelumnya atau periksa Pesanan terlebih dahulu.',
      );
    }
    if (previous?['result'] != null) {
      final order = await this.order(
        text(jsonObject(previous!['result']), 'order_id'),
      );
      if (order.status == OrderStatus.pendingPayment) {
        throw const ApiError(
          'PAYMENT_PENDING',
          'Selesaikan atau tunggu invoice sebelumnya berakhir.',
        );
      }
    }
    final name = attemptKey(offer);
    await services.sessions.runForUser(
      user,
      () => services.sessions.storage.delete(name),
    );
  }

  Future<Order> order(String id) async {
    final actor = user;
    final value = await services.api.get('/orders/$id', Order.fromJson);
    try {
      await services.tickets.save(actor, value);
      cacheAvailable = true;
    } catch (_) {
      cacheAvailable = false;
    }
    return value;
  }

  Future<CachedTicket?> cached(String id) => services.tickets.read(user, id);
  Future<Page<OrderSummary>> history({String? cursor, String? status}) =>
      services.api.get(
        '/orders',
        (j) => Page.fromJson(j, OrderSummary.fromJson),
        query: {'limit': 20, 'cursor': ?cursor, 'status': ?status},
      );
  Future<Payment> paymentIntent(String id) =>
      services.api.get('/payments/$id', Payment.fromJson);
  Future<void> demoPayment(String intent, String outcome) => services.api
      .post<void>('/payments/$intent/demo-event', {'outcome': outcome}, (_) {});
}
