import 'package:flutter/material.dart';

import '../../app_services.dart';
import '../../core/controller.dart';
import '../../core/models/order.dart';
import '../../core/models/user.dart';
import '../../core/storage/operation_store.dart';
import '../../core/widgets/action_button.dart';
import '../../core/widgets/screen_helpers.dart';
import '../../core/widgets/formatters.dart';
import '../../core/widgets/status_badge.dart';
import '../seller/scan_screen.dart';
import '../seller/otp_screen.dart';
import 'complaint_form_screen.dart';
import 'complaint_detail_screen.dart';
import 'review_screen.dart';
import 'merchant_reviews_screen.dart';

class OrderActions extends StatefulWidget {
  final AppServices services;
  final Order order;
  final bool offline;
  final DateTime serverNow;
  final VoidCallback onChanged;
  const OrderActions({
    super.key,
    required this.services,
    required this.order,
    required this.offline,
    required this.serverNow,
    required this.onChanged,
  });
  @override
  State<OrderActions> createState() => _OrderActionsState();
}

class _OrderActionsState extends State<OrderActions> {
  final c = Controller();
  String? frozenReason;
  @override
  void dispose() {
    c.dispose();
    super.dispose();
  }

  Future<void> cancel() async {
    final restored = await c.perform(() async {
      final body = await OperationStore(widget.services)
          .load('cancel', widget.order.id);
      frozenReason = body?['reason'] as String?;
    });
    if (!restored || !mounted) return;
    final accepted = await showDialog<String>(
      context: context,
      builder: (_) =>
          _CancellationDialog(reason: frozenReason, price: widget.order.price),
    );
    if (accepted == null) return;
    frozenReason = accepted;
    final ok = await c.perform(() async {
      final body = {'reason': accepted};
      await OperationStore(widget.services).run(
        'cancel',
        widget.order.id,
        body,
        (key) => widget.services.api.post(
          '/orders/${widget.order.id}/cancel',
          body,
          (j) => j,
          key: key,
        ),
      );
    });
    if (ok && mounted) widget.onChanged();
  }

  Future<void> open(Widget screen) async {
    await openScreen(context, screen);
    if (mounted) widget.onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final o = widget.order;
    final buyer = widget.services.sessions.session?.user.role == Role.buyer;
    return ListenableBuilder(
      listenable: c,
      builder: (context, _) {
        final online = !widget.offline && !c.busy;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (o.complaint != null) ...[
              Notice(
                'Pengaduan: ${statusLabel(o.complaint!.status)}${o.complaint!.status == 'open' ? '. Dana SIMULASI ditahan.' : '. Lihat keputusan dan tanggapan penjual.'}',
              ),
              OutlinedButton(
                onPressed: online
                    ? () => open(
                        ComplaintDetailScreen(
                          services: widget.services,
                          id: o.complaint!.id,
                        ),
                      )
                    : null,
                child: const Text('Lihat pengaduan'),
              ),
            ],
            if (buyer && o.allowedActions.contains('complain'))
              ActionButton(
                label: 'Ajukan pengaduan',
                onPressed: online
                    ? () => open(
                        ComplaintFormScreen(
                          services: widget.services,
                          order: o,
                          serverNow: widget.serverNow,
                        ),
                      )
                    : null,
              ),
            if (buyer && o.allowedActions.contains('review'))
              ActionButton(
                label: 'Beri ulasan',
                onPressed: online
                    ? () => open(
                        ReviewScreen(services: widget.services, orderId: o.id),
                      )
                    : null,
              ),
            if (!buyer && o.allowedActions.contains('pickup')) ...[
              ActionButton(
                label: 'Scan tiket pickup',
                onPressed: online
                    ? () => open(
                        ScanScreen(services: widget.services, orderId: o.code),
                      )
                    : null,
              ),
              const SizedBox(height: 10),
              OutlinedButton(
                onPressed: online
                    ? () => open(
                        OtpScreen(services: widget.services, orderId: o.code),
                      )
                    : null,
                child: const Text('Validasi melalui OTP'),
              ),
            ],
            if (!buyer && o.allowedActions.contains('cancel')) ...[
              const SizedBox(height: 10),
              OutlinedButton(
                onPressed: online ? cancel : null,
                child: const Text('Batalkan & refund simulasi'),
              ),
            ],
            if (o.merchant != null)
              TextButton.icon(
                onPressed: online
                    ? () => open(
                        MerchantReviewsScreen(
                          services: widget.services,
                          merchantId: o.merchant!.id,
                        ),
                      )
                    : null,
                icon: const Icon(Icons.star_outline),
                label: const Text('Lihat ulasan gerai'),
              ),
            if (c.error != null) ...[
              Notice(c.error!, warning: true),
              const Text(
                'Sinkronkan status pesanan untuk memeriksa hasil permintaan.',
              ),
            ],
            if (c.busy) const Center(child: CircularProgressIndicator()),
            const SizedBox(height: 16),
          ],
        );
      },
    );
  }
}

class _CancellationDialog extends StatefulWidget {
  final String? reason;
  final int price;
  const _CancellationDialog({required this.reason, required this.price});
  @override
  State<_CancellationDialog> createState() => _CancellationDialogState();
}

class _CancellationDialogState extends State<_CancellationDialog> {
  late final input = TextEditingController(
    text: widget.reason ?? 'Gerai tidak dapat menyerahkan paket.',
  );
  @override
  void dispose() {
    input.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Batalkan pesanan?'),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Seluruh ${rupiah(widget.price)} akan direfund secara SIMULASI.',
          ),
          const SizedBox(height: 16),
          TextField(
            controller: input,
            maxLength: 500,
            maxLines: 3,
            enabled: widget.reason == null,
            decoration: const InputDecoration(
              labelText: 'Alasan pembatalan (minimal 5 karakter)',
            ),
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Kembali'),
      ),
      FilledButton(
        onPressed: () {
          if (input.text.trim().length >= 5) {
            Navigator.pop(context, input.text.trim());
          }
        },
        child: const Text('Batalkan & refund'),
      ),
    ],
  );
}
