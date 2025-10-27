import 'package:flutter/material.dart';

class AppBarComponent extends StatelessWidget implements PreferredSizeWidget {
  const AppBarComponent({
    super.key,
    required this.title,
    this.actions,
    this.leading,
    this.centerTitle,
    this.backgroundColor,
    this.elevation,
  });

  final String title;
  final List<Widget>? actions;
  final Widget? leading;
  final bool? centerTitle;
  final Color? backgroundColor;
  final double? elevation;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: Text(title),
      actions: actions,
      leading: leading,
      centerTitle: centerTitle,
      backgroundColor: backgroundColor,
      elevation: elevation,
      titleSpacing: leading == null ? 16 : null,
    );
  }
}
