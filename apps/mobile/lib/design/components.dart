import 'package:flutter/material.dart';

import 'tokens.dart';

class WashPage extends StatelessWidget {
  const WashPage({super.key, required this.title, required this.child});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(title), backgroundColor: WashColors.canvas),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(WashSpace.md),
            children: [child],
          ),
        ),
      );
}

class WashStatus extends StatelessWidget {
  const WashStatus({
    super.key,
    required this.label,
    required this.color,
    required this.icon,
  });
  final String label;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: WashColors.surface,
          border: Border.all(color: WashColors.border),
          borderRadius: BorderRadius.circular(WashRadius.pill),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: WashSpace.xs),
            Flexible(
              child: Text(
                label,
                softWrap: true,
                style: TextStyle(color: color, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      );
}

class WashSectionCard extends StatelessWidget {
  const WashSectionCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(WashSpace.md),
  });
  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(padding: padding, child: child),
      );
}
