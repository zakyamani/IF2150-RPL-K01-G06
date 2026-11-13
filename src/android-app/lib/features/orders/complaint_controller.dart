import '../../app_services.dart';
import '../../core/controller.dart';
import '../../core/api/api_error.dart';
import '../../core/models/complaint.dart';
import '../../core/models/order.dart';
import '../../core/models/json.dart';
import '../../core/storage/operation_store.dart';

class ComplaintRepository {
  final AppServices services;
  ComplaintRepository(this.services);
  Future<Complaint> create(Json body) async {
    return OperationStore(services).run(
      'complaint',
      body['order_id'] as String,
      body,
      (key) =>
          services.api.post('/complaints', body, Complaint.fromJson, key: key),
    );
  }

  Future<Complaint> detail(String id) =>
      services.api.get('/complaints/$id', Complaint.fromJson);
  Future<Complaint> decide(String id, bool approved, String response) =>
      services.api.post('/complaints/$id/decision', {
        'approved': approved,
        'response': response.trim(),
      }, Complaint.fromJson);
  Future<Page<Complaint>> list({String? cursor, String? status}) =>
      services.api.get(
        '/complaints',
        (j) => Page.fromJson(j, Complaint.fromJson),
        query: {'limit': 20, 'cursor': ?cursor, 'status': ?status},
      );
}

class ComplaintFormController extends Controller {
  final ComplaintRepository repo;
  final Order order;
  final DateTime anchor, started = DateTime.now().toUtc();
  String reason = 'unfit', description = '';
  final mediaIds = <String>[];
  Complaint? result;
  bool uncertain = false;
  late final Future<bool> ready;
  ComplaintFormController(AppServices s, this.order, {DateTime? serverNow})
    : repo = ComplaintRepository(s),
      anchor = serverNow ?? order.serverTime {
    ready = perform(() async {
      final body = await OperationStore(s).load('complaint', order.id);
      if (body == null || disposed) return;
      reason = text(body, 'reason');
      description = text(body, 'description');
      mediaIds.addAll((body['media_ids'] as List).cast<String>());
      uncertain = true;
    });
  }
  DateTime get now => anchor.add(DateTime.now().toUtc().difference(started));
  bool validate() {
    fields = {};
    if (description.trim().length < 10 || description.trim().length > 2000) {
      fields['description'] = [
        'Jelaskan kondisi paket dalam 10–2000 karakter.',
      ];
    }
    if (mediaIds.length > 2) fields['media_ids'] = ['Maksimal dua foto bukti.'];
    if (![
      'unfit',
      'unavailable',
      'allergen',
      'store_closed',
    ].contains(reason)) {
      fields['reason'] = ['Pilih alasan pengaduan.'];
    }
    if (order.status != OrderStatus.paid || !now.isBefore(order.pickupEnd)) {
      fields['order'] = [
        'Pengaduan hanya tersedia sebelum pickup selesai dan sebelum batas pengambilan.',
      ];
    }
    if (reason == 'store_closed' && now.isBefore(order.pickupStart)) {
      fields['reason'] = [
        'Toko tutup hanya dapat dilaporkan dalam jadwal pengambilan.',
      ];
    }
    changed();
    return fields.isEmpty;
  }

  Future<bool> submit() async {
    if (!await ready) return false;
    if (!uncertain && !validate()) return false;
    return perform(() async {
      try {
        result = await repo.create({
          'order_id': order.id,
          'reason': reason,
          'description': description.trim(),
          'media_ids': mediaIds.toList(),
        });
        uncertain = false;
      } on ApiError {
        uncertain =
            await OperationStore(repo.services).load('complaint', order.id) !=
            null;
        rethrow;
      }
    });
  }
}

class ComplaintDetailController extends Controller {
  final ComplaintRepository repo;
  final String id;
  Complaint? item;
  bool uncertain = false;
  ComplaintDetailController(AppServices s, this.id)
    : repo = ComplaintRepository(s);
  Future<bool> load() => perform(() async {
    item = await repo.detail(id);
    uncertain = false;
  });
  Future<bool> decide(bool approved, String response) async {
    if (response.trim().length < 5 || response.trim().length > 2000) {
      fields = {
        'response': ['Tanggapan 5–2000 karakter.'],
      };
      changed();
      return false;
    }
    return perform(() async {
      try {
        item = await repo.decide(id, approved, response);
      } on ApiError catch (e) {
        if (e.code == 'NETWORK_UNCERTAIN') uncertain = true;
        rethrow;
      }
    });
  }
}

String complaintReason(String reason) => switch (reason) {
  'unfit' => 'Makanan tidak layak',
  'unavailable' => 'Isi paket tidak tersedia',
  'allergen' => 'Alergen tidak sesuai',
  'store_closed' => 'Toko tutup',
  _ => reason,
};
