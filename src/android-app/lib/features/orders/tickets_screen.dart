import 'package:flutter/material.dart';

import '../../app_services.dart';
import '../../core/storage/ticket_cache.dart';
import '../../core/widgets/async_content.dart';
import '../../core/widgets/formatters.dart';
import '../../core/widgets/screen_helpers.dart';
import 'order_repository.dart';
import 'order_detail_screen.dart';

class TicketsScreen extends StatefulWidget {
  final AppServices services;
  const TicketsScreen({super.key, required this.services});
  @override
  State<TicketsScreen> createState() => _TicketsState();
}

class _TicketsState extends State<TicketsScreen> {
  List<CachedTicket> items = [];
  bool busy = true;
  String? error, cursor;
  int generation = 0;
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load({bool more = false}) async {
    final version = ++generation;
    final actor = widget.services.sessions.session?.user.id;
    if (actor == null) return;
    setState(() => busy = true);
    if (!more) {
      final cached = await widget.services.tickets.list(actor);
      if (mounted && version == generation) setState(() => items = cached);
    }
    try {
      final repo = OrderRepository(widget.services);
      final page = await repo.history(
        status: 'paid',
        cursor: more ? cursor : null,
      );
      final ids = {
        ...items.map((entry) => entry.order.id),
        ...page.items.map((o) => o.id),
      };
      for (final id in ids) {
        if (!mounted ||
            version != generation ||
            actor != widget.services.sessions.session?.user.id) {
          return;
        }
        await repo.order(id);
      }
      final cached = await widget.services.tickets.list(actor);
      if (mounted && version == generation) {
        setState(() {
          items = cached;
          cursor = page.nextCursor;
          error = repo.cacheAvailable ? null : 'Sebagian tiket belum tersimpan offline. Periksa penyimpanan perangkat.';
        });
      }
    } catch (_) {
      if (mounted && version == generation) {
        setState(
          () => error = 'Sinkronisasi belum tersedia. Tiket tersimpan ditampilkan dengan status terakhir.',
        );
      }
    } finally {
      if (mounted && version == generation) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => RefreshIndicator(
    onRefresh: () => load(),
    child: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          'Tiket tersimpan',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const Notice(
          'Tiket dapat dibuka offline. Konfirmasi pengambilan oleh penjual tetap memerlukan internet.',
        ),
        if (error != null) Notice(error!, warning: true),
        AsyncContent(
          busy: busy && items.isEmpty,
          empty: items.isEmpty,
          emptyTitle: 'Belum ada tiket',
          emptyMessage: 'Bayar paket, lalu buka pesanan saat online untuk menyimpan QR dan OTP.',
          child: Column(
            children: items
                .map(
                  (entry) => Card(
                    margin: const EdgeInsets.only(bottom: 16),
                    child: ListTile(
                      contentPadding: const EdgeInsets.all(20),
                      isThreeLine: true,
                      title: Text(entry.order.code),
                      subtitle: Text(
                        '${entry.order.merchant?.name ?? categoryLabel(entry.order.category)}\n${entry.expiredAt(DateTime.now()) ? 'Jadwal berakhir' : 'Ambil sebelum ${dateLabel(entry.order.pickupEnd)}'}\nTerakhir sinkron ${dateLabel(entry.syncedAt)}',
                      ),
                      onTap: () async {
                        await openScreen(
                          context,
                          OrderDetailScreen(
                            services: widget.services,
                            id: entry.order.id,
                          ),
                        );
                        if (mounted) load();
                      },
                    ),
                  ),
                )
                .toList(),
          ),
        ),
        if (cursor != null)
          OutlinedButton(
            onPressed: busy ? null : () => load(more: true),
            child: const Text('Sinkronkan tiket lainnya'),
          ),
        OutlinedButton.icon(
          onPressed: busy ? null : () => load(),
          icon: const Icon(Icons.sync),
          label: const Text('Sinkronkan semua status'),
        ),
      ],
    ),
  );
}
