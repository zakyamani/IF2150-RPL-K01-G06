import '../../app_services.dart';
import '../../core/controller.dart';
import '../../core/models/offer.dart';
import '../../core/models/user.dart';
import 'seller_repository.dart';

class SellerController extends Controller {
  final SellerRepository repo;
  MerchantProfile? profile;
  List<SellerOffer> offers = [];
  String? cursor;
  int? saved;
  String filter = 'all';
  SellerController(AppServices services) : repo = SellerRepository(services);
  bool get profileComplete =>
      profile != null &&
      profile!.name.isNotEmpty &&
      profile!.address.isNotEmpty &&
      profile!.latitude != null &&
      profile!.longitude != null;
  List<SellerOffer> get visible => filter == 'all'
      ? offers
      : offers.where((o) => o.status == filter).toList();
  Future<bool> load() => perform(() async {
    final (nextProfile, page, packages) = await (
      repo.profile(),
      repo.offers(),
      repo.packagesSaved(),
    ).wait;
    if (disposed) return;
    profile = nextProfile;
    offers = page.items;
    cursor = page.nextCursor;
    saved = packages;
  });
  Future<bool> loadOffers({bool more = false}) => perform(() async {
    final page = await repo.offers(cursor: more ? cursor : null);
    if (disposed) return;
    offers = more ? [...offers, ...page.items] : page.items;
    cursor = page.nextCursor;
  });
  Future<bool> loadProfile() => perform(() async {
    final value = await repo.profile();
    if (!disposed) profile = value;
  });
  Future<bool> close(String id) => perform(() async {
    await repo.closeOffer(id);
    final page = await repo.offers();
    if (!disposed) {
      offers = page.items;
      cursor = page.nextCursor;
    }
  });
  void setFilter(String value) {
    filter = value;
    changed();
  }
}
