import 'package:flutter/material.dart';

import '../theme/dashboard_tokens.dart';

class DashboardPageHeader extends StatelessWidget {
  const DashboardPageHeader({
    super.key,
    required this.title,
    required this.subtitle,
    this.padding = const EdgeInsets.fromLTRB(8, 10, 8, 6),
  });

  final String title;
  final String subtitle;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: DashboardTokens.pageBackground,
        borderRadius: BorderRadius.circular(DashboardTokens.cardRadius),
      ),
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w700,
              color: DashboardTokens.textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: const TextStyle(
              fontSize: 12,
              color: DashboardTokens.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
