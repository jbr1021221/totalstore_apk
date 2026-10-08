import 'package:flutter/material.dart';

class C {
  static const primary = Color(0xFF000000);
  static const secondary = Color(0xFF007AFF);
  static const tertiary = Color(0xFF5856D6);
  static const neutral = Color(0xFF8E8E93);
  static const bg = Color(0xFFF7F6FB);
  static const card = Colors.white;
  static const line = Color(0xFFE6E5EC);
  static const chip = Color(0xFFEFEEF4);
  static const text = Color(0xFF1A1A1F);
  static const sub = Color(0xFF5E5E66);
  static const red = Color(0xFFD32F2F);
  static const orange = Color(0xFFF59E0B);
  static const green = Color(0xFF16A34A);
  static const purple = Color(0xFF8B5CF6);
}

ThemeData buildTheme() {
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(seedColor: C.secondary, primary: C.primary, surface: C.bg),
    scaffoldBackgroundColor: C.bg,
  );
  return base.copyWith(
    textTheme: base.textTheme.apply(bodyColor: C.text, displayColor: C.text),
    appBarTheme: const AppBarTheme(
      backgroundColor: C.bg,
      elevation: 0,
      scrolledUnderElevation: 0,
      foregroundColor: C.text,
    ),
  );
}

TextStyle mono([double size = 12, Color? color, FontWeight? w]) =>
    TextStyle(fontFamily: 'monospace', fontSize: size, color: color ?? C.text, fontWeight: w);

const taka = '৳';
