import 'package:flutter/material.dart';

final ThemeData lightTheme = ThemeData(
  colorScheme: const ColorScheme.light(
    primary: Color(0xFF2ecc71),
    secondary: Color(0xFF1a237e),
    background: Colors.white,
  ),
  scaffoldBackgroundColor: Colors.white,
  appBarTheme: const AppBarTheme(
    backgroundColor: Color(0xFF1a237e),
    foregroundColor: Colors.white,
  ),
  textTheme: const TextTheme(
    headlineLarge: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold, fontSize: 24),
    titleLarge: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold, fontSize: 20),
    bodyLarge: TextStyle(fontFamily: 'Inter', fontSize: 16),
    bodyMedium: TextStyle(fontFamily: 'Inter', fontSize: 14),
    labelLarge: TextStyle(fontFamily: 'Inter', fontSize: 12, fontWeight: FontWeight.w500),
  ),
  useMaterial3: true,
);

final ThemeData darkTheme = ThemeData(
  colorScheme: const ColorScheme.dark(
    primary: Color(0xFF2ecc71),
    secondary: Color(0xFF1a237e),
    background: Color(0xFF181A20),
  ),
  scaffoldBackgroundColor: const Color(0xFF181A20),
  appBarTheme: const AppBarTheme(
    backgroundColor: Color(0xFF23272F),
    foregroundColor: Colors.white,
  ),
  textTheme: const TextTheme(
    headlineLarge: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold, fontSize: 24, color: Colors.white),
    titleLarge: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold, fontSize: 20, color: Colors.white),
    bodyLarge: TextStyle(fontFamily: 'Inter', fontSize: 16, color: Colors.white),
    bodyMedium: TextStyle(fontFamily: 'Inter', fontSize: 14, color: Colors.white70),
    labelLarge: TextStyle(fontFamily: 'Inter', fontSize: 12, fontWeight: FontWeight.w500, color: Colors.white70),
  ),
  useMaterial3: true,
);
