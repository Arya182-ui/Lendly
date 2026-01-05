
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:lendly/screens/profile/public_profile_screen.dart';
import 'package:lendly/widgets/app_image.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import '../../config/env_config.dart';
import '../../services/item_service.dart';
import '../../services/session_service.dart';
import 'edit_item_screen.dart';

class ItemDetailScreen extends StatelessWidget {
  final Map<String, dynamic> item;
  const ItemDetailScreen({super.key, required this.item});

  Future<void> _showRequestDialog(BuildContext context) async {
    final messageController = TextEditingController();
    final durationController = TextEditingController();
    final priceController = TextEditingController();
    bool loading = false;

    final currentUid = await SessionService.getUid();
    if (currentUid == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please log in to make requests')),
        );
      }
      return;
    }

    final itemName = item['name'] ?? '';
    final itemType = item['type'] ?? '';
    final price = item['price'];
    final ownerId = item['ownerId'] ?? '';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text('Request to ${itemType == 'sell' ? 'Buy' : itemType == 'rent' ? 'Rent' : 'Borrow'} $itemName'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: messageController,
                decoration: const InputDecoration(
                  labelText: 'Message (optional)',
                  hintText: 'Add a message to the owner...',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
                maxLength: 500,
              ),
              const SizedBox(height: 16),
              if (itemType == 'lend') ...[
                TextField(
                  controller: durationController,
                  decoration: const InputDecoration(
                    labelText: 'Duration (optional)',
                    hintText: 'e.g., 1 week, 2 months',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
              ],
              if (itemType == 'sell' || itemType == 'rent') ...[
                TextField(
                  controller: priceController,
                  decoration: InputDecoration(
                    labelText: 'Your offer (₹)',
                    hintText: price != null ? 'Current price: ₹$price' : 'Enter your offer',
                    border: const OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 16),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: loading ? null : () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: loading ? null : () async {
                setState(() => loading = true);
                try {
                  await _createTransactionRequest(
                    requesterId: currentUid,
                    itemOwnerId: ownerId,
                    itemId: item['id'] ?? '',
                    type: itemType == 'sell' ? 'buy' : itemType,
                    message: messageController.text.trim(),
                    duration: durationController.text.trim(),
                    proposedPrice: priceController.text.isNotEmpty 
                        ? double.tryParse(priceController.text) 
                        : price,
                  );
                  
                  if (context.mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Request sent successfully!'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                } catch (e) {
                  setState(() => loading = false);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Failed to send request: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
              child: loading 
                  ? const SizedBox(
                      width: 20, 
                      height: 20, 
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Send Request'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _createTransactionRequest({
    required String requesterId,
    required String itemOwnerId,
    required String itemId,
    required String type,
    String? message,
    String? duration,
    double? proposedPrice,
  }) async {
    final response = await http.post(
      Uri.parse('${EnvConfig.apiBaseUrl}/transactions/request'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'requesterId': requesterId,
        'itemOwnerId': itemOwnerId,
        'itemId': itemId,
        'type': type,
        if (message != null && message.isNotEmpty) 'message': message,
        if (duration != null && duration.isNotEmpty) 'duration': duration,
        if (proposedPrice != null) 'proposedPrice': proposedPrice,
      }),
    );

    if (response.statusCode != 201) {
      final error = jsonDecode(response.body);
      throw Exception(error['error'] ?? 'Failed to create request');
    }
  }

  @override
  Widget build(BuildContext context) {
    final images = [if (item['image'] != null && item['image'].toString().isNotEmpty) item['image']];
    final itemName = item['name'] ?? '';
    final itemType = item['type'] ?? '';
    final price = item['price'];
    final available = item['available'] != false;
    final ownerName = item['owner'] ?? '';
    final ownerAvatar = item['userAvatar'] ?? '';
    final description = item['description'] ?? '';
    final ownerId = item['ownerId'] ?? '';
    final currentUid = ModalRoute.of(context)?.settings.arguments as String?;
    final isOwner = currentUid != null && ownerId == currentUid;
    final itemService = ItemService(EnvConfig.apiBaseUrl);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Item Details'),
        actions: isOwner
            ? [
                IconButton(
                  icon: const Icon(Icons.edit, color: Color(0xFF1DBF73)),
                  tooltip: 'Edit',
                  onPressed: () async {
                    final updatedItem = await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => EditItemScreen(item: item),
                      ),
                    );
                    if (updatedItem != null && context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Item updated!'), backgroundColor: Colors.green),
                      );
                      Navigator.of(context).pop(updatedItem);
                    }
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  tooltip: 'Delete',
                  onPressed: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Delete Item'),
                        content: const Text('Are you sure you want to delete this item?'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: const Text('Cancel'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(context, true),
                            child: const Text('Delete', style: TextStyle(color: Colors.red)),
                          ),
                        ],
                      ),
                    );
                    if (confirm == true) {
                      try {
                        print('DELETE BUTTON PRESSED: id=${item['id']}, ownerId=$ownerId');
                        await itemService.deleteItem(id: item['id'], ownerId: ownerId);
                        if (context.mounted) {
                          Navigator.of(context).pop(true);
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Failed to delete item. Please try again.'), backgroundColor: Colors.red),
                          );
                        }
                      }
                    }
                  },
                ),
              ]
            : [],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 16,
                      offset: Offset(0, 6),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(22),
                  child: images.isNotEmpty
                      ? ItemImage(
                          imageUrl: images[0],
                          height: 240,
                          width: double.infinity,
                          fit: BoxFit.cover,
                        )
                      : Container(
                          height: 240,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Color(0xFFe0eafc), Color(0xFFcfdef3)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(22),
                          ),
                          child: Stack(
                            children: [
                              // Glassmorphism effect
                              Positioned.fill(
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.25),
                                    borderRadius: BorderRadius.circular(22),
                                    border: Border.all(color: Colors.white.withOpacity(0.18), width: 1.5),
                                  ),
                                ),
                              ),
                              Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.image_not_supported, size: 70, color: Colors.grey[350]),
                                    const SizedBox(height: 14),
                                    const Text(
                                      'No Image Provided',
                                      style: TextStyle(
                                        color: Color(0xFF7B7B7B),
                                        fontSize: 18,
                                        fontWeight: FontWeight.w500,
                                        letterSpacing: 0.2,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 18),
              // Modernized type/price section with heading and badges
              Padding(
                padding: const EdgeInsets.only(bottom: 6.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(itemName, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF1a237e))),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              if (itemType.isNotEmpty)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 5),
                                  margin: const EdgeInsets.only(right: 8),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [Color(0xFFe0c3fc), Color(0xFF8ec5fc)],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Color(0xFF7B61FF).withOpacity(0.10),
                                        blurRadius: 10,
                                        offset: Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        itemType == 'sell'
                                            ? Icons.sell
                                            : itemType == 'rent'
                                                ? Icons.calendar_today
                                                : Icons.handshake,
                                        size: 16,
                                        color: Color(0xFF7B61FF),
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        itemType[0].toUpperCase() + itemType.substring(1),
                                        style: const TextStyle(fontSize: 15, color: Color(0xFF7B61FF), fontWeight: FontWeight.w700, letterSpacing: 0.2),
                                      ),
                                    ],
                                  ),
                                ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [Color(0xFFFFE29F), Color(0xFFFFB199)],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  borderRadius: BorderRadius.circular(14),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.orange.withOpacity(0.13),
                                      blurRadius: 12,
                                      offset: Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.attach_money, size: 22, color: Color(0xFFF9A825)),
                                    const SizedBox(width: 6),
                                    Builder(
                                      builder: (context) {
                                        String priceText = '';
                                        dynamic p = price;
                                        // Try to parse price if string
                                        if (p is String) {
                                          p = num.tryParse(p);
                                        }
                                        if (p == null || (p is num && p.isNaN)) {
                                          priceText = 'N/A';
                                        } else if (p == 0) {
                                          priceText = 'Free';
                                        } else if (itemType == 'rent') {
                                          priceText = '₹${p.toString()}/day';
                                        } else if (itemType == 'borrow') {
                                          priceText = '₹${p.toString()} (Deposit)';
                                        } else {
                                          priceText = '₹${p.toString()}';
                                        }
                                        return Text(
                                          priceText,
                                          style: const TextStyle(fontSize: 18, color: Color(0xFF7C4700), fontWeight: FontWeight.bold, letterSpacing: 0.2),
                                        );
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      children: [
                        Icon(Icons.circle, size: 16, color: available ? Color(0xFF1DBF73) : Colors.red),
                        const SizedBox(height: 2),
                        Text(available ? 'Available' : 'Unavailable', style: TextStyle(fontSize: 12, color: available ? const Color(0xFF1DBF73) : Colors.red)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Card(
                elevation: 1,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: ownerId.isNotEmpty
                      ? () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => PublicProfileScreen(uid: ownerId),
                            ),
                          );
                        }
                      : null,
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      children: [
                        if (ownerAvatar.isNotEmpty)
                          ownerAvatar.endsWith('.svg') && ownerAvatar.startsWith('assets/')
                              ? CircleAvatar(
                                  radius: 22,
                                  backgroundColor: Colors.transparent,
                                  child: Padding(
                                    padding: const EdgeInsets.all(2.0),
                                    child: SvgPicture.asset(ownerAvatar, width: 36, height: 36),
                                  ),
                                )
                              : ownerAvatar.startsWith('assets/')
                                  ? CircleAvatar(
                                      radius: 22,
                                      backgroundImage: AssetImage(ownerAvatar),
                                    )
                                  : CircleAvatar(
                                      radius: 22,
                                      backgroundImage: NetworkImage(ownerAvatar),
                                    )
                        else
                          CircleAvatar(radius: 22, child: Icon(Icons.person)),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Owner', style: TextStyle(fontSize: 12, color: Colors.grey)),
                              Text(
                                ownerName,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF1a237e), decoration: TextDecoration.underline),
                              ),
                            ],
                          ),
                        ),
                        if (ownerId.isNotEmpty)
                          const Icon(Icons.chevron_right, color: Color(0xFF1DBF73)),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              const Text('Description', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 6),
              Card(
                elevation: 0,
                color: Color(0xFFF8F8F8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(description, style: const TextStyle(fontSize: 15)),
                ),
              ),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: isOwner
            ? const SizedBox.shrink()
            : Container(
                padding: const EdgeInsets.all(18),
                color: Colors.white,
                child: ElevatedButton(
                  onPressed: available ? () => _showRequestDialog(context) : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1DBF73),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    elevation: 2,
                  ),
                  child: Text(
                    available
                        ? (itemType == 'sell'
                            ? 'Buy Now'
                            : itemType == 'rent'
                                ? 'Rent Now'
                                : 'Borrow Now')
                        : 'Unavailable',
                  ),
                ),
              ),
      ),
    );
  }
}
