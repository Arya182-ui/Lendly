import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_spacing.dart';
import '../../../theme/app_text_styles.dart';
import '../../../widgets/lendly_cards.dart';
import '../add_item_screen.dart';
import '../search_screen.dart';
import '../../chat/messages_screen.dart';
import '../../groups/groups_screen.dart';

/// Quick Actions Section - Main user actions
class HomeQuickActions extends StatelessWidget {
  const HomeQuickActions({super.key});

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Quick Actions',
              style: AppTextStyles.heading.copyWith(
                color: AppColors.textPrimaryLight,
                fontSize: 20,
              ),
            ),
            AppSpacing.gapMd,
            Row(
              children: [
                Expanded(
                  child: _QuickActionButton(
                    title: 'Add Item',
                    icon: Icons.add_circle_outline,
                    color: AppColors.primary,
                    onTap: () => _navigateToAddItem(context),
                  ),
                ),
                AppSpacing.hGapSm,
                Expanded(
                  child: _QuickActionButton(
                    title: 'Browse',
                    icon: Icons.search,
                    color: AppColors.secondary,
                    onTap: () => _navigateToSearch(context),
                  ),
                ),
              ],
            ),
            AppSpacing.gapSm,
            Row(
              children: [
                Expanded(
                  child: _QuickActionButton(
                    title: 'Messages',
                    icon: Icons.chat_bubble_outline,
                    color: AppColors.accentPink,
                    onTap: () => _navigateToMessages(context),
                  ),
                ),
                AppSpacing.hGapSm,
                Expanded(
                  child: _QuickActionButton(
                    title: 'Groups',
                    icon: Icons.group_outlined,
                    color: AppColors.accentOrange,
                    onTap: () => _navigateToGroups(context),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _navigateToAddItem(BuildContext context) {
    HapticFeedback.lightImpact();
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AddItemScreen()),
    );
  }

  void _navigateToSearch(BuildContext context) {
    HapticFeedback.lightImpact();
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const SearchScreen()),
    );
  }

  void _navigateToMessages(BuildContext context) {
    HapticFeedback.lightImpact();
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const MessagesScreen()),
    );
  }

  void _navigateToGroups(BuildContext context) {
    HapticFeedback.lightImpact();
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const GroupsScreen()),
    );
  }
}

class _QuickActionButton extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _QuickActionButton({
    required this.title,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return LendlyCard(
      onTap: onTap,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: color,
              size: 24,
            ),
          ),
          AppSpacing.gapSm,
          Text(
            title,
            style: AppTextStyles.body.copyWith(
              fontWeight: FontWeight.w500,
              color: AppColors.textPrimaryLight,
            ),
          ),
        ],
      ),
    );
  }
}
