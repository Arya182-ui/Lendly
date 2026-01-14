// Component Library Usage Guide
// Import standardized components for consistent UI

// BUTTONS
import '../widgets/lendly_buttons.dart';
// Usage:
// LendlyPrimaryButton(text: 'Send Loan Request', onPressed: () {})
// LendlySecondaryButton(text: 'Cancel', onPressed: () {})
// LendlyTextButton(text: 'Learn More', onPressed: () {})

// CARDS
import '../widgets/lendly_cards.dart';
// Usage:
// LendlyCard(child: YourContent())
// LendlyItemCard(title: 'Loan Request', subtitle: '\$500', onTap: () {})

// COLORS
import '../theme/app_colors.dart';
// Usage:
// AppColors.primary, AppColors.secondary, AppColors.success
// Color(AppColors.primaryValue), AppColors.primarySwatch

// SPACING
import '../theme/app_spacing.dart';
// Usage:
// AppSpacing.md, AppSpacing.paddingMd, AppSpacing.verticalMd
// SizedBox(height: AppSpacing.lg)

// TEXT STYLES
import '../theme/app_text_styles.dart';
// Usage:
// AppTextStyles.hero, AppTextStyles.heading, AppTextStyles.body

// EXAMPLE SCREEN TEMPLATE
/*
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';
import '../widgets/lendly_buttons.dart';
import '../widgets/lendly_cards.dart';

class ExampleScreen extends StatefulWidget {
  @override
  _ExampleScreenState createState() => _ExampleScreenState();
}

class _ExampleScreenState extends State<ExampleScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          'Screen Title',
          style: AppTextStyles.heading,
        ),
        backgroundColor: AppColors.surface,
        elevation: 0,
        iconTheme: IconThemeData(color: AppColors.onSurface),
      ),
      body: SingleChildScrollView(
        padding: AppSpacing.paddingLg,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Section
            Text(
              'Welcome to Lendly',
              style: AppTextStyles.hero.copyWith(
                color: AppColors.primary,
              ),
            ),
            AppSpacing.verticalMd,
            
            // Content Card
            LendlyCard(
              child: Padding(
                padding: AppSpacing.paddingMd,
                child: Column(
                  children: [
                    Text(
                      'Card Title',
                      style: AppTextStyles.subheading,
                    ),
                    AppSpacing.verticalSm,
                    Text(
                      'Card content goes here with proper spacing and typography.',
                      style: AppTextStyles.body,
                    ),
                  ],
                ),
              ),
            ),
            AppSpacing.verticalLg,
            
            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: LendlyPrimaryButton(
                    text: 'Primary Action',
                    onPressed: () {
                      // Handle primary action
                    },
                  ),
                ),
                AppSpacing.horizontalMd,
                Expanded(
                  child: LendlySecondaryButton(
                    text: 'Secondary',
                    onPressed: () {
                      // Handle secondary action
                    },
                  ),
                ),
              ],
            ),
            AppSpacing.verticalMd,
            
            // Text Button
            Center(
              child: LendlyTextButton(
                text: 'Learn More',
                onPressed: () {
                  // Handle text button action
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
*/