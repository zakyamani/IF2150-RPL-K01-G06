import 'json.dart';

class Complaint {
  final String id, reason, description, status;
  final String? orderId, orderCode, response;
  final List<String> mediaIds;
  final DateTime createdAt;
  final DateTime? responseDue;
  const Complaint({
    required this.id,
    required this.reason,
    required this.description,
    required this.status,
    required this.createdAt,
    this.orderId,
    this.orderCode,
    this.response,
    this.responseDue,
    this.mediaIds = const [],
  });
  factory Complaint.fromJson(Json j) => Complaint(
    id: text(j, 'id'),
    reason: text(j, 'reason'),
    description: text(j, 'description'),
    status: text(j, 'status'),
    createdAt: instant(j, 'created_at'),
    orderId: j['order_id'] as String?,
    orderCode: j['order_code'] as String?,
    response: j['response'] as String?,
    responseDue: j['response_due'] == null ? null : instant(j, 'response_due'),
    mediaIds: j['media_ids'] == null ? const [] : strings(j, 'media_ids'),
  );
  Json toJson() => {
    'id': id,
    'reason': reason,
    'description': description,
    'status': status,
    'created_at': createdAt.toIso8601String(),
    'order_id': orderId,
    'response': response,
    'response_due': responseDue?.toIso8601String(),
    'media_ids': mediaIds,
  };
}
