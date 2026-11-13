import 'package:flutter/material.dart';

import '../theme/brand.dart';

String statusLabel(String status) => switch (status) {
  'pending_payment' => 'Menunggu pembayaran',
  'paid' => 'Siap diambil',
  'completed' => 'Selesai',
  'cancelled' => 'Dibatalkan',
  'dispute' => 'Dalam pengaduan',
  'refunded' => 'Direfund',
  'no_show' => 'Tidak diambil',
  'open' => 'Menunggu tanggapan',
  'approved' => 'Disetujui',
  'rejected' => 'Ditolak',
  'auto_refunded' => 'Refund otomatis',
  'active' => 'Aktif',
  'closed' => 'Ditutup',
  'pending' => 'Menunggu payout',
  'held' => 'Ditahan',
  'settled' => 'Selesai (simulasi)',
  _ => status,
};

class StatusBadge extends StatelessWidget {
  final String status;
  const StatusBadge(this.status, {super.key});
  @override
  Widget build(BuildContext context) {
    final warning = [
      'dispute',
      'held',
      'open',
      'pending_payment',
      'no_show',
    ].contains(status);
    final color = warning
        ? Brand.orange
        : Theme.of(context).colorScheme.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: warning ? Brand.orangePale : Brand.pale,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            warning
                ? Icons.schedule_rounded
                : Icons.check_circle_outline_rounded,
            size: 16,
            color: color,
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              statusLabel(status),
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
