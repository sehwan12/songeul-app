import 'package:flutter/material.dart';

import 'app_tokens.dart';

abstract final class AppTheme {
  static final light = ThemeData(
    fontFamily: AppFonts.display,
    brightness: Brightness.light,
    primaryColor: AppColors.primary,
    canvasColor: AppColors.canvas,
    colorScheme: const ColorScheme.light(
      primary: AppColors.primary,
      secondary: AppColors.secondary,
      tertiary: AppColors.tertiary,
    ),
  );
}
