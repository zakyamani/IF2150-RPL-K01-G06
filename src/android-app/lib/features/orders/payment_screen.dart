import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../app_services.dart';
import '../../core/models/order.dart';
import '../../core/widgets/action_button.dart';
import '../../core/widgets/async_content.dart';
import '../../core/widgets/formatters.dart';
import '../../core/widgets/screen_helpers.dart';
import 'order_controller.dart';
import 'order_repository.dart';

class PaymentScreen extends StatefulWidget {
  final AppServices services;
  final String id;
  const PaymentScreen({super.key, required this.services, required this.id});
  @override
  State<PaymentScreen> createState() => _PaymentState();
}

class _PaymentState extends State<PaymentScreen> {
  late final c = OrderController(OrderRepository(widget.services), widget.id);
  @override
  void initState() {
    super.initState();
    c.load();
  }

  @override
  void dispose() {
    c.dispose();
    super.dispose();
  }

  Future<void> pay(String outcome) async {
    if (!await confirm(
      context,
      title: outcome == 'succeeded'
          ? 'Simulasikan pembayaran berhasil?'
          : 'Simulasikan pembayaran gagal?',
      detail: 'Ini demonstrasi. Tidak ada uang nyata yang ditransfer.',
      action: 'Jalankan simulasi',
    )) {
      return;
    }
    final ok = await c.pay(outcome);
    if (ok && mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Pembayaran simulasi')),
    body: SafeArea(
      child: ListenableBuilder(
        listenable: c,
        builder: (context, _) => ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const Notice(
              'SIMULASI — jangan transfer uang atau scan QR ini dengan aplikasi bank.',
              warning: true,
            ),
            AsyncContent(
              busy: c.busy && c.order == null,
              error: c.order == null ? c.error : null,
              onRetry: () => c.load(),
              child: c.order == null
                  ? const SizedBox()
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          rupiah(c.order!.price),
                          style: Theme.of(context).textTheme.headlineLarge,
                        ),
                        DetailLine('Invoice', c.order!.invoice),
                        DetailLine(
                          'Batas pembayaran',
                          dateLabel(c.order!.paymentDeadline),
                        ),
                        if (c.order!.status == OrderStatus.pendingPayment) ...[
                          Text(
                            c.paymentRemaining <= Duration.zero
                                ? 'Invoice berakhir'
                                : 'Sisa waktu ${c.paymentRemaining.inMinutes}:${(c.paymentRemaining.inSeconds % 60).toString().padLeft(2, '0')}',
                          ),
                          const SizedBox(height: 20),
                          Center(
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 240),
                              child: AspectRatio(
                                aspectRatio: 1,
                                child: QrImageView(
                                  data:
                                      'sisarasa:demo-payment:v1:${c.order!.payment?.id}',
                                  backgroundColor: Colors.white,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                          if (c.error != null) Notice(c.error!, warning: true),
                          ActionButton(
                            label: 'Simulasikan berhasil',
                            busy: c.busy,
                            onPressed:
                                c.offline ||
                                    !c.order!.allowedActions.contains('pay') ||
                                    c.paymentRemaining <= Duration.zero
                                ? null
                                : () => pay('succeeded'),
                          ),
                          const SizedBox(height: 12),
                          OutlinedButton(
                            onPressed:
                                c.busy ||
                                    c.offline ||
                                    c.paymentRemaining <= Duration.zero
                                ? null
                                : () => pay('failed'),
                            child: const Text('Simulasikan gagal'),
                          ),
                          const SizedBox(height: 12),
                          TextButton(
                            onPressed: c.busy ? null : () => c.load(),
                            child: const Text('Periksa status pembayaran'),
                          ),
                        ] else ...[
                          const Notice(
                            'Status pembayaran sudah berubah. Kembali ke pesanan untuk melihat hasil terbaru.',
                          ),
                          ActionButton(
                            label: 'Kembali ke pesanan',
                            onPressed: () => Navigator.pop(context, true),
                          ),
                        ],
                      ],
                    ),
            ),
          ],
        ),
      ),
    ),
  );
}
