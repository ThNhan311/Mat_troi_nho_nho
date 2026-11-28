import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Bảng màu "Sage": nền xanh xô thơm, thẻ trắng, điểm nhấn olive đậm.
class AppColors {
  // Giao diện sáng
  static const Color ink = Color(0xFF1A2016);
  static const Color inkSoft = Color(0xFF4F5848);
  static const Color olive = Color(0xFF3F5230);
  static const Color oliveSoft = Color(0xFFDDE5D1);
  static const Color moss = Color(0xFF5C6E45);
  static const List<Color> lightBackdrop = [
    Color(0xFFA9B59D),
    Color(0xFFCDD5C4),
    Color(0xFFEDEFE9),
  ];

  // Giao diện tối
  static const Color night = Color(0xFF12150F);
  static const Color nightCard = Color(0xFF22281D);
  static const Color mist = Color(0xFFE9EEE2);
  static const Color mistSoft = Color(0xFFB4BCA9);
  static const Color leaf = Color(0xFFBCD09E);
  static const List<Color> darkBackdrop = [
    Color(0xFF2F3B27),
    Color(0xFF1C2317),
    night,
  ];
}

/// Nền chuyển màu nằm sau mọi trang. Scaffold để trong suốt nên thấy được nền.
class AppBackdrop extends StatelessWidget {
  const AppBackdrop({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        stops: const [0, 0.28, 0.65],
        colors: Theme.of(context).brightness == Brightness.dark
            ? AppColors.darkBackdrop
            : AppColors.lightBackdrop,
      ),
    ),
    child: child,
  );
}

/// Mỗi trang được vẽ kèm nền riêng để trang cũ không lộ qua khi chuyển trang.
class _BackdropTransitions extends PageTransitionsBuilder {
  const _BackdropTransitions();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final curved = CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutCubic,
    );
    return FadeTransition(
      opacity: curved,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.02),
          end: Offset.zero,
        ).animate(curved),
        child: AppBackdrop(child: child),
      ),
    );
  }
}

class AppTheme {
  static ThemeData get lightTheme => _build(
    const ColorScheme(
      brightness: Brightness.light,
      primary: AppColors.olive,
      onPrimary: Colors.white,
      primaryContainer: AppColors.oliveSoft,
      onPrimaryContainer: Color(0xFF25331A),
      secondary: AppColors.moss,
      onSecondary: Colors.white,
      secondaryContainer: AppColors.oliveSoft,
      onSecondaryContainer: Color(0xFF25331A),
      tertiary: Color(0xFF1C2119),
      onTertiary: Colors.white,
      error: Color(0xFFA63D2A),
      onError: Colors.white,
      errorContainer: Color(0xFFF7DDD6),
      onErrorContainer: Color(0xFF5A1B0F),
      surface: Color(0xFFFDFEFB),
      onSurface: AppColors.ink,
      onSurfaceVariant: AppColors.inkSoft,
      surfaceContainerLowest: Colors.white,
      surfaceContainerLow: Color(0xFFFAFBF7),
      surfaceContainer: Color(0xFFF5F7F1),
      surfaceContainerHigh: Color(0xFFF1F4EC),
      surfaceContainerHighest: Color(0xFFF7F9F3),
      outline: Color(0xFF8D9682),
      outlineVariant: Color(0xFFD8DDCF),
      inverseSurface: Color(0xFF1C2119),
      onInverseSurface: Color(0xFFF1F4EC),
      inversePrimary: AppColors.leaf,
      surfaceTint: Colors.transparent,
    ),
  );

