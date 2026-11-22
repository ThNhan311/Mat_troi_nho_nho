import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'services/api_client.dart';
import 'services/booking_service.dart';
import 'screens/home_page.dart';
import 'screens/login_page.dart';
import 'theme/app_theme.dart';

void main() => runApp(const FitCenterApp());

class FitCenterApp extends StatefulWidget {
  final ApiClient? api;
  const FitCenterApp({super.key, this.api});
  @override
  State<FitCenterApp> createState() => _FitCenterAppState();
}

class _FitCenterAppState extends State<FitCenterApp> {
  late final ApiClient api = widget.api ?? ApiClient(expectedRole: 'MEMBER');
  ThemeMode mode = ThemeMode.dark;
  void toggle(bool dark) =>
      setState(() => mode = dark ? ThemeMode.dark : ThemeMode.light);
  @override
  void dispose() {
    if (widget.api == null) api.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
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
    themeMode: mode,
    home: AnimatedBuilder(
      animation: api,
      builder: (context, _) => api.authenticated
          ? Navigator(
              key: ValueKey('session-${api.sessionEpoch}'),
              onGenerateRoute: (_) => MaterialPageRoute<void>(
                builder: (_) => HomePage(
                  service: BookingService(api),
                  onLogout: api.logout,
                  isDark: mode == ThemeMode.dark,
                  onToggleTheme: toggle,
                ),
              ),
            )
          : LoginPage(api: api),
    ),
  );
}
