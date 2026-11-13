import 'json.dart';
import 'payment.dart';
import 'complaint.dart';

enum OrderStatus {
  pendingPayment('pending_payment'),
  paid('paid'),
  cancelled('cancelled'),
  completed('completed'),
  dispute('dispute'),
  refunded('refunded'),
  noShow('no_show');

  final String wire;
  const OrderStatus(this.wire);
  static OrderStatus parse(String s) => values.firstWhere(
    (e) => e.wire == s,
    orElse: () => throw const FormatException('Status pesanan tidak didukung.'),
  );
}

class Merchant {
  final String id, name, address;
  final double latitude, longitude;
  final String? photoId;
  const Merchant({
    required this.id,
    required this.name,
    required this.address,
    required this.latitude,
    required this.longitude,
    this.photoId,
  });
  factory Merchant.fromJson(Json j) => Merchant(
    id: text(j, 'id'),
    name: text(j, 'name'),
    address: text(j, 'address'),
    latitude: coordinate(j, 'latitude')!,
    longitude: coordinate(j, 'longitude')!,
    photoId: j['photo_id'] as String?,
  );
  Json toJson() => {
    'id': id,
    'name': name,
    'address': address,
    'latitude': latitude,
    'longitude': longitude,
    'photo_id': photoId,
  };
}

class PickupTicket {
  final String qr, otp;
  const PickupTicket(this.qr, this.otp);
  factory PickupTicket.fromJson(Json j) {
    final otp = text(j, 'otp'), qr = text(j, 'qr');
    if (!RegExp(r'^\d{6}$').hasMatch(otp) ||
        !RegExp(
          r'^sisarasa:v1:[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}:[A-Za-z0-9_-]{43}$',
        ).hasMatch(qr)) {
      throw const FormatException('Tiket pickup tidak valid.');
    }
    return PickupTicket(qr, otp);
  }
  Json toJson() => {'qr': qr, 'otp': otp};
}

class OrderSummary {
  final String id, code, category;
  final OrderStatus status;
  final int price, fee;
  final DateTime pickupStart, pickupEnd, safeEatUntil, createdAt;
  const OrderSummary({
    required this.id,
    required this.code,
    required this.category,
    required this.status,
    required this.price,
    required this.fee,
    required this.pickupStart,
    required this.pickupEnd,
    required this.safeEatUntil,
    required this.createdAt,
  });
  factory OrderSummary.fromJson(Json j) => OrderSummary(
    id: text(j, 'id'),
    code: text(j, 'code'),
    category: text(j, 'category'),
    status: OrderStatus.parse(text(j, 'status')),
    price: integer(j, 'price'),
    fee: integer(j, 'fee'),
    pickupStart: instant(j, 'pickup_start'),
    pickupEnd: instant(j, 'pickup_end'),
    safeEatUntil: instant(j, 'safe_eat_until'),
    createdAt: instant(j, 'created_at'),
  );
}

class HistoryEntry {
  final String action;
  final DateTime at;
  const HistoryEntry(this.action, this.at);
  factory HistoryEntry.fromJson(Json j) =>
      HistoryEntry(text(j, 'action'), instant(j, 'occurred_at'));
  Json toJson() => {'action': action, 'occurred_at': at.toIso8601String()};
}

class Order extends OrderSummary {
  final String invoice;
  final int normalPrice, feeBps;
  final List<String> allergens, allowedActions;
  final DateTime paymentDeadline, serverTime;
  final Payment? payment;
  final Merchant? merchant;
  final PickupTicket? pickup;
  final Complaint? complaint;
  final List<HistoryEntry> history;
  const Order({
    required super.id,
    required super.code,
    required super.category,
    required super.status,
    required super.price,
    required super.fee,
    required super.pickupStart,
    required super.pickupEnd,
    required super.safeEatUntil,
    required super.createdAt,
    required this.invoice,
    required this.normalPrice,
    required this.feeBps,
    required this.allergens,
    required this.allowedActions,
    required this.paymentDeadline,
    required this.serverTime,
    this.payment,
    this.merchant,
    this.pickup,
    this.complaint,
    required this.history,
  });
  factory Order.fromJson(Json j) => Order(
    id: text(j, 'id'),
    code: text(j, 'code'),
    category: text(j, 'category'),
    status: OrderStatus.parse(text(j, 'status')),
    price: integer(j, 'price'),
    fee: integer(j, 'fee'),
    pickupStart: instant(j, 'pickup_start'),
    pickupEnd: instant(j, 'pickup_end'),
    safeEatUntil: instant(j, 'safe_eat_until'),
    createdAt: instant(j, 'created_at'),
    invoice: text(j, 'invoice'),
    normalPrice: integer(j, 'normal_price'),
    feeBps: integer(j, 'fee_bps'),
    allergens: strings(j, 'allergens'),
    allowedActions: strings(j, 'allowed_actions'),
    paymentDeadline: instant(j, 'payment_deadline'),
    serverTime: instant(j, 'server_time'),
    payment: j['payment'] == null
        ? null
        : Payment.fromJson(jsonObject(j['payment'])),
    merchant: j['merchant'] == null
        ? null
        : Merchant.fromJson(jsonObject(j['merchant'])),
    pickup: j['pickup'] == null
        ? null
        : PickupTicket.fromJson(jsonObject(j['pickup'])),
    complaint: j['complaint'] == null
        ? null
        : Complaint.fromJson(jsonObject(j['complaint'])),
    history: List.unmodifiable(
      (j['history'] as List).map((e) => HistoryEntry.fromJson(jsonObject(e))),
    ),
  );
  Json toJson() => {
    'id': id,
    'code': code,
    'invoice': invoice,
    'category': category,
    'status': status.wire,
    'price': price,
    'fee': fee,
    'normal_price': normalPrice,
    'fee_bps': feeBps,
    'allergens': allergens,
    'allowed_actions': allowedActions,
    'pickup_start': pickupStart.toIso8601String(),
    'pickup_end': pickupEnd.toIso8601String(),
    'safe_eat_until': safeEatUntil.toIso8601String(),
    'created_at': createdAt.toIso8601String(),
    'payment_deadline': paymentDeadline.toIso8601String(),
    'server_time': serverTime.toIso8601String(),
    'payment': payment?.toJson(),
    'merchant': merchant?.toJson(),
    'pickup': pickup?.toJson(),
    'complaint': complaint?.toJson(),
    'history': history.map((e) => e.toJson()).toList(),
    'simulation': true,
  };
}
