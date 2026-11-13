import '../seller/complaints_screen.dart';

import 'package:flutter/material.dart';

import '../../app_services.dart';
import '../../core/config/app_config.dart';
import '../../core/widgets/screen_helpers.dart';
import '../auth/auth_controller.dart';
import '../buyer/allergen_screen.dart';
import 'server_settings_screen.dart';

class AccountScreen extends StatelessWidget {
  final AppServices services;
  final bool embedded;
  const AccountScreen({
    super.key,
    required this.services,
    this.embedded = false,
  });
  @override
  Widget build(BuildContext context) {
    final user = services.sessions.session!.user;
    return ListView(
      shrinkWrap: embedded,
      physics: embedded ? const NeverScrollableScrollPhysics() : null,
      padding: const EdgeInsets.all(24),
      children: [
        Text(user.name, style: Theme.of(context).textTheme.headlineMedium),
        DetailLine('Email', user.email),
        DetailLine(
          'Peran',
          user.role.name == 'buyer' ? 'Pembeli' : 'Mitra penjual',
        ),
        if (user.role.name == 'buyer')
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.tune),
            title: const Text('Filter alergen'),
            onTap: () =>
                openScreen(context, AllergenScreen(services: services)),
          ),
        if (AppConfig.developerSettings)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.dns_outlined),
            title: const Text('Alamat server'),
            subtitle: Text(services.sessions.origin),
            onTap: () =>
                openScreen(context, ServerSettingsScreen(services: services)),
          ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.report_problem_outlined),
          title: const Text('Riwayat pengaduan'),
          onTap: () =>
              openScreen(context, ComplaintsScreen(services: services)),
        ),
        const Notice(
          'Pembayaran dan pencairan adalah SIMULASI. Tiket tersimpan tetap dapat dibuka tanpa internet.',
        ),
        const SizedBox(height: 24),
        OutlinedButton.icon(
          onPressed: () async {
            if (await confirm(
              context,
              title: 'Keluar dari akun?',
              detail: 'Sesi dan tiket offline akan dihapus dari perangkat.',
              action: 'Keluar',
            )) {
              final c = AuthController(services);
              await c.logout();
              c.dispose();
            }
          },
          icon: const Icon(Icons.logout),
          label: const Text('Keluar'),
        ),
      ],
    );
  }
}
