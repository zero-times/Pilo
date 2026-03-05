import 'package:flutter/material.dart';

import '../theme/dashboard_tokens.dart';

class DashboardSurfaceCard extends StatelessWidget {
  const DashboardSurfaceCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(12),
    this.color = DashboardTokens.surface,
    this.outlined = false,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color color;
  final bool outlined;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(DashboardTokens.cardRadius),
        border: outlined
            ? Border.all(color: DashboardTokens.borderSubtle)
            : null,
      ),
      child: child,
    );
  }
}
