import 'package:flutter/material.dart';

import '../../app_services.dart';
import '../../core/config/app_config.dart';
import '../../core/widgets/brand_art.dart';
import '../../core/models/user.dart';
import '../../core/widgets/action_button.dart';
import '../../core/widgets/screen_helpers.dart';
import '../settings/server_settings_screen.dart';
import 'auth_controller.dart';

class LoginScreen extends StatefulWidget {
  final AppServices services;
  final bool registering;
  const LoginScreen({
    super.key,
    required this.services,
    this.registering = false,
  });
  @override
  State<LoginScreen> createState() => _LoginState();
}

class _LoginState extends State<LoginScreen> {
  late final c = AuthController(widget.services);
  final email = TextEditingController(),
      password = TextEditingController(),
      name = TextEditingController();
  bool obscure = true;
  Role role = Role.buyer;
  @override
  void dispose() {
    c.dispose();
    email.dispose();
    password.dispose();
    name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const BrandTitle(),
      actions: [
        if (AppConfig.developerSettings)
          IconButton(
            tooltip: 'Alamat server',
            onPressed: () => openScreen(
              context,
              ServerSettingsScreen(services: widget.services),
            ),
            icon: const Icon(Icons.settings_outlined),
          ),
      ],
    ),
    body: SafeArea(
      child: ListenableBuilder(
        listenable: c,
        builder: (context, _) => AutofillGroup(
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              const BagPanel(),
              const SizedBox(height: 24),
              Text(
                widget.registering
                    ? 'Mulai menyelamatkan makanan'
                    : 'Rasa enak.\nNiat baik.',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 12),
              const Text(
                'Temukan paket kejutan dari makanan yang masih layak. Hemat 50–70% sambil mengurangi sisa makanan.',
              ),
              const SizedBox(height: 28),
              if (widget.registering) ...[
                TextField(
                  controller: name,
                  autofillHints: const [AutofillHints.name],
                  decoration: InputDecoration(
                    labelText: 'Nama',
                    errorText: c.fields['name']?.join('\n'),
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<Role>(
                  initialValue: role,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Saya ingin'),
                  items: const [
                    DropdownMenuItem(
                      value: Role.buyer,
                      child: Text('Membeli paket'),
                    ),
                    DropdownMenuItem(
                      value: Role.seller,
                      child: Text('Menjual sebagai mitra'),
                    ),
                  ],
                  onChanged: c.busy ? null : (v) => setState(() => role = v!),
                ),
                const SizedBox(height: 16),
              ],
              TextField(
                key: const Key('auth-email'),
                controller: email,
                autofillHints: const [AutofillHints.email],
                keyboardType: TextInputType.emailAddress,
                autocorrect: false,
                decoration: InputDecoration(
                  labelText: 'Email',
                  errorText: c.fields['email']?.join('\n'),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                key: const Key('auth-password'),
                controller: password,
                obscureText: obscure,
                autofillHints: [
                  widget.registering
                      ? AutofillHints.newPassword
                      : AutofillHints.password,
                ],
                decoration: InputDecoration(
                  labelText: 'Password',
                  helperText: widget.registering ? 'Minimal 12 karakter' : null,
                  errorText: c.fields['password']?.join('\n'),
                  suffixIcon: IconButton(
                    tooltip: obscure
                        ? 'Tampilkan password'
                        : 'Sembunyikan password',
                    onPressed: () => setState(() => obscure = !obscure),
                    icon: Icon(
                      obscure
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              if (c.error != null) Notice(c.error!, warning: true),
              ActionButton(
                key: const Key('auth-submit'),
                label: widget.registering ? 'Buat akun' : 'Masuk',
                busy: c.busy,
                onPressed: () async {
                  final ok = await c.submit(
                    email: email.text,
                    password: password.text,
                    name: name.text,
                    role: role,
                    registering: widget.registering,
                  );
                  if (ok && widget.registering && context.mounted) {
                    Navigator.of(context).popUntil((r) => r.isFirst);
                  }
                },
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: c.busy
                    ? null
                    : () => widget.registering
                          ? Navigator.pop(context)
                          : openScreen(
                              context,
                              LoginScreen(
                                services: widget.services,
                                registering: true,
                              ),
                            ),
                child: Text(
                  widget.registering
                      ? 'Sudah punya akun? Masuk'
                      : 'Belum punya akun? Daftar',
                ),
              ),
              const Notice(
                'Pembayaran dan pencairan pada versi ini adalah SIMULASI. Tidak ada uang nyata yang dipindahkan.',
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
