import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/wallet_service.dart';
import '../../services/api_client.dart';
import '../../services/session_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_shadows.dart';

class WalletScreen extends StatefulWidget {
  const WalletScreen({Key? key}) : super(key: key);

  @override
  _WalletScreenState createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> with TickerProviderStateMixin {
  Map<String, dynamic>? wallet;
  List<Map<String, dynamic>> transactions = [];
  bool isLoading = true;
  bool isLoadingMore = false;
  bool hasMore = false;
  String selectedFilter = 'all';
  String selectedPeriod = '30d';
  Map<String, dynamic>? stats;
  late TabController _tabController;
  num balance = 0;

  final List<String> filterOptions = [
    'all',
    'earned_transaction',
    'bonus_signup',
    'bonus_referral',
    'bonus_verification',
    'spent_transaction',
    'spent_listing',
    'admin_adjustment'
  ];

  final List<String> periodOptions = ['7d', '30d', '90d', '1y'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadWalletData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadWalletData() async {
    setState(() => isLoading = true);

    try {
      final uid = await SessionService.getUid();
      if (uid == null) {
        _showError('User not logged in');
        return;
      }

      final results = await Future.wait([
        WalletService.getWallet(uid),
        WalletService.getTransactions(uid, limit: 20, type: selectedFilter),
        WalletService.getWalletStats(uid, period: selectedPeriod),
      ]);

      final walletResult = results[0];
      final transactionsResult = results[1];
      final statsResult = results[2];

      if (walletResult['success']) {
        wallet = walletResult['wallet'];
      } else {
        _showError(walletResult['error']);
        return;
      }

      if (transactionsResult['success']) {
        transactions = List<Map<String, dynamic>>.from(transactionsResult['transactions']);
        hasMore = transactionsResult['hasMore'] ?? false;
      }

      if (statsResult['success']) {
        stats = statsResult['stats'];
      }
    } catch (e) {
      _showError('Failed to load wallet data: $e');
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> _loadMoreTransactions() async {
    if (isLoadingMore || !hasMore) return;

    setState(() => isLoadingMore = true);

    try {
      final uid = await SessionService.getUid();
      if (uid == null) return;

      final result = await WalletService.getTransactions(
        uid,
        limit: 10,
        offset: transactions.length,
        type: selectedFilter,
      );

      if (result['success']) {
        final newTransactions = List<Map<String, dynamic>>.from(result['transactions']);
        setState(() {
          transactions.addAll(newTransactions);
          hasMore = result['hasMore'] ?? false;
        });
      }
    } catch (e) {
      _showError('Failed to load more transactions: $e');
    } finally {
      setState(() => isLoadingMore = false);
    }
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error_outline_rounded, color: Colors.white, size: 20),
              const SizedBox(width: 12),
              Expanded(child: Text(message)),
            ],
          ),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
        ),
      );
    }
  }

  void _onFilterChanged(String? newFilter) {
    if (newFilter != null && newFilter != selectedFilter) {
      HapticFeedback.selectionClick();
      setState(() {
        selectedFilter = newFilter;
        transactions.clear();
        hasMore = false;
      });
      _loadWalletData();
    }
  }

  void _onPeriodChanged(String? newPeriod) {
    if (newPeriod != null && newPeriod != selectedPeriod) {
      HapticFeedback.selectionClick();
      setState(() => selectedPeriod = newPeriod);
      _loadWalletData();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.backgroundDark : AppColors.backgroundLight,
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          SliverAppBar(
            expandedHeight: 200,
            floating: false,
            pinned: true,
            backgroundColor: isDark ? AppColors.surfaceDark : Colors.white,
            surfaceTintColor: Colors.transparent,
            leading: IconButton(
              icon: Icon(
                Icons.arrow_back_ios_rounded,
                color: innerBoxIsScrolled 
                    ? (isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight)
                    : Colors.white,
              ),
              onPressed: () => Navigator.pop(context),
            ),
            title: innerBoxIsScrolled
                ? Text(
                    'My Wallet',
                    style: TextStyle(
                      color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                      fontWeight: FontWeight.w700,
                    ),
                  )
                : null,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF10B981), Color(0xFF059669)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 50, 20, 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'My Wallet',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.9),
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              isLoading ? '---' : WalletService.formatAmount(wallet?['balance'] ?? 0),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 42,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -1,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Text(
                                'points',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.8),
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(56),
              child: Container(
                decoration: BoxDecoration(
                  color: isDark ? AppColors.surfaceDark : Colors.white,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(24),
                    topRight: Radius.circular(24),
                  ),
                ),
                child: TabBar(
                  controller: _tabController,
                  labelColor: AppColors.primary,
                  unselectedLabelColor: isDark ? AppColors.textTertiaryDark : AppColors.textTertiaryLight,
                  indicatorColor: AppColors.primary,
                  indicatorWeight: 3,
                  labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                  tabs: const [
                    Tab(text: 'Overview'),
                    Tab(text: 'History'),
                    Tab(text: 'Stats'),
                  ],
                ),
              ),
            ),
          ),
        ],
        body: isLoading
            ? Center(
                child: CircularProgressIndicator(
                  color: AppColors.primary,
                  strokeWidth: 3,
                ),
              )
            : TabBarView(
                controller: _tabController,
                children: [
                  _buildBalanceTab(),
                  _buildHistoryTab(),
                  _buildStatsTab(),
                ],
              ),
      ),
    );
  }

  Widget _buildBalanceTab() {
    if (wallet == null) {
      return const Center(child: Text('Failed to load wallet information'));
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Wallet Stats Row
          Row(
            children: [
              Expanded(
                child: _buildModernStatCard(
                  'Total Earned',
                  WalletService.formatAmount(wallet!['totalEarned'] ?? 0),
                  Icons.trending_up_rounded,
                  AppColors.success,
                  isDark,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildModernStatCard(
                  'Total Spent',
                  WalletService.formatAmount(wallet!['totalSpent'] ?? 0),
                  Icons.trending_down_rounded,
                  AppColors.accentOrange,
                  isDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          
          // Quick Actions
          Text(
            'Quick Actions',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _buildActionCard(
                  icon: Icons.add_circle_rounded,
                  title: 'Earn Points',
                  subtitle: 'Complete transactions',
                  color: AppColors.primary,
                  onTap: _showHowToEarnDialog,
                  isDark: isDark,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildActionCard(
                  icon: Icons.shopping_bag_rounded,
                  title: 'Spend Points',
                  subtitle: 'List new items',
                  color: AppColors.secondary,
                  onTap: _showHowToSpendDialog,
                  isDark: isDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          
          // Recent Transactions
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Recent Transactions',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                ),
              ),
              TextButton(
                onPressed: () => _tabController.animateTo(1),
                child: const Text('See All'),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...transactions.take(5).map((transaction) => _buildTransactionItem(transaction)),
          if (transactions.isEmpty)
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: isDark ? AppColors.surfaceDark : AppColors.backgroundLight,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.receipt_long_rounded,
                      size: 48,
                      color: isDark ? AppColors.textTertiaryDark : AppColors.textTertiaryLight,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'No transactions yet',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Start lending to earn points!',
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? AppColors.textTertiaryDark : AppColors.textTertiaryLight,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildModernStatCard(String title, String value, IconData icon, Color color, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDark : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: color.withOpacity(0.15),
          width: 1.5,
        ),
        boxShadow: AppShadows.soft,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [color, color.withOpacity(0.8)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: AppShadows.colored(color, opacity: 0.3),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 24, color: Colors.white),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 12,
                color: Colors.white.withOpacity(0.85),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryTab() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      children: [
        // Filter dropdown
        Container(
          padding: const EdgeInsets.all(16),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            decoration: BoxDecoration(
              color: isDark ? AppColors.cardDark : Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isDark ? AppColors.borderDark : AppColors.borderLight,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.filter_list_rounded,
                  color: AppColors.primary,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: selectedFilter,
                      isExpanded: true,
                      icon: const Icon(Icons.keyboard_arrow_down_rounded),
                      style: TextStyle(
                        color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                        fontWeight: FontWeight.w500,
                      ),
                      items: filterOptions.map((filter) {
                        return DropdownMenuItem(
                          value: filter,
                          child: Text(
                            filter == 'all' ? 'All Transactions' : WalletService.getTransactionTypeDisplayName(filter),
                          ),
                        );
                      }).toList(),
                      onChanged: _onFilterChanged,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.refresh_rounded),
                  color: AppColors.primary,
                  onPressed: _loadWalletData,
                ),
              ],
            ),
          ),
        ),
        
        Expanded(
          child: transactions.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.history_rounded,
                        size: 64,
                        color: isDark ? AppColors.textTertiaryDark : AppColors.textTertiaryLight,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No transactions yet',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: transactions.length + (hasMore ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index == transactions.length) {
                      return Padding(
                        padding: const EdgeInsets.all(16),
                        child: Center(
                          child: isLoadingMore
                              ? CircularProgressIndicator(color: AppColors.primary, strokeWidth: 3)
                              : TextButton.icon(
                                  onPressed: _loadMoreTransactions,
                                  icon: const Icon(Icons.expand_more_rounded),
                                  label: const Text('Load More'),
                                ),
                        ),
                      );
                    }
                    return _buildTransactionItem(transactions[index]);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildStatsTab() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    if (stats == null) {
      return Center(child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 3));
    }

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Period selector
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: isDark ? AppColors.cardDark : Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isDark ? AppColors.borderDark : AppColors.borderLight,
              ),
            ),
            child: Row(
              children: [
                Text(
                  'Period: ',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                  ),
                ),
                const SizedBox(width: 8),
                ...periodOptions.map((period) => Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: () => _onPeriodChanged(period),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: selectedPeriod == period 
                            ? AppColors.primary 
                            : (isDark ? AppColors.surfaceDark : AppColors.backgroundLight),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        period,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: selectedPeriod == period 
                              ? Colors.white 
                              : (isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight),
                        ),
                      ),
                    ),
                  ),
                )),
              ],
            ),
          ),
          const SizedBox(height: 24),
          
          // Stats cards
          Row(
            children: [
              Expanded(
                child: _buildModernStatCard(
                  'Earned',
                  WalletService.formatAmount(stats!['period']['earned'] ?? 0),
                  Icons.trending_up_rounded,
                  AppColors.success,
                  isDark,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildModernStatCard(
                  'Spent',
                  WalletService.formatAmount(stats!['period']['spent'] ?? 0),
                  Icons.trending_down_rounded,
                  AppColors.error,
                  isDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildModernStatCard(
                  'Net Change',
                  WalletService.formatAmount(stats!['period']['net'] ?? 0),
                  Icons.account_balance_rounded,
                  stats!['period']['net'] >= 0 ? AppColors.success : AppColors.error,
                  isDark,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildModernStatCard(
                  'Transactions',
                  '${stats!['period']['transactionCount'] ?? 0}',
                  Icons.receipt_long_rounded,
                  AppColors.info,
                  isDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          
          // Transaction types breakdown
          Text(
            'Transaction Types',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
            ),
          ),
          const SizedBox(height: 16),
          ...stats!['transactionsByType'].entries.map((entry) =>
            _buildTransactionTypeCard(entry.key, entry.value, isDark)
          ).toList(),
        ],
      ),
    );
  }

  Widget _buildTransactionItem(Map<String, dynamic> transaction) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isEarning = transaction['type'].startsWith('earned_') || transaction['type'].startsWith('bonus_');
    final amount = transaction['amount'] ?? 0;
    final type = transaction['type'] ?? '';
    final description = transaction['description'] ?? '';
    final createdAt = transaction['createdAt'] ?? '';
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDark : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? AppColors.borderDark : AppColors.borderLight.withOpacity(0.5),
        ),
        boxShadow: AppShadows.soft,
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isEarning ? AppColors.successSurface : AppColors.errorSurface,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              WalletService.getTransactionTypeIcon(type),
              style: const TextStyle(fontSize: 22),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  WalletService.getTransactionTypeDisplayName(type),
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  createdAt,
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? AppColors.textTertiaryDark : AppColors.textTertiaryLight,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: isEarning 
                  ? AppColors.success.withOpacity(0.1) 
                  : AppColors.error.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '${isEarning ? '+' : '-'}${WalletService.formatAmount(amount)}',
              style: TextStyle(
                color: isEarning ? AppColors.success : AppColors.error,
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionTypeCard(String type, Map<String, dynamic> data, bool isDark) {
    final count = data['count'] ?? 0;
    final total = data['total'] ?? 0;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDark : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? AppColors.borderDark : AppColors.borderLight.withOpacity(0.5),
        ),
      ),
      child: Row(
        children: [
          Text(
            WalletService.getTransactionTypeIcon(type),
            style: const TextStyle(fontSize: 28),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  WalletService.getTransactionTypeDisplayName(type),
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                  ),
                ),
                Text(
                  '$count transactions',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                  ),
                ),
              ],
            ),
          ),
          Text(
            WalletService.formatAmount(total),
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 16,
              color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
            ),
          ),
        ],
      ),
    );
  }

  void _showHowToEarnDialog() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? AppColors.surfaceDark : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? AppColors.borderDark : AppColors.borderLight,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'How to Earn Points 💰',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
              ),
            ),
            const SizedBox(height: 20),
            _buildEarnItem('💰', 'Complete transactions', '+10-50 pts', AppColors.success),
            _buildEarnItem('✅', 'Verify your student status', '+25 pts', AppColors.info),
            _buildEarnItem('👥', 'Refer friends', '+75 pts', AppColors.secondary),
            _buildEarnItem('🔥', 'Daily login streak', '+5-25 pts', AppColors.accentOrange),
            _buildEarnItem('🎉', 'Welcome bonus', '+100 pts', AppColors.accentOrange),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildEarnItem(String emoji, String title, String points, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 28)),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: Theme.of(context).brightness == Brightness.dark
                    ? AppColors.textPrimaryDark
                    : AppColors.textPrimaryLight,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              points,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showHowToSpendDialog() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? AppColors.surfaceDark : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? AppColors.borderDark : AppColors.borderLight,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'How to Spend Points 🛒',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
              ),
            ),
            const SizedBox(height: 20),
            _buildEarnItem('📝', 'List new items', '-10 pts', AppColors.accentOrange),
            _buildEarnItem('⭐', 'Boost listing visibility', '-50 pts', AppColors.secondary),
            _buildEarnItem('🎁', 'Premium features', '-200 pts', AppColors.accentPink),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
  
  Future<void> _collectWelcomeBonus() async {
    try {
      final uid = await SessionService.getUid();
      if (uid == null) return;
      
      final response = await SimpleApiClient.post(
        '/wallet/collect-welcome-bonus',
        body: {'uid': uid},
        requiresAuth: true,
      );
      
      if (response['success'] == true) {
        setState(() {
          balance = response['newBalance'] ?? balance;
        });
        
        _showSuccessMessage('Welcome bonus collected! +100 coins');
        _loadWalletData(); // Refresh data
      }
    } catch (e) {
      _showErrorMessage('Welcome bonus already collected or error occurred');
    }
  }

  void _showSuccessMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showErrorMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}