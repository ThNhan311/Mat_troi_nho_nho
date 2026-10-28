import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'theme/app_theme.dart';
import 'screens/home_page.dart';

void main() {
  runApp(const FitCenterAdminApp());
}

class FitCenterAdminApp extends StatefulWidget {
  const FitCenterAdminApp({super.key});

  @override
  State<FitCenterAdminApp> createState() => _FitCenterAdminAppState();
}

class _FitCenterAdminAppState extends State<FitCenterAdminApp> {
  ThemeMode _themeMode = ThemeMode.dark;

  void _toggleTheme(bool isDark) {
    setState(() {
      _themeMode = isDark ? ThemeMode.dark : ThemeMode.light;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'FitCenter Admin',

      theme: AppTheme.lightTheme.copyWith(
        appBarTheme: const AppBarTheme(
          systemOverlayStyle: SystemUiOverlayStyle.dark,
        ),
      ),

      darkTheme: AppTheme.darkTheme.copyWith(
        appBarTheme: const AppBarTheme(
          systemOverlayStyle: SystemUiOverlayStyle.light,
        ),
      ),

      themeMode: _themeMode,

      home: AdminHomePage(
        isDark: _themeMode == ThemeMode.dark,
        onToggleTheme: _toggleTheme,
      ),
    );
  }
}