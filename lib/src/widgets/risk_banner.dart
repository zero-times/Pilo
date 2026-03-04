import 'package:flutter/material.dart';

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
      color: const Color(0xFFFFF4EA),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onToggle,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFFFD7B8)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.warning_amber_rounded,
                    color: Color(0xFFD95F00),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      summary.isEmpty ? '风险提示' : summary,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: const Color(0xFF7C2D12),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Icon(
                    expanded ? Icons.expand_less : Icons.expand_more,
                    color: const Color(0xFF9A3412),
                  ),
                ],
              ),
              AnimatedCrossFade(
                firstChild: const SizedBox.shrink(),
                secondChild: const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Divider(height: 1, color: Color(0xFFFFD7B8)),
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
                      color: Color(0xFF9A3412),
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
