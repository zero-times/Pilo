import 'package:flutter/material.dart';

import '../services/local_snapshot_store.dart';
import '../widgets/dashboard_bottom_tab_bar.dart';
import '../screens/training_planner_page.dart';

class DashboardTabNavigator {
  const DashboardTabNavigator._();

  static void goToTabRoot(
    BuildContext context, {
    required DashboardTab tab,
    LocalSnapshotStore? snapshotStore,
  }) {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(
        builder: (_) => TrainingPlannerPage(
          initialTabIndex: tab.index,
          snapshotStore: snapshotStore,
        ),
      ),
      (_) => false,
    );
  }
}
