import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app_services.dart';
import '../../core/widgets/action_button.dart';
import '../../core/widgets/screen_helpers.dart';
import 'scan_controller.dart';

class OtpScreen extends StatefulWidget {
  final AppServices services;
  final String? orderId;
  const OtpScreen({super.key, required this.services, this.orderId});
  @override
  State<OtpScreen> createState() => _OtpState();
}

class _OtpState extends State<OtpScreen> {
  late final c = ScanController(widget.services);
  late final order = TextEditingController(text: widget.orderId);
  final otp = TextEditingController();
  @override
  void dispose() {
    c.dispose();
    order.dispose();
    otp.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Validasi OTP')),
    body: SafeArea(
      child: ListenableBuilder(
        listenable: c,
        builder: (context, _) => ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const Notice(
              'Konfirmasi setelah paket siap diserahkan. Validasi berhasil menyelesaikan pesanan dan tidak dapat dibatalkan.',
            ),
            TextField(
              controller: order,
              enabled: !c.busy,
              autocorrect: false,
              decoration: InputDecoration(
                labelText: 'Kode pesanan',
                hintText: 'SR-…',
                errorText: c.fields['order_id']?.join('\n'),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: otp,
              enabled: !c.busy,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(6),
              ],
              decoration: InputDecoration(
                labelText: 'OTP 6 digit',
                errorText: c.fields['otp']?.join('\n'),
              ),
            ),
            const Notice(
              'OTP salah dibatasi lima percobaan dalam 15 menit. Periksa kode bersama pembeli.',
            ),
            if (c.error != null) Notice(c.error!, warning: true),
            const SizedBox(height: 20),
            ActionButton(
              label: 'Konfirmasi pengambilan',
              busy: c.busy,
              onPressed: () async {
                if (!await confirm(
                  context,
                  title: 'Serahkan paket?',
                  detail: 'Pastikan paket dan pesanan sesuai. OTP akan divalidasi secara online.',
                  action: 'Validasi OTP',
                )) {
                  return;
                }
                if (await c.otp(order.text, otp.text) && context.mounted) {
                  Navigator.pop(context, c.result);
                }
              },
            ),
          ],
        ),
      ),
    ),
  );
}
