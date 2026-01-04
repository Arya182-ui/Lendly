import 'package:flutter/material.dart';

class OnboardingPermissionsScreen extends StatelessWidget {
  const OnboardingPermissionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Permissions')), 
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Enable location and notifications for best experience.', style: TextStyle(fontSize: 16)),
            const SizedBox(height: 24),
            SwitchListTile(
              title: const Text('Location Access'),
              value: true,
              onChanged: (val) {},
            ),
            SwitchListTile(
              title: const Text('Push Notifications'),
              value: false,
              onChanged: (val) {},
            ),
            const Spacer(),
            ElevatedButton(
              onPressed: () {},
              child: const Text('Finish'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2ecc71),
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(48),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
