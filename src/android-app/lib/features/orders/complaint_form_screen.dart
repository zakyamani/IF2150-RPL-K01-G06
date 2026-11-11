import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../app_services.dart';
import '../../core/api/api_error.dart';
import '../../core/models/order.dart';
import '../../core/widgets/action_button.dart';
import '../../core/widgets/private_photo.dart';
import '../../core/widgets/screen_helpers.dart';
import '../../core/widgets/formatters.dart';
import '../seller/seller_repository.dart';
import 'complaint_controller.dart';

class ComplaintFormScreen extends StatefulWidget {
  final AppServices services;
  final Order order;
  final DateTime? serverNow;
  const ComplaintFormScreen({
    super.key,
    required this.services,
    required this.order,
    this.serverNow,
  });
  @override
  State<ComplaintFormScreen> createState() => _ComplaintFormState();
}

class _ComplaintFormState extends State<ComplaintFormScreen> {
  late final c = ComplaintFormController(
    widget.services,
    widget.order,
    serverNow: widget.serverNow,
  );
  final description = TextEditingController();
  final images = <String, Uint8List>{};
  bool uploading = false;
  String? imageError;
  @override
  void initState() {
    super.initState();
    c.ready.then((_) {
      if (mounted) {
        description.text = c.description;
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    c.dispose();
    description.dispose();
    super.dispose();
  }

  Future<void> image() async {
    if (c.mediaIds.length >= 2) return;
    setState(() => uploading = true);
    try {
      final chosen = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 1280,
        maxHeight: 1280,
        imageQuality: 85,
      );
      if (chosen == null) return;
      final bytes = await chosen.readAsBytes();
      final id = await SellerRepository(widget.services)
          .upload(bytes, 'evidence');
      if (mounted) {
        setState(() {
          images[id] = bytes;
          c.mediaIds.add(id);
          imageError = null;
        });
      }
    } on ApiError catch (e) {
      if (mounted) setState(() => imageError = e.message);
    } catch (_) {
      if (mounted) {
        setState(
          () => imageError = 'Foto belum dapat ditambahkan. Anda dapat mengajukan pengaduan tanpa foto.',
        );
      }
    } finally {
      if (mounted) setState(() => uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Ajukan pengaduan')),
    body: SafeArea(
      child: ListenableBuilder(
        listenable: c,
        builder: (context, _) => ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              widget.order.code,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            DetailLine('Batas pengaduan', dateLabel(widget.order.pickupEnd)),
            const Notice(
              'Ajukan sebelum pickup selesai dan batas pengambilan. Dana simulasi ditahan selama pengaduan terbuka.',
            ),
            DropdownButtonFormField<String>(
              key: ValueKey(c.reason),
              initialValue: c.reason,
              isExpanded: true,
              isDense: false,
              itemHeight: null,
              decoration: InputDecoration(
                labelText: 'Alasan',
                errorText: c.fields['reason']?.join('\n'),
              ),
              items: ['unfit', 'unavailable', 'allergen', 'store_closed']
                  .map(
                    (r) => DropdownMenuItem(
                      value: r,
                      child: Text(complaintReason(r)),
                    ),
                  )
                  .toList(),
              onChanged: c.busy || c.uncertain
                  ? null
                  : (r) => setState(() => c.reason = r!),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: description,
              enabled: !c.busy && !c.uncertain,
              maxLines: 5,
              maxLength: 2000,
              decoration: InputDecoration(
                labelText: 'Kondisi paket / gerai',
                helperText: 'Minimal 10 karakter',
                errorText: c.fields['description']?.join('\n'),
              ),
              onChanged: (value) => c.description = value,
            ),
            if (c.reason == 'store_closed')
              const Notice(
                'Toko tutup tanpa tanggapan penjual selama 24 jam akan memicu refund penuh SIMULASI. Alasan lain menunggu keputusan penjual.',
              ),
            const SizedBox(height: 12),
            Text(
              'Foto bukti (${c.mediaIds.length}/2)',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: List.generate(
                c.mediaIds.length,
                (i) => SizedBox(
                  width: 120,
                  child: Column(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: images[c.mediaIds[i]] == null
                            ? PrivatePhoto(
                                services: widget.services,
                                id: c.mediaIds[i],
                                height: 100,
                              )
                            : Image.memory(
                                images[c.mediaIds[i]]!,
                                height: 100,
                                width: 120,
                                fit: BoxFit.cover,
                              ),
                      ),
                      TextButton(
                        onPressed: c.busy || c.uncertain
                            ? null
                            : () => setState(() {
                                images.remove(c.mediaIds[i]);
                                c.mediaIds.removeAt(i);
                              }),
                        child: const Text('Hapus foto'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (imageError != null) Notice(imageError!, warning: true),
            OutlinedButton.icon(
              onPressed:
                  c.busy || c.uncertain || uploading || c.mediaIds.length >= 2
                  ? null
                  : image,
              icon: const Icon(Icons.add_photo_alternate_outlined),
              label: Text(
                uploading ? 'Menambahkan foto…' : 'Tambahkan foto (opsional)',
              ),
            ),
            if (c.fields['order'] != null)
              Notice(c.fields['order']!.join('\n'), warning: true),
            if (c.error != null) Notice(c.error!, warning: true),
            if (c.uncertain)
              const Notice(
                'Respons belum pasti. Data permintaan dikunci untuk mencegah pengaduan ganda. Kirim ulang data yang sama atau kembali dan sinkronkan pesanan.',
              ),
            const SizedBox(height: 20),
            ActionButton(
              label: c.uncertain
                  ? 'Pulihkan pengaduan yang sama'
                  : 'Kirim pengaduan',
              busy: c.busy,
              onPressed: uploading
                  ? null
                  : () async {
                      if (!await confirm(
                        context,
                        title: 'Kirim pengaduan?',
                        detail: 'Dana simulasi akan ditahan hingga pengaduan selesai.',
                        action: 'Kirim pengaduan',
                      )) {
                        return;
                      }
                      if (await c.submit() && context.mounted) {
                        Navigator.pop(context, c.result);
                      }
                    },
            ),
          ],
        ),
      ),
    ),
  );
}
