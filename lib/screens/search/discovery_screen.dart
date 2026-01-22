import 'package:flutter/material.dart';
import '../../services/search_service.dart';
import '../../widgets/app_image.dart';
import '../home/item_detail_screen.dart';
import 'advanced_search_screen.dart';

class DiscoveryScreen extends StatefulWidget {
  const DiscoveryScreen({super.key});

  @override
  State<DiscoveryScreen> createState() => _DiscoveryScreenState();
}

class _DiscoveryScreenState extends State<DiscoveryScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final ScrollController _trendingScrollController = ScrollController();
  final ScrollController _newArrivalsScrollController = ScrollController();
  final ScrollController _nearbyScrollController = ScrollController();

  // Data state
  Map<String, List<dynamic>> _categoryItems = {};
  List<dynamic> _trendingItems = [];
  List<dynamic> _newArrivals = [];
  List<dynamic> _nearbyItems = [];
  bool _loading = true;
  bool _loadingMoreTrending = false;
  bool _loadingMoreNewArrivals = false;
  bool _loadingMoreNearby = false;
  String? _error;

  // Categories with icons - using lowercase values matching backend
  final List<Map<String, dynamic>> _categories = [
    {'name': 'Books', 'value': 'books', 'icon': Icons.menu_book, 'color': Colors.blue},
    {'name': 'Electronics', 'value': 'electronics', 'icon': Icons.laptop, 'color': Colors.purple},
    {'name': 'Sports', 'value': 'sports', 'icon': Icons.sports_soccer, 'color': Colors.orange},
    {'name': 'Tools', 'value': 'tools', 'icon': Icons.build, 'color': Colors.brown},
    {'name': 'Clothing', 'value': 'clothing', 'icon': Icons.checkroom, 'color': Colors.pink},
    {'name': 'Furniture', 'value': 'furniture', 'icon': Icons.chair, 'color': Colors.teal},
    {'name': 'Other', 'value': 'other', 'icon': Icons.category, 'color': Colors.grey},
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadDiscoveryData();

    _trendingScrollController.addListener(() {
      if (_trendingScrollController.position.pixels ==
          _trendingScrollController.position.maxScrollExtent) {
        _loadMoreTrendingItems();
      }
    });

    _newArrivalsScrollController.addListener(() {
      if (_newArrivalsScrollController.position.pixels ==
          _newArrivalsScrollController.position.maxScrollExtent) {
        _loadMoreNewArrivals();
      }
    });

    _nearbyScrollController.addListener(() {
      if (_nearbyScrollController.position.pixels ==
          _nearbyScrollController.position.maxScrollExtent) {
        _loadMoreNearbyItems();
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _trendingScrollController.dispose();
    _newArrivalsScrollController.dispose();
    _nearbyScrollController.dispose();
    super.dispose();
  }

  Future<void> _loadMoreTrendingItems() async {
    if (_loadingMoreTrending) return;
    setState(() {
      _loadingMoreTrending = true;
    });

    try {
      final newItems = await SearchService.getTrendingItems(
        offset: _trendingItems.length,
      );
      setState(() {
        _trendingItems.addAll(newItems);
        _loadingMoreTrending = false;
      });
    } catch (e) {
      setState(() {
        _loadingMoreTrending = false;
      });
    }
  }

  Future<void> _loadMoreNewArrivals() async {
    if (_loadingMoreNewArrivals) return;
    setState(() {
      _loadingMoreNewArrivals = true;
    });

    try {
      final newItems = await SearchService.getNewArrivals(
        offset: _newArrivals.length,
      );
      setState(() {
        _newArrivals.addAll(newItems);
        _loadingMoreNewArrivals = false;
      });
    } catch (e) {
      setState(() {
        _loadingMoreNewArrivals = false;
      });
    }
  }

  Future<void> _loadMoreNearbyItems() async {
    if (_loadingMoreNearby) return;
    setState(() {
      _loadingMoreNearby = true;
    });

    try {
      // Note: This requires the SearchService to be updated to handle location for "nearby"
      final newItems = await SearchService.getNearbyItems(
        latitude: 0, // Replace with actual user location
        longitude: 0, // Replace with actual user location
        offset: _nearbyItems.length,
      );
      setState(() {
        _nearbyItems.addAll(newItems);
        _loadingMoreNearby = false;
      });
    } catch (e) {
      setState(() {
        _loadingMoreNearby = false;
      });
    }
  }

  Future<void> _loadDiscoveryData() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      // Load categories with items
      final categoriesData = await SearchService.getItemsByCategories(limit: 10);
      
      // Process categories
      final Map<String, List<dynamic>> categorized = {};
      for (final category in _categories) {
        final categoryName = category['name'] as String;
        final categoryData = categoriesData[categoryName.toLowerCase()];
        if (categoryData != null && categoryData['items'] != null) {
          categorized[categoryName] = List<dynamic>.from(categoryData['items']);
        } else {
          categorized[categoryName] = [];
        }
      }

      // Get trending and new arrivals
      final trending = await SearchService.getTrendingItems(limit: 10);
      final newItems = await SearchService.getNewArrivals(limit: 10);
      
      // For nearby items, we'd need location - for now use general results
      final nearby = await SearchService.searchItems(
        availableOnly: true,
        sortBy: 'newest',
        limit: 10,
      );

      setState(() {
        _categoryItems = categorized;
        _trendingItems = trending;
        _newArrivals = newItems;
        _nearbyItems = nearby['items'] ?? [];
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Widget _buildCategoryGrid() {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 1.2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: _categories.length,
      itemBuilder: (context, index) {
        final category = _categories[index];
        final items = _categoryItems[category['name']] ?? [];
        final color = category['color'] as Color;

        return Card(
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => CategoryDetailScreen(
                    categoryName: category['name'],
                    items: items,
                  ),
                ),
              );
            },
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: LinearGradient(
                  colors: [
                    color.withOpacity(0.1),
                    color.withOpacity(0.2),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      category['icon'] as IconData,
                      size: 32,
                      color: color,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    category['name'],
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${items.length} items',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildItemsList(List<dynamic> items, ScrollController controller, bool loadingMore) {
    if (items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox_outlined, size: 64, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text(
              'No items available',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      controller: controller,
      padding: const EdgeInsets.all(16),
      itemCount: items.length + (loadingMore ? 1 : 0),
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        if (index == items.length) {
          return const Center(child: CircularProgressIndicator());
        }
        final item = items[index];
        return _buildItemCard(item);
      },
    );
  }

  Widget _buildItemCard(Map<String, dynamic> item) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ItemDetailScreen(item: item),
            ),
          );
        },
        child: Container(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Image
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: item['image'] != null && item['image'].toString().isNotEmpty
                    ? Image.network(
                        item['image'],
                        width: 80,
                        height: 80,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) =>
                            Container(
                              width: 80,
                              height: 80,
                              color: Colors.grey[200],
                              child: Icon(Icons.image_not_supported, color: Colors.grey[500]),
                            ),
                      )
                    : Container(
                        width: 80,
                        height: 80,
                        color: Colors.grey[200],
                        child: Icon(Icons.image, color: Colors.grey[500]),
                      ),
              ),
              const SizedBox(width: 12),

              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item['name'] ?? '',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1a237e),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),

                    Text(
                      item['owner'] ?? '',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 8),

                    Row(
                      children: [
                        if (item['price'] != null && item['price'] > 0) ...[
                          Text(
                            'â‚¹${item['price']}',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1DBF73),
                            ),
                          ),
                          const SizedBox(width: 16),
                        ],

                        Icon(
                          item['available'] == true ? Icons.check_circle : Icons.cancel,
                          color: item['available'] == true ? const Color(0xFF1DBF73) : Colors.red,
                          size: 16,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          item['available'] == true ? 'Available' : 'Unavailable',
                          style: TextStyle(
                            color: item['available'] == true ? const Color(0xFF1DBF73) : Colors.red,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Category chip
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF1DBF73),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  item['category'] ?? '',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Discover'),
        backgroundColor: const Color(0xFF1DBF73),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const AdvancedSearchScreen(),
                ),
              );
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(text: 'Categories'),
            Tab(text: 'Trending'),
            Tab(text: 'New'),
            Tab(text: 'Nearby'),
          ],
        ),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF1DBF73)),
              ),
            )
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error, size: 64, color: Colors.red[300]),
                      const SizedBox(height: 16),
                      Text(
                        'Something went wrong',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[700],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _error!,
                        style: TextStyle(color: Colors.grey[600]),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadDiscoveryData,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildCategoryGrid(),
                    _buildItemsList(_trendingItems, _trendingScrollController, _loadingMoreTrending),
                    _buildItemsList(_newArrivals, _newArrivalsScrollController, _loadingMoreNewArrivals),
                    _buildItemsList(_nearbyItems, _nearbyScrollController, _loadingMoreNearby),
                  ],
                ),
    );
  }
}

