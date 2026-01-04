import 'package:flutter/material.dart';

class OnboardingHostelScreen extends StatelessWidget {
  const OnboardingHostelScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Select Hostel / Area')),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            DropdownButtonFormField<String>(
              items: const [
                DropdownMenuItem(value: 'Hostel 1', child: Text('Hostel 1')),
                DropdownMenuItem(value: 'Hostel 2', child: Text('Hostel 2')),
              ],
              onChanged: (value) {},
              decoration: const InputDecoration(labelText: 'Hostel / Area'),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {},
              child: const Text('Continue'),
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
