import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';

/// Put this file at lib/theme/glass_theme.dart
class GlassTheme {
  static ThemeData light() => _build(Brightness.light);
  static ThemeData dark() => _build(Brightness.dark);

  static Color glass(Brightness b) =>
      b == Brightness.dark ? Colors.white.withAlpha(24) : Colors.white.withAlpha(150);

  static Color edge(Brightness b) =>
      b == Brightness.dark ? Colors.white.withAlpha(40) : Colors.white.withAlpha(210);

  static ThemeData _build(Brightness b) {
    final dark = b == Brightness.dark;
    final scheme = ColorScheme.fromSeed(
        seedColor: const Color(0xFF0A84FF), brightness: b);
    final g = glass(b), e = edge(b);

    OutlineInputBorder field(Color c, [double w = 1]) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: c, width: w));

    final buttonShape =
    RoundedRectangleBorder(borderRadius: BorderRadius.circular(16));

    return ThemeData(
      useMaterial3: true,
      brightness: b,
      colorScheme: scheme,
      scaffoldBackgroundColor: Colors.transparent,
      canvasColor: Colors.transparent,
      pageTransitionsTheme: PageTransitionsTheme(builders: {
        for (final p in TargetPlatform.values) p: const _GlassTransitions(),
      }),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: scheme.onSurface),
      ),
      cardTheme: CardThemeData(
        color: g,
        elevation: 0,
        shadowColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        margin: const EdgeInsets.symmetric(vertical: 4),
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
            side: BorderSide(color: e)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: g,
        border: field(e),
        enabledBorder: field(e),
        focusedBorder: field(scheme.primary, 1.6),
        errorBorder: field(scheme.error),
        focusedErrorBorder: field(scheme.error, 1.6),
        disabledBorder: field(e.withAlpha(60)),
      ),
      filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
              shape: buttonShape,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14))),
      outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
              shape: buttonShape,
              backgroundColor: g,
              side: BorderSide(color: e),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14))),
      textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(shape: buttonShape)),
      chipTheme: ChipThemeData(
        backgroundColor: g,
        side: BorderSide(color: e),
        shape: const StadiumBorder(),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surface.withAlpha(dark ? 235 : 240),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
            side: BorderSide(color: e)),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surface.withAlpha(dark ? 240 : 245),
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      expansionTileTheme: const ExpansionTileThemeData(
        shape: Border(),
        collapsedShape: Border(),
      ),
      dividerTheme: DividerThemeData(color: e.withAlpha(90)),
    );
  }
}

/// Soft gradient with colour glows. Every page is wrapped in this
/// automatically by the page transition below.
class GlassBackground extends StatelessWidget {
  final Widget child;
  const GlassBackground({super.key, required this.child});

  // Widget _glow(Color c, double size,
  //     {double? top, double? left, double? right, double? bottom}) =>
  //     Positioned(
  //       top: top,
  //       left: left,
  //       right: right,
  //       bottom: bottom,
  //       child: IgnorePointer(
  //         child: Container(
  //           width: size,
  //           height: size,
  //           decoration: BoxDecoration(
  //               shape: BoxShape.circle,
  //               gradient: RadialGradient(colors: [c, c.withAlpha(0)])),
  //         ),
  //       ),
  //     );

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: dark
              ? const [Color(0xFF0B1020), Color(0xFF121A3C), Color(0xFF1C1033)]
              : const [Color(0xFFE6F0FF), Color(0xFFF2E8FF), Color(0xFFE4FAF3)],
        ),
      ),
      child: Stack(fit: StackFit.expand, children: [
        Positioned.fill(child: child),
      ]),
    );
  }
}

/// iOS-style slide, with the glass background baked into every page so
/// pages never show through each other while animating.
class _GlassTransitions extends PageTransitionsBuilder {
  const _GlassTransitions();

  @override
  Widget buildTransitions<T>(
      PageRoute<T> route,
      BuildContext context,
      Animation<double> animation,
      Animation<double> secondaryAnimation,
      Widget child,
      ) => CupertinoPageTransitionsBuilder().buildTransitions<T>(
          route, context, animation, secondaryAnimation,
          GlassBackground(child: child));
}

/// Frosted card with a real blur. Use in place of Card(...) where you want
/// the full glass effect.
class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry margin;
  final double radius;

  const GlassCard({
    super.key,
    required this.child,
    this.margin = const EdgeInsets.symmetric(vertical: 4),
    this.radius = 22,
  });

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    final r = BorderRadius.circular(radius);
    return Padding(
      padding: margin,
      child: ClipRRect(
        borderRadius: r,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: Container(
            decoration: BoxDecoration(
              color: GlassTheme.glass(b),
              borderRadius: r,
              border: Border.all(color: GlassTheme.edge(b)),
            ),
            child: Material(type: MaterialType.transparency, child: child),
          ),
        ),
      ),
    );
  }
}
