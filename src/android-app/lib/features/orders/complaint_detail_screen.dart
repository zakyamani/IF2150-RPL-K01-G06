import 'package:flutter/material.dart';

import '../../app_services.dart';
import '../../core/models/user.dart';
import '../../core/widgets/async_content.dart';
import '../../core/widgets/action_button.dart';
import '../../core/widgets/formatters.dart';
import '../../core/widgets/status_badge.dart';
import '../../core/widgets/screen_helpers.dart';
import '../../core/widgets/private_photo.dart';
import 'complaint_controller.dart';

class ComplaintDetailScreen extends StatefulWidget {
  final AppServices services;
  final String id;
  const ComplaintDetailScreen({
    super.key,
    required this.services,
    required this.id,
  });
  @override
  State<ComplaintDetailScreen> createState() => _ComplaintDetailState();
}

class _ComplaintDetailState extends State<ComplaintDetailScreen> {
  late final c = ComplaintDetailController(widget.services, widget.id);
  final response = TextEditingController();
  @override
  void initState() {
    super.initState();
    c.load();
  }

  @override
  void dispose() {
    c.dispose();
    response.dispose();
    super.dispose();
  }

  Future<void> decide(bool approved) async {
    if (!await confirm(
      context,
      title: approved ? 'Setujui refund penuh?' : 'Tolak pengaduan?',
      detail: approved
          ? 'Seluruh harga paket akan dikembalikan secara SIMULASI.'
          : 'Tanggapan wajib diberikan. Status pesanan akan dievaluasi ulang sesuai jadwal pengambilan.',
      action: approved ? 'Setujui refund' : 'Tolak pengaduan',
    )) {
      return;
    }
    await c.decide(approved, response.text);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Pengaduan')),
    body: SafeArea(
      child: ListenableBuilder(
        listenable: c,
        builder: (context, _) => ListView(
          padding: const EdgeInsets.all(20),
          children: [
            AsyncContent(
              busy: c.busy && c.item == null,
              error: c.item == null ? c.error : null,
              onRetry: () => c.load(),
              child: c.item == null
                  ? const SizedBox()
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        StatusBadge(c.item!.status),
                        DetailLine('Alasan', complaintReason(c.item!.reason)),
                        DetailLine('Keterangan', c.item!.description),
                        DetailLine('Diajukan', dateLabel(c.item!.createdAt)),
                        if (c.item!.responseDue != null)
                          DetailLine(
                            'Batas tanggapan toko tutup',
                            dateLabel(c.item!.responseDue!),
                          ),
                        if (c.item!.status == 'open')
                          const Notice(
                            'Dana SIMULASI ditahan. Toko tutup tanpa tanggapan selama 24 jam akan direfund penuh; alasan lain menunggu keputusan penjual.',
                            warning: true,
                          ),
                        ...c.item!.mediaIds.map(
                          (id) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: PrivatePhoto(
                              services: widget.services,
                              id: id,
                            ),
                          ),
                        ),
                        if (c.item!.response != null)
                          DetailLine('Tanggapan penjual', c.item!.response!),
                        if (widget.services.sessions.session?.user.role ==
                                Role.seller &&
                            c.item!.status == 'open') ...[
                          TextField(
                            controller: response,
                            enabled: !c.busy && !c.uncertain,
                            maxLength: 2000,
                            maxLines: 4,
                            decoration: InputDecoration(
                              labelText: 'Tanggapan (minimal 5 karakter)',
                              errorText: c.fields['response']?.join('\n'),
                            ),
                          ),
                          ActionButton(
                            label: 'Setujui refund penuh',
                            busy: c.busy,
                            onPressed: c.uncertain ? null : () => decide(true),
                          ),
                          const SizedBox(height: 12),
                          OutlinedButton(
                            onPressed: c.busy || c.uncertain
                                ? null
                                : () => decide(false),
                            child: const Text('Tolak dengan tanggapan'),
                          ),
                        ],
                        if (c.error != null) Notice(c.error!, warning: true),
                        if (c.uncertain)
                          const Notice(
                            'Keputusan mungkin sudah diproses. Sinkronkan status sebelum mengambil keputusan lain.',
                          ),
                        const SizedBox(height: 20),
                        OutlinedButton.icon(
                          onPressed: c.busy ? null : () => c.load(),
                          icon: const Icon(Icons.sync),
                          label: const Text('Sinkronkan pengaduan'),
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    ),
  );
}
