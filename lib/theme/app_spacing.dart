import 'package:flutter/material.dart';

/// Lendly Spacing System - 8-Point Grid
/// Ensures consistent spacing across all components
class AppSpacing {
  // Core Spacing Scale (8-point grid)
  static const double xs = 4.0;   // Micro spacing, borders, icons
  static const double sm = 8.0;   // Tight spacing, form elements
  static const double md = 16.0;  // Standard spacing, card padding
  static const double lg = 24.0;  // Section spacing, major gaps
  static const double xl = 32.0;  // Major sections, screen margins
  static const double xxl = 48.0; // Hero sections, major breaks
  
  // Legacy alias properties for compatibility
  static const EdgeInsets paddingMd = EdgeInsets.all(md);
  static const EdgeInsets paddingLg = EdgeInsets.all(lg);
  static const Widget verticalXs = SizedBox(height: xs);
  static const Widget verticalSm = SizedBox(height: sm);
  static const Widget verticalMd = SizedBox(height: md);
  static const Widget verticalLg = SizedBox(height: lg);
  static const Widget verticalXl = SizedBox(height: xl);
  static const Widget horizontalXs = SizedBox(width: xs);
  static const Widget horizontalSm = SizedBox(width: sm);
  static const Widget horizontalMd = SizedBox(width: md);
  static const Widget horizontalLg = SizedBox(width: lg);
  
  // Common Edge Insets
  static const EdgeInsets screenPadding = EdgeInsets.all(md);
  static const EdgeInsets cardPadding = EdgeInsets.all(md);
  static const EdgeInsets sectionPadding = EdgeInsets.symmetric(vertical: lg);
  static const EdgeInsets itemPadding = EdgeInsets.symmetric(vertical: sm, horizontal: md);
  
  // Common SizedBox widgets
  static const Widget gapXs = SizedBox(height: xs, width: xs);
  static const Widget gapSm = SizedBox(height: sm, width: sm);
  static const Widget gapMd = SizedBox(height: md, width: md);
  static const Widget gapLg = SizedBox(height: lg, width: lg);
  static const Widget gapXl = SizedBox(height: xl, width: xl);
  
  // Horizontal gaps
  static const Widget hGapXs = SizedBox(width: xs);
  static const Widget hGapSm = SizedBox(width: sm);
  static const Widget hGapMd = SizedBox(width: md);
  static const Widget hGapLg = SizedBox(width: lg);
  
  // Vertical gaps
  static const Widget vGapXs = SizedBox(height: xs);
  static const Widget vGapSm = SizedBox(height: sm);
  static const Widget vGapMd = SizedBox(height: md);
  static const Widget vGapLg = SizedBox(height: lg);
}
