import '../../app_services.dart';
import '../../core/controller.dart';
import '../../core/models/json.dart';

class PickupResult {
  final String orderId, code;
  final DateTime at;
  const PickupResult(this.orderId, this.code, this.at);
  factory PickupResult.fromJson(Json j) {
    if (j['status'] != 'completed') throw const FormatException();
    return PickupResult(
      text(j, 'order_id'),
      text(j, 'code'),
      instant(j, 'completed_at'),
    );
  }
}

class ScanController extends Controller {
  final AppServices services;
  PickupResult? result;
  final _seen = <String>{};
  ScanController(this.services);
  static final qrPattern = RegExp(
    r'^sisarasa:v1:([0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}):[A-Za-z0-9_-]{43}$',
  );
  static final orderPattern = RegExp(
    r'^(SR-[0-9A-HJKMNP-TV-Z]{10}|[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12})$',
  );
  Future<bool> qr(String value) async {
    if (busy || result != null || _seen.contains(value)) return false;
    final match = qrPattern.firstMatch(value);
    if (match == null) {
      error = 'QR ini bukan tiket pengambilan SisaRasa. Gunakan QR pickup atau OTP 6 digit.';
      changed();
      return false;
    }
    _seen.add(value);
    return perform(() async {
      result = await services.api.post('/pickup/validate', {
        'order_id': match.group(1),
        'kind': 'qr',
        'value': value,
      }, PickupResult.fromJson);
    });
  }

  void retry() {
    if (!busy) {
      _seen.clear();
      error = null;
      result = null;
      changed();
    }
  }

  Future<bool> otp(String order, String code) async {
    final normalized = order.trim().toUpperCase().startsWith('SR-')
        ? order.trim().toUpperCase()
        : order.trim().toLowerCase();
    fields = {};
    if (!orderPattern.hasMatch(normalized)) {
      fields['order_id'] = ['Masukkan kode SR-… yang tertera pada pesanan.'];
    }
    if (!RegExp(r'^\d{6}$').hasMatch(code)) {
      fields['otp'] = ['OTP harus enam digit.'];
    }
    if (fields.isNotEmpty) {
      changed();
      return false;
    }
    return perform(() async {
      result = await services.api.post('/pickup/validate', {
        'order_id': normalized,
        'kind': 'otp',
        'value': code,
      }, PickupResult.fromJson);
    });
  }
}
