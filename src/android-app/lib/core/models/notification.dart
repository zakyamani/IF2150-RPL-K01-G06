import 'json.dart';

class InboxEvent {
  final String id, sequence, type, resourceId, summary;
  final DateTime occurredAt;
  final DateTime? readAt;
  const InboxEvent({
    required this.id,
    required this.sequence,
    required this.type,
    required this.resourceId,
    required this.summary,
    required this.occurredAt,
    this.readAt,
  });
  Json toJson() => {
    'id': id,
    'sequence': sequence,
    'type': type,
    'resource_id': resourceId,
    'summary': summary,
    'occurred_at': occurredAt.toIso8601String(),
    'read_at': readAt?.toIso8601String(),
  };
  InboxEvent withRead(DateTime at) => InboxEvent(
    id: id,
    sequence: sequence,
    type: type,
    resourceId: resourceId,
    summary: summary,
    occurredAt: occurredAt,
    readAt: at,
  );
  factory InboxEvent.fromJson(Json j) {
    final sequence = text(j, 'sequence');
    if (!RegExp(r'^(0|[1-9]\d{0,18})$').hasMatch(sequence) ||
        BigInt.parse(sequence) > BigInt.parse('9223372036854775807')) {
      throw const FormatException('Cursor inbox tidak valid.');
    }
    return InboxEvent(
      id: text(j, 'id'),
      sequence: sequence,
      type: text(j, 'type'),
      resourceId: text(j, 'resource_id'),
      summary: text(j, 'summary'),
      occurredAt: instant(j, 'occurred_at'),
      readAt: j['read_at'] == null ? null : instant(j, 'read_at'),
    );
  }
}
