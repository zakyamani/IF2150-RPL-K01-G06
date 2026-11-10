import 'package:flutter/material.dart';

import '../../core/models/offer.dart';
import '../../core/widgets/brand_art.dart';
import '../../core/widgets/action_button.dart';
import '../../core/widgets/formatters.dart';
import '../../core/widgets/screen_helpers.dart';

class OfferDetailScreen extends StatelessWidget {
  final Offer offer;
  final VoidCallback? onCheckout;
  const OfferDetailScreen({super.key, required this.offer, this.onCheckout});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Paket kejutan')),
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          BagPanel(bread: offer.category == 'roti_kudapan'),
          const SizedBox(height: 24),
          Text(
            categoryLabel(offer.category),
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 8),
          Text(
            rupiah(offer.discountPrice),
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          Text(
            '${rupiah(offer.normalPrice)} · hemat ${offer.discountPercent.toStringAsFixed(0)}%',
          ),
          DetailLine('Tersedia', '${offer.available} paket'),
          const Notice(
            'Isi paket merupakan kejutan. Identitas toko dan alamat lengkap dibuka setelah pembayaran berhasil.',
          ),
          DetailLine('Ambil mulai', dateLabel(offer.pickupStart)),
          DetailLine('Batas pengambilan', dateLabel(offer.pickupEnd)),
          DetailLine('Batas konsumsi', dateLabel(offer.safeEatUntil)),
          const SizedBox(height: 12),
          Text(
            'Alergen yang dilaporkan',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: offer.allergens.isEmpty
                ? [const Chip(label: Text('Tidak dilaporkan'))]
                : offer.allergens.map((a) => Chip(label: Text(a))).toList(),
          ),
          const Notice(allergenDisclaimer, warning: true),
          if (offer.distanceKm != null)
            DetailLine(
              'Perkiraan jarak',
              '${offer.distanceKm!.toStringAsFixed(1)} km',
            ),
          if (onCheckout != null)
            ActionButton(label: 'Pesan satu paket', onPressed: onCheckout),
        ],
      ),
    ),
  );
}