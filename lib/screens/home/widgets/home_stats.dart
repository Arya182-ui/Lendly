import 'package:flutter/material.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_spacing.dart';
import '../../../theme/app_text_styles.dart';
import '../../../widgets/lendly_cards.dart';
import '../../wallet/wallet_screen.dart';
import '../../impact/impact_screen.dart';

/// Home Stats Section - Trust Score, Coins, Impact
class HomeStats extends StatelessWidget {
  final Map<String, dynamic> userProfile;

  const HomeStats({
    super.key,
    required this.userProfile,
  });

  @override
  Widget build(BuildContext context) {
    final trustScore = userProfile['trustScore'] ?? 0;
    final coinBalance = userProfile['coinBalance'] ?? 0;
    final itemsShared = userProfile['itemsShared'] ?? 0;

    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Your Impact',
              style: AppTextStyles.heading.copyWith(
                color: AppColors.textPrimaryLight,
                fontSize: 20,
              ),
            ),
            AppSpacing.gapMd,
            Row(
              children: [
                // Trust Score Card
                Expanded(
                  child: _StatCard(
                    title: 'Trust Score',
                    value: '$trustScore',
                    subtitle: 'Build trust',
                    icon: Icons.shield_outlined,
                    color: AppColors.primary,
                    onTap: () {}, // Navigate to trust score details
                  ),
                ),
                AppSpacing.hGapMd,
                // Coins Card
                Expanded(
                  child: _StatCard(
                    title: 'Lend Coins',
                    value: '$coinBalance',
                    subtitle: 'Earn more',
                    icon: Icons.monetization_on_outlined,
                    color: AppColors.accentOrange,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const WalletScreen()),
                      );
                    },
                  ),
                ),
              ],
            ),
            AppSpacing.gapMd,
            // Impact Card (full width)
            _StatCard(
              title: 'Items Shared',
              value: '$itemsShared',
              subtitle: 'Help your community',
              icon: Icons.eco_outlined,
              color: AppColors.success,
              fullWidth: true,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ImpactScreen()),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color color;
  final bool fullWidth;
  final VoidCallback onTap;

  const _StatCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
    this.fullWidth = false,
  });

  @override
  Widget build(BuildContext context) {
    return LendlyCard(
      onTap: onTap,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: fullWidth
          ? Row(
              children: [
                _buildIcon(),
                AppSpacing.hGapMd,
                Expanded(child: _buildContent()),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildIcon(),
                AppSpacing.gapSm,
                _buildContent(),
              ],
            ),
    );
  }

  Widget _buildIcon() {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(
        icon,
        color: color,
        size: fullWidth ? 24 : 20,
      ),
    );
  }

  Widget _buildContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: AppTextStyles.caption.copyWith(
            color: AppColors.textSecondaryLight,
            fontWeight: FontWeight.w500,
          ),
        ),
        AppSpacing.vGapXs,
        Text(
          value,
          style: AppTextStyles.subheading.copyWith(
            color: AppColors.textPrimaryLight,
            fontWeight: FontWeight.bold,
          ),
        ),
        AppSpacing.vGapXs,
        Text(
          subtitle,
          style: AppTextStyles.caption.copyWith(
            color: AppColors.textTertiaryLight,
          ),
        ),
      ],
    );
  }
}
