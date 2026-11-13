import '../../core/storage/session_store.dart';

import 'package:flutter/material.dart';

import '../../app_services.dart';
import '../../core/config/app_config.dart';
import '../../core/widgets/action_button.dart';
import '../../core/widgets/screen_helpers.dart';

class ServerSettingsScreen extends StatefulWidget {
  final AppServices services;
  const ServerSettingsScreen({super.key, required this.services});
  @override
  State<ServerSettingsScreen> createState() => _ServerSettingsState();
}

class _ServerSettingsState extends State<ServerSettingsScreen> {
  late final url = TextEditingController(text: widget.services.sessions.origin);
  bool busy = false;
  String? error;
  @override
  void dispose() {
    url.dispose();
    super.dispose();
  }

  Future<void> save() async {
    try {
      final next = SessionStore.normalizeOrigin(
        url.text,
        allowHttp: widget.services.sessions.allowHttp,
      );
      if (next == widget.services.sessions.origin) {
        Navigator.pop(context);
        return;
      }
    } on FormatException catch (e) {
      setState(() => error = e.message);
      return;
    }
    if (widget.services.sessions.session != null &&
        !await confirm(
          context,
          title: 'Ganti server?',
          detail: 'Anda akan keluar. Tiket offline dan sesi lama akan dihapus.',
          action: 'Ganti server',
        )) {
      return;
    }
    if (!mounted) return;
    setState(() => busy = true);
    try {
      await widget.services.sessions.changeOrigin(url.text);
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) {
        setState(
          () => error = 'URL belum tersimpan. Periksa penyimpanan perangkat.',
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => !AppConfig.developerSettings
      ? const Scaffold(
          body: SafeArea(
            child: Center(child: Text('Pengaturan tidak tersedia.')),
          ),
        )
      : Scaffold(
          appBar: AppBar(title: const Text('Alamat server')),
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                const Notice(
                  'Gunakan alamat HTTPS server SisaRasa. Mengganti alamat server menghapus sesi dan tiket offline pada perangkat.',
                ),
                TextField(
                  controller: url,
                  keyboardType: TextInputType.url,
                  autocorrect: false,
                  decoration: InputDecoration(
                    labelText: 'URL server',
                    hintText: 'https://….trycloudflare.com',
                    errorText: error,
                  ),
                ),
                const SizedBox(height: 20),
                ActionButton(
                  label: 'Simpan alamat',
                  busy: busy,
                  onPressed: save,
                ),
              ],
            ),
          ),
        );
}
