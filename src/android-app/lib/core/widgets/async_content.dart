import 'package:flutter/material.dart';

class AsyncContent extends StatelessWidget {
  final bool busy, empty;
  final String? error;
  final String emptyTitle, emptyMessage;
  final Widget child;
  final VoidCallback? onRetry;
  const AsyncContent({
    super.key,
    required this.child,
    this.busy = false,
    this.empty = false,
    this.error,
    this.emptyTitle = 'Belum ada data',
    this.emptyMessage = 'Data akan muncul di sini.',
    this.onRetry,
  });
  @override
  Widget build(BuildContext context) {
    if (busy) {
      return const Padding(
        padding: EdgeInsets.all(40),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (error != null) {
      return EmptyState(
        title: 'Belum dapat dimuat',
        message: error!,
        icon: Icons.wifi_off_rounded,
        onAction: onRetry,
        action: 'Coba lagi',
      );
    }
    if (empty) {
      return EmptyState(
        title: emptyTitle,
        message: emptyMessage,
        icon: Icons.shopping_bag_outlined,
      );
    }
    return child;
  }
}

class EmptyState extends StatelessWidget {
  final String title, message, action;
  final IconData icon;
  final VoidCallback? onAction;
  const EmptyState({
    super.key,
    required this.title,
    required this.message,
    this.icon = Icons.inbox_outlined,
    this.onAction,
    this.action = 'Coba lagi',
  });
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 52, color: Theme.of(context).colorScheme.primary),
        const SizedBox(height: 20),
        Text(
          title,
          style: Theme.of(context).textTheme.titleLarge,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 10),
        Text(message, textAlign: TextAlign.center),
        if (onAction != null) ...[
          const SizedBox(height: 20),
          OutlinedButton(onPressed: onAction, child: Text(action)),
        ],
      ],
    ),
  );
}
