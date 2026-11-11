import 'package:flutter/material.dart';

import '../../app_services.dart';
import '../../core/widgets/formatters.dart';
import '../../core/widgets/screen_helpers.dart';
import '../orders/order_repository.dart';
import '../orders/order_detail_screen.dart';

class InboxScreen extends StatefulWidget {
  final AppServices services;
  const InboxScreen({super.key, required this.services});
  @override
  State<InboxScreen> createState() => _InboxState();
}

class _InboxState extends State<InboxScreen> {
  @override
  void initState() {
    super.initState();
    if (widget.services.notifications.items.isEmpty) {
      widget.services.notifications.start();
    } else {
      widget.services.notifications.catchUp();
    }
  }

  Future<void> open(int index) async {
    final c = widget.services.notifications;
    final event = c.items[index];
    final actor = widget.services.sessions.session?.user.id,
        epoch = widget.services.sessions.epoch;
    try {
      await OrderRepository(widget.services).order(event.resourceId);
      if (!mounted ||
          actor != widget.services.sessions.session?.user.id ||
          epoch != widget.services.sessions.epoch) {
        return;
      }
      await c.markRead(event);
      if (!mounted) return;
      await openScreen(
        context,
        OrderDetailScreen(services: widget.services, id: event.resourceId),
      );
    } catch (_) {
      if (mounted) {
        message(
          context,
          'Pesanan belum tersedia. Periksa koneksi atau masuk kembali.',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.services.notifications;
    return Scaffold(
      appBar: AppBar(title: const Text('Inbox')),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: c,
          builder: (context, _) => RefreshIndicator(
            onRefresh: () async {
              await c.catchUp();
              await c.history();
            },
            child: ListView.builder(
              padding: const EdgeInsets.all(20),
              itemCount: c.items.length + 2,
              itemBuilder: (context, index) {
                if (index == 0) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Notice(
                        c.connected
                            ? 'Terhubung · pembaruan pesanan diterima saat koneksi aktif.'
                            : 'Sinkronisasi saat aplikasi dibuka. Inbox tersimpan tetap dapat dibaca.',
                      ),
                      if (c.error != null) Notice(c.error!, warning: true),
                      if (c.items.isEmpty)
                        const Padding(
                          padding: EdgeInsets.all(24),
                          child: Text('Belum ada notifikasi pesanan.'),
                        ),
                      if (c.busy)
                        const Center(child: CircularProgressIndicator()),
                    ],
                  );
                }
                if (index == c.items.length + 1) {
                  return c.historyCursor == null
                      ? const SizedBox()
                      : OutlinedButton(
                          onPressed: c.busy
                              ? null
                              : () => c.history(more: true),
                          child: const Text('Muat notifikasi sebelumnya'),
                        );
                }
                final event = c.items[index - 1];
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(20),
                    leading: Icon(
                      event.readAt == null
                          ? Icons.markunread_outlined
                          : Icons.drafts_outlined,
                    ),
                    title: Text(event.summary),
                    subtitle: Text(dateLabel(event.occurredAt)),
                    onTap: () => open(index - 1),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class InboxButton extends StatelessWidget {
  final AppServices services;
  const InboxButton({super.key, required this.services});
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: services.notifications,
    builder: (context, _) => IconButton(
      tooltip: 'Inbox',
      onPressed: () => openScreen(context, InboxScreen(services: services)),
      icon: Badge(
        isLabelVisible: services.notifications.unread > 0,
        label: Text('${services.notifications.unread}'),
        child: const Icon(Icons.notifications_outlined),
      ),
    ),
  );
}