class CategoryDetailScreen extends StatefulWidget {
  final String categoryName;
  final List<dynamic> items;

  const CategoryDetailScreen({
    super.key,
    required this.categoryName,
    required this.items,
  });

  @override
  State<CategoryDetailScreen> createState() => _CategoryDetailScreenState();
}

class _CategoryDetailScreenState extends State<CategoryDetailScreen> {
  List<dynamic> _filteredItems = [];
  String _sortBy = 'newest';

  final List<Map<String, String>> _sortOptions = [
    {'value': 'newest', 'label': 'Newest First'},
    {'value': 'oldest', 'label': 'Oldest First'},
    {'value': 'price_low', 'label': 'Price: Low to High'},
    {'value': 'price_high', 'label': 'Price: High to Low'},
  ];

  @override
  void initState() {
    super.initState();
    _filteredItems = List.from(widget.items);
    _sortItems();
  }

  void _sortItems() {
    switch (_sortBy) {
      case 'newest':
        _filteredItems.sort((a, b) {
          final aDate = DateTime.tryParse(a['createdAt'] ?? '') ?? DateTime.now();
          final bDate = DateTime.tryParse(b['createdAt'] ?? '') ?? DateTime.now();
          return bDate.compareTo(aDate);
        });
        break;
      case 'oldest':
        _filteredItems.sort((a, b) {
          final aDate = DateTime.tryParse(a['createdAt'] ?? '') ?? DateTime.now();
          final bDate = DateTime.tryParse(b['createdAt'] ?? '') ?? DateTime.now();
          return aDate.compareTo(bDate);
        });
        break;
      case 'price_low':
        _filteredItems.sort((a, b) {
          final aPrice = (a['price'] ?? 0).toDouble();
          final bPrice = (b['price'] ?? 0).toDouble();
          return aPrice.compareTo(bPrice);
        });
        break;
      case 'price_high':
        _filteredItems.sort((a, b) {
          final aPrice = (a['price'] ?? 0).toDouble();
          final bPrice = (b['price'] ?? 0).toDouble();
          return bPrice.compareTo(aPrice);
        });
        break;
    }
    setState(() {});
  }

