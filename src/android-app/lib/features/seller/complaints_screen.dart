import 'package:flutter/material.dart';

import '../../app_services.dart';
import '../../core/controller.dart';
import '../../core/models/complaint.dart';
import '../../core/widgets/async_content.dart';
import '../../core/widgets/status_badge.dart';
import '../../core/widgets/screen_helpers.dart';
import '../orders/complaint_controller.dart';
import '../orders/complaint_detail_screen.dart';

class ComplaintsScreen extends StatefulWidget {
  final AppServices services;
  const ComplaintsScreen({super.key, required this.services});
  @override
  State<ComplaintsScreen> createState() => _ComplaintsState();
}

class _ComplaintsState extends State<ComplaintsScreen> {
  final c = Controller();
  late final repo = ComplaintRepository(widget.services);
  List<Complaint> items = [];
  String? cursor, status;
  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void dispose() {
    c.dispose();
    super.dispose();
  }

  Future<void> load({bool more = false}) => c
      .perform(() async {
        final page = await repo.list(
          cursor: more ? cursor : null,
          status: status,
        );
        if (c.disposed) return;
        items = more ? [...items, ...page.items] : page.items;
        cursor = page.nextCursor;
      })
      .then((_) {});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Daftar pengaduan')),
    body: SafeArea(
      child: ListenableBuilder(
        listenable: c,
        builder: (context, _) => RefreshIndicator(
          onRefresh: load,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              DropdownButtonFormField<String>(
                initialValue: '',
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Status pengaduan',
                ),
                items: ['', 'open', 'approved', 'rejected', 'auto_refunded']
                    .map(
                      (s) => DropdownMenuItem(
                        value: s,
                        child: Text(s.isEmpty ? 'Semua' : statusLabel(s)),
                      ),
                    )
                    .toList(),
                onChanged: c.busy
                    ? null
                    : (s) {
                        status = s!.isEmpty ? null : s;
                        load();
                      },
              ),
              const SizedBox(height: 20),
              AsyncContent(
                busy: c.busy && items.isEmpty,
                error: c.error,
                empty: items.isEmpty,
                onRetry: load,
                emptyTitle: 'Belum ada pengaduan',
                child: Column(
                  children: items
                      .map(
                        (item) => Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          child: ListTile(
                            contentPadding: const EdgeInsets.all(20),
                            title: Text(item.orderCode ?? 'Pengaduan pesanan'),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 8),
                                StatusBadge(item.status),
                                const SizedBox(height: 8),
                                Text(complaintReason(item.reason)),
                              ],
                            ),
                            onTap: () async {
                              await openScreen(
                                context,
                                ComplaintDetailScreen(
                                  services: widget.services,
                                  id: item.id,
                                ),
                              );
                              if (!c.disposed) load();
                            },
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),
              if (cursor != null)
                OutlinedButton(
                  onPressed: c.busy ? null : () => load(more: true),
                  child: const Text('Muat pengaduan lainnya'),
                ),
            ],
          ),
        ),
      ),
    ),
  );
}
