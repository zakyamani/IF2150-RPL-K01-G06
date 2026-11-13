import 'package:flutter/material.dart';

import '../../app_services.dart';
import '../../core/models/offer.dart';
import '../../core/theme/brand.dart';
import '../../core/widgets/brand_art.dart';
import '../../core/widgets/formatters.dart';
import '../../core/widgets/async_content.dart';
import '../../core/widgets/screen_helpers.dart';
import 'catalog_controller.dart';
import 'allergen_screen.dart';
import 'offer_detail_screen.dart';

class CatalogScreen extends StatefulWidget {
  final AppServices services;
  final void Function(Offer)? onOffer;
  const CatalogScreen({super.key, required this.services, this.onOffer});
  @override
  State<CatalogScreen> createState() => _CatalogState();
}

class _CatalogState extends State<CatalogScreen> {
  late final c = CatalogController(widget.services);
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
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
        children: [
          LayoutBuilder(
            builder: (context, box) {
              final headline = Text(
                'Rasa enak.\nNiat baik.',
                style: Theme.of(context).textTheme.headlineMedium,
              );
              if (box.maxWidth < 310 ||
                  MediaQuery.textScalerOf(context).scale(1) > 1.4) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    headline,
                    const Align(
                      alignment: Alignment.centerRight,
                      child: SurpriseBag(width: 76, height: 100),
                    ),
                  ],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(child: headline),
                  const SizedBox(width: 12),
                  const SurpriseBag(width: 92, height: 122),
                ],
              );
            },
          ),
          const SizedBox(height: 8),
          const Text(
            'Paket kejutan, hemat 50–70%.\nBantu makanan baik menemukan rumah.',
            style: TextStyle(color: Brand.muted),
          ),
          const SizedBox(height: 20),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                categoryChip('Semua', null),
                ...categoryChoices.map(
                  (a) => categoryChip(categoryLabel(a), a),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: () async {
                  final saved = await openScreen<bool>(
                    context,
                    AllergenScreen(services: widget.services),
                  );
                  if (saved == true && !c.disposed) c.load();
                },
                icon: const Icon(Icons.tune, size: 18),
                label: const Text('Filter alergen'),
              ),
              OutlinedButton.icon(
                onPressed: c.busy
                    ? null
                    : () async {
                        if (await confirm(
                          context,
                          title: 'Gunakan lokasi?',
                          detail: 'Lokasi dipakai untuk menghitung jarak. Anda tetap dapat melihat paket jika izin ditolak.',
                          action: 'Gunakan lokasi',
                        )) {
                          c.locate();
                        }
                      },
                icon: const Icon(Icons.near_me_outlined, size: 18),
                label: const Text('Hitung jarak'),
              ),
            ],
          ),
          if (c.locationMessage != null) Notice(c.locationMessage!),
          const SizedBox(height: 24),
          Text(
            'Selamatkan hari ini',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 4),
          const Text(
            'Gerai terungkap setelah pembayaran.',
            style: TextStyle(color: Brand.muted, fontSize: 12),
          ),
          const SizedBox(height: 16),
          AsyncContent(
            busy: c.busy && c.items.isEmpty,
            error: c.error,
            empty: c.items.isEmpty,
            onRetry: () => c.load(),
            emptyTitle: 'Belum ada paket yang cocok',
            emptyMessage:
                'Coba kategori lain atau ubah filter. $allergenDisclaimer',
            child: Column(children: c.items.map(offerCard).toList()),
          ),
          if (c.cursor != null)
            OutlinedButton(
              onPressed: c.busy ? null : () => c.load(more: true),
              child: const Text('Muat paket lainnya'),
            ),
          const SizedBox(height: 12),
          const Text(
            allergenDisclaimer,
            style: TextStyle(fontSize: 12, color: Brand.muted),
          ),
        ],
      ),
    ),
  );

  Widget categoryChip(String label, String? category) => Padding(
    padding: const EdgeInsets.only(right: 8),
    child: ChoiceChip(
      label: Text(label),
      selected: c.category == category,
      selectedColor: Brand.green,
      labelStyle: TextStyle(
        color: c.category == category ? Colors.white : Brand.muted,
      ),
      onSelected: c.busy ? null : (_) => c.load(category: category ?? ''),
    ),
  );

  Widget offerCard(Offer offer) => Card(
    margin: const EdgeInsets.only(bottom: 16),
    child: InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () => widget.onOffer != null
          ? widget.onOffer!(offer)
          : openScreen(context, OfferDetailScreen(offer: offer)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 92,
              height: 126,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: offer.category == 'roti_kudapan'
                    ? Brand.orangePale
                    : Brand.pale,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SurpriseBag(
                    width: 74,
                    height: 98,
                    bread: offer.category == 'roti_kudapan',
                  ),
                  Positioned(
                    top: 5,
                    left: 5,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '−${offer.discountPercent.toStringAsFixed(0)}%',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Brand.green,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    categoryLabel(offer.category),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${offer.available} paket tersisa',
                    style: const TextStyle(color: Brand.orange, fontSize: 12),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    'Ambil sebelum ${dateLabel(offer.pickupEnd)}',
                    style: const TextStyle(fontSize: 12, color: Brand.muted),
                  ),
                  if (offer.distanceKm != null)
                    Text(
                      '${offer.distanceKm!.toStringAsFixed(1)} km dari Anda',
                      style: const TextStyle(fontSize: 12, color: Brand.muted),
                    ),
                  const SizedBox(height: 12),
                  Text(
                    rupiah(offer.discountPrice),
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    'dari ${rupiah(offer.normalPrice)}',
                    style: const TextStyle(fontSize: 11, color: Brand.muted),
                  ),
                  const SizedBox(height: 5),
                  const Text(
                    'Lihat paket',
                    style: TextStyle(
                      color: Brand.green,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
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
