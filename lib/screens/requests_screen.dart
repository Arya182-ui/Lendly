import 'package:flutter/material.dart';
import 'dart:convert';
import '../services/api_client.dart';
import '../services/session_service.dart';
import '../widgets/rating_dialog.dart';
import '../config/env_config.dart';
class RequestsScreen extends StatefulWidget {
  const RequestsScreen({Key? key}) : super(key: key);

  @override
  State<RequestsScreen> createState() => _RequestsScreenState();
}

class _RequestsScreenState extends State<RequestsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Map<String, dynamic>> sentRequests = [];
  List<Map<String, dynamic>> receivedRequests = [];
  bool loading = true;
  String? error;
  String? currentUid;
  static String get baseUrl => EnvConfig.apiBaseUrl;

  String? get _currentUid => currentUid;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadRequests();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadRequests() async {
    setState(() => loading = true);
    try {
      currentUid = await SessionService.getUid();
      if (currentUid == null) {
        setState(() => error = 'Please log in to view requests');
        return;
      }

      final data = await SimpleApiClient.get(
        '/transactions/my/$currentUid',
        requiresAuth: true,
      );
      final List<dynamic> list = data is List ? data : (data['transactions'] ?? []);
      setState(() {
        sentRequests = list.where((t) => t['role'] == 'requester').cast<Map<String, dynamic>>().toList();
        receivedRequests = list.where((t) => t['role'] == 'owner').cast<Map<String, dynamic>>().toList();
        loading = false;
        error = null;
      });
    } catch (e) {
      setState(() {
        error = 'Error: $e';
        loading = false;
      });
    }
  }

  Future<void> _respondToRequest(String transactionId, String action, String? message) async {
    try {
      await SimpleApiClient.post(
        '/transactions/$transactionId/respond',
        body: {
          'ownerId': currentUid,
          'action': action,
          if (message != null && message.isNotEmpty) 'message': message,
        },
        requiresAuth: true,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Request ${action}ed successfully'),
          backgroundColor: action == 'accept' ? Colors.green : Colors.orange,
        ),
      );
      _loadRequests(); // Refresh the list
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _completeTransaction(String transactionId, int? rating, String? review) async {
    try {
      await SimpleApiClient.post(
        '/transactions/$transactionId/complete',
        body: {
          'userId': currentUid,
          if (rating != null) 'rating': rating,
          if (review != null && review.isNotEmpty) 'review': review,
        },
        requiresAuth: true,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Transaction completed successfully'),
          backgroundColor: Colors.green,
        ),
      );
      _loadRequests(); // Refresh the list
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showRespondDialog(Map<String, dynamic> request) {
    final messageController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Respond to ${request['type']} request'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Item: ${request['itemName']}'),
            const SizedBox(height: 8),
            if (request['message'] != null && request['message'].isNotEmpty)
              Text('Message: "${request['message']}"'),
            const SizedBox(height: 16),
            TextField(
              controller: messageController,
              decoration: const InputDecoration(
                labelText: 'Response message (optional)',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _respondToRequest(request['id'], 'reject', messageController.text);
            },
            child: const Text('Reject', style: TextStyle(color: Colors.red)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _respondToRequest(request['id'], 'accept', messageController.text);
            },
            child: const Text('Accept'),
          ),
        ],
      ),
    );
  }

  void _showCompleteDialog(Map<String, dynamic> request) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Complete Transaction'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Mark transaction for "${request['itemName']}" as completed?'),
            const SizedBox(height: 8),
            const Text(
              'You\'ll be able to rate your experience after completion.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _showCompleteTransactionDialog(request);
            },
            child: const Text('Complete'),
          ),
        ],
      ),
    );
  }

  void _showCompleteTransactionDialog(Map<String, dynamic> request) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Complete Transaction'),
        content: Text('Mark this transaction as completed?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _completeTransactionWithRating(request['id'], request);
            },
            child: const Text('Complete'),
          ),
        ],
      ),
    );
  }

  Future<void> _completeTransactionWithRating(String requestId, Map<String, dynamic> request) async {
    try {
      await SimpleApiClient.post(
        '/transactions/$requestId/complete',
        body: {
          'userId': _currentUid,
        },
        requiresAuth: true,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Transaction completed successfully!'),
          backgroundColor: Colors.green,
        ),
      );
      _loadRequests(); // Refresh the list
      
      // Show rating dialog after successful completion
      _showRatingDialog(request);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showRatingDialog(Map<String, dynamic> request) {
    // Determine who to rate based on the current user's role in the transaction
    String? otherUserId;
    String? otherUserName;
    
    if (_currentUid == request['lenderUid']) {
      // Current user is lender, rate the borrower
      otherUserId = request['borrowerUid'];
      otherUserName = request['borrowerName'] ?? 'User';
    } else if (_currentUid == request['borrowerUid']) {
      // Current user is borrower, rate the lender
      otherUserId = request['lenderUid'];
      otherUserName = request['lenderName'] ?? 'User';
    }

    if (otherUserId != null && otherUserName != null) {
      showRatingDialog(
        context: context,
        toUid: otherUserId,
        toUserName: otherUserName,
        transactionId: request['id'],
        onRatingSubmitted: () {
          // Optionally refresh the list or show confirmation
        },
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Requests'),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1a237e),
        elevation: 0.5,
        bottom: TabBar(
          controller: _tabController,
          labelColor: const Color(0xFF1DBF73),
          unselectedLabelColor: Colors.grey,
          indicatorColor: const Color(0xFF1DBF73),
          tabs: const [
            Tab(text: 'Sent'),
            Tab(text: 'Received'),
          ],
        ),
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(error!),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadRequests,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildRequestsList(sentRequests, false),
                    _buildRequestsList(receivedRequests, true),
                  ],
                ),
    );
  }

  Widget _buildRequestsList(List<Map<String, dynamic>> requests, bool isReceived) {
    if (requests.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isReceived ? Icons.inbox : Icons.send,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              isReceived ? 'No requests received' : 'No requests sent',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey[600],
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              isReceived 
                  ? 'Requests for your items will appear here'
                  : 'Your item requests will appear here',
              style: TextStyle(fontSize: 14, color: Colors.grey[500]),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: requests.length,
      itemBuilder: (context, index) {
        final request = requests[index];
        final status = request['status'] ?? 'pending';
        
        return Card(
          elevation: 2,
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: _getStatusColor(status),
              child: Icon(
                _getStatusIcon(status),
                color: Colors.white,
              ),
            ),
            title: Text(
              request['itemName'] ?? 'Unknown Item',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Type: ${request['type']?.toUpperCase()}'),
                if (request['message'] != null && request['message'].isNotEmpty)
                  Text('Message: "${request['message']}"'),
                Text('Status: ${status.toUpperCase()}'),
                if (request['proposedPrice'] != null)
                  Text('Price: ₹${request['proposedPrice']}'),
              ],
            ),
            trailing: _buildActionButton(request, isReceived),
            isThreeLine: true,
          ),
        );
      },
    );
  }

  Widget _buildActionButton(Map<String, dynamic> request, bool isReceived) {
    final status = request['status'] ?? 'pending';
    
    if (status == 'pending' && isReceived) {
      return ElevatedButton(
        onPressed: () => _showRespondDialog(request),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF1DBF73),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        ),
        child: const Text('Respond', style: TextStyle(fontSize: 12)),
      );
    } else if (status == 'accepted') {
      return ElevatedButton(
        onPressed: () => _showCompleteDialog(request),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.blue,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        ),
        child: const Text('Complete', style: TextStyle(fontSize: 12)),
      );
    } else {
      return Chip(
        label: Text(
          status.toUpperCase(),
          style: const TextStyle(fontSize: 10, color: Colors.white),
        ),
        backgroundColor: _getStatusColor(status),
      );
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return Colors.orange;
      case 'accepted':
        return Colors.blue;
      case 'completed':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      case 'cancelled':
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return Icons.hourglass_empty;
      case 'accepted':
        return Icons.check;
      case 'completed':
        return Icons.check_circle;
      case 'rejected':
        return Icons.close;
      case 'cancelled':
        return Icons.cancel;
      default:
        return Icons.help;
    }
  }
}