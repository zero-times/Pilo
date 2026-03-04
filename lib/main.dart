import 'package:flutter/material.dart';

import 'src/screens/training_planner_page.dart';
import 'src/theme/dashboard_tokens.dart';

void main() {
  runApp(const FitnessApp());
}

class FitnessApp extends StatelessWidget {
  const FitnessApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: '个人锻炼助手',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: DashboardTokens.accent,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        scaffoldBackgroundColor: DashboardTokens.pageBackground,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: DashboardTokens.textPrimary,
          elevation: 0,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFFF8FAFC),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: DashboardTokens.accent),
          ),
        ),
        cardTheme: CardThemeData(
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: DashboardTokens.accent,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        segmentedButtonTheme: SegmentedButtonThemeData(
          style: SegmentedButton.styleFrom(
            selectedBackgroundColor: DashboardTokens.accent,
            selectedForegroundColor: Colors.white,
            foregroundColor: const Color(0xFF3C3C43),
            side: BorderSide.none,
            textStyle: const TextStyle(fontSize: 12),
          ),
        ),
        bottomSheetTheme: const BottomSheetThemeData(
          backgroundColor: Color(0xFFEEF3F8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          showDragHandle: true,
        ),
      ),
      home: const TrainingPlannerPage(),
    );
  }
}
