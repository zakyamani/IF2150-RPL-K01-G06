import '../../app_services.dart';
import '../../core/controller.dart';
import '../../core/models/json.dart';
import '../../core/models/payout.dart';

class PayoutController extends Controller {
  final AppServices services;
  PayoutSummary? summary;
  List<Payout> items = [];
  String? status, cursor;
  PayoutController(this.services);
  Future<bool> load({bool more = false, String? status}) {
    if (status != null) this.status = status.isEmpty ? null : status;
    return perform(() async {
      final (balance, page) = await (
        services.api.get('/payouts/summary', PayoutSummary.fromJson),
        services.api.get(
          '/payouts',
          (j) => Page.fromJson(j, Payout.fromJson),
          query: {
            'cursor': ?more ? cursor : null,
            'status': ?this.status,
            'limit': 20,
          },
        ),
      ).wait;
      if (disposed) return;
      summary = balance;
      items = more ? [...items, ...page.items] : page.items;
      cursor = page.nextCursor;
    });
  }
}