  void _showSortOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Sort by',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            ..._sortOptions.map((option) => ListTile(
              title: Text(option['label']!),
              trailing: _sortBy == option['value']
                  ? const Icon(Icons.check, color: Color(0xFF1DBF73))
                  : null,
              onTap: () {
                setState(() {
                  _sortBy = option['value']!;
                });
                _sortItems();
                Navigator.pop(context);
              },
            )),
          ],
        ),
      ),
    );
  }

  Widget _buildItemCard(Map<String, dynamic> item) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ItemDetailScreen(item: item),
            ),
          );
        },
        child: Container(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Image
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: item['image'] != null && item['image'].toString().isNotEmpty
                    ? Image.network(
                        item['image'],
                        width: 80,
                        height: 80,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) =>
                            Container(
                              width: 80,
                              height: 80,
                              color: Colors.grey[200],
                              child: Icon(Icons.image_not_supported, color: Colors.grey[500]),
                            ),
                      )
                    : Container(
                        width: 80,
                        height: 80,
                        color: Colors.grey[200],
                        child: Icon(Icons.image, color: Colors.grey[500]),
                      ),
              ),
              const SizedBox(width: 12),

              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item['name'] ?? '',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1a237e),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),

                    Text(
                      item['description'] ?? '',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        if (item['price'] != null && item['price'] > 0)
                          Text(
                            'â‚¹${item['price']}',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1DBF73),
                            ),
                          ),

                        Row(
                          children: [
                            Icon(
                              item['available'] == true ? Icons.check_circle : Icons.cancel,
                              color: item['available'] == true ? const Color(0xFF1DBF73) : Colors.red,
                              size: 16,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              item['available'] == true ? 'Available' : 'Unavailable',
                              style: TextStyle(
                                color: item['available'] == true ? const Color(0xFF1DBF73) : Colors.red,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(widget.categoryName),
        backgroundColor: const Color(0xFF1DBF73),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.sort),
            onPressed: _showSortOptions,
          ),
        ],
      ),
      body: Column(
        children: [
          // Items count
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${_filteredItems.length} items in ${widget.categoryName}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1a237e),
                  ),
                ),
                Text(
                  'Sort: ${_sortOptions.firstWhere((o) => o['value'] == _sortBy)['label']}',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),

          // Items list
          Expanded(
            child: _filteredItems.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.inbox_outlined, size: 64, color: Colors.grey[300]),
                        const SizedBox(height: 16),
                        Text(
                          'No items in this category',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _filteredItems.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      return _buildItemCard(_filteredItems[index]);
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
