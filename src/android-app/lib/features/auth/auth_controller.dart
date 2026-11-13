import 'dart:convert';

import '../../app_services.dart';
import '../../core/controller.dart';
import '../../core/models/user.dart';

class AuthController extends Controller {
  final AppServices services;
  AuthController(this.services);
  Future<bool> submit({
    required String email,
    required String password,
    String name = '',
    bool registering = false,
    Role role = Role.buyer,
  }) async {
    fields = {};
    error = null;
    if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email.trim())) {
      fields['email'] = ['Masukkan email yang valid.'];
    }
    if (password.isEmpty ||
        utf8.encode(password).length > 72 ||
        (registering && password.length < 12)) {
      fields['password'] = [
        registering
            ? 'Gunakan password 12 karakter atau lebih, maksimal 72 byte.'
            : 'Masukkan password, maksimal 72 byte.',
      ];
    }
    if (registering && (name.trim().length < 2 || name.trim().length > 100)) {
      fields['name'] = ['Nama 2–100 karakter.'];
    }
    if (fields.isNotEmpty) {
      changed();
      return false;
    }
    return perform(() async {
      final epoch = services.sessions.epoch;
      final bundle = await services.api.post(
        registering ? '/auth/register' : '/auth/login',
        {
          'email': email.trim().toLowerCase(),
          'password': password,
          if (registering) 'name': name.trim(),
          if (registering) 'role': role.name,
        },
        SessionBundle.fromJson,
        anonymous: true,
      );
      await services.sessions.save(bundle, expectedEpoch: epoch);
    });
  }

  Future<void> logout() async {
    try {
      await services.api.post<void>('/auth/logout', {}, (_) {});
    } catch (_) {
    } finally {
      await services.sessions.clear();
    }
  }
}
