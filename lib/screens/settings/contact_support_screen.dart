import 'package:flutter/material.dart';

class ContactSupportScreen extends StatelessWidget {
  const ContactSupportScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Contact Support'),
        backgroundColor: const Color(0xFF2ecc71),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Card(
            elevation: 4,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Icon(Icons.support_agent, color: theme.primaryColor, size: 32),
                      const SizedBox(width: 12),
                      Text('Contact Support', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text('Need help? Our support team is here for you!\n\nYou can reach us at:',
                      style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey[700])),
                  const SizedBox(height: 18),
                  Row(
                    children: const [
                      Icon(Icons.email_outlined, color: Color(0xFF2ecc71)),
                      SizedBox(width: 8),
                      SelectableText('support@lendly.app', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: const [
                      Icon(Icons.phone_outlined, color: Color(0xFF2ecc71)),
                      SizedBox(width: 8),
                      SelectableText('+91 98765 43210', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Text('We usually respond within 24 hours.', style: TextStyle(color: Colors.grey[600])),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
