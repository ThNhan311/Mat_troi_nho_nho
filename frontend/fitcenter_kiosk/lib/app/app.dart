import 'package:flutter/material.dart';

import '../features/kiosk/kiosk_page.dart';
import 'theme.dart';

class FitCenterApp extends StatelessWidget {
  const FitCenterApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FitCenter Kiosk',
      debugShowCheckedModeBanner: false,
      theme: FitCenterTheme.light,
      home: const KioskPage(),
    );
  }
}