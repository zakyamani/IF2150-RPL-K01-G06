import 'json.dart';

class ReviewEntry {
  final String id, comment;
  final String? reviewerName;
  final int rating;
  final DateTime createdAt;
  const ReviewEntry(
    this.id,
    this.comment,
    this.reviewerName,
    this.rating,
    this.createdAt,
  );
  factory ReviewEntry.fromJson(Json j) {
    final rating = integer(j, 'rating');
    if (rating < 1 || rating > 5) {
      throw const FormatException('Nilai ulasan tidak valid.');
    }
    return ReviewEntry(
      text(j, 'id'),
      text(j, 'comment'),
      j['reviewer_name'] as String?,
      rating,
      instant(j, 'created_at'),
    );
  }
}

class MerchantReviews {
  final Page<ReviewEntry> page;
  final double? average;
  final int count;
  const MerchantReviews(this.page, this.average, this.count);
  factory MerchantReviews.fromJson(Json j) {
    final average = (j['rating_average'] as num?)?.toDouble();
    if (average != null && (!average.isFinite || average < 1 || average > 5)) {
      throw const FormatException('Rata-rata tidak valid.');
    }
    return MerchantReviews(
      Page.fromJson(j, ReviewEntry.fromJson),
      average,
      integer(j, 'rating_count'),
    );
  }
}
