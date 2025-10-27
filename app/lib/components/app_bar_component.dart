import 'package:flutter/material.dart';

class AppBarComponent extends StatelessWidget implements PreferredSizeWidget {
  const AppBarComponent({
    super.key,
    required this.title,
    this.actions,
    this.centerTitle = false,
    this.leading,
    this.backgroundColor,
    this.elevation,
  });

  final String title;
  final List<Widget>? actions;
  final bool centerTitle;
  final Widget? leading;
  final Color? backgroundColor;
  final double? elevation;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: Text(title),
      centerTitle: centerTitle,
      leading: leading,
      actions: actions,
      backgroundColor: backgroundColor,
      elevation: elevation,
    );
  }
}
