import 'package:flutter/material.dart';

class Pal {
  final Color bg, surface, ink, muted, line, pond, lotus, gold, onAccent;
  const Pal(this.bg, this.surface, this.ink, this.muted, this.line, this.pond, this.lotus, this.gold, this.onAccent);

  static const light = Pal(
    Color(0xFFECF0EA), Color(0xFFF8FAF6), Color(0xFF17231F), Color(0xFF5A6A63), Color(0xFFD2DBD3),
    Color(0xFF2F5D57), Color(0xFFB0446A), Color(0xFF8F6D2C), Color(0xFFF8FAF6),
  );
  static const dark = Pal(
    Color(0xFF0D1615), Color(0xFF14211F), Color(0xFFE3EBE5), Color(0xFF93A59D), Color(0xFF263837),
    Color(0xFF82BAB0), Color(0xFFE58BAB), Color(0xFFD2B06C), Color(0xFF0D1615),
  );

  static Pal of(BuildContext c) => Theme.of(c).brightness == Brightness.dark ? dark : light;
}

const serif = 'NotoSerifThai';
const sans = 'PlexThai';
const cute = 'Mali';

ThemeData buildTheme(Brightness b) {
  final p = b == Brightness.dark ? Pal.dark : Pal.light;
  final scheme = ColorScheme.fromSeed(seedColor: p.pond, brightness: b).copyWith(
    primary: p.pond,
    onPrimary: p.onAccent,
    secondary: p.lotus,
    surface: p.surface,
    onSurface: p.ink,
    outline: p.line,
  );
  final base = ThemeData(useMaterial3: true, colorScheme: scheme, fontFamily: sans, brightness: b);
  return base.copyWith(
    scaffoldBackgroundColor: p.bg,
    textTheme: base.textTheme.apply(bodyColor: p.ink, displayColor: p.ink),
    cardTheme: CardThemeData(
      color: p.surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18), side: BorderSide(color: p.line)),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: p.surface,
      indicatorColor: p.lotus.withValues(alpha: .18),
      labelTextStyle: WidgetStatePropertyAll(TextStyle(fontFamily: sans, fontSize: 12, color: p.ink)),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: p.bg,
      selectedColor: p.ink,
      labelStyle: TextStyle(fontFamily: sans, color: p.ink, fontSize: 13),
      secondaryLabelStyle: TextStyle(fontFamily: sans, color: p.bg, fontSize: 13),
      side: BorderSide(color: p.line),
      shape: const StadiumBorder(),
      checkmarkColor: p.bg,
    ),
    bottomSheetTheme: BottomSheetThemeData(backgroundColor: p.surface, showDragHandle: true),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(backgroundColor: p.pond, foregroundColor: p.onAccent, textStyle: const TextStyle(fontFamily: sans, fontWeight: FontWeight.w600)),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: p.ink,
      contentTextStyle: TextStyle(fontFamily: sans, color: p.bg),
      shape: const StadiumBorder(),
    ),
  );
}

TextStyle eyebrow(BuildContext c) => TextStyle(fontSize: 12.5, letterSpacing: .6, color: Pal.of(c).muted);
TextStyle number(BuildContext c, double size) =>
    TextStyle(fontFamily: sans, fontSize: size, fontWeight: FontWeight.w600, height: 1.2, color: Pal.of(c).ink);
TextStyle display(BuildContext c, double size) =>
    TextStyle(fontFamily: cute, fontSize: size, fontWeight: FontWeight.w600, height: 1.4, color: Pal.of(c).ink);
