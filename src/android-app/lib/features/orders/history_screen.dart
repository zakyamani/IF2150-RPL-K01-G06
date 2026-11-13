import 'package:flutter/material.dart';

import '../../app_services.dart';
import '../../core/models/order.dart';
import '../../core/widgets/status_badge.dart';
import '../../core/widgets/formatters.dart';
import '../../core/widgets/async_content.dart';
import '../../core/widgets/screen_helpers.dart';
import 'order_controller.dart';
import 'order_repository.dart';
import 'order_detail_screen.dart';

class HistoryScreen extends StatefulWidget {
  final AppServices services;
  const HistoryScreen({super.key, required this.services});
  @override
  State<HistoryScreen> createState() => _HistoryState();
}

class _HistoryState extends State<HistoryScreen> {
  late final c = HistoryController(OrderRepository(widget.services));
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
          DropdownButtonFormField<String>(
            initialValue: '',
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Status pesanan'),
            items: [
              const DropdownMenuItem(value: '', child: Text('Semua status')),
              ...OrderStatus.values.map(
                (s) => DropdownMenuItem(
                  value: s.wire,
                  child: Text(statusLabel(s.wire)),
                ),
              ),
            ],
            onChanged: c.busy ? null : (v) => c.load(status: v),
          ),
          const SizedBox(height: 20),
          AsyncContent(
            busy: c.busy && c.items.isEmpty,
            error: c.error,
            empty: c.items.isEmpty,
            onRetry: () => c.load(),
            emptyTitle: 'Belum ada pesanan',
            emptyMessage: 'Invoice, pengambilan, pembatalan, dan refund Anda akan tampil di sini.',
            child: Column(
              children: c.items
                  .map(
                    (o) => Card(
                      margin: const EdgeInsets.only(bottom: 16),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(20),
                        onTap: () async {
                          await openScreen(
                            context,
                            OrderDetailScreen(
                              services: widget.services,
                              id: o.id,
                            ),
                          );
                          if (!c.disposed) c.load();
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              StatusBadge(o.status.wire),
                              const SizedBox(height: 12),
                              Text(
                                o.code,
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                              Text(categoryLabel(o.category)),
                              Text(rupiah(o.price)),
                              const SizedBox(height: 8),
                              Text('Ambil sebelum ${dateLabel(o.pickupEnd)}'),
                              const SizedBox(height: 8),
                              Text(
                                o.status == OrderStatus.pendingPayment
                                    ? 'Lanjutkan invoice'
                                    : 'Lihat pesanan',
                              ),
                            ],
                          ),
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
              child: const Text('Muat pesanan lainnya'),
            ),
        ],
      ),
    ),
  );
}
