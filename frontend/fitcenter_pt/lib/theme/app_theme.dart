import 'package:flutter/material.dart';

class AppColors {
  // Giao diện tối
  static const Color background = Color(0xFF101410);
  static const Color green = Color(0xFFB6F36B);
  static const Color cardColor = Color(0xFF20271F);
  static const Color darkText = Color(0xFF101410);

  // Giao diện sáng
  static const Color lightBackground = Color(0xFFF5F7F2);
  static const Color lightCardColor = Color(0xFFFFFFFF);
  static const Color lightText = Color(0xFF20271F);
  static const Color lightGreen = Color(0xFF3F512F);

  // Màu trung tính cho icon và viền
  static const Color lightIcon = Color(0xFF737B87);
  static const Color lightIconBackground = Color(0xFFF0F1F3);

  // Xanh dịu hơn cho icon trong giao diện tối
  static const Color darkIcon = Color(0xFF9DBB78);
}

class AppTheme {
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.background,

      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.green,
        brightness: Brightness.dark,
        surface: AppColors.cardColor,
      ).copyWith(primary: AppColors.darkIcon, secondary: AppColors.darkIcon),

      fontFamily: 'Roboto',

      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.background,
        foregroundColor: Colors.white,
      ),

      cardTheme: const CardThemeData(color: AppColors.cardColor),

      textTheme: const TextTheme(
        bodyLarge: TextStyle(color: Colors.white),
        bodyMedium: TextStyle(color: Colors.white),
        bodySmall: TextStyle(color: Colors.white70),
        titleLarge: TextStyle(color: Colors.white),
        titleMedium: TextStyle(color: Colors.white),
        titleSmall: TextStyle(color: Colors.white),
      ),

      iconTheme: const IconThemeData(color: AppColors.darkIcon),
    );
  }

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: AppColors.lightBackground,

      colorScheme:
          ColorScheme.fromSeed(
            seedColor: AppColors.lightGreen,
            brightness: Brightness.light,
            surface: AppColors.lightCardColor,
          ).copyWith(
            primary: AppColors.lightGreen,
            secondary: AppColors.lightGreen,
          ),

      fontFamily: 'Roboto',

      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.lightBackground,
        foregroundColor: AppColors.lightText,
      ),

      cardTheme: const CardThemeData(color: AppColors.lightCardColor),

      textTheme: const TextTheme(
        bodyLarge: TextStyle(color: AppColors.lightText),
        bodyMedium: TextStyle(color: AppColors.lightText),
        bodySmall: TextStyle(color: Colors.black54),
        titleLarge: TextStyle(color: AppColors.lightText),
        titleMedium: TextStyle(color: AppColors.lightText),
        titleSmall: TextStyle(color: AppColors.lightText),
      ),

      iconTheme: const IconThemeData(color: AppColors.lightIcon),
    );
  }
}
