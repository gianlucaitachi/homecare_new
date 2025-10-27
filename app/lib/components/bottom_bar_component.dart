import 'package:flutter/material.dart';

class BottomBarComponent extends StatelessWidget {
  const BottomBarComponent({
    super.key,
    required this.currentIndex,
    this.onTap,
  });

  final int currentIndex;
  final ValueChanged<int>? onTap;

  @override
  Widget build(BuildContext context) {
    return BottomNavigationBar(
      currentIndex: currentIndex,
      onTap: onTap,
      items: const [
        BottomNavigationBarItem(
          icon: Icon(Icons.checklist_rounded),
          label: 'Tasks',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.qr_code_scanner),
          label: 'Scan',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.person),
          label: 'Profile',
        ),
      ],
    );
  }
}
