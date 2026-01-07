import 'package:flutter/material.dart';

class AppLayout extends StatelessWidget {
  final Widget child;
  final bool showBottomNav;
  
  const AppLayout({
    Key? key,
    required this.child,
    this.showBottomNav = true,
  }) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    return child;
  }
}