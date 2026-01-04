import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/wallet_service.dart';
import '../../services/session_service.dart';

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
    setState(() {
      isLoading = true;
    });

    try {
      final uid = await SessionService.getUid();
      if (uid == null) {
        _showError('User not logged in');
        return;
      }

      // Load wallet, transactions, and stats in parallel
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
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> _loadMoreTransactions() async {
    if (isLoadingMore || !hasMore) return;

    setState(() {
      isLoadingMore = true;
    });

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
      setState(() {
        isLoadingMore = false;
      });
    }
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _onFilterChanged(String? newFilter) {
    if (newFilter != null && newFilter != selectedFilter) {
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
      setState(() {
        selectedPeriod = newPeriod;
      });
      _loadWalletData();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Wallet'),
        backgroundColor: Colors.green[600],
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.account_balance_wallet), text: 'Balance'),
            Tab(icon: Icon(Icons.history), text: 'History'),
            Tab(icon: Icon(Icons.analytics), text: 'Stats'),
          ],
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
        ),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildBalanceTab(),
                _buildHistoryTab(),
                _buildStatsTab(),
              ],
            ),
    );
  }

  Widget _buildBalanceTab() {
    if (wallet == null) {
      return const Center(
        child: Text('Failed to load wallet information'),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Balance Card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.green[400]!, Colors.green[600]!],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.green.withOpacity(0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Current Balance',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  WalletService.formatAmount(wallet!['balance'] ?? 0),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Total Earned',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                          ),
                        ),
                        Text(
                          WalletService.formatAmount(wallet!['totalEarned'] ?? 0),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        const Text(
                          'Total Spent',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                          ),
                        ),
                        Text(
                          WalletService.formatAmount(wallet!['totalSpent'] ?? 0),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          
          // Quick Actions
          const Text(
            'Quick Actions',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildActionCard(
                  icon: Icons.add_circle,
                  title: 'Earn Points',
                  subtitle: 'Complete transactions',
                  color: Colors.blue,
                  onTap: () {
                    _showHowToEarnDialog();
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildActionCard(
                  icon: Icons.shopping_cart,
                  title: 'Spend Points',
                  subtitle: 'List new items',
                  color: Colors.orange,
                  onTap: () {
                    _showHowToSpendDialog();
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // Recent Transactions
          const Text(
            'Recent Transactions',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          ...transactions.take(5).map((transaction) => _buildTransactionItem(transaction)),
          if (transactions.length > 5)
            TextButton(
              onPressed: () {
                _tabController.animateTo(1);
              },
              child: const Text('View All Transactions'),
            ),
        ],
      ),
    );
  }

  Widget _buildHistoryTab() {
    return Column(
      children: [
        // Filter dropdown
        Container(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: selectedFilter,
                  decoration: const InputDecoration(
                    labelText: 'Filter by type',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  items: filterOptions.map((filter) {
                    return DropdownMenuItem(
                      value: filter,
                      child: Text(
                        filter == 'all' ? 'All Transactions' : 
                        WalletService.getTransactionTypeDisplayName(filter),
                      ),
                    );
                  }).toList(),
                  onChanged: _onFilterChanged,
                ),
              ),
              const SizedBox(width: 12),
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: _loadWalletData,
              ),
            ],
          ),
        ),
        
        // Transactions list
        Expanded(
          child: transactions.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.history, size: 64, color: Colors.grey),
                      SizedBox(height: 16),
                      Text(
                        'No transactions yet',
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: transactions.length + (hasMore ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index == transactions.length) {
                      return Padding(
                        padding: const EdgeInsets.all(16),
                        child: Center(
                          child: isLoadingMore
                              ? const CircularProgressIndicator()
                              : ElevatedButton(
                                  onPressed: _loadMoreTransactions,
                                  child: const Text('Load More'),
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
    if (stats == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Period selector
          Row(
            children: [
              const Text(
                'Period: ',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              ),
              DropdownButton<String>(
                value: selectedPeriod,
                items: periodOptions.map((period) {
                  return DropdownMenuItem(
                    value: period,
                    child: Text(period),
                  );
                }).toList(),
                onChanged: _onPeriodChanged,
              ),
            ],
          ),
          const SizedBox(height: 24),
          
          // Stats cards
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  'Earned',
                  WalletService.formatAmount(stats!['period']['earned'] ?? 0),
                  Icons.trending_up,
                  Colors.green,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  'Spent',
                  WalletService.formatAmount(stats!['period']['spent'] ?? 0),
                  Icons.trending_down,
                  Colors.red,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  'Net Change',
                  WalletService.formatAmount(stats!['period']['net'] ?? 0),
                  Icons.account_balance,
                  stats!['period']['net'] >= 0 ? Colors.green : Colors.red,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  'Transactions',
                  '${stats!['period']['transactionCount'] ?? 0}',
                  Icons.receipt,
                  Colors.blue,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          
          // Transaction types breakdown
          const Text(
            'Transaction Types',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          ...stats!['transactionsByType'].entries.map((entry) =>
            _buildTransactionTypeCard(entry.key, entry.value)
          ).toList(),
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
  }) {
    return Card(
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Icon(icon, size: 32, color: color),
              const SizedBox(height: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTransactionItem(Map<String, dynamic> transaction) {
    final isEarning = transaction['type'].startsWith('earned_') || 
                     transaction['type'].startsWith('bonus_');
    final amount = transaction['amount'] ?? 0;
    final type = transaction['type'] ?? '';
    final description = transaction['description'] ?? '';
    final createdAt = transaction['createdAt'] ?? '';
    
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: isEarning ? Colors.green[100] : Colors.red[100],
          child: Text(
            WalletService.getTransactionTypeIcon(type),
            style: const TextStyle(fontSize: 20),
          ),
        ),
        title: Text(
          WalletService.getTransactionTypeDisplayName(type),
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(description),
            const SizedBox(height: 4),
            Text(
              createdAt,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
        trailing: Text(
          '${isEarning ? '+' : '-'}${WalletService.formatAmount(amount)}',
          style: TextStyle(
            color: isEarning ? Colors.green : Colors.red,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        isThreeLine: true,
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                color: color,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTransactionTypeCard(String type, Map<String, dynamic> data) {
    final count = data['count'] ?? 0;
    final total = data['total'] ?? 0;
    
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Text(
          WalletService.getTransactionTypeIcon(type),
          style: const TextStyle(fontSize: 24),
        ),
        title: Text(WalletService.getTransactionTypeDisplayName(type)),
        subtitle: Text('$count transactions'),
        trailing: Text(
          WalletService.formatAmount(total),
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ),
    );
  }

  void _showHowToEarnDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('How to Earn Points'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('💰 Complete transactions (+10 pts)'),
            SizedBox(height: 8),
            Text('✅ Verify your student status (+25 pts)'),
            SizedBox(height: 8),
            Text('👥 Refer friends (+50 pts)'),
            SizedBox(height: 8),
            Text('🎉 Get welcome bonus (+100 pts)'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Got it!'),
          ),
        ],
      ),
    );
  }

  void _showHowToSpendDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('How to Spend Points'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('📝 List new items (-5 pts)'),
            SizedBox(height: 8),
            Text('⭐ Premium features (coming soon)'),
            SizedBox(height: 8),
            Text('🎁 Special rewards (coming soon)'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Got it!'),
          ),
        ],
      ),
    );
  }
}