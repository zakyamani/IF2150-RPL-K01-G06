import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../app_services.dart';
import '../../core/widgets/action_button.dart';
import '../../core/widgets/screen_helpers.dart';
import 'scan_controller.dart';
import 'otp_screen.dart';

class ScanScreen extends StatefulWidget {
  final AppServices services;
  final String? orderId, cameraError;
  const ScanScreen({
    super.key,
    required this.services,
    this.orderId,
    this.cameraError,
  });
  @override
  State<ScanScreen> createState() => _ScanState();
}

class _ScanState extends State<ScanScreen> {
  late final c = ScanController(widget.services);
  MobileScannerController? camera;
  bool enabled = false, handling = false;
  @override
  void dispose() {
    c.dispose();
    camera?.dispose();
    super.dispose();
  }

  Future<void> detected(BarcodeCapture data) async {
    if (handling || c.busy) return;
    final raw = data.barcodes
        .map((b) => b.rawValue)
        .whereType<String>()
        .firstOrNull;
    if (raw == null) return;
    if (!ScanController.qrPattern.hasMatch(raw)) {
      await c.qr(raw);
      return;
    }
    handling = true;
    await camera?.stop();
    if (!mounted) return;
    if (!await confirm(
      context,
      title: 'Konfirmasi pengambilan?',
      detail: 'Pastikan paket telah siap untuk pembeli. Pemindaian berhasil menyelesaikan pesanan.',
      action: 'Validasi QR',
    )) {
      handling = false;
      if (mounted) await camera?.start();
      return;
    }
    final ok = await c.qr(raw);
    if (!mounted) return;
    if (ok) {
      Navigator.pop(context, c.result);
    } else {
      setState(() => handling = false);
    }
  }

  Widget fallback(String error) => Padding(
    padding: const EdgeInsets.all(20),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.no_photography_outlined, size: 48),
        const SizedBox(height: 16),
        Text(error, textAlign: TextAlign.center),
        const SizedBox(height: 12),
        const Text('Pengambilan tetap bisa dikonfirmasi melalui OTP.'),
      ],
    ),
  );
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Scan tiket pickup')),
    body: SafeArea(
      child: ListenableBuilder(
        listenable: c,
        builder: (context, _) => ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Notice(
              'Scan QR tiket pengambilan pembeli, setelah paket siap diserahkan.',
            ),
            if (widget.cameraError != null)
              fallback(widget.cameraError!)
            else if (!enabled) ...[
              fallback('Kamera hanya digunakan untuk membaca QR pickup.'),
              ActionButton(
                label: 'Aktifkan kamera',
                onPressed: () {
                  setState(() {
                    enabled = true;
                    camera = MobileScannerController(
                      formats: [BarcodeFormat.qrCode],
                    );
                  });
                },
              ),
            ] else
              ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: AspectRatio(
                  aspectRatio: 1,
                  child: MobileScanner(
                    controller: camera,
                    onDetect: detected,
                    errorBuilder: (context, error) => SingleChildScrollView(
                      child: fallback(
                        'Kamera belum tersedia atau izin ditolak. Gunakan OTP.',
                      ),
                    ),
                  ),
                ),
              ),
            if (c.busy)
              const Padding(
                padding: EdgeInsets.all(20),
                child: Center(child: CircularProgressIndicator()),
              ),
            if (c.error != null) ...[
              Notice(c.error!, warning: true),
              OutlinedButton(
                onPressed: c.busy
                    ? null
                    : () async {
                        c.retry();
                        handling = false;
                        await camera?.start();
                      },
                child: const Text('Scan kembali'),
              ),
            ],
            const SizedBox(height: 20),
            ActionButton(
              label: 'Gunakan OTP',
              onPressed: c.busy
                  ? null
                  : () async {
                      await camera?.stop();
                      if (!context.mounted) return;
                      final result = await openScreen<PickupResult>(
                        context,
                        OtpScreen(
                          services: widget.services,
                          orderId: widget.orderId,
                        ),
                      );
                      if (result != null && context.mounted) {
                        Navigator.pop(context, result);
                      } else if (mounted && enabled) {
                        await camera?.start();
                      }
                    },
            ),
          ],
        ),
      ),
    ),
  );
}
