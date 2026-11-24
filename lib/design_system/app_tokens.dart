import 'package:flutter/material.dart';

abstract final class AppColors {
  static const primary = Color(0xFFCEEF91);
  static const canvas = Color(0xFFFFFBF3);
  static const secondary = Color(0xFFFFE5F2);
  static const tertiary = Color(0xFFFFCEEF);
  static const text = Colors.black87;
  static const navigationSelected = Color.fromARGB(221, 241, 105, 14);
}

abstract final class AppFonts {
  static const display = 'Cafe24Ssurround';
  static const reading = 'MaruBuri';
  static const interface = 'Pretendard';
}

abstract final class AppSpacing {
  static const small = 8.0;
  static const medium = 16.0;
}

abstract final class AppRadius {
  static const control = 8.0;
  static const card = 12.0;
  static const dialog = 16.0;
}
