import 'package:flutter/material.dart';
import '../../services/session_service.dart';
import '../../services/verification_service.dart';
import '../profile/profile_screen.dart';

class VerificationDashboardScreen extends StatefulWidget {
  const VerificationDashboardScreen({Key? key}) : super(key: key);

  @override
  _VerificationDashboardScreenState createState() => _VerificationDashboardScreenState();
}

class _VerificationDashboardScreenState extends State<VerificationDashboardScreen> {
  String? currentUid;
  Map<String, dynamic>? verificationData;
  bool isLoading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    _loadVerificationStatus();
  }

  Future<void> _loadVerificationStatus() async {
    setState(() {
      isLoading = true;
      error = null;
    });

    try {
      final uid = await SessionService.getUid();
      if (uid == null) {
        setState(() {
          error = 'User not logged in';
          isLoading = false;
        });
        return;
      }

      currentUid = uid;
      
      // Get verification status from backend
      final result = await VerificationService.getVerificationStatus(uid);
      
      if (result['success'] == true) {
        setState(() {
          verificationData = result['data'];
          isLoading = false;
        });
      } else {
        setState(() {
          error = result['error'] ?? 'Failed to load verification status';
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        error = 'Error loading verification status: $e';
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Verification Dashboard'),
        backgroundColor: Colors.blue[600],
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadVerificationStatus,
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : error != null
              ? _buildErrorState()
              : _buildContent(),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error, size: 64, color: Colors.red),
          const SizedBox(height: 16),
          Text(
            error!,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 16),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _loadVerificationStatus,
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    final status = verificationData?['verificationStatus'] ?? 'unknown';
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStatusCard(status),
          const SizedBox(height: 24),
          _buildInstructionsSection(),
          const SizedBox(height: 24),
          _buildRequirementsSection(),
          if (status == 'rejected') ...[
            const SizedBox(height: 24),
            _buildRejectionReasonCard(),
          ],
          if (status != 'verified') ...[
            const SizedBox(height: 24),
            _buildActionSection(),
          ],
          const SizedBox(height: 24),
          _buildBenefitsSection(),
        ],
      ),
    );
  }

  Widget _buildStatusCard(String status) {
    String title;
    String description;
    IconData icon;
    Color color;
    Color backgroundColor;

    switch (status) {
      case 'verified':
        title = 'Verified Student';
        description = 'Your student status has been verified successfully!';
        icon = Icons.verified_user;
        color = Colors.green[700]!;
        backgroundColor = Colors.green[50]!;
        break;
      case 'pending':
        title = 'Verification Pending';
        description = 'Your documents are under review. We\'ll notify you within 24-48 hours.';
        icon = Icons.hourglass_empty;
        color = Colors.orange[700]!;
        backgroundColor = Colors.orange[50]!;
        break;
      case 'rejected':
        title = 'Verification Rejected';
        description = 'Your verification was rejected. Please review the feedback and resubmit.';
        icon = Icons.cancel;
        color = Colors.red[700]!;
        backgroundColor = Colors.red[50]!;
        break;
      default:
        title = 'Not Verified';
        description = 'Verify your student status to access all features and build trust.';
        icon = Icons.school;
        color = Colors.grey[700]!;
        backgroundColor = Colors.grey[50]!;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3), width: 2),
      ),
      child: Column(
        children: [
          Icon(icon, size: 48, color: color),
          const SizedBox(height: 12),
          Text(
            title,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            description,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: color.withOpacity(0.8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInstructionsSection() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.info_outline, color: Colors.blue[600]),
                const SizedBox(width: 8),
                const Text(
                  'How to Verify',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildInstructionStep(1, 'Take a clear photo', 'Capture your student ID card with good lighting'),
            _buildInstructionStep(2, 'Upload document', 'Submit your photo through the app'),
            _buildInstructionStep(3, 'Wait for review', 'Our team will verify within 24-48 hours'),
            _buildInstructionStep(4, 'Start lending!', 'Access all features once verified'),
          ],
        ),
      ),
    );
  }

  Widget _buildInstructionStep(int step, String title, String description) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: Colors.blue[600],
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                '$step',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRequirementsSection() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.checklist, color: Colors.green[600]),
                const SizedBox(width: 8),
                const Text(
                  'Requirements',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildRequirement(Icons.check_circle_outline, 'Valid student ID card', true),
            _buildRequirement(Icons.check_circle_outline, 'Clear, readable photo', true),
            _buildRequirement(Icons.check_circle_outline, 'All text must be visible', true),
            _buildRequirement(Icons.check_circle_outline, 'File size under 5MB', true),
            _buildRequirement(Icons.check_circle_outline, 'JPG, PNG, or PDF format', true),
          ],
        ),
      ),
    );
  }

  Widget _buildRequirement(IconData icon, String text, bool isChecked) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(
            icon,
            size: 16,
            color: isChecked ? Colors.green[600] : Colors.grey[400],
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: isChecked ? Colors.grey[800] : Colors.grey[500],
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRejectionReasonCard() {
    final reason = verificationData?['rejectionReason'] ?? 'No specific reason provided.';
    
    return Card(
      elevation: 2,
      color: Colors.red[50],
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.feedback, color: Colors.red[600]),
                const SizedBox(width: 8),
                const Text(
                  'Feedback',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                reason,
                style: TextStyle(
                  color: Colors.red[800],
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionSection() {
    final status = verificationData?['verificationStatus'] ?? 'unknown';
    
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: () async {
          final result = await Navigator.pushNamed(
            context,
            '/id-upload',
            arguments: currentUid,
          );
          
          if (result == true) {
            _loadVerificationStatus();
          }
        },
        icon: Icon(status == 'rejected' ? Icons.refresh : Icons.upload_file),
        label: Text(status == 'rejected' ? 'Resubmit Documents' : 'Upload Student ID'),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.blue[600],
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  Widget _buildBenefitsSection() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.star, color: Colors.amber[600]),
                const SizedBox(width: 8),
                const Text(
                  'Verification Benefits',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildBenefit(Icons.security, 'Increased trust score'),
            _buildBenefit(Icons.account_balance_wallet, '25 bonus points reward'),
            _buildBenefit(Icons.add_box, 'List unlimited items'),
            _buildBenefit(Icons.verified, 'Verification badge on profile'),
            _buildBenefit(Icons.priority_high, 'Priority in search results'),
          ],
        ),
      ),
    );
  }

  Widget _buildBenefit(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.blue[600]),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}