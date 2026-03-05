import 'package:flutter/material.dart';

import '../theme/dashboard_tokens.dart';

class RiskBanner extends StatelessWidget {
  const RiskBanner({
    super.key,
    required this.warning,
    required this.expanded,
    required this.onToggle,
  });

  final String warning;
  final bool expanded;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final safeWarning = warning.trim().isEmpty ? '无特别风险提示。' : warning.trim();
    final summary = safeWarning.split(RegExp(r'[。.!?]')).first.trim();

    return Material(
      color: DashboardTokens.warningSoft,
      borderRadius: BorderRadius.circular(DashboardTokens.cardRadius),
      child: InkWell(
        onTap: onToggle,
        borderRadius: BorderRadius.circular(DashboardTokens.cardRadius),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(DashboardTokens.cardRadius),
            border: Border.all(
              color: DashboardTokens.warning.withValues(alpha: 0.35),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.warning_amber_rounded,
                    color: DashboardTokens.warning,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      summary.isEmpty ? '风险提示' : summary,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: DashboardTokens.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Icon(
                    expanded ? Icons.expand_less : Icons.expand_more,
                    color: DashboardTokens.textSecondary,
                  ),
                ],
              ),
              AnimatedCrossFade(
                firstChild: const SizedBox.shrink(),
                secondChild: Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Divider(
                    height: 1,
                    color: DashboardTokens.warning.withValues(alpha: 0.3),
                  ),
                ),
                crossFadeState: expanded
                    ? CrossFadeState.showSecond
                    : CrossFadeState.showFirst,
                duration: const Duration(milliseconds: 180),
              ),
              AnimatedCrossFade(
                firstChild: const SizedBox.shrink(),
                secondChild: Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    safeWarning,
                    style: const TextStyle(
                      color: DashboardTokens.textSecondary,
                      height: 1.35,
                    ),
                  ),
                ),
                crossFadeState: expanded
                    ? CrossFadeState.showSecond
                    : CrossFadeState.showFirst,
                duration: const Duration(milliseconds: 180),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
