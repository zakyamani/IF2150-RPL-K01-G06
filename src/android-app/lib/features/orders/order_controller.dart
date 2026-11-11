import 'dart:async';

import '../../app_services.dart';
import '../../core/controller.dart';
import '../../core/api/api_error.dart';
import '../../core/models/json.dart';
import '../../core/models/order.dart';
import '../../core/models/payment.dart';
import 'order_repository.dart';

class CheckoutController extends Controller {
  final OrderRepository repo;
  final String offer;
  Checkout? result;
  CheckoutController(AppServices services, this.offer)
    : repo = OrderRepository(services);
  Future<bool> restore() => perform(() async {
    final attempt = await repo.attempt(offer);
    if (attempt?['result'] != null) {
      result = Checkout.fromJson(jsonObject(attempt!['result']));
    }
  });
  Future<bool> checkout() => perform(() async {
    result = await repo.checkout(offer);
  });
  Future<bool> newAttempt() => perform(() async {
    await repo.newAttempt(offer);
    result = null;
  });
}

class OrderController extends Controller {
  final OrderRepository repo;
  final String id;
  Order? order;
  bool offline = false;
  DateTime? syncedAt;
  final watch = Stopwatch();
  Timer? timer;
  DateTime? anchor;
  OrderController(this.repo, this.id);
  DateTime get serverNow =>
      anchor?.add(watch.elapsed) ?? DateTime.now().toUtc();
  bool get ticketExpired =>
      order != null && !serverNow.isBefore(order!.pickupEnd);
  Duration get paymentRemaining =>
      order?.paymentDeadline.difference(serverNow) ?? Duration.zero;
  Future<bool> load() => perform(() async {
    final epoch = repo.services.sessions.epoch;
    final cache = await repo.cached(id);
    if (disposed || epoch != repo.services.sessions.epoch) {
      throw const ApiError('SESSION_CHANGED', 'Sesi berubah.');
    }
    if (cache != null) {
      order = cache.order;
      syncedAt = cache.syncedAt;
      offline = true;
      anchor = order!.serverTime.add(
        DateTime.now().toUtc().difference(cache.syncedAt),
      );
      watch
        ..reset()
        ..start();
      timer?.cancel();
      timer = Timer.periodic(const Duration(seconds: 1), (_) => changed());
      changed();
    }
    try {
      order = await repo.order(id);
      syncedAt = DateTime.now().toUtc();
      anchor = order!.serverTime;
      offline = false;
    } on ApiError catch (e) {
      if (e.code != 'NETWORK_UNAVAILABLE' || cache == null) {
        order = null;
        offline = false;
        rethrow;
      }
    }
    if (disposed || epoch != repo.services.sessions.epoch) {
      order = null;
      throw const ApiError('SESSION_CHANGED', 'Sesi berubah.');
    }
    watch
      ..reset()
      ..start();
    timer?.cancel();
    timer = Timer.periodic(const Duration(seconds: 1), (_) => changed());
  });
  Future<bool> pay(String outcome) => perform(() async {
    final current = order;
    if (current?.payment == null) {
      throw const ApiError('PAYMENT_NOT_FOUND', 'Invoice tidak tersedia.');
    }
    await repo.demoPayment(current!.payment!.id, outcome);
    order = await repo.order(id);
    offline = false;
    syncedAt = DateTime.now().toUtc();
    anchor = order!.serverTime;
    watch
      ..reset()
      ..start();
  });
  @override
  void dispose() {
    timer?.cancel();
    watch.stop();
    super.dispose();
  }
}

class HistoryController extends Controller {
  final OrderRepository repo;
  StreamSubscription? _updates;
  Timer? _refresh;
  List<OrderSummary> items = [];
  String? cursor, status;
  HistoryController(this.repo) {
    _updates = repo.services.notifications.changes.listen((event) {
      if (!event.type.startsWith('payout.')) _scheduleRefresh();
    });
  }
  void _scheduleRefresh() {
    _refresh?.cancel();
    _refresh = Timer(const Duration(milliseconds: 400), () {
      if (disposed) return;
      if (busy) {
        _scheduleRefresh();
      } else {
        unawaited(load());
      }
    });
  }

  @override
  void dispose() {
    _refresh?.cancel();
    _updates?.cancel();
    super.dispose();
  }

  Future<bool> load({bool more = false, String? status}) {
    if (status != null) this.status = status.isEmpty ? null : status;
    return perform(() async {
      final page = await repo.history(
        cursor: more ? cursor : null,
        status: this.status,
      );
      if (disposed) return;
      items = more ? [...items, ...page.items] : page.items;
      cursor = page.nextCursor;
    });
  }
}
