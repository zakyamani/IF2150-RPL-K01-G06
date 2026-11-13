import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sisarasa_app/app_services.dart';
import 'package:sisarasa_app/core/models/user.dart';

import '../helpers/memory_store.dart';
import '../helpers/samples.dart';
import '../helpers/fake_http.dart';

void main() {
  test(
    'multipart auth retry clones file body and rotates token once',
    () async {
      var uploads = 0, refreshes = 0;
      final http = FakeHttp((r) async {
        if (r.path == '/auth/refresh') {
          refreshes++;
          return (200, sessionJson(access: 'fresh-token'));
        }
        uploads++;
        expect(
          r.headers[Headers.contentTypeHeader],
          contains('multipart/form-data'),
        );
        expect((r.data as FormData).fields.single.value, 'shop');
        return uploads == 1
            ? (401, {'code': 'UNAUTHORIZED', 'message': 'Expired'})
            : (201, {'id': 'media'});
      });
      final s = await AppServices.create(
        storage: MemoryStore(),
        initialOrigin: 'https://api.example.test',
        dio: Dio()..httpClientAdapter = http,
      );
      await s.sessions.save(SessionBundle.fromJson(sessionJson()));
      final media = await s.api.upload(
        Uint8List.fromList([0xff, 0xd8, 0xff]),
        'image/jpeg',
        'shop',
      );
      expect(media['id'], 'media');
      expect(uploads, 2);
      expect(refreshes, 1);
      s.dispose();
    },
  );
}
