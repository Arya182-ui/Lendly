import 'package:flutter/material.dart';
import 'dart:ui';
import 'app_colors.dart';
import 'app_shadows.dart';
import 'app_text_styles.dart';

/// Modern Card Designs for Lendly
class ModernCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double borderRadius;
  final Color? backgroundColor;
  final List<BoxShadow>? shadow;
  final Border? border;
  final Gradient? gradient;
  final VoidCallback? onTap;
  final bool enableHover;

  const ModernCard({
    Key? key,
    required this.child,
    this.padding,
    this.margin,
    this.borderRadius = 16,
    this.backgroundColor,
    this.shadow,
    this.border,
    this.gradient,
    this.onTap,
    this.enableHover = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      margin: margin,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(borderRadius),
          child: Container(
            padding: padding ?? const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: gradient == null 
                  ? (backgroundColor ?? (isDark ? AppColors.cardDark : AppColors.cardLight))
                  : null,
              gradient: gradient,
              borderRadius: BorderRadius.circular(borderRadius),
              border: border ?? Border.all(
                color: isDark ? AppColors.borderDark : AppColors.borderLight.withOpacity(0.5),
                width: 1,
              ),
              boxShadow: shadow ?? AppShadows.soft,
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// Glass Card with Blur Effect
class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double borderRadius;
  final double blur;
  final Color? overlayColor;
  final VoidCallback? onTap;

  const GlassCard({
    Key? key,
    required this.child,
    this.padding,
    this.margin,
    this.borderRadius = 20,
    this.blur = 10,
    this.overlayColor,
    this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: GestureDetector(
            onTap: onTap,
            child: Container(
              padding: padding ?? const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: overlayColor ?? AppColors.glassWhite,
                borderRadius: BorderRadius.circular(borderRadius),
                border: Border.all(
                  color: AppColors.glassBorder,
                  width: 1.5,
                ),
              ),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

/// Gradient Card
class GradientCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double borderRadius;
  final LinearGradient gradient;
  final List<BoxShadow>? shadow;
  final VoidCallback? onTap;

  const GradientCard({
    Key? key,
    required this.child,
    required this.gradient,
    this.padding,
    this.margin,
    this.borderRadius = 20,
    this.shadow,
    this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(borderRadius),
          child: Container(
            padding: padding ?? const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: gradient,
              borderRadius: BorderRadius.circular(borderRadius),
              boxShadow: shadow ?? AppShadows.colored(gradient.colors.first),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// Stat Card
class StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final String? subtitle;
  final VoidCallback? onTap;
  final bool compact;

  const StatCard({
    Key? key,
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    this.subtitle,
    this.onTap,
    this.compact = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return ModernCard(
      onTap: onTap,
      padding: EdgeInsets.all(compact ? 12 : 16),
      border: Border.all(
        color: color.withOpacity(0.15),
        width: 1.5,
      ),
      shadow: AppShadows.colored(color, opacity: 0.12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: EdgeInsets.all(compact ? 8 : 10),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [color.withOpacity(0.15), color.withOpacity(0.08)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: compact ? 18 : 22),
              ),
              if (onTap != null)
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: color.withOpacity(0.5),
                  size: compact ? 12 : 14,
                ),
            ],
          ),
          SizedBox(height: compact ? 10 : 14),
          Text(
            value,
            style: (compact ? AppTextStyles.numericSmall : AppTextStyles.numericMedium).copyWith(
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            title,
            style: AppTextStyles.labelMedium.copyWith(
              color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle!,
              style: AppTextStyles.caption.copyWith(
                color: isDark ? AppColors.textTertiaryDark : AppColors.textTertiaryLight,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Feature Card with Icon
class FeatureCard extends StatelessWidget {
  final String title;
  final String? description;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;
  final Widget? trailing;

  const FeatureCard({
    Key? key,
    required this.title,
    this.description,
    required this.icon,
    required this.color,
    this.onTap,
    this.trailing,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return ModernCard(
      onTap: onTap,
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTextStyles.titleSmall.copyWith(
                    color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                  ),
                ),
                if (description != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    description!,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null) trailing!
          else if (onTap != null)
            Icon(
              Icons.chevron_right_rounded,
              color: isDark ? AppColors.textTertiaryDark : AppColors.textTertiaryLight,
            ),
        ],
      ),
    );
  }
}
