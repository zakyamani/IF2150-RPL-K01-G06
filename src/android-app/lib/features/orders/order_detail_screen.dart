import 'order_actions.dart';

import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../app_services.dart';
import '../../core/models/order.dart';
import '../../core/widgets/async_content.dart';
import '../../core/widgets/action_button.dart';
import '../../core/widgets/status_badge.dart';
import '../../core/widgets/formatters.dart';
import '../../core/widgets/screen_helpers.dart';
import '../../core/widgets/private_photo.dart';
import 'order_controller.dart';
import 'order_repository.dart';
import 'payment_screen.dart';

class OrderDetailScreen extends StatefulWidget {
  final AppServices services;
  final String id;
  const OrderDetailScreen({
    super.key,
    required this.services,
    required this.id,
  });
  @override
  State<OrderDetailScreen> createState() => _OrderDetailState();
}

class _OrderDetailState extends State<OrderDetailScreen> {
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

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Pesanan')),
    body: SafeArea(
      child: ListenableBuilder(
        listenable: c,
        builder: (context, _) => RefreshIndicator(
          onRefresh: () async {
            await c.load();
          },
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              AsyncContent(
                busy: c.busy && c.order == null,
                error: c.order == null ? c.error : null,
                onRetry: () => c.load(),
                child: c.order == null ? const SizedBox() : detail(c.order!),
              ),
            ],
          ),
        ),
      ),
    ),
  );
  Widget detail(Order o) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      StatusBadge(o.status.wire),
      const SizedBox(height: 16),
      if (o.merchant != null) ...[
        Text(
          o.merchant!.name,
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        Text(o.merchant!.address),
        DetailLine(
          'Jadwal pengambilan',
          '${dateLabel(o.pickupStart)} – ${dateLabel(o.pickupEnd)}',
        ),
      ],
      if (o.pickup != null && o.status == OrderStatus.paid) ...[
        const Divider(height: 32),
        Text(
          'Tiket pengambilan',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        if (c.ticketExpired)
          const Notice(
            'Jadwal pengambilan telah berakhir. QR/OTP ini bukan bukti bahwa pesanan masih dapat diambil.',
            warning: true,
          )
        else
          const Notice(
            'Tunjukkan QR atau OTP kepada penjual dalam jadwal pengambilan.',
          ),
        const SizedBox(height: 12),
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 232),
            child: AspectRatio(
              aspectRatio: 1,
              child: QrImageView(
                data: o.pickup!.qr,
                backgroundColor: Colors.white,
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        const Text('OTP 6 digit'),
        SelectableText(
          o.pickup!.otp,
          style: Theme.of(context).textTheme.headlineLarge,
        ),
        const Notice('Jangan bagikan tiket atau OTP kepada pihak lain.'),
      ],
      SelectableText(o.code, style: Theme.of(context).textTheme.headlineMedium),
      Text(
        categoryLabel(o.category),
        style: Theme.of(context).textTheme.titleLarge,
      ),
      DetailLine('Ambil mulai', dateLabel(o.pickupStart)),
      DetailLine('Batas pengambilan', dateLabel(o.pickupEnd)),
      DetailLine('Batas konsumsi', dateLabel(o.safeEatUntil)),
      if (c.offline)
        Notice(
          'OFFLINE · terakhir disinkronkan ${dateLabel(c.syncedAt!)}. Status dapat berubah. Validasi oleh penjual tetap memerlukan internet.',
          warning: true,
        ),
      if (!c.repo.cacheAvailable)
        const Notice(
          'Tiket belum dapat disimpan offline. Periksa penyimpanan perangkat dan sinkronkan ulang.',
          warning: true,
        ),
      if (c.error != null) Notice(c.error!, warning: true),
      if (o.status == OrderStatus.pendingPayment) ...[
        const Notice('Identitas toko dibuka setelah pembayaran berhasil.'),
        DetailLine('Batas pembayaran', dateLabel(o.paymentDeadline)),
        if (o.allowedActions.contains('pay'))
          ActionButton(
            label: 'Lanjutkan pembayaran simulasi',
            onPressed: c.busy
                ? null
                : () async {
                    await openScreen(
                      context,
                      PaymentScreen(services: widget.services, id: o.id),
                    );
                    if (mounted) c.load();
                  },
          ),
      ],
      if (o.merchant?.photoId != null && !c.offline)
        PrivatePhoto(services: widget.services, id: o.merchant!.photoId!),
      const Divider(height: 32),
      DetailLine(
        'Alergen',
        o.allergens.isEmpty ? 'Tidak dilaporkan' : o.allergens.join(', '),
      ),
      const Notice(allergenDisclaimer, warning: true),
      OrderActions(
        services: widget.services,
        order: o,
        offline: c.offline,
        serverNow: c.serverNow,
        onChanged: () => c.load(),
      ),
      Text('Riwayat status', style: Theme.of(context).textTheme.titleLarge),
      ...o.history.map(
        (e) => DetailLine(eventLabel(e.action), dateLabel(e.at)),
      ),
      const SizedBox(height: 16),
      OutlinedButton.icon(
        onPressed: c.busy ? null : () => c.load(),
        icon: const Icon(Icons.sync),
        label: const Text('Sinkronkan status'),
      ),
      const Notice('Pembayaran, refund, fee, dan pencairan adalah SIMULASI.'),
    ],
  );
}

String eventLabel(String type) => switch (type) {
  'order.checkout' || 'order.created' => 'Invoice dibuat',
  'payment.succeeded' => 'Pembayaran berhasil',
  'payment.failed' => 'Pembayaran gagal',
  'order.expired' => 'Invoice kedaluwarsa',
  'pickup.completed' => 'Paket diambil',
  'order.no_show' => 'Jadwal terlewat',
  'complaint.opened' => 'Pengaduan dibuat',
  'complaint.approved' => 'Pengaduan disetujui',
  'complaint.rejected' => 'Pengaduan ditolak',
  'order.refunded' => 'Dana dikembalikan',
  'payout.settled' => 'Pencairan simulasi selesai',
  _ => type.replaceAll('.', ' · '),
};
