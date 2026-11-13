import '../../app_services.dart';
import '../../core/controller.dart';
import '../../core/api/api_error.dart';

class ReviewController extends Controller {
  final AppServices services;
  final String orderId;
  int rating = 0;
  String comment = '';
  bool duplicate = false, submitted = false;
  ReviewController(this.services, this.orderId);
  Future<bool> submit() async {
    if (submitted) return true;
    fields = {};
    if (rating < 1 || rating > 5) {
      fields['rating'] = ['Pilih nilai 1–5 bintang.'];
    }
    if (comment.trim().length > 1000) {
      fields['comment'] = ['Ulasan maksimal 1000 karakter.'];
    }
    if (fields.isNotEmpty) {
      changed();
      return false;
    }
    return perform(() async {
      try {
        await services.api.post('/reviews', {
          'order_id': orderId,
          'rating': rating,
          'comment': comment.trim(),
        }, (j) => j);
      } on ApiError catch (e) {
        if (e.code != 'CONFLICT') rethrow;
        duplicate = true;
      }
      submitted = true;
    });
  }
}
