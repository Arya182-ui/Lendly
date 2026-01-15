import 'package:flutter/material.dart';

/// Lendly App Color Palette - Modern & Professional Design System
class AppColors {
  // Primary Brand Colors
  static const Color primary = Color(0xFF1DBF73);
  static const Color primaryDark = Color(0xFF0D9488);
  static const Color primaryLight = Color(0xFF6EE7B7);
  static const Color primarySurface = Color(0xFFECFDF5);
  
  // Secondary Colors
  static const Color secondary = Color(0xFF6366F1);
  static const Color secondaryDark = Color(0xFF4F46E5);
  static const Color secondaryLight = Color(0xFFA5B4FC);
  static const Color secondarySurface = Color(0xFFEEF2FF);
  
  // Accent Colors
  static const Color accent = Color(0xFF8B5CF6);
  static const Color accentPink = Color(0xFFEC4899);
  static const Color accentOrange = Color(0xFFF59E0B);
  static const Color accentCyan = Color(0xFF06B6D4);
  
  // Semantic Colors
  static const Color success = Color(0xFF10B981);
  static const Color successSurface = Color(0xFFD1FAE5);
  static const Color warning = Color(0xFFF59E0B);
  static const Color warningSurface = Color(0xFFFEF3C7);
  static const Color error = Color(0xFFEF4444);
  static const Color errorSurface = Color(0xFFFEE2E2);
  static const Color info = Color(0xFF3B82F6);
  static const Color infoSurface = Color(0xFFDBEAFE);
  
  // Neutral Colors - Light Mode
  static const Color backgroundLight = Color(0xFFF8FAFC);
  static const Color surfaceLight = Color(0xFFFFFFFF);
  static const Color cardLight = Color(0xFFFFFFFF);
  static const Color borderLight = Color(0xFFE2E8F0);
  static const Color dividerLight = Color(0xFFF1F5F9);
  
  // Text Colors - Light Mode
  static const Color textPrimaryLight = Color(0xFF0F172A);
  static const Color textSecondaryLight = Color(0xFF475569);
  static const Color textTertiaryLight = Color(0xFF94A3B8);
  static const Color textMutedLight = Color(0xFF94A3B8); // Alias for tertiary
  static const Color textDisabledLight = Color(0xFFCBD5E1);
  
  // Neutral Colors - Dark Mode
  static const Color backgroundDark = Color(0xFF0F172A);
  static const Color surfaceDark = Color(0xFF1E293B);
  static const Color cardDark = Color(0xFF334155);
  static const Color borderDark = Color(0xFF475569);
  static const Color dividerDark = Color(0xFF334155);
  
  // Text Colors - Dark Mode
  static const Color textPrimaryDark = Color(0xFFF8FAFC);
  static const Color textSecondaryDark = Color(0xFFCBD5E1);
  static const Color textTertiaryDark = Color(0xFF94A3B8);
  static const Color textDisabledDark = Color(0xFF64748B);
  
  // Gradient Presets
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primary, primaryDark],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  
  static const LinearGradient secondaryGradient = LinearGradient(
    colors: [secondary, accent],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  
  static const LinearGradient successGradient = LinearGradient(
    colors: [success, Color(0xFF059669)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  
  static const LinearGradient warmGradient = LinearGradient(
    colors: [Color(0xFFFF6B6B), Color(0xFFFFE66D)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  
  static const LinearGradient coolGradient = LinearGradient(
    colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  
  static const LinearGradient sunsetGradient = LinearGradient(
    colors: [Color(0xFFFA709A), Color(0xFFFEE140)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  
  // Category Colors
  static const Color categoryBooks = Color(0xFF6366F1);
  static const Color categoryElectronics = Color(0xFF10B981);
  static const Color categorySports = Color(0xFFF59E0B);
  static const Color categoryTools = Color(0xFFEF4444);
  static const Color categoryGaming = Color(0xFF8B5CF6);
  static const Color categoryMusic = Color(0xFFEC4899);
  static const Color categoryClothing = Color(0xFF06B6D4);
  static const Color categoryOther = Color(0xFF6B7280);
  
  // Shadow Colors
  static Color shadowLight = Colors.black.withValues(alpha: 0.08);
  static Color shadowMedium = Colors.black.withValues(alpha: 0.12);
  static Color shadowDark = Colors.black.withValues(alpha: 0.16);
  
  // Overlay Colors
  static Color overlayLight = Colors.white.withValues(alpha: 0.8);
  static Color overlayDark = Colors.black.withValues(alpha: 0.5);
  
  // Glass Effect Colors
  static Color glassWhite = Colors.white.withValues(alpha: 0.15);
  static Color glassBorder = Colors.white.withValues(alpha: 0.2);
}
