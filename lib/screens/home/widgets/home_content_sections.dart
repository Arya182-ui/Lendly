import 'package:flutter/material.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_spacing.dart';
import '../../../theme/app_text_styles.dart';
import '../../../widgets/lendly_cards.dart';
import '../../../widgets/lendly_buttons.dart';
import '../../../widgets/error_handler.dart';
import '../item_detail_screen.dart';
import '../../groups/group_detail_screen.dart';

/// Home Content Sections - Recent items, groups, activities
class HomeContentSections extends StatelessWidget {
  final List<dynamic> recentItems;
  final List<dynamic> activeGroups;
  final List<dynamic> nearbyItems;

  const HomeContentSections({
    super.key,
    required this.recentItems,
    required this.activeGroups,
    required this.nearbyItems,
  });

  @override
  Widget build(BuildContext context) {
    return SliverList(
      delegate: SliverChildListDelegate([
        // Recent Items Section
        _buildSection(
          context: context,
          title: 'Recent Items',
          items: recentItems,
          emptyMessage: 'No recent items yet',
          emptyIcon: Icons.inventory_2_outlined,
          onItemTap: (item) => _navigateToItemDetail(context, item),
          itemBuilder: (item) => _buildItemTile(item),
        ),
        
        AppSpacing.gapLg,
        
        // Active Groups Section
        _buildSection(
          context: context,
          title: 'Your Groups',
          items: activeGroups,
          emptyMessage: 'Join groups to connect with peers',
          emptyIcon: Icons.group_outlined,
          onItemTap: (item) => _navigateToGroupDetail(context, item),
          itemBuilder: (item) => _buildGroupTile(item),
        ),
        
        AppSpacing.gapLg,
        
        // Nearby Items Section (if available)
        if (nearbyItems.isNotEmpty)
          _buildSection(
            context: context,
            title: 'Near You',
            items: nearbyItems,
            emptyMessage: null, // Won't show since we check if not empty
            emptyIcon: Icons.location_on_outlined,
            onItemTap: (item) => _navigateToItemDetail(context, item),
            itemBuilder: (item) => _buildItemTile(item),
          ),
      ]),
    );
  }

  Widget _buildSection({
    required BuildContext context,
    required String title,
    required List<dynamic> items,
    required String? emptyMessage,
    required IconData emptyIcon,
    required Function(dynamic) onItemTap,
    required Widget Function(dynamic) itemBuilder,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: AppTextStyles.heading.copyWith(
                  color: AppColors.textPrimaryLight,
                  fontSize: 20,
                ),
              ),
              if (items.isNotEmpty)
                LendlyTextButton(
                  text: 'View All',
                  onPressed: () {}, // Navigate to full list
                ),
            ],
          ),
          AppSpacing.gapMd,
          
          if (items.isEmpty && emptyMessage != null)
            _buildEmptyState(emptyMessage, emptyIcon)
          else
            ...items.take(3).map((item) => Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: GestureDetector(
                onTap: () => onItemTap(item),
                child: itemBuilder(item),
              ),
            )),
        ],
      ),
    );
  }

  Widget _buildEmptyState(String message, IconData icon) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.backgroundLight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.borderLight,
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Icon(
            icon,
            size: 48,
            color: AppColors.textTertiaryLight,
          ),
          AppSpacing.gapMd,
          Text(
            message,
            style: AppTextStyles.body.copyWith(
              color: AppColors.textSecondaryLight,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildItemTile(dynamic item) {
    return LendlyItemCard(
      title: item['name'] ?? 'Unknown Item',
      subtitle: 'By ${item['owner'] ?? 'Unknown'} • ${item['type'] ?? 'Item'}',
      imageUrl: item['image'],
      trailing: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (item['price'] != null && item['price'] > 0)
            Text(
              '₹${item['price']}',
              style: AppTextStyles.subheading.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          Text(
            item['type']?.toUpperCase() ?? 'ITEM',
            style: AppTextStyles.caption.copyWith(
              color: AppColors.textTertiaryLight,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGroupTile(dynamic group) {
    return LendlyItemCard(
      title: group['name'] ?? 'Unknown Group',
      subtitle: '${group['memberCount'] ?? 0} members • ${group['type'] ?? 'Group'}',
      trailing: Icon(
        Icons.arrow_forward_ios,
        size: 16,
        color: AppColors.textTertiaryLight,
      ),
    );
  }

  void _navigateToItemDetail(BuildContext context, dynamic item) {
    if (item['id'] != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ItemDetailScreen(itemId: item['id']),
        ),
      );
    }
  }

  void _navigateToGroupDetail(BuildContext context, dynamic group) {
    if (group['id'] != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => GroupDetailScreen(groupId: group['id']),
        ),
      );
    }
  }
}
