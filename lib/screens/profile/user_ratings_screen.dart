import 'package:flutter/material.dart';
import '../../services/rating_service.dart';
import '../../widgets/avatar_options.dart';
import 'package:flutter_svg/flutter_svg.dart';

class UserRatingsScreen extends StatefulWidget {
  final String uid;
  final String userName;

  const UserRatingsScreen({
    Key? key,
    required this.uid,
    required this.userName,
  }) : super(key: key);

  @override
  State<UserRatingsScreen> createState() => _UserRatingsScreenState();
}

class _UserRatingsScreenState extends State<UserRatingsScreen> {
  List<Map<String, dynamic>> _ratings = [];
  Map<String, dynamic> _ratingSummary = {};
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadRatings();
  }

  Future<void> _loadRatings() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final results = await Future.wait([
        RatingService.getRatings(widget.uid),
        RatingService.getUserRatingSummary(widget.uid),
      ]);

      setState(() {
        _ratings = results[0] as List<Map<String, dynamic>>;
        _ratingSummary = results[1] as Map<String, dynamic>;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return 'Unknown date';
    
    try {
      final date = DateTime.parse(dateStr);
      final now = DateTime.now();
      final diff = now.difference(date);
      
      if (diff.inDays == 0) {
        return 'Today';
      } else if (diff.inDays == 1) {
        return 'Yesterday';
      } else if (diff.inDays < 7) {
        return '${diff.inDays} days ago';
      } else {
        return '${date.day}/${date.month}/${date.year}';
      }
    } catch (e) {
      return dateStr;
    }
  }

  Widget _buildRatingSummary() {
    final rating = (_ratingSummary['rating'] ?? 0.0).toDouble();
    final totalRatings = _ratingSummary['totalRatings'] ?? 0;
    final trustScore = _ratingSummary['trustScore'] ?? 0;

    return Card(
      margin: const EdgeInsets.all(16),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    children: [
                      Text(
                        rating.toStringAsFixed(1),
                        style: const TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1a237e),
                        ),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(5, (index) {
                          return Icon(
                            index < rating.floor() 
                                ? Icons.star 
                                : (index < rating) 
                                    ? Icons.star_half 
                                    : Icons.star_border,
                            color: Colors.amber,
                            size: 20,
                          );
                        }),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$totalRatings reviews',
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 1,
                  height: 80,
                  color: Colors.grey.withOpacity(0.3),
                ),
                Expanded(
                  child: Column(
                    children: [
                      Text(
                        '$trustScore',
                        style: const TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1DBF73),
                        ),
                      ),
                      const Text(
                        'Trust Score',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1DBF73),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _getTrustLevel(trustScore),
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _getTrustLevel(int trustScore) {
    if (trustScore >= 80) return 'Excellent';
    if (trustScore >= 60) return 'Good';
    if (trustScore >= 40) return 'Fair';
    if (trustScore >= 20) return 'Poor';
    return 'New User';
  }

  Widget _buildRatingItem(Map<String, dynamic> rating) {
    final fromUserName = rating['fromUserName'] ?? 'Anonymous';
    final fromUserAvatar = rating['fromUserAvatar'];
    final stars = rating['rating'] ?? 0;
    final review = rating['review'] ?? '';
    final createdAt = rating['createdAt'];

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // User avatar
                CircleAvatar(
                  radius: 20,
                  backgroundColor: const Color(0xFFE8F9F1),
                  child: fromUserAvatar != null && AvatarOptions.avatarOptions.contains(fromUserAvatar)
                      ? SvgPicture.asset(
                          fromUserAvatar,
                          width: 32,
                          height: 32,
                        )
                      : const Icon(Icons.person, color: Color(0xFF1DBF73)),
                ),
                const SizedBox(width: 12),
                
                // User name and date
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        fromUserName,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        _formatDate(createdAt),
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Star rating
                Row(
                  children: List.generate(5, (index) {
                    return Icon(
                      index < stars ? Icons.star : Icons.star_border,
                      color: Colors.amber,
                      size: 18,
                    );
                  }),
                ),
              ],
            ),
            
            // Review text
            if (review.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  review,
                  style: const TextStyle(fontSize: 14),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.userName}\'s Reviews'),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1a237e),
        elevation: 0.5,
      ),
      backgroundColor: const Color(0xFFF8FAFB),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, size: 80, color: Colors.red),
                      const SizedBox(height: 16),
                      Text(_error!, textAlign: TextAlign.center),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadRatings,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadRatings,
                  child: CustomScrollView(
                    slivers: [
                      // Rating summary
                      SliverToBoxAdapter(
                        child: _buildRatingSummary(),
                      ),
                      
                      // Reviews list
                      if (_ratings.isEmpty)
                        SliverFillRemaining(
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.star_border,
                                  size: 80,
                                  color: Colors.grey,
                                ),
                                const SizedBox(height: 16),
                                const Text(
                                  'No reviews yet',
                                  style: TextStyle(
                                    fontSize: 18,
                                    color: Colors.grey,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                const Text(
                                  'Reviews from transactions will appear here',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      else
                        SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, index) => _buildRatingItem(_ratings[index]),
                            childCount: _ratings.length,
                          ),
                        ),
                    ],
                  ),
                ),
    );
  }
}