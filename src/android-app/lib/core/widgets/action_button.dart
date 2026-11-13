import 'package:flutter/material.dart';

class ActionButton extends StatelessWidget {
  final String label;
  final bool busy;
  final VoidCallback? onPressed;
  final IconData? icon;
  const ActionButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.busy = false,
    this.icon,
  });
  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    child: FilledButton(
      onPressed: busy ? null : onPressed,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (busy)
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else if (icon != null)
            Icon(icon),
          if (busy || icon != null) const SizedBox(width: 10),
          Flexible(
            child: Text(
              busy ? 'Tunggu sebentar…' : label,
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    ),
  );
}
