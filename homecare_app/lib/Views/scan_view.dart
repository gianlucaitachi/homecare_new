import 'package:flutter/material.dart';

class ScanView extends StatelessWidget {
  const ScanView({super.key, required this.baseUrl});

  final String baseUrl;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.qr_code_scanner, size: 96),
            const SizedBox(height: 16),
            Text('Scanning will post results to: ' + baseUrl),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Scanner placeholder action')),
              ),
              child: const Text('Start Scanning'),
            ),
          ],
        ),
      ),
    );
  }
}
