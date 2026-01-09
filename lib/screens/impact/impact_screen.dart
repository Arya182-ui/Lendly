import 'package:flutter/material.dart';
import '../../config/env_config.dart';
import '../../services/impact_service.dart';
import '../../services/session_service.dart';
import '../../services/data_cache_manager.dart';
import '../../services/api_client.dart';
import '../../config/app_colors.dart';
import '../../widgets/app_image.dart';

class ImpactScreen extends StatefulWidget {
  const ImpactScreen({Key? key}) : super(key: key);

  @override
  State<ImpactScreen> createState() => _ImpactScreenState();
}

class _ImpactScreenState extends State<ImpactScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _counterAnim;
  bool isLoading = true;
  bool isError = false;
  String errorMsg = '';
  bool hasAnyData = false;

  // Data
  Map<String, dynamic> personal = {};
  Map<String, dynamic> environmental = {};
  Map<String, dynamic> community = {};
  List<dynamic> leaderboard = [];
  List<dynamic> badges = [];

  final ImpactService _service = ImpactService(EnvConfig.apiBaseUrl);
  String? userId;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(duration: const Duration(milliseconds: 1200), vsync: this);
    _counterAnim = CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic);
    _initUserAndLoad();
  }

  Future<void> _initUserAndLoad() async {
    userId = await SessionService.getUid();
    if (userId == null) {
      setState(() {
        isError = true;
        errorMsg = 'User not logged in.';
        isLoading = false;
      });
      return;
    }
    await _loadData();
  }

  Future<void> _loadData({bool forceRefresh = false}) async {
    if (userId == null) return;
    setState(() {
      isLoading = true;
      isError = false;
      errorMsg = '';
    });

    try {
      // Clear cache if force refresh
      if (forceRefresh) {
        await DataCacheManager.clearCache('impact_personal');
        await DataCacheManager.clearCache('impact_environmental');
        await DataCacheManager.clearCache('impact_community');
        await DataCacheManager.clearCache('impact_leaderboard');
        await DataCacheManager.clearCache('impact_badges');
        SimpleApiClient.clearCacheEntry('/impact/');
      }
      
      // Try loading from cache first if not forcing refresh
      if (!forceRefresh) {
        final cachedPersonal = await DataCacheManager.getCached<Map<String, dynamic>>('impact_personal');
        final cachedEnvironmental = await DataCacheManager.getCached<Map<String, dynamic>>('impact_environmental');
        final cachedCommunity = await DataCacheManager.getCached<Map<String, dynamic>>('impact_community');
        final cachedLeaderboard = await DataCacheManager.getCached<List>('impact_leaderboard');
        final cachedBadges = await DataCacheManager.getCached<List>('impact_badges');

        if (cachedPersonal != null && cachedEnvironmental != null) {
          _updateDataState(cachedPersonal, cachedEnvironmental, cachedCommunity ?? {}, cachedLeaderboard ?? [], cachedBadges ?? []);
          // Still fetch fresh data in background
          _fetchFreshData();
          return;
        }
      }

      await _fetchFreshData();
    } catch (e) {
      final errorMessage = e.toString().replaceFirst(RegExp(r'Exception: '), '');
      setState(() {
        isError = true;
        errorMsg = errorMessage;
        isLoading = false;
      });
    }
  }

  Future<void> _fetchFreshData() async {
    try {
      final results = await Future.wait([
        _service.getPersonalImpact(userId!).catchError((e) => <String, dynamic>{}),
        _service.getEnvironmentalImpact(userId!).catchError((e) => <String, dynamic>{}),
        _service.getCommunityImpact(userId!).catchError((e) => <String, dynamic>{}),
        _service.getLeaderboard().catchError((e) => <dynamic>[]),
        _service.getBadges(userId!).catchError((e) => <dynamic>[]),
      ]);

      final newPersonal = results[0] is Map<String, dynamic> ? results[0] as Map<String, dynamic> : <String, dynamic>{};
      final newEnvironmental = results[1] is Map<String, dynamic> ? results[1] as Map<String, dynamic> : <String, dynamic>{};
      final newCommunity = results[2] is Map<String, dynamic> ? results[2] as Map<String, dynamic> : <String, dynamic>{};
      final newLeaderboard = results[3] is List ? results[3] as List : <dynamic>[];
      final newBadges = results[4] is List ? results[4] as List : <dynamic>[];

      // Cache data
      await DataCacheManager.setCache('impact_personal', newPersonal);
      await DataCacheManager.setCache('impact_environmental', newEnvironmental);
      await DataCacheManager.setCache('impact_community', newCommunity);
      await DataCacheManager.setCache('impact_leaderboard', newLeaderboard);
      await DataCacheManager.setCache('impact_badges', newBadges);

      _updateDataState(newPersonal, newEnvironmental, newCommunity, newLeaderboard, newBadges);
    } catch (e) {
      final errorMessage = e.toString().replaceFirst(RegExp(r'Exception: '), '');
      if (mounted && !hasAnyData) {
        setState(() {
          isError = true;
          errorMsg = errorMessage;
          isLoading = false;
        });
      }
    }
  }

  void _updateDataState(
    Map<String, dynamic> newPersonal,
    Map<String, dynamic> newEnvironmental,
    Map<String, dynamic> newCommunity,
    List newLeaderboard,
    List newBadges,
  ) {
    if (!mounted) return;
    
    setState(() {
      personal = newPersonal;
      environmental = newEnvironmental;
      community = newCommunity;
      leaderboard = newLeaderboard;
      badges = newBadges;
      
      // Check if we have ANY meaningful data - more generous check
      hasAnyData = (personal['moneySaved'] ?? 0) > 0 ||
          (personal['itemsReused'] ?? 0) > 0 ||
          (personal['borrowVsBuy'] ?? 0) > 0 ||
          (environmental['co2SavedKg'] ?? 0) > 0 ||
          (environmental['resourceReuse'] ?? 0) > 0 ||
          (community['itemsReused'] ?? 0) > 0 ||
          leaderboard.isNotEmpty ||
          badges.isNotEmpty ||
          (personal['trustScore'] ?? 0) > 0;
          
      isLoading = false;
    });
    _controller.forward(from: 0);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isDark 
                ? [const Color(0xFF2E2E2E), const Color(0xFF121212)]
                : [const Color(0xFFF5F5F5), const Color(0xFFE8F5E9)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildAppBar(theme, isDark),
              Expanded(
                child: isLoading
                    ? _buildLoadingState()
                    : isError && !hasAnyData
                        ? _buildErrorState(theme)
                        : hasAnyData
                            ? _buildContent(theme, isDark)
                            : _buildFirstTimeState(theme, isDark),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAppBar(ThemeData theme, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          if (Navigator.canPop(context))
            IconButton(
              icon: const Icon(Icons.arrow_back_ios_new, color: Colors.blue, size: 20),
              onPressed: () => Navigator.of(context).pop(),
            ),
          const SizedBox(width: 8),
          const Icon(Icons.eco, color: Colors.blue, size: 28),
          const SizedBox(width: 12),
          Text(
            'Your Impact',
            style: theme.textTheme.titleLarge?.copyWith(
              color: Colors.blue,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.blue),
            onPressed: () => _loadData(forceRefresh: true),
            tooltip: 'Refresh',
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              strokeWidth: 3,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Loading your impact...',
            style: TextStyle(color: Colors.white, fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.red.shade100,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(Icons.cloud_off, color: Colors.red, size: 48),
            ),
            const SizedBox(height: 20),
            Text(
              'Couldn\'t load impact data',
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              errorMsg,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600], fontSize: 14),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              icon: const Icon(Icons.refresh),
              label: const Text('Try Again'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green[600],
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              ),
              onPressed: () => _loadData(forceRefresh: true),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(ThemeData theme, bool isDark) {
    return RefreshIndicator(
      onRefresh: () => _loadData(forceRefresh: true),
      color: Colors.green,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildTrustScoreCard(theme, isDark),
            const SizedBox(height: 16),
            _buildPersonalImpact(theme, isDark),
            const SizedBox(height: 16),
            _buildEnvironmentalImpact(theme, isDark),
            const SizedBox(height: 16),
            if (community.isNotEmpty) ...[
              _buildCommunityImpact(theme, isDark),
              const SizedBox(height: 16),
            ],
            if (leaderboard.isNotEmpty) ...[
              _buildLeaderboard(theme, isDark),
              const SizedBox(height: 16),
            ],
            if (badges.isNotEmpty) ...[
              _buildBadges(theme, isDark),
              const SizedBox(height: 16),
            ],
            _buildTipsCard(theme, isDark),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildTrustScoreCard(ThemeData theme, bool isDark) {
    final trustScore = (personal['trustScore'] ?? 0).toDouble();
    const maxTrust = 100.0;
    final trustPercentage = (trustScore / maxTrust).clamp(0.0, 1.0);
    
    Color getTrustColor() {
      if (trustScore >= 80) return Colors.green;
      if (trustScore >= 60) return Colors.lightGreen;
      if (trustScore >= 40) return Colors.amber;
      return Colors.orange;
    }
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark 
              ? [Colors.grey[900]!, Colors.grey[850]!]
              : [Colors.white, Colors.grey[50]!],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: getTrustColor().withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.verified_user, color: getTrustColor(), size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Trust Score',
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      'Your community reliability rating',
                      style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
              AnimatedBuilder(
                animation: _counterAnim,
                builder: (context, child) => Text(
                  '${(_counterAnim.value * trustScore).toInt()}',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: getTrustColor(),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: AnimatedBuilder(
              animation: _counterAnim,
              builder: (context, child) => LinearProgressIndicator(
                value: _counterAnim.value * trustPercentage,
                minHeight: 10,
                backgroundColor: Colors.grey[200],
                valueColor: AlwaysStoppedAnimation<Color>(getTrustColor()),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPersonalImpact(ThemeData theme, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[900] : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.savings_outlined, color: Colors.green[700], size: 24),
              ),
              const SizedBox(width: 12),
              Text(
                'Personal Impact',
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _ImpactStatCard(
                  icon: Icons.currency_rupee,
                  label: 'Money Saved',
                  value: personal['moneySaved'] ?? 0,
                  suffix: '₹',
                  color: Colors.green,
                  animation: _counterAnim,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _ImpactStatCard(
                  icon: Icons.recycling,
                  label: 'Items Reused',
                  value: personal['itemsReused'] ?? 0,
                  color: Colors.teal,
                  animation: _counterAnim,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _ImpactStatCard(
            icon: Icons.compare_arrows,
            label: 'Borrow vs Buy Ratio',
            value: personal['borrowVsBuy'] ?? 0,
            suffix: '%',
            color: Colors.lightGreen,
            animation: _counterAnim,
            fullWidth: true,
          ),
        ],
      ),
    );
  }

  Widget _buildEnvironmentalImpact(ThemeData theme, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.green.shade100.withValues(alpha: isDark ? 0.3 : 1.0),
            Colors.teal.shade50.withValues(alpha: isDark ? 0.3 : 1.0),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.green[700]!.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.eco, color: Colors.green[800], size: 24),
              ),
              const SizedBox(width: 12),
              Text(
                'Environmental Impact',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.green[200] : Colors.green[900],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _EnvironmentalStat(
                icon: Icons.cloud_outlined,
                value: environmental['co2SavedKg'] ?? 0,
                unit: 'kg',
                label: 'CO₂ Saved',
                animation: _counterAnim,
                isDark: isDark,
              ),
              Container(
                width: 1,
                height: 60,
                color: Colors.green.withValues(alpha: 0.3),
              ),
              _EnvironmentalStat(
                icon: Icons.loop,
                value: environmental['resourceReuse'] ?? 0,
                unit: '',
                label: 'Resources Saved',
                animation: _counterAnim,
                isDark: isDark,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCommunityImpact(ThemeData theme, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[900] : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.groups_outlined, color: Colors.blue[700], size: 24),
              ),
              const SizedBox(width: 12),
              Text(
                'Community Impact',
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? Colors.grey[800] : Colors.blue[50],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(Icons.location_city, color: Colors.blue[600], size: 40),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        community['hostel'] ?? 'Your Campus',
                        style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${community['itemsReused'] ?? 0} items shared collectively',
                        style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
                Column(
                  children: [
                    Text(
                      '${community['userContribution'] ?? 0}',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue[700],
                      ),
                    ),
                    Text(
                      'Your Share',
                      style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLeaderboard(ThemeData theme, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[900] : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.emoji_events, color: Colors.amber[700], size: 24),
              ),
              const SizedBox(width: 12),
              Text(
                'Campus Leaderboard',
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...leaderboard.take(5).toList().asMap().entries.map((entry) {
            int idx = entry.key;
            var l = entry.value;
            final isTop3 = idx < 3;
            final medalColors = [Colors.amber, Colors.grey[400]!, Colors.orange[300]!];
            
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: isTop3 
                    ? medalColors[idx].withValues(alpha: 0.1)
                    : (isDark ? Colors.grey[800] : Colors.grey[50]),
                borderRadius: BorderRadius.circular(12),
                border: isTop3 
                    ? Border.all(color: medalColors[idx].withValues(alpha: 0.3))
                    : null,
              ),
              child: Row(
                children: [
                  if (isTop3)
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: medalColors[idx],
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          '${idx + 1}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    )
                  else
                    Container(
                      width: 28,
                      height: 28,
                      alignment: Alignment.center,
                      child: Text(
                        '${idx + 1}',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  const SizedBox(width: 12),
                  _LeaderboardAvatar(url: l['avatar']?.toString()),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      l['name']?.toString() ?? 'User',
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: isTop3 ? FontWeight.bold : FontWeight.w500,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.star, color: Colors.green[700], size: 16),
                        const SizedBox(width: 4),
                        Text(
                          '${l['score'] ?? 0}',
                          style: TextStyle(
                            color: Colors.green[700],
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildBadges(ThemeData theme, bool isDark) {
    IconData iconFromString(String icon) {
      switch (icon) {
        case 'eco': return Icons.eco;
        case 'star': return Icons.star;
        case 'public': return Icons.public;
        case 'handshake': return Icons.handshake;
        case 'volunteer_activism': return Icons.volunteer_activism;
        default: return Icons.verified;
      }
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[900] : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.purple.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.military_tech, color: Colors.purple[700], size: 24),
              ),
              const SizedBox(width: 12),
              Text(
                'Achievements',
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 40,
            runSpacing: 26,
            children: badges.map((b) {
              return _BadgeWidget(
                icon: iconFromString(b['icon'] as String? ?? 'verified'),
                label: b['label'] as String? ?? 'Badge',
                earned: b['earned'] as bool? ?? false,
                progress: (b['progress'] as num? ?? 0).toDouble(),
                animation: _counterAnim,
                isDark: isDark,
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildTipsCard(ThemeData theme, bool isDark) {
    final tips = [
      'Lend items you don\'t use often to earn trust points!',
      'Complete transactions on time to boost your trust score.',
      'Write reviews to help others make better decisions.',
      'Share items within your hostel for quick exchanges.',
    ];
    final randomTip = tips[(DateTime.now().second % tips.length)];
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.green[400]!, Colors.teal[400]!],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.lightbulb_outline, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Tip',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.8),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  randomTip,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFirstTimeState(ThemeData theme, bool isDark) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(100),
              ),
              child: const Icon(
                Icons.eco,
                color: Colors.white,
                size: 80,
              ),
            ),
            const SizedBox(height: 32),
            Text(
              'Start Making an Impact!',
              style: theme.textTheme.headlineSmall?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Borrow and lend items to see your positive impact on your wallet and the planet. Every share counts!',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.9),
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _FirstTimeFeature(icon: Icons.savings, label: 'Save Money'),
                const SizedBox(width: 24),
                _FirstTimeFeature(icon: Icons.eco, label: 'Go Green'),
                const SizedBox(width: 24),
                _FirstTimeFeature(icon: Icons.groups, label: 'Build Trust'),
              ],
            ),
            const SizedBox(height: 40),
            ElevatedButton.icon(
              icon: const Icon(Icons.explore),
              label: const Text('Explore Items'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.green[700],
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
                elevation: 4,
              ),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      ),
    );
  }
}

// --- Helper Widgets ---

class _FirstTimeFeature extends StatelessWidget {
  final IconData icon;
  final String label;

  const _FirstTimeFeature({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(icon, color: Colors.white, size: 28),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _LeaderboardAvatar extends StatelessWidget {
  final String? url;
  const _LeaderboardAvatar({Key? key, this.url}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (url == null || url!.isEmpty) {
      return CircleAvatar(
        backgroundColor: Colors.green[100],
        radius: 18,
        child: Icon(Icons.person, color: Colors.green[700], size: 20),
      );
    }
    return UserAvatar(avatarUrl: url!, radius: 18);
  }
}

class _ImpactStatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final num value;
  final String? suffix;
  final Color color;
  final Animation<double> animation;
  final bool fullWidth;

  const _ImpactStatCard({
    required this.icon,
    required this.label,
    required this.value,
    this.suffix,
    required this.color,
    required this.animation,
    this.fullWidth = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? color.withValues(alpha: 0.15) : color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: fullWidth
          ? Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: color, size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: TextStyle(
                          color: isDark ? Colors.grey[300] : Colors.grey[700],
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 4),
                      AnimatedBuilder(
                        animation: animation,
                        builder: (context, child) => Text(
                          '${suffix ?? ''}${(animation.value * value.toDouble()).toInt()}',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: color,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, color: color, size: 28),
                const SizedBox(height: 12),
                Text(
                  label,
                  style: TextStyle(
                    color: isDark ? Colors.grey[300] : Colors.grey[700],
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 4),
                AnimatedBuilder(
                  animation: animation,
                  builder: (context, child) => Text(
                    '${suffix ?? ''}${(animation.value * value.toDouble()).toInt()}',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

class _EnvironmentalStat extends StatelessWidget {
  final IconData icon;
  final num value;
  final String unit;
  final String label;
  final Animation<double> animation;
  final bool isDark;

  const _EnvironmentalStat({
    required this.icon,
    required this.value,
    required this.unit,
    required this.label,
    required this.animation,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.green[700]!.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: Colors.green[800], size: 28),
        ),
        const SizedBox(height: 12),
        AnimatedBuilder(
          animation: animation,
          builder: (context, child) => Text(
            '${(animation.value * value.toDouble()).toStringAsFixed(1)} $unit',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.green[200] : Colors.green[800],
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: isDark ? Colors.green[300] : Colors.green[700],
            fontSize: 13,
          ),
        ),
      ],
    );
  }
}

class _BadgeWidget extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool earned;
  final double progress;
  final Animation<double> animation;
  final bool isDark;

  const _BadgeWidget({
    required this.icon,
    required this.label,
    required this.earned,
    required this.progress,
    required this.animation,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 80,
      child: Column(
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              if (!earned)
                SizedBox(
                  width: 56,
                  height: 56,
                  child: AnimatedBuilder(
                    animation: animation,
                    builder: (context, child) => CircularProgressIndicator(
                      value: animation.value * progress,
                      backgroundColor: isDark ? Colors.grey[700] : Colors.grey[200],
                      valueColor: const AlwaysStoppedAnimation<Color>(Colors.green),
                      strokeWidth: 4,
                    ),
                  ),
                ),
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  gradient: earned
                      ? LinearGradient(colors: [Colors.green[600]!, Colors.teal[500]!])
                      : null,
                  color: earned ? null : (isDark ? Colors.grey[700] : Colors.grey[200]),
                  shape: BoxShape.circle,
                  boxShadow: earned
                      ? [
                          BoxShadow(
                            color: Colors.green.withValues(alpha: 0.3),
                            blurRadius: 8,
                            spreadRadius: 2,
                          ),
                        ]
                      : null,
                ),
                child: Icon(
                  icon,
                  color: earned ? Colors.white : (isDark ? Colors.grey[400] : Colors.grey[600]),
                  size: 24,
                ),
              ),
              if (earned)
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: Colors.amber,
                      shape: BoxShape.circle,
                      border: Border.all(color: isDark ? Colors.grey[900]! : Colors.white, width: 2),
                    ),
                    child: const Icon(Icons.check, color: Colors.white, size: 12),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              fontWeight: earned ? FontWeight.w600 : FontWeight.w400,
              color: earned
                  ? (isDark ? Colors.green[300] : Colors.green[800])
                  : (isDark ? Colors.grey[400] : Colors.grey[600]),
            ),
          ),
        ],
      ),
    );
  }
}
