import 'package:flutter/material.dart';

import '../../app_services.dart';
import '../../core/widgets/async_content.dart';
import '../../core/widgets/action_button.dart';
import '../../core/widgets/formatters.dart';
import '../../core/widgets/status_badge.dart';
import '../../core/widgets/screen_helpers.dart';
import 'seller_controller.dart';
import 'offer_form_screen.dart';
import 'profile_screen.dart';

class OffersScreen extends StatelessWidget {
  final AppServices services;
  final SellerController controller;
  const OffersScreen({
    super.key,
    required this.services,
    required this.controller,
  });
  @override
  Widget build(BuildContext context) {
    final c = controller;
    return ListenableBuilder(
      listenable: c,
      builder: (context, _) => RefreshIndicator(
        onRefresh: () async {
          await c.load();
        },
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              c.profile?.name.isNotEmpty == true
                  ? c.profile!.name
                  : 'Selamat datang, mitra',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 12),
            if (!c.profileComplete) ...[
              const Notice(
                'Lengkapi nama, alamat, dan koordinat gerai sebelum menerbitkan paket.',
              ),
              OutlinedButton.icon(
                onPressed: () async {
                  await openScreen(context, ProfileScreen(services: services));
                  if (!c.disposed) c.loadProfile();
                },
                icon: const Icon(Icons.store_outlined),
                label: const Text('Lengkapi profil gerai'),
              ),
            ],
            if (c.saved != null)
              Notice(
                'Komunitas telah menyelamatkan ${c.saved} paket melalui pengambilan yang selesai.',
              ),
            const SizedBox(height: 12),
            const Text('Ringkasan penawaran yang telah dimuat'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                summary(
                  context,
                  'Tersedia',
                  c.offers.fold<int>(0, (n, o) => n + o.available),
                ),
                summary(
                  context,
                  'Ditahan',
                  c.offers.fold<int>(0, (n, o) => n + o.held),
                ),
                summary(
                  context,
                  'Terjual',
                  c.offers.fold<int>(0, (n, o) => n + o.sold),
                ),
              ],
            ),
            const SizedBox(height: 20),
            ActionButton(
              label: 'Buat penawaran',
              onPressed: c.busy || !c.profileComplete
                  ? null
                  : () async {
                      if (await openScreen<bool>(
                                context,
                                OfferFormScreen(services: services),
                              ) ==
                              true &&
                          !c.disposed) {
                        c.loadOffers();
                      }
                    },
            ),
            const SizedBox(height: 20),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final value in ['all', 'active', 'closed'])
                  ChoiceChip(
                    label: Text(value == 'all' ? 'Semua' : statusLabel(value)),
                    selected: c.filter == value,
                    onSelected: (_) => c.setFilter(value),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            AsyncContent(
              busy: c.busy && c.offers.isEmpty,
              error: c.error,
              empty: c.visible.isEmpty,
              emptyTitle: 'Belum ada penawaran',
              emptyMessage:
                  'Terbitkan paket kejutan dari makanan yang masih layak.',
              onRetry: () => c.load(),
              child: Column(
                children: c.visible
                    .map(
                      (o) => Card(
                        margin: const EdgeInsets.only(bottom: 16),
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              StatusBadge(o.status),
                              const SizedBox(height: 12),
                              Text(
                                categoryLabel(o.category),
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                              Text(rupiah(o.discountPrice)),
                              Text(
                                'Tersedia ${o.available} · ditahan ${o.held} · terjual ${o.sold}',
                              ),
                              const SizedBox(height: 8),
                              Text('Mulai ${dateLabel(o.pickupStart)}'),
                              Text('Sampai ${dateLabel(o.pickupEnd)}'),
                              Text('Layak hingga ${dateLabel(o.safeEatUntil)}'),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  OutlinedButton(
                                    onPressed: c.busy || !o.editable
                                        ? null
                                        : () async {
                                            if (await openScreen<bool>(
                                                      context,
                                                      OfferFormScreen(
                                                        services: services,
                                                        offer: o,
                                                      ),
                                                    ) ==
                                                    true &&
                                                !c.disposed) {
                                              c.loadOffers();
                                            }
                                          },
                                    child: const Text('Ubah'),
                                  ),
                                  TextButton(
                                    onPressed: c.busy || !o.editable
                                        ? null
                                        : () async {
                                            if (await confirm(
                                              context,
                                              title: 'Tutup penawaran?',
                                              detail: 'Paket ini akan dihapus dari katalog. Paket yang ditahan atau pernah dibayar tidak dapat ditutup.',
                                              action: 'Tutup penawaran',
                                            )) {
                                              await c.close(o.id);
                                            }
                                          },
                                    child: const Text('Tutup'),
                                  ),
                                ],
                              ),
                              if (!o.editable)
                                const Text(
                                  'Perubahan dibatasi saat paket ditahan, dibayar, atau telah ditutup.',
                                ),
                            ],
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
            if (c.cursor != null)
              OutlinedButton(
                onPressed: c.busy ? null : () => c.loadOffers(more: true),
                child: const Text('Muat penawaran lainnya'),
              ),
          ],
        ),
      ),
    );
  }

  Widget summary(BuildContext context, String label, int amount) => Container(
    width: 100,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      border: Border.all(color: const Color(0xFFE6EADB)),
      borderRadius: BorderRadius.circular(16),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('$amount', style: Theme.of(context).textTheme.headlineSmall),
        Text(label),
      ],
    ),
  );
}
