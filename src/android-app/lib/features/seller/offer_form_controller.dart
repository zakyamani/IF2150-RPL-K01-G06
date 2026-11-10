import '../../app_services.dart';
import '../../core/controller.dart';
import '../../core/api/api_error.dart';
import '../../core/models/offer.dart';
import '../../core/models/json.dart';
import 'seller_repository.dart';

class OfferFormController extends Controller {
  final SellerRepository repo;
  final DateTime Function() now;
  final String? offerId;
  String category = 'campuran',
      quota = '1',
      normalPrice = '',
      discountPrice = '';
  final allergens = <String>{};
  bool fitness = false, uncertain = false;
  late DateTime start, end, safe;
  SellerOffer? result;
  OfferFormController(
    AppServices services, {
    this.offerId,
    SellerOffer? offer,
    DateTime Function()? now,
  }) : repo = SellerRepository(services),
       now = now ?? DateTime.now {
    start = offer?.pickupStart ?? this.now().add(const Duration(minutes: 10));
    end = offer?.pickupEnd ?? start.add(const Duration(hours: 1));
    safe = offer?.safeEatUntil ?? end.add(const Duration(hours: 1));
    if (offer != null) {
      category = offer.category;
      quota = offer.total.toString();
      normalPrice = offer.normalPrice.toString();
      discountPrice = offer.discountPrice.toString();
      allergens.addAll(offer.allergens);
    }
  }
  Json get payload => {
    'category': category,
    'allergens': allergens.toList(),
    'quota': int.parse(quota),
    'normal_price': int.parse(normalPrice),
    'discount_price': int.parse(discountPrice),
    'pickup_start': start.toUtc().toIso8601String(),
    'pickup_end': end.toUtc().toIso8601String(),
    'safe_eat_until': safe.toUtc().toIso8601String(),
    'fitness_confirmed': fitness,
  };
  bool validate() {
    fields = {};
    error = null;
    final q = int.tryParse(quota),
        n = int.tryParse(normalPrice),
        d = int.tryParse(discountPrice);
    if (q == null || q < 1 || q > 500) fields['quota'] = ['Kuota 1–500 paket.'];
    if (n == null || n <= 0 || n > 2000000000) {
      fields['normal_price'] = [
        'Harga normal berupa integer rupiah, maksimal Rp2 miliar.',
      ];
    }
    if (d == null ||
        d <= 0 ||
        d > 2000000000 ||
        (n != null && (d * 100 < n * 30 || d * 100 > n * 50))) {
      fields['discount_price'] = ['Harga paket harus memiliki diskon 50–70%.'];
    }
    final current = now().toUtc();
    if (start.toUtc().isBefore(current) ||
        start.toUtc().isAfter(current.add(const Duration(hours: 2)))) {
      fields['pickup_start'] = [
        'Mulai pickup antara sekarang dan dua jam ke depan.',
      ];
    }
    if (!end.isAfter(start)) {
      fields['pickup_end'] = ['Batas pengambilan harus setelah waktu mulai.'];
    }
    if (safe.isBefore(end)) {
      fields['safe_eat_until'] = [
        'Batas konsumsi tidak sebelum pickup selesai.',
      ];
    }
    if (!fitness) {
      fields['fitness_confirmed'] = [
        'Konfirmasi kelayakan paket sebelum menerbitkan.',
      ];
    }
    changed();
    return fields.isEmpty;
  }

  Future<bool> save() async {
    if (uncertain) {
      error = 'Respons sebelumnya belum pasti. Periksa daftar penawaran dan stok sebelum membuat perubahan lain.';
      changed();
      return false;
    }
    if (!validate()) return false;
    return perform(() async {
      try {
        result = await repo.saveOffer(payload, id: offerId);
      } on ApiError catch (e) {
        if (e.code == 'NETWORK_UNCERTAIN') uncertain = true;
        rethrow;
      }
    });
  }
}
