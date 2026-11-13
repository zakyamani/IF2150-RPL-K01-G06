import 'package:flutter/material.dart';

import '../../app_services.dart';
import '../../core/models/offer.dart';
import '../../core/widgets/action_button.dart';
import '../../core/widgets/formatters.dart';
import '../../core/widgets/screen_helpers.dart';
import 'order_controller.dart';
import 'order_detail_screen.dart';

class CheckoutScreen extends StatefulWidget {
  final AppServices services;
  final Offer offer;
  const CheckoutScreen({
    super.key,
    required this.services,
    required this.offer,
  });
  @override
  State<CheckoutScreen> createState() => _CheckoutState();
}

class _CheckoutState extends State<CheckoutScreen> {
  late final c = CheckoutController(widget.services, widget.offer.id);
  @override
  void initState() {
    super.initState();
    c.restore();
  }

  @override
  void dispose() {
    c.dispose();
    super.dispose();
  }

  Future<void> checkout() async {
    if (await c.checkout() && mounted) {
      await openScreen(
        context,
        OrderDetailScreen(services: widget.services, id: c.result!.orderId),
      );
      if (mounted) c.restore();
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Checkout')),
    body: SafeArea(
      child: ListenableBuilder(
        listenable: c,
        builder: (context, _) => ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text(
              'Satu paket untuk diselamatkan',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            DetailLine('Paket', categoryLabel(widget.offer.category)),
            DetailLine('Jumlah', '1 paket'),
            DetailLine('Total pembayaran', rupiah(widget.offer.discountPrice)),
            DetailLine('Ambil mulai', dateLabel(widget.offer.pickupStart)),
            DetailLine('Batas pengambilan', dateLabel(widget.offer.pickupEnd)),
            const Notice(
              'Identitas toko dan alamat lengkap dibuka setelah pembayaran berhasil.',
            ),
            const Notice(allergenDisclaimer, warning: true),
            const Notice(
              'Pembayaran SIMULASI. Invoice berlaku paling lama 15 menit dan dapat berakhir lebih awal pada batas pengambilan.',
            ),
            if (c.error != null) Notice(c.error!, warning: true),
            if (c.result != null)
              Notice(
                'Checkout sebelumnya: ${c.result!.code}. Tombol di bawah membuka pesanan yang sama.',
              ),
            const SizedBox(height: 20),
            ActionButton(
              label: c.result == null
                  ? 'Buat invoice simulasi'
                  : 'Buka pesanan sebelumnya',
              busy: c.busy,
              onPressed: checkout,
            ),
            if (c.result != null)
              TextButton(
                onPressed: c.busy
                    ? null
                    : () async {
                        if (await confirm(
                          context,
                          title: 'Pesan paket tambahan?',
                          detail: 'Ini membuat pembelian terpisah. Invoice sebelumnya harus sudah selesai.',
                          action: 'Siapkan checkout baru',
                        )) {
                          await c.newAttempt();
                        }
                      },
                child: const Text('Pesan paket tambahan'),
              ),
          ],
        ),
      ),
    ),
  );
}
