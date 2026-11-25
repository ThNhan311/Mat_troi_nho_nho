import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'theme/app_theme.dart';
import 'screens/home_page.dart';
import 'screens/login_page.dart';
import 'services/api_client.dart';
import 'services/booking_policy_service.dart';
import 'services/membership_plan_service.dart';

void main() {
  runApp(const FitCenterAdminApp());
}

class FitCenterAdminApp extends StatefulWidget {
  final ApiClient? api;
  const FitCenterAdminApp({super.key, this.api});

  @override
  State<FitCenterAdminApp> createState() => _FitCenterAdminAppState();
}

class _FitCenterAdminAppState extends State<FitCenterAdminApp> {
  late final ApiClient api = widget.api ?? ApiClient(expectedRole: 'ADMIN');
  @override
  void dispose() {
    if (widget.api == null) api.dispose();
    super.dispose();
  }

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

      home: AnimatedBuilder(
        animation: api,
        builder: (context, _) => api.authenticated
            ? Navigator(
                key: ValueKey('session-${api.sessionEpoch}'),
                onGenerateRoute: (_) => MaterialPageRoute<void>(
                  builder: (_) => AdminHomePage(
                    service: BookingPolicyService(api),
                    plans: MembershipPlanService(api),
                    onLogout: api.logout,
                    isDark: _themeMode == ThemeMode.dark,
                    onToggleTheme: _toggleTheme,
                  ),
                ),
              )
            : LoginPage(api: api),
      ),
    );
  }
}
