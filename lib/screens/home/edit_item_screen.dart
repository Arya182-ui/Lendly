import 'package:flutter/material.dart';
import '../../config/env_config.dart';
import '../../services/item_service.dart';
import '../../services/session_service.dart';
import '../../services/image_service.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';

class EditItemScreen extends StatefulWidget {
  final Map<String, dynamic> item;
  const EditItemScreen({Key? key, required this.item}) : super(key: key);

  @override
  State<EditItemScreen> createState() => _EditItemScreenState();
}

class _EditItemScreenState extends State<EditItemScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _descController;
  late TextEditingController _priceController;
  late String _category;
  late String _type;
  bool _loading = false;
  String? _error;
  File? _selectedImage;
  final ItemService _service = ItemService(EnvConfig.apiBaseUrl);

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.item['name'] ?? '');
    _descController = TextEditingController(text: widget.item['description'] ?? '');
    _priceController = TextEditingController(text: widget.item['price']?.toString() ?? '');
    _category = widget.item['category'] ?? 'Books';
    _type = widget.item['type'] ?? 'borrow';
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
    try {
      final updatedItem = await _service.updateItem(
        id: widget.item['id'],
        ownerId: uid,
        name: _nameController.text.trim(),
        description: _descController.text.trim(),
        category: _category,
        price: double.tryParse(_priceController.text) ?? 0,
        type: _type,
        imageFile: _selectedImage,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Item updated successfully!'), backgroundColor: Colors.green),
        );
        if (Navigator.canPop(context)) {
          Navigator.pop(context, updatedItem);
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
    return Scaffold(
      appBar: AppBar(title: const Text('Edit Item')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              Center(
                child: GestureDetector(
                  onTap: _loading ? null : _pickImage,
                  child: Container(
                    width: 150,
                    height: 150,
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.grey[300]!,
                        width: 2,
                      ),
                    ),
                    child: _selectedImage != null
                        ? Stack(
                            fit: StackFit.expand,
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(14),
                                child: Image.file(
                                  _selectedImage!,
                                  fit: BoxFit.cover,
                                ),
                              ),
                              Positioned(
                                top: 8,
                                right: 8,
                                child: GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      _selectedImage = null;
                                    });
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: const BoxDecoration(
                                      color: Colors.red,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.close,
                                      color: Colors.white,
                                      size: 16,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          )
                        : (widget.item['image'] != null && widget.item['image'].toString().isNotEmpty)
                            ? Stack(
                                fit: StackFit.expand,
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(14),
                                    child: CachedNetworkImage(
                                      imageUrl: widget.item['image'],
                                      fit: BoxFit.cover,
                                      placeholder: Container(
                                        color: Colors.grey[200],
                                        child: const Center(
                                          child: CircularProgressIndicator(),
                                        ),
                                      ),
                                    ),
                                  ),
                                  Positioned(
                                    bottom: 8,
                                    right: 8,
                                    child: Container(
                                      padding: const EdgeInsets.all(6),
                                      decoration: BoxDecoration(
                                        color: Colors.blue.withOpacity(0.8),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.edit,
                                        color: Colors.white,
                                        size: 16,
                                      ),
                                    ),
                                  ),
                                ],
                              )
                            : Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.add_a_photo,
                                    size: 48,
                                    color: Colors.grey[400],
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    'Add Photo',
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: Colors.grey[600],
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Tap to select image',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[500],
                                    ),
                                  ),
                                ],
                              ),
                  ),
                ),
              ),
              const SizedBox(height: 22),
              TextFormField(
                controller: _nameController,
                maxLength: 40,
                decoration: const InputDecoration(labelText: 'Item Name', border: OutlineInputBorder(), counterText: ''),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Item name is required';
                  if (v.trim().length > 40) return 'Max 40 characters allowed';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descController,
                maxLength: 120,
                decoration: const InputDecoration(labelText: 'Description', border: OutlineInputBorder(), counterText: ''),
                maxLines: 2,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Description is required';
                  if (v.trim().length > 120) return 'Max 120 characters allowed';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _category,
                items: ['Books', 'Tech', 'Sports', 'Tools', 'Other']
                    .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                    .toList(),
                onChanged: (v) => setState(() => _category = v ?? 'Books'),
                decoration: const InputDecoration(labelText: 'Category', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _type,
                items: [
                  DropdownMenuItem(value: 'lend', child: Text('Lend (Rent)')),
                  DropdownMenuItem(value: 'sell', child: Text('Sell')),
                  DropdownMenuItem(value: 'borrow', child: Text('Borrow Request')),
                ],
                onChanged: (v) => setState(() => _type = v ?? 'borrow'),
                decoration: const InputDecoration(labelText: 'Type', border: OutlineInputBorder()),
              ),
              if (_type == 'lend' || _type == 'sell') ...[
                const SizedBox(height: 16),
                TextFormField(
                  controller: _priceController,
                  decoration: const InputDecoration(labelText: 'Price / Rent (₹)', border: OutlineInputBorder()),
                  keyboardType: TextInputType.number,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Price is required';
                    final price = double.tryParse(v);
                    if (price == null || price <= 0) return 'Enter a valid price';
                    return null;
                  },
                ),
              ],
              const SizedBox(height: 24),
              if (_error != null) ...[
                Text(_error!, style: const TextStyle(color: Colors.red)),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: _loading ? null : _submit,
                    child: const Text('Retry'),
                  ),
                ),
                const SizedBox(height: 10),
              ],
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _loading ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1DBF73),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _loading
                      ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Update Item'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
