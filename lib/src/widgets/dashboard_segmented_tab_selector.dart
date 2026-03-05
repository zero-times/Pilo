import 'package:flutter/material.dart';

import '../theme/dashboard_tokens.dart';

class DashboardSegmentedTabItem<T> {
  const DashboardSegmentedTabItem({
    required this.value,
    required this.label,
    this.icon,
  });

  final T value;
  final String label;
  final IconData? icon;
}

class DashboardSegmentedTabSelector<T> extends StatelessWidget {
  const DashboardSegmentedTabSelector({
    super.key,
    required this.items,
    required this.selectedValue,
    required this.onChanged,
  });

  final List<DashboardSegmentedTabItem<T>> items;
  final T selectedValue;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List<Widget>.generate(items.length, (index) {
        final item = items[index];
        final selected = item.value == selectedValue;
        final color = selected
            ? DashboardTokens.accent
            : DashboardTokens.textInactive;

        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(
              left: index == 0 ? 0 : 3,
              right: index == items.length - 1 ? 0 : 3,
            ),
            child: InkWell(
              key: ValueKey('dashboard-segment-${item.label}'),
              borderRadius: BorderRadius.circular(DashboardTokens.buttonRadius),
              onTap: selected ? null : () => onChanged(item.value),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                curve: Curves.easeOut,
                height: 40,
                decoration: BoxDecoration(
                  color: selected
                      ? DashboardTokens.accentSoft
                      : DashboardTokens.pageBackground,
                  borderRadius: BorderRadius.circular(
                    DashboardTokens.buttonRadius,
                  ),
                  border: Border.all(
                    color: selected
                        ? DashboardTokens.accent
                        : DashboardTokens.borderSubtle,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (item.icon != null) ...[
                      Icon(item.icon, size: 14, color: color),
                      const SizedBox(width: 4),
                    ],
                    Text(
                      item.label,
                      style: TextStyle(
                        fontSize: 12,
                        color: color,
                        fontWeight: selected
                            ? FontWeight.w600
                            : FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }),
    );
  }
}
