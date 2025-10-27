import 'package:flutter/material.dart';

import '../Utils/app_router.dart';

class HomeView extends StatelessWidget {
  const HomeView({super.key, required this.baseUrl});

  final String baseUrl;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Home'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person),
            onPressed: () => Navigator.of(context).pushNamed(AppRouter.profileRoute),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Connected to: ' + baseUrl),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => Navigator.of(context).pushNamed(AppRouter.taskFormRoute),
              icon: const Icon(Icons.assignment_add),
              label: const Text('New Task'),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: () => Navigator.of(context).pushNamed(AppRouter.scanRoute),
              icon: const Icon(Icons.qr_code_scanner),
              label: const Text('Scan Code'),
            ),
          ],
        ),
      ),
    );
  }
}
