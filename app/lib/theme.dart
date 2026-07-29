import 'package:flutter/material.dart';

/// 카테고리별 색. 피드에서 한눈에 구분되게 하는 게 목적이라
/// 채도는 높지 않게, 라이트/다크 양쪽에서 읽히도록 골랐다.
class CategoryStyle {
  final Color light;
  final Color dark;
  const CategoryStyle(this.light, this.dark);

  static const _map = {
    '속보': CategoryStyle(Color(0xFFD93F26), Color(0xFFFF8A6B)),
    '중요': CategoryStyle(Color(0xFF2C5FD9), Color(0xFF7DA5FF)),
    '참고': CategoryStyle(Color(0xFF5A6472), Color(0xFF9AA5B4)),
    '팁': CategoryStyle(Color(0xFF1E8C5A), Color(0xFF5FD39B)),
  };

  static Color of(String category, Brightness brightness) {
    final style = _map[category] ?? _map['참고']!;
    return brightness == Brightness.dark ? style.dark : style.light;
  }
}

ThemeData buildTheme(Brightness brightness) {
  final isDark = brightness == Brightness.dark;
  final scheme = ColorScheme.fromSeed(
    seedColor: const Color(0xFF2C5FD9),
    brightness: brightness,
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: isDark ? const Color(0xFF101215) : const Color(0xFFF7F8FA),
    appBarTheme: AppBarTheme(
      backgroundColor: isDark ? const Color(0xFF101215) : Colors.white,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0.5,
      centerTitle: false,
      titleTextStyle: TextStyle(
        color: scheme.onSurface,
        fontSize: 19,
        fontWeight: FontWeight.w700,
      ),
    ),
    cardTheme: CardThemeData(
      color: isDark ? const Color(0xFF191C21) : Colors.white,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
    dividerTheme: DividerThemeData(
      color: isDark ? const Color(0xFF262A31) : const Color(0xFFE6E8EC),
      thickness: 1,
      space: 1,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: isDark ? const Color(0xFF16191D) : Colors.white,
      surfaceTintColor: Colors.transparent,
      indicatorColor: scheme.primary.withValues(alpha: 0.14),
      height: 64,
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
    ),
    chipTheme: ChipThemeData(
      side: BorderSide(
        color: isDark ? const Color(0xFF2E333A) : const Color(0xFFDDE1E6),
      ),
      backgroundColor: Colors.transparent,
      labelStyle: TextStyle(fontSize: 13, color: scheme.onSurface),
      padding: const EdgeInsets.symmetric(horizontal: 4),
    ),
  );
}
