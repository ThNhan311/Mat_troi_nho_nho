
import 'package:flutter/material.dart';

import 'screens/home_page.dart';
import 'screens/login_page.dart';
import 'theme/app_theme.dart';
import 'package:flutter/services.dart';

void main() {
  runApp(const FitCenterApp());
}

class FitCenterApp extends StatefulWidget {
  const FitCenterApp({super.key});

  @override
  State<FitCenterApp> createState() => _FitCenterAppState();
}

class _FitCenterAppState extends State<FitCenterApp> {
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
      title: 'FitCenter',
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
      home: LoginPageWrapper(
        isDark: _themeMode == ThemeMode.dark,
        onToggleTheme: _toggleTheme,
      ),
    );

  }
}

class LoginPageWrapper extends StatelessWidget {
  final bool isDark;
  final ValueChanged<bool> onToggleTheme;

  const LoginPageWrapper({
    super.key,
    required this.isDark,
    required this.onToggleTheme,
  });

  void _openDemo(BuildContext context) {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => HomePage(
          isDark: isDark,
          onToggleTheme: onToggleTheme,
          onLogout: () {
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute<void>(
                builder: (_) => LoginPageWrapper(
                  isDark: isDark,
                  onToggleTheme: onToggleTheme,
                ),
              ),
                  (route) => false,
            );
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LoginPage(
      onOpenDemo: () => _openDemo(context),
    );
  }
}
