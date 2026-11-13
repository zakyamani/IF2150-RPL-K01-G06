import 'dart:typed_data';

import '../../app_services.dart';
import '../../core/models/json.dart';
import '../../core/models/offer.dart';
import '../../core/models/user.dart';
import '../../core/api/api_error.dart';

class SellerRepository {
  final AppServices services;
  SellerRepository(this.services);
  Future<MerchantProfile> profile() =>
      services.api.get('/merchant/profile', MerchantProfile.fromJson);
  Future<MerchantProfile> saveProfile(Json input) =>
      services.api.patch('/merchant/profile', input, MerchantProfile.fromJson);
  Future<Page<SellerOffer>> offers({String? cursor}) => services.api.get(
    '/offers',
    (j) => Page.fromJson(j, SellerOffer.fromJson),
    query: {'limit': 20, 'cursor': ?cursor},
  );
  Future<SellerOffer> saveOffer(Json input, {String? id}) => id == null
      ? services.api.post('/offers', input, SellerOffer.fromJson)
      : services.api.patch('/offers/$id', input, SellerOffer.fromJson);
  Future<SellerOffer> closeOffer(String id) =>
      services.api.post('/offers/$id/close', {}, SellerOffer.fromJson);
  Future<int> packagesSaved() =>
      services.api.get('/metrics', (j) => integer(j, 'packages_saved'));
  Future<String> upload(Uint8List bytes, String kind) async {
    if (bytes.length > 2097152) {
      throw const ApiError(
        'IMAGE_TOO_LARGE',
        'Foto maksimal 2 MB. Pilih JPEG/PNG/WebP yang lebih kecil.',
      );
    }
    final mime = bytes.length >= 12 && bytes[0] == 0x89 && bytes[1] == 0x50
        ? 'image/png'
        : bytes.length >= 12 &&
              String.fromCharCodes(bytes.take(4)) == 'RIFF' &&
              String.fromCharCodes(bytes.sublist(8, 12)) == 'WEBP'
        ? 'image/webp'
        : bytes.length >= 2 && bytes[0] == 0xff && bytes[1] == 0xd8
        ? 'image/jpeg'
        : null;
    if (mime == null) {
      throw const ApiError(
        'INVALID_UPLOAD',
        'Pilih foto JPEG, PNG, atau WebP.',
      );
    }
    final result = await services.api.upload(bytes, mime, kind);
    return text(result, 'id');
  }

  Future<MerchantProfile> setPhoto(String id) async {
    await services.api.patch('/merchant/photo', {
      'media_id': id,
    }, (j) => text(j, 'photo_id'));
    return profile();
  }
}
