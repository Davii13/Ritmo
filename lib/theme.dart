import 'package:flutter/material.dart';

import 'models/item.dart';

const _seed = Color(0xFF0F766E);

ThemeData buildTheme(Brightness brightness) {
  final dark = brightness == Brightness.dark;
  final scheme = ColorScheme.fromSeed(seedColor: _seed, brightness: brightness);
  final radius = BorderRadius.circular(14);

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor:
        dark ? const Color(0xFF0D1311) : const Color(0xFFF3F6F5),
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.w700,
        color: scheme.onSurface,
      ),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: scheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.7)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: scheme.surface,
      border: OutlineInputBorder(
          borderRadius: radius, borderSide: BorderSide(color: scheme.outline)),
      enabledBorder: OutlineInputBorder(
          borderRadius: radius,
          borderSide: BorderSide(color: scheme.outlineVariant)),
      focusedBorder: OutlineInputBorder(
          borderRadius: radius,
          borderSide: BorderSide(color: scheme.primary, width: 2)),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: scheme.surface,
      indicatorColor: scheme.primaryContainer,
      labelTextStyle: WidgetStatePropertyAll(
          const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
    ),
    navigationRailTheme: NavigationRailThemeData(
      backgroundColor: scheme.surface,
      indicatorColor: scheme.primaryContainer,
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: scheme.primary,
      foregroundColor: scheme.onPrimary,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    chipTheme: ChipThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      side: BorderSide(color: scheme.outlineVariant),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: radius),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      ),
    ),
    dividerTheme: DividerThemeData(color: scheme.outlineVariant, space: 1),
  );
}

extension ItemKindStyle on ItemKind {
  IconData get icon => switch (this) {
        ItemKind.purchase => Icons.shopping_bag_rounded,
        ItemKind.work => Icons.work_rounded,
        ItemKind.task => Icons.check_circle_outline_rounded,
        ItemKind.recurring => Icons.event_repeat_rounded,
      };

  Color get color => switch (this) {
        ItemKind.purchase => const Color(0xFF8B5CF6),
        ItemKind.work => const Color(0xFF3B82F6),
        ItemKind.task => const Color(0xFF14B8A6),
        ItemKind.recurring => const Color(0xFFF97316),
      };
}

extension ItemPriorityStyle on ItemPriority {
  Color get color => switch (this) {
        ItemPriority.low => const Color(0xFF64748B),
        ItemPriority.medium => const Color(0xFFD97706),
        ItemPriority.high => const Color(0xFFDC2626),
      };

  IconData get icon => switch (this) {
        ItemPriority.low => Icons.keyboard_arrow_down_rounded,
        ItemPriority.medium => Icons.drag_handle_rounded,
        ItemPriority.high => Icons.keyboard_double_arrow_up_rounded,
      };
}

extension ItemStatusStyle on ItemStatus {
  IconData get icon => switch (this) {
        ItemStatus.pending => Icons.radio_button_unchecked_rounded,
        ItemStatus.inProgress => Icons.timelapse_rounded,
        ItemStatus.done => Icons.check_circle_rounded,
      };
}

const overdueColor = Color(0xFFDC2626);
