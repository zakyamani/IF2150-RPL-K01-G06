import 'json.dart';

class Offer {
  final String id, category;
  final List<String> allergens;
  final int available, normalPrice, discountPrice;
  final double discountPercent;
  final DateTime pickupStart, pickupEnd, safeEatUntil;
  final double? distanceKm;
  const Offer({
    required this.id,
    required this.category,
    required this.allergens,
    required this.available,
    required this.normalPrice,
    required this.discountPrice,
    required this.discountPercent,
    required this.pickupStart,
    required this.pickupEnd,
    required this.safeEatUntil,
    this.distanceKm,
  });
  factory Offer.fromJson(Json j) => Offer(
    id: text(j, 'id'),
    category: text(j, 'category'),
    allergens: strings(j, 'allergens'),
    available: integer(j, 'quota_available'),
    normalPrice: integer(j, 'normal_price'),
    discountPrice: integer(j, 'discount_price'),
    discountPercent: (j['discount_percent'] as num).toDouble(),
    pickupStart: instant(j, 'pickup_start'),
    pickupEnd: instant(j, 'pickup_end'),
    safeEatUntil: instant(j, 'safe_eat_until'),
    distanceKm: coordinate(j, 'distance_km'),
  );
}

class SellerOffer {
  final String id, category, status;
  final List<String> allergens;
  final int total, available, held, sold, normalPrice, discountPrice;
  final DateTime pickupStart, pickupEnd, safeEatUntil;
  const SellerOffer({
    required this.id,
    required this.category,
    required this.status,
    required this.allergens,
    required this.total,
    required this.available,
    required this.held,
    required this.sold,
    required this.normalPrice,
    required this.discountPrice,
    required this.pickupStart,
    required this.pickupEnd,
    required this.safeEatUntil,
  });
  factory SellerOffer.fromJson(Json j) => SellerOffer(
    id: text(j, 'id'),
    category: text(j, 'category'),
    status: text(j, 'status'),
    allergens: strings(j, 'allergens'),
    total: integer(j, 'quota_total'),
    available: integer(j, 'quota_available'),
    held: integer(j, 'quota_held'),
    sold: integer(j, 'quota_sold'),
    normalPrice: integer(j, 'normal_price'),
    discountPrice: integer(j, 'discount_price'),
    pickupStart: instant(j, 'pickup_start'),
    pickupEnd: instant(j, 'pickup_end'),
    safeEatUntil: instant(j, 'safe_eat_until'),
  );
  bool get editable => status == 'active' && held == 0 && sold == 0;
}