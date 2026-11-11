import 'package:flutter/material.dart';

import '../../app_services.dart';
import '../../core/widgets/screen_helpers.dart';

class MonitorCard extends StatelessWidget {
  final AppServices services;
  const MonitorCard({super.key, required this.services});
  @override
  Widget build(BuildContext context) {
    final c = services.monitor;
    return ListenableBuilder(
      listenable: c,
      builder: (context, _) => Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Pantau pesanan',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              const Text(
                'Aktifkan notifikasi pemantauan saat Anda siap melayani. Pesanan diperbarui selama terhubung ke internet.',
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  c.active ? 'Pemantauan aktif' : 'Pemantauan nonaktif',
                ),
                value: c.active,
                onChanged: c.busy
                    ? null
                    : (value) async {
                        if (value) {
                          if (await confirm(
                            context,
                            title: 'Aktifkan pemantauan?',
                            detail: 'Android akan menampilkan notifikasi layanan. Pemantauan dapat dihentikan sistem; Android 15+ membatasi layanan ini hingga enam jam. Buka inbox untuk menyinkronkan pesan yang terlewat.',
                            action: 'Aktifkan',
                          )) {
                            await c.start();
                          }
                        } else {
                          await c.stop();
                        }
                      },
              ),
              if (c.error != null) Notice(c.error!, warning: true),
              if (c.busy) const Center(child: CircularProgressIndicator()),
            ],
          ),
        ),
      ),
    );
  }
}
