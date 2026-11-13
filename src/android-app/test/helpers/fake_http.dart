import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

class FakeHttp implements HttpClientAdapter {
  final Future<(int, Object?)> Function(RequestOptions) respond;
  final List<RequestOptions> calls = [];
  FakeHttp(this.respond);
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    calls.add(options);
    final (status, data) = await respond(options);
    return ResponseBody.fromString(
      jsonEncode(data),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
