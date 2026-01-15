import 'package:flutter/material.dart';
import '../../config/env_config.dart';
import '../../services/item_service.dart';
import '../../services/session_service.dart';
import '../../services/image_service.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';

class AddItemScreen extends StatefulWidget {
  const AddItemScreen({Key? key}) : super(key: key);

  @override
  State<AddItemScreen> createState() => _AddItemScreenState();
}

class _AddItemScreenState extends State<AddItemScreen> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descController = TextEditingController();
  final _priceController = TextEditingController();
  String _category = 'books';
  String _type = 'borrow';
  bool _loading = false;
  String? _error;
  File? _selectedImage;
  final ItemService _service = ItemService(EnvConfig.apiBaseUrl);
  
  late AnimationController _animController;
  late Animation<double> _fadeAnim;

  final List<Map<String, dynamic>> _categories = [
    {'id': 'books', 'name': 'Books', 'icon': Icons.menu_book_rounded, 'color': const Color(0xFF6366F1)},
    {'id': 'electronics', 'name': 'Electronics', 'icon': Icons.devices_rounded, 'color': const Color(0xFF10B981)},
    {'id': 'sports', 'name': 'Sports', 'icon': Icons.sports_basketball_rounded, 'color': const Color(0xFFF59E0B)},
    {'id': 'tools', 'name': 'Tools', 'icon': Icons.build_rounded, 'color': const Color(0xFFEF4444)},
    {'id': 'clothing', 'name': 'Clothing', 'icon': Icons.checkroom_rounded, 'color': const Color(0xFFEC4899)},
    {'id': 'furniture', 'name': 'Furniture', 'icon': Icons.chair_rounded, 'color': const Color(0xFF8B5CF6)},
    {'id': 'other', 'name': 'Other', 'icon': Icons.category_rounded, 'color': const Color(0xFF64748B)},
  ];

  final List<Map<String, dynamic>> _types = [
    {'id': 'lend', 'name': 'Lend', 'desc': 'Rent out your item', 'icon': Icons.currency_exchange_rounded, 'color': const Color(0xFF1DBF73)},
    {'id': 'sell', 'name': 'Sell', 'desc': 'Sell your item', 'icon': Icons.sell_rounded, 'color': const Color(0xFF6366F1)},
    {'id': 'borrow', 'name': 'Borrow', 'desc': 'Request to borrow', 'icon': Icons.handshake_rounded, 'color': const Color(0xFFF59E0B)},
  ];

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    _nameController.dispose();
    _descController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final file = await ImageService.showImagePickerDialog(context);
      if (file != null) {
        setState(() {
          _selectedImage = file;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error picking image: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _loading = true; _error = null; });
    final uid = await SessionService.getUid();
    if (uid == null) {
      setState(() { _loading = false; _error = 'User not logged in.'; });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('User not logged in.'), backgroundColor: Colors.red),
      );
      return;
    }
    double? latitude;
    double? longitude;
    try {
      final locPerm = await Geolocator.checkPermission();
      if (locPerm == LocationPermission.denied) {
        await Geolocator.requestPermission();
      }
      final pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      latitude = pos.latitude;
      longitude = pos.longitude;
    } catch (e) {
      // If location fails, continue without it
      latitude = null;
      longitude = null;
    }
    try {
      final newItem = await _service.addItem(
        name: _nameController.text.trim(),
        description: _descController.text.trim(),
        category: _category,
        price: double.tryParse(_priceController.text) ?? 0,
        type: _type,
        ownerId: uid,
        imageFile: _selectedImage,
        latitude: latitude,
        longitude: longitude,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Item added successfully!'), backgroundColor: Colors.green),
        );
        if (Navigator.canPop(context)) {
          Navigator.pop(context, newItem); // Pass new item data for optimistic update
        }
      }
    } catch (e) {
      setState(() { _error = e.toString(); });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceAll('Exception: ', '')), backgroundColor: Colors.red),
      );
    } finally {
      setState(() { _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          SliverAppBar(
            expandedHeight: 120,
            floating: true,
            pinned: true,
            backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
            elevation: 0,
            leading: IconButton(
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: (isDark ? Colors.white : Colors.black).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.arrow_back, color: isDark ? Colors.white : Colors.black87),
              ),
              onPressed: () => Navigator.pop(context),
            ),
            flexibleSpace: FlexibleSpaceBar(
              centerTitle: false,
              titlePadding: const EdgeInsets.only(left: 56, bottom: 16),
              title: Text(
                'Add New Item',
                style: TextStyle(
                  color: isDark ? Colors.white : Colors.black87,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isDark
                        ? [const Color(0xFF1E293B), const Color(0xFF0F172A)]
                        : [Colors.white, const Color(0xFFF1F5F9)],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),
            ),
          ),
        ],
        body: FadeTransition(
          opacity: _fadeAnim,
          child: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                // Image picker section
                _buildSectionTitle('Item Photo', Icons.image_rounded),
                const SizedBox(height: 12),
                _buildImagePicker(isDark),
                const SizedBox(height: 28),

                // Item details section
                _buildSectionTitle('Item Details', Icons.info_outline_rounded),
                const SizedBox(height: 12),
                _buildTextField(
                  controller: _nameController,
                  label: 'Item Name',
                  hint: 'e.g., Engineering Textbook',
                  icon: Icons.label_outline_rounded,
                  maxLength: 40,
                  isDark: isDark,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Item name is required';
                    if (v.trim().length > 40) return 'Max 40 characters allowed';
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                _buildTextField(
                  controller: _descController,
                  label: 'Description',
                  hint: 'Describe your item briefly...',
                  icon: Icons.description_outlined,
                  maxLength: 120,
                  maxLines: 3,
                  isDark: isDark,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Description is required';
                    if (v.trim().length > 120) return 'Max 120 characters allowed';
                    return null;
                  },
                ),
                const SizedBox(height: 28),

                // Category section
                _buildSectionTitle('Category', Icons.category_rounded),
                const SizedBox(height: 12),
                _buildCategorySelector(isDark),
                const SizedBox(height: 28),

                // Type section
                _buildSectionTitle('Listing Type', Icons.swap_horiz_rounded),
                const SizedBox(height: 12),
                _buildTypeSelector(isDark),
                
                // Price field (conditional)
                if (_type == 'lend' || _type == 'sell') ...[
                  const SizedBox(height: 28),
                  _buildSectionTitle('Pricing', Icons.currency_rupee_rounded),
                  const SizedBox(height: 12),
                  _buildTextField(
                    controller: _priceController,
                    label: _type == 'lend' ? 'Rent per day (₹)' : 'Price (₹)',
                    hint: _type == 'lend' ? 'e.g., 50' : 'e.g., 500',
                    icon: Icons.currency_rupee_rounded,
                    keyboardType: TextInputType.number,
                    isDark: isDark,
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Price is required';
                      final price = double.tryParse(v);
                      if (price == null || price <= 0) return 'Enter a valid price';
                      return null;
                    },
                  ),
                ],
                
                const SizedBox(height: 32),
                
                // Error message
                if (_error != null) ...[
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.red.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline, color: Colors.red),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _error!.replaceAll('Exception: ', ''),
                            style: const TextStyle(color: Colors.red, fontSize: 14),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                
                // Submit button
                _buildSubmitButton(isDark),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 20, color: const Color(0xFF1DBF73)),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Color(0xFF1DBF73),
          ),
        ),
      ],
    );
  }

  Widget _buildImagePicker(bool isDark) {
    return GestureDetector(
      onTap: _loading ? null : _pickImage,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 180,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: _selectedImage != null 
                ? const Color(0xFF1DBF73) 
                : (isDark ? Colors.grey[700]! : Colors.grey[300]!),
            width: _selectedImage != null ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: _selectedImage != null ? _buildSelectedImage() : _buildImagePlaceholder(isDark),
      ),
    );
  }

  Widget _buildSelectedImage() {
    return Stack(
      fit: StackFit.expand,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Image.file(_selectedImage!, fit: BoxFit.cover),
        ),
        Positioned(
          top: 12,
          right: 12,
          child: GestureDetector(
            onTap: () => setState(() => _selectedImage = null),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.red.withOpacity(0.4),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(Icons.close, color: Colors.white, size: 18),
            ),
          ),
        ),
        Positioned(
          bottom: 12,
          left: 12,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.black54,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.check_circle, color: Color(0xFF1DBF73), size: 16),
                SizedBox(width: 6),
                Text('Image Selected', style: TextStyle(color: Colors.white, fontSize: 12)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildImagePlaceholder(bool isDark) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF1DBF73).withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.add_a_photo_rounded, size: 32, color: Color(0xFF1DBF73)),
        ),
        const SizedBox(height: 12),
        Text(
          'Add Item Photo',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white : Colors.grey[800],
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Tap to take or choose a photo',
          style: TextStyle(fontSize: 13, color: Colors.grey[500]),
        ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    required bool isDark,
    int maxLength = 0,
    int maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      maxLength: maxLength > 0 ? maxLength : null,
      maxLines: maxLines,
      keyboardType: keyboardType,
      style: TextStyle(color: isDark ? Colors.white : Colors.black87),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        counterText: '',
        prefixIcon: Icon(icon, color: const Color(0xFF1DBF73)),
        filled: true,
        fillColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: isDark ? Colors.grey[700]! : Colors.grey[300]!),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: isDark ? Colors.grey[700]! : Colors.grey[300]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFF1DBF73), width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Colors.red),
        ),
        labelStyle: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600]),
        hintStyle: TextStyle(color: isDark ? Colors.grey[600] : Colors.grey[400]),
      ),
      validator: validator,
    );
  }

  Widget _buildCategorySelector(bool isDark) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: _categories.map((cat) {
        final isSelected = _category == cat['id'];
        return GestureDetector(
          onTap: () => setState(() => _category = cat['id']),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isSelected 
                  ? (cat['color'] as Color).withOpacity(0.15) 
                  : (isDark ? const Color(0xFF1E293B) : Colors.white),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isSelected ? cat['color'] as Color : (isDark ? Colors.grey[700]! : Colors.grey[300]!),
                width: isSelected ? 2 : 1,
              ),
              boxShadow: isSelected ? [
                BoxShadow(
                  color: (cat['color'] as Color).withOpacity(0.2),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ] : null,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  cat['icon'] as IconData,
                  size: 18,
                  color: isSelected ? cat['color'] as Color : (isDark ? Colors.grey[400] : Colors.grey[600]),
                ),
                const SizedBox(width: 8),
                Text(
                  cat['name'] as String,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                    color: isSelected ? cat['color'] as Color : (isDark ? Colors.grey[300] : Colors.grey[700]),
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildTypeSelector(bool isDark) {
    return Column(
      children: _types.map((type) {
        final isSelected = _type == type['id'];
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: GestureDetector(
            onTap: () => setState(() => _type = type['id']),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isSelected 
                    ? (type['color'] as Color).withOpacity(0.1)
                    : (isDark ? const Color(0xFF1E293B) : Colors.white),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isSelected ? type['color'] as Color : (isDark ? Colors.grey[700]! : Colors.grey[300]!),
                  width: isSelected ? 2 : 1,
                ),
                boxShadow: isSelected ? [
                  BoxShadow(
                    color: (type['color'] as Color).withOpacity(0.15),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ] : null,
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: (type['color'] as Color).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      type['icon'] as IconData,
                      color: type['color'] as Color,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          type['name'] as String,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: isSelected ? type['color'] as Color : (isDark ? Colors.white : Colors.grey[800]),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          type['desc'] as String,
                          style: TextStyle(
                            fontSize: 13,
                            color: isDark ? Colors.grey[500] : Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (isSelected)
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: type['color'] as Color,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.check, color: Colors.white, size: 16),
                    ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildSubmitButton(bool isDark) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(
          colors: [Color(0xFF1DBF73), Color(0xFF10B981)],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1DBF73).withOpacity(0.4),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: _loading ? null : _submit,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          padding: const EdgeInsets.symmetric(vertical: 18),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        child: _loading
            ? const SizedBox(
                height: 22,
                width: 22,
                child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
              )
            : const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_circle_outline, color: Colors.white),
                  SizedBox(width: 10),
                  Text(
                    'Add Item',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
