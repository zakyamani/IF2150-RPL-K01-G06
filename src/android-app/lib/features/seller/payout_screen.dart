import 'package:flutter/material.dart';

import '../../app_services.dart';
import '../../core/widgets/async_content.dart';
import '../../core/widgets/formatters.dart';
import '../../core/widgets/status_badge.dart';
import '../../core/widgets/screen_helpers.dart';
import 'payout_controller.dart';

class PayoutScreen extends StatefulWidget {
  final AppServices services;
  const PayoutScreen({super.key, required this.services});
  @override
  State<PayoutScreen> createState() => _PayoutState();
}

class _PayoutState extends State<PayoutScreen> {
  late final c = PayoutController(widget.services);
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
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: c,
    builder: (context, _) => RefreshIndicator(
      onRefresh: () async {
        await c.load();
      },
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'Keuangan simulasi',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const Notice(
            'SIMULASI — tidak ada pencairan uang atau transfer bank nyata. Fee disimpan saat checkout; payout dijadwalkan satu jam setelah pengambilan selesai atau no-show.',
            warning: true,
          ),
          if (c.summary != null)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    DetailLine('Menunggu', rupiah(c.summary!.pending)),
                    DetailLine('Ditahan', rupiah(c.summary!.held)),
                    DetailLine('Selesai', rupiah(c.summary!.settled)),
                    DetailLine('Dibatalkan', rupiah(c.summary!.cancelled)),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 20),
          DropdownButtonFormField<String>(
            initialValue: '',
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Status payout'),
            items: ['', 'pending', 'held', 'settled', 'cancelled']
                .map(
                  (s) => DropdownMenuItem(
                    value: s,
                    child: Text(s.isEmpty ? 'Semua status' : statusLabel(s)),
                  ),
                )
                .toList(),
            onChanged: c.busy ? null : (s) => c.load(status: s),
          ),
          const SizedBox(height: 20),
          AsyncContent(
            busy: c.busy && c.items.isEmpty,
            error: c.error,
            empty: c.items.isEmpty,
            onRetry: () => c.load(),
            emptyTitle: 'Belum ada payout',
            emptyMessage: 'Payout muncul setelah pickup/no-show atau saat dana perlu ditahan karena pengaduan.',
            child: Column(
              children: c.items
                  .map(
                    (p) => Card(
                      margin: const EdgeInsets.only(bottom: 16),
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            StatusBadge(p.status),
                            const SizedBox(height: 12),
                            Text(
                              p.orderCode,
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            DetailLine('Harga paket (gross)', rupiah(p.gross)),
                            DetailLine('Fee simulasi', rupiah(p.fee)),
                            DetailLine('Dana bersih (net)', rupiah(p.net)),
                            if (p.status == 'held')
                              const Notice(
                                'Dana ditahan selama pengaduan. Jadwal akan dievaluasi setelah keputusan.',
                              ),
                            if (p.status == 'pending')
                              DetailLine('Jadwal payout', dateLabel(p.dueAt)),
                            if (p.settledAt != null)
                              DetailLine(
                                'Diselesaikan',
                                dateLabel(p.settledAt!),
                              ),
                            if (p.status == 'cancelled')
                              const Text(
                                'Payout dibatalkan; lihat status refund pada pesanan.',
                              ),
                            const Text('SIMULASI'),
                          ],
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
          if (c.cursor != null)
            OutlinedButton(
              onPressed: c.busy ? null : () => c.load(more: true),
              child: const Text('Muat payout lainnya'),
            ),
        ],
      ),
    ),
  );
}
