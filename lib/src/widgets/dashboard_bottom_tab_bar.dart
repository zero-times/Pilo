import 'package:flutter/material.dart';

import '../theme/dashboard_tokens.dart';

enum DashboardTab { home, plan, stats, profile }

typedef DashboardTabChanged = void Function(DashboardTab tab);

class DashboardBottomTabBar extends StatelessWidget {
  const DashboardBottomTabBar({
    super.key,
    required this.selectedTab,
    required this.onTabChanged,
    this.allowReselectCurrentTab = false,
  });

  final DashboardTab selectedTab;
  final DashboardTabChanged onTabChanged;
  final bool allowReselectCurrentTab;

  static const List<({IconData icon, String label})> _items = [
    (icon: Icons.home_filled, label: '首页'),
    (icon: Icons.view_quilt_rounded, label: '计划'),
    (icon: Icons.bar_chart_rounded, label: '统计'),
    (icon: Icons.person_rounded, label: '我的'),
  ];

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        decoration: const BoxDecoration(
          color: DashboardTokens.surface,
          border: Border(top: BorderSide(color: DashboardTokens.borderSubtle)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
        child: Row(
          children: List<Widget>.generate(_items.length, (index) {
            final item = _items[index];
            final tab = DashboardTab.values[index];
            final selected = selectedTab == tab;
            final color = selected
                ? DashboardTokens.accent
                : DashboardTokens.textInactive;

            return Expanded(
              child: InkWell(
                key: ValueKey('dashboard-tab-${item.label}'),
                borderRadius: BorderRadius.circular(
                  DashboardTokens.buttonRadius,
                ),
                onTap: !selected || allowReselectCurrentTab
                    ? () => onTabChanged(tab)
                    : null,
                child: SizedBox(
                  height: 44,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(item.icon, size: 18, color: color),
                      const SizedBox(height: 2),
                      Text(
                        item.label,
                        style: TextStyle(
                          fontSize: 11,
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
            );
          }),
        ),
      ),
    );
  }
}
