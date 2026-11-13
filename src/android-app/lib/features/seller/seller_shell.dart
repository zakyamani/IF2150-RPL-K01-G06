import 'dart:async';

import '../notifications/inbox_screen.dart';
import '../notifications/monitor_card.dart';
import '../../core/models/notification.dart';
import '../orders/order_repository.dart';
import '../orders/order_detail_screen.dart';
import '../orders/merchant_reviews_screen.dart';
import 'scan_controller.dart';
import 'scan_screen.dart';
import 'complaints_screen.dart';
import 'payout_screen.dart';

import 'package:flutter/material.dart';

import '../../app_services.dart';
import '../../core/widgets/brand_art.dart';
import '../../core/widgets/screen_helpers.dart';
import '../settings/account_screen.dart';
import 'seller_controller.dart';
import 'offers_screen.dart';
import 'orders_screen.dart';
import 'profile_screen.dart';

class SellerShell extends StatefulWidget {
  final AppServices services;
  const SellerShell({super.key, required this.services});
  @override
  State<SellerShell> createState() => _SellerShellState();
}

class _SellerShellState extends State<SellerShell> {
  late final c = SellerController(widget.services);
  StreamSubscription<InboxEvent>? _updates;
  StreamSubscription<String>? _taps;
  Timer? _refresh;
  int tab = 0;
  final visited = <int>{0};
  @override
  void initState() {
    super.initState();
    c.load();
    _updates = widget.services.notifications.changes.listen((event) {
      _refresh?.cancel();
      _refresh = Timer(const Duration(milliseconds: 400), () {
        if (!c.disposed && !c.busy) c.loadOffers();
      });
    });
    _taps = widget.services.monitor.taps.listen((id) async {
      final actor = widget.services.sessions.session?.user.id,
          epoch = widget.services.sessions.epoch;
      try {
        await OrderRepository(widget.services).order(id);
        if (mounted &&
            actor == widget.services.sessions.session?.user.id &&
            epoch == widget.services.sessions.epoch) {
          await openScreen(
            context,
            OrderDetailScreen(services: widget.services, id: id),
          );
        }
      } catch (_) {
        if (mounted) message(context, 'Pesanan belum tersedia. Periksa inbox.');
      }
    });
  }

  @override
  void dispose() {
    _updates?.cancel();
    _taps?.cancel();
    _refresh?.cancel();
    c.dispose();
    super.dispose();
  }

  Widget page(int i) => switch (i) {
    0 => OffersScreen(services: widget.services, controller: c),
    1 => SellerOrdersScreen(services: widget.services),
    2 => PayoutScreen(services: widget.services),
    _ => ListView(
      children: [
        MonitorCard(services: widget.services),
        ListTile(
          leading: const Icon(Icons.store_outlined),
          title: const Text('Kelola profil gerai'),
          subtitle: const Text(
            'Foto, alamat, lokasi pengambilan dan tujuan demo',
          ),
          onTap: () async {
            await openScreen(context, ProfileScreen(services: widget.services));
            if (!c.disposed) c.loadProfile();
          },
        ),
        ListTile(
          leading: const Icon(Icons.star_outline),
          title: const Text('Ulasan gerai'),
          onTap: () => openScreen(
            context,
            MerchantReviewsScreen(
              services: widget.services,
              merchantId: widget.services.sessions.session!.user.id,
            ),
          ),
        ),
        AccountScreen(services: widget.services, embedded: true),
      ],
    ),
  };
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      actions: [
        InboxButton(services: widget.services),
        IconButton(
          tooltip: 'Pengaduan',
          onPressed: () =>
              openScreen(context, ComplaintsScreen(services: widget.services)),
          icon: const Icon(Icons.report_problem_outlined),
        ),
      ],
      title: BrandTitle(
        title: ['Penawaran', 'Pesanan', 'Keuangan', 'Profil'][tab],
      ),
    ),
    body: SafeArea(
      child: IndexedStack(
        index: tab,
        children: List.generate(
          4,
          (i) => visited.contains(i) ? page(i) : const SizedBox(),
        ),
      ),
    ),
    floatingActionButton: tab == 1
        ? FloatingActionButton.extended(
            onPressed: () async {
              final result = await openScreen<PickupResult>(
                context,
                ScanScreen(services: widget.services),
              );
              if (result != null && context.mounted) {
                await openScreen(
                  context,
                  OrderDetailScreen(
                    services: widget.services,
                    id: result.orderId,
                  ),
                );
              }
            },
            icon: const Icon(Icons.qr_code_scanner),
            label: const Text('Scan pickup'),
          )
        : null,
    bottomNavigationBar: NavigationBar(
      selectedIndex: tab,
      onDestinationSelected: (i) => setState(() {
        tab = i;
        visited.add(i);
      }),
      destinations: const [
        NavigationDestination(
          icon: Icon(Icons.store_outlined),
          label: 'Penawaran',
        ),
        NavigationDestination(
          icon: Icon(Icons.receipt_long_outlined),
          label: 'Pesanan',
        ),
        NavigationDestination(
          icon: Icon(Icons.account_balance_wallet_outlined),
          label: 'Keuangan',
        ),
        NavigationDestination(
          icon: Icon(Icons.person_outline),
          label: 'Profil',
        ),
      ],
    ),
  );
}
