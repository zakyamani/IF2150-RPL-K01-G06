import 'package:flutter/material.dart' hide Page;

import '../../app_services.dart';
import '../../core/controller.dart';
import '../../core/models/review.dart';
import '../../core/widgets/async_content.dart';
import '../../core/widgets/formatters.dart';

class MerchantReviewsScreen extends StatefulWidget {
  final AppServices services;
  final String merchantId;
  const MerchantReviewsScreen({
    super.key,
    required this.services,
    required this.merchantId,
  });
  @override
  State<MerchantReviewsScreen> createState() => _MerchantReviewsState();
}

class _MerchantReviewsState extends State<MerchantReviewsScreen> {
  final c = Controller();
  List<ReviewEntry> items = [];
  String? cursor;
  num? average;
  int count = 0;
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
        final result = await widget.services.api.get(
          '/reviews/merchant/${widget.merchantId}',
          MerchantReviews.fromJson,
          query: {'cursor': ?more ? cursor : null, 'limit': 20},
        );
        if (c.disposed) return;
        items = more ? [...items, ...result.page.items] : result.page.items;
        cursor = result.page.nextCursor;
        average = result.average;
        count = result.count;
      })
      .then((_) {});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Ulasan gerai')),
    body: SafeArea(
      child: ListenableBuilder(
        listenable: c,
        builder: (context, _) => ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              average == null
                  ? 'Belum ada penilaian'
                  : '${average!.toStringAsFixed(1)} / 5 · $count ulasan',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 20),
            AsyncContent(
              busy: c.busy && items.isEmpty,
              error: c.error,
              empty: items.isEmpty,
              onRetry: load,
              emptyTitle: 'Belum ada ulasan',
              child: Column(
                children: items
                    .map(
                      (j) => Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                j.reviewerName ?? 'Pembeli',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              Text('${j.rating} / 5 bintang'),
                              const SizedBox(height: 8),
                              Text(j.comment),
                              Text(dateLabel(j.createdAt)),
                            ],
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
            if (cursor != null)
              OutlinedButton(
                onPressed: c.busy ? null : () => load(more: true),
                child: const Text('Muat ulasan lainnya'),
              ),
          ],
        ),
      ),
    ),
  );
}
