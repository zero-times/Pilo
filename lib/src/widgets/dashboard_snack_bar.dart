import 'package:flutter/material.dart';

import '../theme/dashboard_tokens.dart';

void showDashboardSnackBar(
  BuildContext context, {
  required String message,
  bool isError = false,
  String? actionLabel,
  VoidCallback? onAction,
  Duration duration = const Duration(seconds: 2),
}) {
  final messenger = ScaffoldMessenger.of(context);
  messenger.hideCurrentSnackBar();
  messenger.showSnackBar(
    SnackBar(
      content: Text(
        message,
        style: const TextStyle(
          color: DashboardTokens.textPrimary,
          fontWeight: FontWeight.w500,
        ),
      ),
      behavior: SnackBarBehavior.floating,
      duration: duration,
      backgroundColor: isError
          ? DashboardTokens.warningSoft
          : DashboardTokens.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(DashboardTokens.buttonRadius),
        side: const BorderSide(color: DashboardTokens.borderSubtle),
      ),
      action: actionLabel != null && onAction != null
          ? SnackBarAction(
              label: actionLabel,
              textColor: DashboardTokens.accent,
              onPressed: onAction,
            )
          : null,
    ),
  );
}