  static ThemeData get darkTheme => _build(
    const ColorScheme(
      brightness: Brightness.dark,
      primary: AppColors.leaf,
      onPrimary: Color(0xFF1D2912),
      primaryContainer: Color(0xFF3B4A2C),
      onPrimaryContainer: Color(0xFFDDE9C8),
      secondary: Color(0xFFA7BA8B),
      onSecondary: Color(0xFF1D2912),
      secondaryContainer: Color(0xFF3B4A2C),
      onSecondaryContainer: Color(0xFFDDE9C8),
      tertiary: AppColors.mist,
      onTertiary: Color(0xFF1C2119),
      error: Color(0xFFF2A08C),
      onError: Color(0xFF4A150A),
      errorContainer: Color(0xFF6B2819),
      onErrorContainer: Color(0xFFF9DCD3),
      surface: AppColors.nightCard,
      onSurface: AppColors.mist,
      onSurfaceVariant: AppColors.mistSoft,
      surfaceContainerLowest: Color(0xFF171B13),
      surfaceContainerLow: Color(0xFF1D2218),
      surfaceContainer: Color(0xFF252B1F),
      surfaceContainerHigh: Color(0xFF2B3225),
      surfaceContainerHighest: Color(0xFF293023),
      outline: Color(0xFF808A74),
      outlineVariant: Color(0xFF3A4232),
      inverseSurface: AppColors.mist,
      onInverseSurface: Color(0xFF1C2119),
      inversePrimary: AppColors.olive,
      surfaceTint: Colors.transparent,
    ),
  );

  static ThemeData _build(ColorScheme colors) {
    final isDark = colors.brightness == Brightness.dark;
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: colors,
      fontFamily: 'Roboto',
    );
    final text = base.textTheme.apply(
      bodyColor: colors.onSurface,
      displayColor: colors.onSurface,
    );
    const pill = StadiumBorder();
    const buttonSize = Size(64, 48);
    const buttonPadding = EdgeInsets.symmetric(horizontal: 22, vertical: 14);
    const buttonText = TextStyle(
      fontFamily: 'Roboto',
      fontSize: 15,
      fontWeight: FontWeight.w600,
    );
    OutlineInputBorder field(Color color, [double width = 1]) =>
        OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide(color: color, width: width),
        );

    return base.copyWith(
      textTheme: text,
      scaffoldBackgroundColor: Colors.transparent,
      pageTransitionsTheme: PageTransitionsTheme(
        builders: {
          for (final platform in TargetPlatform.values)
            platform: const _BackdropTransitions(),
        },
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: colors.onSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        systemOverlayStyle: isDark
            ? SystemUiOverlayStyle.light
            : SystemUiOverlayStyle.dark,
        titleTextStyle: TextStyle(
          fontFamily: 'Roboto',
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: colors.onSurface,
        ),
      ),
      cardTheme: CardThemeData(
        color: colors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
      iconTheme: IconThemeData(color: colors.primary),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: colors.primary,
          foregroundColor: colors.onPrimary,
          elevation: 0,
          minimumSize: buttonSize,
          padding: buttonPadding,
          shape: pill,
          textStyle: buttonText,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: buttonSize,
          padding: buttonPadding,
          shape: pill,
          textStyle: buttonText,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          backgroundColor: colors.surface,
          foregroundColor: colors.primary,
          side: BorderSide(color: colors.outlineVariant),
          minimumSize: buttonSize,
          padding: buttonPadding,
          shape: pill,
          textStyle: buttonText,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(shape: pill, textStyle: buttonText),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: colors.primary,
        foregroundColor: colors.onPrimary,
        shape: pill,
      ),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: colors.surface,
        selectedColor: colors.primaryContainer,
        side: BorderSide(color: colors.outlineVariant),
        shape: pill,
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: SegmentedButton.styleFrom(
          backgroundColor: colors.surface,
          selectedBackgroundColor: colors.primary,
          selectedForegroundColor: colors.onPrimary,
          side: BorderSide(color: colors.outlineVariant),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colors.surfaceContainerLowest,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 18,
        ),
        border: field(colors.outlineVariant),
        enabledBorder: field(colors.outlineVariant),
        disabledBorder: field(colors.outlineVariant.withValues(alpha: 0.5)),
        focusedBorder: field(colors.primary, 1.6),
        errorBorder: field(colors.error),
        focusedErrorBorder: field(colors.error, 1.6),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: colors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: colors.surface,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: colors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: colors.inverseSurface,
        contentTextStyle: TextStyle(
          fontFamily: 'Roboto',
          color: colors.onInverseSurface,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: colors.primary,
        unselectedLabelColor: colors.onSurfaceVariant,
        indicatorColor: colors.primary,
        dividerColor: Colors.transparent,
      ),
      dividerTheme: DividerThemeData(color: colors.outlineVariant),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: colors.primary,
        linearTrackColor: colors.primaryContainer,
      ),
    );
  }
}
