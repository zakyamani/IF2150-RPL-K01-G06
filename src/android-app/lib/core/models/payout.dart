import 'json.dart';

class PayoutSummary {
  final int pending, held, settled, cancelled;
  const PayoutSummary(this.pending, this.held, this.settled, this.cancelled);
  factory PayoutSummary.fromJson(Json j) {
    if (j['simulation'] != true) {
      throw const FormatException('Saldo wajib simulasi.');
    }
    return PayoutSummary(
      integer(j, 'pending'),
      integer(j, 'held'),
      integer(j, 'settled'),
      integer(j, 'cancelled'),
    );
  }
}

class Payout {
  final String id, orderId, orderCode, status, reason;
  final int gross, fee, net;
  final DateTime dueAt;
  final DateTime? settledAt;
  const Payout({
    required this.id,
    required this.orderId,
    required this.orderCode,
    required this.status,
    required this.reason,
    required this.gross,
    required this.fee,
    required this.net,
    required this.dueAt,
    this.settledAt,
  });
  factory Payout.fromJson(Json j) {
    if (j['simulation'] != true) {
      throw const FormatException('Payout wajib simulasi.');
    }
    return Payout(
      id: text(j, 'id'),
      orderId: text(j, 'order_id'),
      orderCode: text(j, 'order_code'),
      status: text(j, 'status'),
      reason: text(j, 'reason'),
      gross: integer(j, 'gross'),
      fee: integer(j, 'fee'),
      net: integer(j, 'net'),
      dueAt: instant(j, 'due_at'),
      settledAt: j['settled_at'] == null ? null : instant(j, 'settled_at'),
    );
  }
}
