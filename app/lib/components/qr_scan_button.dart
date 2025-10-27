import 'package:flutter/material.dart';

import '../utils/app_router.dart';

class QrScanButton extends StatelessWidget {
  const QrScanButton({
    super.key,
    this.label,
    this.style,
    this.onNavigate,
  });

  final String? label;
  final ButtonStyle? style;
  final VoidCallback? onNavigate;

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: () {
        if (onNavigate != null) {
          onNavigate!.call();
          return;
        }
        Navigator.of(context).pushNamed(AppRouter.scanRoute);
      },
      style: style,
      icon: const Icon(Icons.qr_code_scanner),
      label: Text(label ?? 'Scan Code'),
    );
  }
}
