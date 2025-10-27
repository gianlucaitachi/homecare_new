import 'package:flutter/material.dart';

import '../utils/app_router.dart';

class QrScanButton extends StatelessWidget {
  const QrScanButton({
    super.key,
    this.label = 'Scan QR Code',
    this.icon = Icons.qr_code_scanner,
    this.onPressed,
    this.style,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  final ButtonStyle? style;

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      icon: Icon(icon),
      label: Text(label),
      style: style,
      onPressed: onPressed ??
          () => Navigator.of(context).pushNamed(AppRouter.scanRoute),
    );
  }
}
