import 'package:flutter/material.dart';

import '../colors.dart';
import '../typography.dart';
import 'toast_type.dart';

class PravaToast {
  PravaToast._();

  static void show(
    BuildContext context, {
    required String message,
    PravaToastType type = PravaToastType.info,
  }) {
    final tokens = context.pravaColors;

    Color background;
    Color foreground;
    IconData icon;
    String title;

    switch (type) {
      case PravaToastType.success:
        background = tokens.statusSuccessContainer;
        foreground = tokens.statusSuccess;
        icon = Icons.check_circle_rounded;
        title = 'Success';
        break;
      case PravaToastType.warning:
        background = tokens.statusWarningContainer;
        foreground = tokens.statusWarning;
        icon = Icons.warning_rounded;
        title = 'Warning';
        break;
      case PravaToastType.error:
        background = tokens.statusErrorContainer;
        foreground = tokens.statusError;
        icon = Icons.error_rounded;
        title = 'Error';
        break;
      case PravaToastType.info:
        background = tokens.statusInfoContainer;
        foreground = tokens.statusInfo;
        icon = Icons.info_rounded;
        title = 'Info';
        break;
    }

    final snackBar = SnackBar(
      content: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: foreground, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: PravaTypography.toast.copyWith(color: foreground),
                ),
                const SizedBox(height: 2),
                Text(
                  message,
                  style: PravaTypography.snackbarText.copyWith(
                    color: tokens.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      backgroundColor: background,
      behavior: SnackBarBehavior.floating,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: foreground.withValues(alpha: 0.2)),
      ),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      duration: const Duration(seconds: 3),
    );

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(snackBar);
  }
}
