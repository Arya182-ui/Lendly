import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

/// Lendly Card System - Consistent Content Containers
/// Provides elevation hierarchy and consistent styling

/// Standard content card
class LendlyCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final VoidCallback? onTap;
  final bool elevated;
  final Color? backgroundColor;

  const LendlyCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.onTap,
    this.elevated = true,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      child: Material(
        color: backgroundColor ?? AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(16),
        elevation: elevated ? 2 : 0,
        shadowColor: AppColors.primary.withOpacity(0.1),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: padding ?? AppSpacing.cardPadding,
            child: child,
          ),
        ),
      ),
    );
  }
}

/// Item listing card with consistent structure
class LendlyItemCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final String? imageUrl;
  final Widget? trailing;
  final VoidCallback? onTap;
  final List<Widget>? actions;

  const LendlyItemCard({
    super.key,
    required this.title,
    this.subtitle,
    this.imageUrl,
    this.trailing,
    this.onTap,
    this.actions,
  });

  @override
  Widget build(BuildContext context) {
    return LendlyCard(
      onTap: onTap,
      child: Row(
        children: [
          // Image placeholder or actual image
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: AppColors.primarySurface,
              borderRadius: BorderRadius.circular(12),
              image: imageUrl != null
                  ? DecorationImage(
                      image: NetworkImage(imageUrl!),
                      fit: BoxFit.cover,
                    )
                  : null,
            ),
            child: imageUrl == null
                ? const Icon(
                    Icons.inventory_2_outlined,
                    color: AppColors.primary,
                    size: 24,
                  )
                : null,
          ),
          AppSpacing.hGapMd,
          // Content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimaryLight,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (subtitle != null) ..[
                  AppSpacing.vGapXs,
                  Text(
                    subtitle!,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondaryLight,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                if (actions != null) ..[
                  AppSpacing.vGapSm,
                  Row(
                    children: actions!,
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null) ..[
            AppSpacing.hGapSm,
            trailing!,
          ],
        ],
      ),
    );
  }
}
