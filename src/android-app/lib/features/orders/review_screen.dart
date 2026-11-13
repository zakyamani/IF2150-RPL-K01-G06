import 'package:flutter/material.dart';

import '../../app_services.dart';
import '../../core/widgets/action_button.dart';
import '../../core/widgets/screen_helpers.dart';
import 'review_controller.dart';

class ReviewScreen extends StatefulWidget {
  final AppServices services;
  final String orderId;
  const ReviewScreen({
    super.key,
    required this.services,
    required this.orderId,
  });
  @override
  State<ReviewScreen> createState() => _ReviewState();
}

class _ReviewState extends State<ReviewScreen> {
  late final c = ReviewController(widget.services, widget.orderId);
  final comment = TextEditingController();
  @override
  void dispose() {
    c.dispose();
    comment.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Ulas paket')),
    body: SafeArea(
      child: ListenableBuilder(
        listenable: c,
        builder: (context, _) => ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text(
              'Bagaimana paket Anda?',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const Notice(
              'Ulasan tersedia setelah pengambilan selesai. Satu ulasan untuk setiap pesanan.',
            ),
            Wrap(
              children: List.generate(
                5,
                (i) => IconButton(
                  tooltip: '${i + 1} bintang',
                  onPressed: c.busy || c.submitted
                      ? null
                      : () => setState(() => c.rating = i + 1),
                  icon: Icon(
                    i < c.rating
                        ? Icons.star_rounded
                        : Icons.star_outline_rounded,
                    color: const Color(0xFFB66600),
                    size: 36,
                  ),
                ),
              ),
            ),
            if (c.fields['rating'] != null)
              Notice(c.fields['rating']!.join('\n'), warning: true),
            const SizedBox(height: 20),
            TextField(
              controller: comment,
              enabled: !c.busy && !c.submitted,
              maxLines: 5,
              maxLength: 1000,
              decoration: const InputDecoration(
                labelText: 'Ceritakan pengalaman (opsional)',
              ),
              onChanged: (v) => c.comment = v,
            ),
            if (c.error != null) Notice(c.error!, warning: true),
            if (c.submitted)
              Notice(
                c.duplicate
                    ? 'Ulasan pesanan ini sudah tersimpan. Sinkronkan pesanan untuk melihat status terbaru.'
                    : 'Ulasan berhasil disimpan.',
              ),
            ActionButton(
              label: c.submitted ? 'Kembali ke pesanan' : 'Kirim ulasan',
              busy: c.busy,
              onPressed: c.submitted
                  ? () => Navigator.pop(context, true)
                  : () async {
                      if (await c.submit() && mounted) {
                        setState(() {});
                      }
                    },
            ),
          ],
        ),
      ),
    ),
  );
}
