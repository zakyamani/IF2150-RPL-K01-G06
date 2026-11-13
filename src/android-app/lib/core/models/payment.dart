import 'json.dart';

class Payment {
  final String id, orderId, status;
  final int amount;
  const Payment({
    required this.id,
    required this.orderId,
    required this.status,
    required this.amount,
  });
  factory Payment.fromJson(Json j) {
    if (j['simulation'] != true || j['currency'] != 'IDR') {
      throw const FormatException('Gateway pembayaran tidak didukung.');
    }
    return Payment(
      id: text(j, 'id'),
      orderId: text(j, 'order_id'),
      status: text(j, 'status'),
      amount: integer(j, 'amount'),
    );
  }
  Json toJson() => {
    'id': id,
    'order_id': orderId,
    'status': status,
    'amount': amount,
    'currency': 'IDR',
    'simulation': true,
  };
}

class Checkout {
  final String orderId, intentId, code, invoice;
  final int price, fee;
  final DateTime deadline;
  const Checkout({
    required this.orderId,
    required this.intentId,
    required this.code,
    required this.invoice,
    required this.price,
    required this.fee,
    required this.deadline,
  });
  factory Checkout.fromJson(Json j) => Checkout(
    orderId: text(j, 'order_id'),
    intentId: text(j, 'intent_id'),
    code: text(j, 'code'),
    invoice: text(j, 'invoice'),
    price: integer(j, 'price'),
    fee: integer(j, 'fee'),
    deadline: instant(j, 'payment_deadline'),
  );
}
