import 'package:flutter/material.dart';

import '../navigation/dashboard_tab_navigator.dart';
import '../services/local_snapshot_store.dart';
import '../theme/dashboard_tokens.dart';
import 'dashboard_bottom_tab_bar.dart';

export 'dashboard_bottom_tab_bar.dart' show DashboardTab, DashboardTabChanged;

class DashboardTabPageScaffold extends StatelessWidget {
  const DashboardTabPageScaffold({
    super.key,
    required this.title,
    required this.body,
    required this.selectedTab,
    this.snapshotStore,
    this.onTabChanged,
    this.backgroundColor = DashboardTokens.pageBackground,
    this.useSafeArea = true,
    this.appBarActions,
    this.showAppBar = true,
    this.showBottomNavigationBar = true,
    this.allowReselectCurrentTab = false,
  });

  final String title;
  final Widget body;
  final DashboardTab selectedTab;
  final LocalSnapshotStore? snapshotStore;
  final DashboardTabChanged? onTabChanged;
  final Color backgroundColor;
  final bool useSafeArea;
  final List<Widget>? appBarActions;
  final bool showAppBar;
  final bool showBottomNavigationBar;
  final bool allowReselectCurrentTab;

  void _defaultOnTabChanged(BuildContext context, DashboardTab tab) {
    DashboardTabNavigator.goToTabRoot(
      context,
      tab: tab,
      snapshotStore: snapshotStore,
    );
  }

  @override
  Widget build(BuildContext context) {
    final DashboardTabChanged tabChanged =
        onTabChanged ?? (tab) => _defaultOnTabChanged(context, tab);
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: showAppBar
          ? AppBar(
              title: Text(title),
              backgroundColor: DashboardTokens.surface,
              foregroundColor: DashboardTokens.textPrimary,
              elevation: 0,
              actions: appBarActions,
            )
          : null,
      body: useSafeArea ? SafeArea(child: body) : body,
      bottomNavigationBar: showBottomNavigationBar
          ? DashboardBottomTabBar(
              selectedTab: selectedTab,
              onTabChanged: tabChanged,
              allowReselectCurrentTab: allowReselectCurrentTab,
            )
          : null,
    );
  }
}
