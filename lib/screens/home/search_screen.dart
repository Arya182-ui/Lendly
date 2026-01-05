import 'package:flutter/material.dart';
import '../../config/env_config.dart';
import '../../services/item_service.dart';
import '../../widgets/app_image.dart';
import '../search/advanced_search_screen.dart';
import '../search/discovery_screen.dart';
import 'item_detail_screen.dart';

class SearchScreen extends StatefulWidget {
  final String? initialQuery;
  
  const SearchScreen({super.key, this.initialQuery});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _controller = TextEditingController();
  final List<String> _categories = [
    'Books', 'Tech', 'Sports', 'Tools', 'Gaming', 'Music', 'Electronics', 'Other'
  ];
  String _searchQuery = '';
  String? _selectedCategory;
  List<dynamic> _allItems = [];
  List<dynamic> _filteredItems = [];
  bool _loading = true;
  String? _error;
  final ItemService _service = ItemService(EnvConfig.apiBaseUrl);

  @override
  void initState() {
    super.initState();
    // Apply initial query if provided (from category selection)
    if (widget.initialQuery != null && widget.initialQuery!.isNotEmpty) {
      _searchQuery = widget.initialQuery!;
      _controller.text = widget.initialQuery!;
    }
    _fetchItems();
  }

  Future<void> _fetchItems() async {
    setState(() { _loading = true; _error = null; });
    try {
      final items = await _service.getItems();
      setState(() {
        _allItems = items;
        _filteredItems = items;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceAll('Exception: ', '')), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _filterItems() {
    List<dynamic> filtered = _allItems;
    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((item) =>
        (item['name'] ?? '').toString().toLowerCase().contains(_searchQuery.toLowerCase()) ||
        (item['description'] ?? '').toString().toLowerCase().contains(_searchQuery.toLowerCase())
      ).toList();
    }
    if (_selectedCategory != null && _selectedCategory!.isNotEmpty) {
      filtered = filtered.where((item) => (item['category'] ?? '').toString().toLowerCase() == _selectedCategory!.toLowerCase()).toList();
    }
    setState(() { _filteredItems = filtered; });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Search'),
        backgroundColor: Colors.green[700],
        actions: [
          IconButton(
            icon: const Icon(Icons.tune),
            tooltip: 'Advanced Search',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const AdvancedSearchScreen(),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.explore),
            tooltip: 'Discover',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const DiscoveryScreen(),
                ),
              );
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Material(
              elevation: 2,
              borderRadius: BorderRadius.circular(24),
              child: TextField(
                controller: _controller,
                onChanged: (val) {
                  setState(() => _searchQuery = val);
                  _filterItems();
                },
                decoration: InputDecoration(
                  hintText: 'Search for items, categories...',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _controller.clear();
                            setState(() => _searchQuery = '');
                            _filterItems();
                          },
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 14),
                ),
                textInputAction: TextInputAction.search,
              ),
            ),
            const SizedBox(height: 18),
            
            // Quick access buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const AdvancedSearchScreen(),
                        ),
                      );
                    },
                    icon: const Icon(Icons.tune),
                    label: const Text('Advanced Search'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1DBF73),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const DiscoveryScreen(),
                        ),
                      );
                    },
                    icon: const Icon(Icons.explore),
                    label: const Text('Discover'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF1DBF73),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      side: const BorderSide(color: Color(0xFF1DBF73)),
                    ),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 18),
            SizedBox(
              height: 38,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _categories.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, i) => ChoiceChip(
                  label: Text(_categories[i]),
                  selected: _selectedCategory == _categories[i],
                  onSelected: (selected) {
                    setState(() {
                      _selectedCategory = selected ? _categories[i] : null;
                      _filterItems();
                    });
                  },
                  selectedColor: Colors.green[100],
                  backgroundColor: Colors.grey[100],
                  labelStyle: TextStyle(
                    color: _selectedCategory == _categories[i]
                        ? Colors.green[900]
                        : Colors.grey[800],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 18),
            if (_loading)
              const Expanded(child: Center(child: CircularProgressIndicator())),
            if (_error != null)
              Expanded(child: Center(child: Text(_error!, style: TextStyle(color: Colors.red)))),
            if (!_loading && _error == null)
              Expanded(
                child: _filteredItems.isEmpty
                    ? Center(child: Text('No items found.', style: theme.textTheme.titleMedium))
                    : ListView.separated(
                        itemCount: _filteredItems.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (context, i) {
                          final item = _filteredItems[i];
                          return Card(
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            elevation: 2,
                            child: ListTile(
                              leading: ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: ItemImage(
                                  imageUrl: item['image'],
                                  width: 54,
                                  height: 54,
                                  fit: BoxFit.cover,
                                ),
                              ),
                              title: Text(item['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
                              subtitle: Text(item['description'] ?? '', maxLines: 2, overflow: TextOverflow.ellipsis),
                              trailing: Text(item['category'] ?? '', style: const TextStyle(fontSize: 13, color: Colors.green)),
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (context) => ItemDetailScreen(item: item)),
                                );
                              },
                            ),
                          );
                        },
                      ),
              ),
          ],
        ),
      ),
    );
  }
}
