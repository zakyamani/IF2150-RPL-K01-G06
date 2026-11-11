import 'features/notifications/inbox_screen.dart';
import 'features/seller/seller_shell.dart';
import 'features/orders/checkout_screen.dart';
import 'features/orders/history_screen.dart';
import 'features/orders/tickets_screen.dart';
import 'features/buyer/offer_detail_screen.dart';
import 'core/widgets/screen_helpers.dart';
import 'core/widgets/brand_art.dart';

import 'package:flutter/material.dart';

import 'app_services.dart';
import 'core/models/user.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/login_screen.dart';
import 'features/buyer/catalog_screen.dart';
import 'features/settings/account_screen.dart';

class SisaRasaApp extends StatefulWidget {
  final AppServices services;
  final TextScaler? textScaler;
  const SisaRasaApp({super.key, required this.services, this.textScaler});
  @override
  State<SisaRasaApp> createState() => _AppState();
}

class _AppState extends State<SisaRasaApp> with WidgetsBindingObserver {
  final nav = GlobalKey<NavigatorState>();
  String? actor;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    actor = widget.services.sessions.session?.user.id;
    widget.services.sessions.addListener(changed);
  }

  void changed() {
    final next = widget.services.sessions.session?.user.id;
    if (next != actor) {
      actor = next;
      nav.currentState?.popUntil((r) => r.isFirst);
    }
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.services.sessions.removeListener(changed);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && widget.services.runtimeEnabled) {
      widget.services.notifications.catchUp();
    }
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    navigatorKey: nav,
    title: 'SisaRasa',
    debugShowCheckedModeBanner: false,
    theme: appTheme(),
    builder: widget.textScaler == null
        ? null
        : (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: widget.textScaler),
            child: child!,
          ),
    home: widget.services.sessions.session == null
        ? LoginScreen(services: widget.services)
        : widget.services.sessions.session!.user.role == Role.seller
        ? SellerShell(
            key: ValueKey('${widget.services.sessions.origin}:$actor'),
            services: widget.services,
          )
        : HomeScreen(
            key: ValueKey('${widget.services.sessions.origin}:$actor'),
            services: widget.services,
          ),
  );
}

class HomeScreen extends StatefulWidget {
  final AppServices services;
  const HomeScreen({super.key, required this.services});
  @override
  State<HomeScreen> createState() => _HomeState();
}

class _HomeState extends State<HomeScreen> {
  int tab = 0;
  final visited = <int>{0};
  Widget buyerPage(int i) => switch (i) {
    0 => CatalogScreen(
      services: widget.services,
      onOffer: (offer) => openScreen(
        context,
        OfferDetailScreen(
          offer: offer,
          onCheckout: () => openScreen(
            context,
            CheckoutScreen(services: widget.services, offer: offer),
          ),
        ),
      ),
    ),
    1 => HistoryScreen(services: widget.services),
    2 => TicketsScreen(services: widget.services),
    _ => AccountScreen(services: widget.services),
  };
  @override
  Widget build(BuildContext context) {
    final seller = widget.services.sessions.session!.user.role == Role.seller;
    return Scaffold(
      appBar: AppBar(
        actions: [InboxButton(services: widget.services)],
        title: BrandTitle(
          title: seller
              ? (tab == 0 ? 'Kelola toko' : 'Akun')
              : ['sisarasa', 'Pesanan', 'Tiket', 'Akun'][tab],
        ),
      ),
      body: SafeArea(
        child: seller
            ? (tab == 1
                  ? AccountScreen(services: widget.services)
                  : ListView(
                      padding: const EdgeInsets.all(24),
                      children: [
                        Text(
                          'Selamat datang, mitra!',
                          style: Theme.of(context).textTheme.headlineMedium,
                        ),
                        const Text('Profil mitra terdaftar.'),
                      ],
                    ))
            : IndexedStack(
                index: tab,
                children: List.generate(
                  4,
                  (i) => visited.contains(i) ? buyerPage(i) : const SizedBox(),
                ),
              ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: tab,
        onDestinationSelected: (i) => setState(() {
          tab = i;
          visited.add(i);
        }),
        destinations: seller
            ? const [
                NavigationDestination(
                  icon: Icon(Icons.store_outlined),
                  label: 'Toko',
                ),
                NavigationDestination(
                  icon: Icon(Icons.person_outline),
                  label: 'Akun',
                ),
              ]
            : const [
                NavigationDestination(
                  icon: Icon(Icons.shopping_bag_outlined),
                  label: 'Katalog',
                ),
                NavigationDestination(
                  icon: Icon(Icons.receipt_long_outlined),
                  label: 'Pesanan',
                ),
                NavigationDestination(
                  icon: Icon(Icons.qr_code_2),
                  label: 'Tiket',
                ),
                NavigationDestination(
                  icon: Icon(Icons.person_outline),
                  label: 'Akun',
                ),
              ],
      ),
    );
  }
}
