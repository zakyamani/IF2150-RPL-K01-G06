import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../models/json.dart';
import '../models/user.dart';
import '../storage/session_store.dart';
import 'api_error.dart';
export 'api_error.dart';

class ApiClient {
  final SessionStore sessions;
  final Dio dio;
  Future<void>? _refreshing;
  CancelToken _scope = CancelToken();
  String _origin;
  int _epoch;
  bool _disposed = false;
  ApiClient(this.sessions, {Dio? dio})
    : dio = dio ?? Dio(),
      _origin = sessions.origin,
      _epoch = sessions.epoch {
    this.dio.options = BaseOptions(
      baseUrl: _origin.isEmpty ? '' : '$_origin/api/v1',
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 15),
      sendTimeout: const Duration(seconds: 15),
      followRedirects: false,
      contentType: Headers.jsonContentType,
    );
    sessions.addListener(_changed);
  }
  void _changed() {
    if (_origin != sessions.origin || _epoch != sessions.epoch) {
      _scope.cancel('Session scope changed');
      _scope = CancelToken();
      _refreshing = null;
      _origin = sessions.origin;
      _epoch = sessions.epoch;
      dio.options.baseUrl = _origin.isEmpty ? '' : '$_origin/api/v1';
    }
  }

  Future<T> get<T>(String path, T Function(Json) decode, {Json? query}) =>
      _request('GET', path, null, decode, query: query);
  Future<T> post<T>(
    String path,
    Object? body,
    T Function(Json) decode, {
    String? key,
    bool anonymous = false,
  }) => _request('POST', path, body, decode, key: key, anonymous: anonymous);
  Future<T> patch<T>(String path, Object? body, T Function(Json) decode) =>
      _request('PATCH', path, body, decode);
  Future<Json> upload(Uint8List bytes, String mime, String kind) => _request(
    'POST',
    '/media',
    FormData.fromMap({
      'kind': kind,
      'file': MultipartFile.fromBytes(
        bytes,
        filename: 'photo',
        contentType: DioMediaType.parse(mime),
      ),
    }),
    (j) => j,
  );
  Future<Uint8List> bytes(String path) => _request(
    'GET',
    path,
    null,
    (j) => throw StateError('Binary decoder not used'),
    binary: true,
  );
  Future<T> _request<T>(
    String method,
    String path,
    Object? body,
    T Function(Json) decode, {
    String? key,
    Json? query,
    bool anonymous = false,
    bool retry = false,
    bool binary = false,
  }) async {
    if (_origin.isEmpty) {
      throw const ApiError(
        'SERVER_REQUIRED',
        'Layanan belum tersedia. Coba lagi beberapa saat.',
      );
    }
    final epoch = sessions.epoch;
    final access = sessions.session?.accessToken;
    try {
      final r = await dio.request<Object?>(
        path,
        data: body is FormData ? body.clone() : body,
        queryParameters: query,
        cancelToken: _scope,
        options: Options(
          method: method,
          responseType: binary ? ResponseType.bytes : ResponseType.json,
          headers: {
            if (!anonymous && access != null) 'Authorization': 'Bearer $access',
            'Idempotency-Key': ?key,
          },
        ),
      );
      if (epoch != sessions.epoch) {
        throw const ApiError('SESSION_CHANGED', 'Sesi atau server berubah.');
      }
      if (binary) return Uint8List.fromList((r.data as List).cast<int>()) as T;
      if (r.statusCode == 204) return null as T;
      try {
        return decode(jsonObject(r.data));
      } catch (_) {
        throw const ApiError(
          'INVALID_RESPONSE',
          'Layanan sedang diperbarui. Coba lagi atau perbarui aplikasi.',
        );
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 401 &&
          !anonymous &&
          !retry &&
          sessions.session != null) {
        if (sessions.session!.accessToken == access) await _refresh();
        if (epoch != sessions.epoch) {
          throw const ApiError(
            'UNAUTHORIZED',
            'Sesi berakhir. Silakan masuk kembali.',
            status: 401,
          );
        }
        return _request(
          method,
          path,
          body,
          decode,
          key: key,
          query: query,
          anonymous: anonymous,
          retry: true,
          binary: binary,
        );
      }
      if (e.response?.statusCode == 401 && !anonymous) {
        await sessions.clear();
        throw const ApiError(
          'UNAUTHORIZED',
          'Sesi berakhir. Silakan masuk kembali.',
          status: 401,
        );
      }
      throw _error(e, method);
    }
  }

  Future<void> _refresh() {
    if (_refreshing != null) return _refreshing!;
    late Future<void> pending;
    pending = _rotate().whenComplete(() {
      if (identical(_refreshing, pending)) _refreshing = null;
    });
    _refreshing = pending;
    return pending;
  }

  Future<void> _rotate() async {
    final current = sessions.session;
    if (current == null) {
      throw const ApiError(
        'UNAUTHORIZED',
        'Silakan masuk kembali.',
        status: 401,
      );
    }
    final epoch = sessions.epoch;
    try {
      final r = await dio.post<Object?>(
        '/auth/refresh',
        data: {'refresh_token': current.refreshToken},
        cancelToken: _scope,
      );
      if (epoch != sessions.epoch) {
        throw const ApiError('SESSION_CHANGED', 'Sesi berubah.');
      }
      await sessions.save(
        SessionBundle.fromJson(jsonObject(r.data)),
        expectedEpoch: epoch,
      );
    } on SessionScopeChanged {
      throw const ApiError('SESSION_CHANGED', 'Sesi berubah.');
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        await sessions.clear();
        throw const ApiError(
          'UNAUTHORIZED',
          'Sesi dicabut. Silakan masuk kembali.',
          status: 401,
        );
      }
      throw _error(e, 'GET');
    }
  }

  ApiError _error(DioException e, String method) {
    if (e.response?.data is Map) {
      final data = jsonObject(e.response!.data);
      final fields = <String, List<String>>{};
      if (data['field_errors'] is Map) {
        for (final entry in (data['field_errors'] as Map).entries) {
          if (entry.value is List) {
            fields[entry.key.toString()] = (entry.value as List)
                .whereType<String>()
                .toList();
          }
        }
      }
      return ApiError(
        data['code'] as String? ?? 'REQUEST_FAILED',
        data['message'] as String? ?? 'Permintaan gagal.',
        fieldErrors: fields,
        status: e.response?.statusCode,
      );
    }
    if (e.type == DioExceptionType.cancel) {
      return const ApiError('CANCELLED', 'Permintaan dibatalkan.');
    }
    return ApiError(
      method == 'GET' ? 'NETWORK_UNAVAILABLE' : 'NETWORK_UNCERTAIN',
      method == 'GET'
          ? 'Jaringan belum tersedia. Tiket tersimpan tetap dapat dibuka.'
          : 'Respons belum diterima. Periksa status atau coba kembali dengan permintaan yang sama.',
    );
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    sessions.removeListener(_changed);
    _scope.cancel();
    dio.close(force: true);
  }
}
