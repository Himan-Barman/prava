import 'package:flutter/material.dart';
import '../colors.dart';
import 'toast_type.dart';

class PravaToast {
  PravaToast._();

  static void show(
    BuildContext context, {
    required String message,
    PravaToastType type = PravaToastType.info,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    Color background;
    Color foreground;

    switch (type) {
      case PravaToastType.success:
        background = PravaColors.success;
        foreground = Colors.white;
        break;
      case PravaToastType.warning:
        background = PravaColors.warning;
        foreground = Colors.black;
        break;
      case PravaToastType.error:
        background = PravaColors.error;
        foreground = Colors.white;
        break;
      case PravaToastType.info:
        background = isDark
            ? PravaColors.darkBgElevated
            : PravaColors.lightBgElevated;
        foreground = isDark
            ? PravaColors.darkTextPrimary
            : PravaColors.lightTextPrimary;
        break;
    }

    final snackBar = SnackBar(
      content: Text(
        message,
        style: TextStyle(color: foreground),
      ),
      backgroundColor: background,
      behavior: SnackBarBehavior.floating,
      elevation: 6,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      duration: const Duration(seconds: 3),
    );

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(snackBar);
  }
}
