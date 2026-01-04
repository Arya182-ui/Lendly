import 'package:flutter/material.dart';
import '../../services/search_service.dart';
import '../../widgets/app_image.dart';
import '../home/item_detail_screen.dart';

class AdvancedSearchScreen extends StatefulWidget {
  const AdvancedSearchScreen({super.key});

  @override
  State<AdvancedSearchScreen> createState() => _AdvancedSearchScreenState();
}

class _AdvancedSearchScreenState extends State<AdvancedSearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  
  // Search state
  String _searchQuery = '';
  List<dynamic> _filteredItems = [];
  bool _loading = false;
  String? _error;
  
  // Filter state
  String? _selectedCategory;
  String? _selectedType;
  String? _selectedCondition;
  RangeValues _priceRange = const RangeValues(0, 1000);
  double _maxDistance = 50; // km
  String _sortBy = 'newest'; // newest, oldest, price_low, price_high, distance
  bool _availableOnly = true;
  
  // Filter options
  final List<String> _categories = ['Books', 'Tech', 'Sports', 'Tools', 'Other'];
  final List<String> _types = ['lend', 'sell', 'borrow'];
  final List<String> _conditions = ['new', 'like_new', 'good', 'fair'];
  final List<Map<String, String>> _sortOptions = [
    {'value': 'newest', 'label': 'Newest First'},
    {'value': 'oldest', 'label': 'Oldest First'},
    {'value': 'price_low', 'label': 'Price: Low to High'},
    {'value': 'price_high', 'label': 'Price: High to Low'},
    {'value': 'distance', 'label': 'Distance'},
  ];

  @override
  void initState() {
    super.initState();
    // Start with an empty search - user will trigger search when ready
    _performSearch();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _performSearch() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final result = await SearchService.searchItems(
        query: _searchQuery.isEmpty ? null : _searchQuery,
        category: _selectedCategory,
        type: _selectedType,
        condition: _selectedCondition,
        minPrice: _priceRange.start > 0 ? _priceRange.start : null,
        maxPrice: _priceRange.end < 5000 ? _priceRange.end : null,
        availableOnly: _availableOnly,
        sortBy: _sortBy,
        limit: 100,
      );

      setState(() {
        _filteredItems = result['items'] ?? [];
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  void _clearFilters() {
    setState(() {
      _selectedCategory = null;
      _selectedType = null;
      _selectedCondition = null;
      _priceRange = const RangeValues(0, 1000);
      _maxDistance = 50;
      _sortBy = 'newest';
      _availableOnly = true;
      _searchController.clear();
      _searchQuery = '';
    });
    _performSearch();
  }

  void _showFilterSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.8,
        minChildSize: 0.5,
        maxChildSize: 0.9,
        builder: (context, scrollController) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Handle bar
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              
              // Header
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Filter & Sort',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        _clearFilters();
                        Navigator.pop(context);
                      },
                      child: const Text('Clear All'),
                    ),
                  ],
                ),
              ),
              
              // Filter content
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    _buildFilterSection(
                      'Category',
                      _buildCategoryFilter(),
                    ),
                    const SizedBox(height: 20),
                    
                    _buildFilterSection(
                      'Type',
                      _buildTypeFilter(),
                    ),
                    const SizedBox(height: 20),
                    
                    _buildFilterSection(
                      'Condition',
                      _buildConditionFilter(),
                    ),
                    const SizedBox(height: 20),
                    
                    _buildFilterSection(
                      'Price Range (₹${_priceRange.start.round()} - ₹${_priceRange.end.round()})',
                      _buildPriceRangeFilter(),
                    ),
                    const SizedBox(height: 20),
                    
                    _buildFilterSection(
                      'Sort By',
                      _buildSortFilter(),
                    ),
                    const SizedBox(height: 20),
                    
                    _buildFilterSection(
                      'Other Options',
                      _buildOtherOptions(),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
              
              // Apply button
              Padding(
                padding: const EdgeInsets.all(16),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      _performSearch();
                      Navigator.pop(context);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1DBF73),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text('Apply Filters (${_filteredItems.length} items)'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterSection(String title, Widget content) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Color(0xFF1a237e),
          ),
        ),
        const SizedBox(height: 12),
        content,
      ],
    );
  }

  Widget _buildCategoryFilter() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _categories.map((category) => FilterChip(
        label: Text(category),
        selected: _selectedCategory == category,
        onSelected: (selected) {
          setState(() {
            _selectedCategory = selected ? category : null;
          });
        },
        selectedColor: const Color(0xFF1DBF73),
        backgroundColor: Colors.grey[100],
        labelStyle: TextStyle(
          color: _selectedCategory == category ? Colors.white : Colors.black87,
        ),
      )).toList(),
    );
  }

  Widget _buildTypeFilter() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _types.map((type) => FilterChip(
        label: Text(_getTypeLabel(type)),
        selected: _selectedType == type,
        onSelected: (selected) {
          setState(() {
            _selectedType = selected ? type : null;
          });
        },
        selectedColor: const Color(0xFF1DBF73),
        backgroundColor: Colors.grey[100],
        labelStyle: TextStyle(
          color: _selectedType == type ? Colors.white : Colors.black87,
        ),
      )).toList(),
    );
  }

  Widget _buildConditionFilter() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _conditions.map((condition) => FilterChip(
        label: Text(_getConditionLabel(condition)),
        selected: _selectedCondition == condition,
        onSelected: (selected) {
          setState(() {
            _selectedCondition = selected ? condition : null;
          });
        },
        selectedColor: const Color(0xFF1DBF73),
        backgroundColor: Colors.grey[100],
        labelStyle: TextStyle(
          color: _selectedCondition == condition ? Colors.white : Colors.black87,
        ),
      )).toList(),
    );
  }

  Widget _buildPriceRangeFilter() {
    return Column(
      children: [
        RangeSlider(
          values: _priceRange,
          min: 0,
          max: 5000,
          divisions: 50,
          activeColor: const Color(0xFF1DBF73),
          inactiveColor: Colors.grey[300],
          onChanged: (values) {
            setState(() {
              _priceRange = values;
            });
          },
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('₹0', style: TextStyle(color: Colors.grey[600])),
            Text('₹5000', style: TextStyle(color: Colors.grey[600])),
          ],
        ),
      ],
    );
  }

  Widget _buildSortFilter() {
    return Column(
      children: _sortOptions.map((option) => RadioListTile<String>(
        title: Text(option['label']!),
        value: option['value']!,
        groupValue: _sortBy,
        activeColor: const Color(0xFF1DBF73),
        contentPadding: EdgeInsets.zero,
        onChanged: (value) {
          setState(() {
            _sortBy = value!;
          });
        },
      )).toList(),
    );
  }

  Widget _buildOtherOptions() {
    return Column(
      children: [
        SwitchListTile(
          title: const Text('Available items only'),
          subtitle: const Text('Hide unavailable items'),
          value: _availableOnly,
          activeColor: const Color(0xFF1DBF73),
          contentPadding: EdgeInsets.zero,
          onChanged: (value) {
            setState(() {
              _availableOnly = value;
            });
          },
        ),
      ],
    );
  }

  String _getTypeLabel(String type) {
    switch (type) {
      case 'lend':
        return 'Lend (Rent)';
      case 'sell':
        return 'Sell';
      case 'borrow':
        return 'Borrow Request';
      default:
        return type;
    }
  }

  String _getConditionLabel(String condition) {
    switch (condition) {
      case 'new':
        return 'New';
      case 'like_new':
        return 'Like New';
      case 'good':
        return 'Good';
      case 'fair':
        return 'Fair';
      default:
        return condition;
    }
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
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Image
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: ItemImage(
                  imageUrl: item['image'],
                  width: 80,
                  height: 80,
                  fit: BoxFit.cover,
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
                      children: [
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
                        const SizedBox(width: 8),
                        
                        // Type chip
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.blue[100],
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            _getTypeLabel(item['type'] ?? ''),
                            style: TextStyle(
                              color: Colors.blue[800],
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        if (item['price'] != null && item['price'] > 0)
                          Text(
                            '₹${item['price']}',
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
        title: const Text('Advanced Search'),
        backgroundColor: const Color(0xFF1DBF73),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.tune),
            onPressed: _showFilterSheet,
          ),
        ],
      ),
      body: Column(
        children: [
          // Search bar
          Container(
            color: const Color(0xFF1DBF73),
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: TextField(
                controller: _searchController,
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value;
                  });
                  _performSearch();
                },
                decoration: InputDecoration(
                  hintText: 'Search items, owners, descriptions...',
                  prefixIcon: const Icon(Icons.search, color: Colors.grey),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, color: Colors.grey),
                          onPressed: () {
                            _searchController.clear();
                            setState(() {
                              _searchQuery = '';
                            });
                            _performSearch();
                          },
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                ),
              ),
            ),
          ),
          
          // Active filters display
          if (_selectedCategory != null || _selectedType != null || _selectedCondition != null || !_availableOnly)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  const Text(
                    'Active filters: ',
                    style: TextStyle(fontWeight: FontWeight.w500),
                  ),
                  Expanded(
                    child: Wrap(
                      spacing: 8,
                      children: [
                        if (_selectedCategory != null)
                          Chip(
                            label: Text(_selectedCategory!),
                            onDeleted: () {
                              setState(() {
                                _selectedCategory = null;
                              });
                              _performSearch();
                            },
                            backgroundColor: const Color(0xFF1DBF73),
                            labelStyle: const TextStyle(color: Colors.white),
                          ),
                        if (_selectedType != null)
                          Chip(
                            label: Text(_getTypeLabel(_selectedType!)),
                            onDeleted: () {
                              setState(() {
                                _selectedType = null;
                              });
                              _performSearch();
                            },
                            backgroundColor: Colors.blue[100],
                            labelStyle: TextStyle(color: Colors.blue[800]),
                          ),
                        if (_selectedCondition != null)
                          Chip(
                            label: Text(_getConditionLabel(_selectedCondition!)),
                            onDeleted: () {
                              setState(() {
                                _selectedCondition = null;
                              });
                              _performSearch();
                            },
                            backgroundColor: Colors.orange[100],
                            labelStyle: TextStyle(color: Colors.orange[800]),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          
          // Results
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF1DBF73)),
                  ))
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
                              onPressed: _performSearch,
                              child: const Text('Retry'),
                            ),
                          ],
                        ),
                      )
                    : _filteredItems.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.search_off, size: 64, color: Colors.grey[300]),
                                const SizedBox(height: 16),
                                Text(
                                  'No items found',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.grey[700],
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Try adjusting your search or filters',
                                  style: TextStyle(color: Colors.grey[600]),
                                ),
                              ],
                            ),
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Results count
                              Padding(
                                padding: const EdgeInsets.all(16),
                                child: Text(
                                  '${_filteredItems.length} items found',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF1a237e),
                                  ),
                                ),
                              ),
                              
                              // Items list
                              Expanded(
                                child: ListView.separated(
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
          ),
        ],
      ),
    );
  }
}