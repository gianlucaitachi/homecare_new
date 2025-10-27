import 'package:flutter/material.dart';

class AppBarComponent extends StatelessWidget implements PreferredSizeWidget {
  const AppBarComponent({
    super.key,
    required this.title,
    this.actions,
    this.centerTitle,
  });

  final String title;
  final List<Widget>? actions;
  final bool? centerTitle;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: Text(title),
      centerTitle: centerTitle,
      actions: actions,
    );
  }
}
