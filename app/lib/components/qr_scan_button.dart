import 'package:flutter/material.dart';

class QrScanButton extends StatelessWidget {
  const QrScanButton({
    super.key,
    this.onPressed,
    this.tooltip,
  });

  final VoidCallback? onPressed;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.qr_code_scanner),
      tooltip: tooltip ?? 'Quét QR',
      onPressed: onPressed,
    );
  }
}
