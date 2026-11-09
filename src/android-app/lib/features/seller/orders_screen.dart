import 'package:flutter/material.dart';

import '../../app_services.dart';
import '../orders/history_screen.dart';

class SellerOrdersScreen extends StatelessWidget {
  final AppServices services;
  const SellerOrdersScreen({super.key, required this.services});
  @override
  Widget build(BuildContext context) => HistoryScreen(services: services);
}
