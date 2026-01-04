import 'package:flutter/material.dart';

class OnboardingInterestsScreen extends StatelessWidget {
  const OnboardingInterestsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final interests = [
      'Books', 'Electronics', 'Sports', 'Clothes', 'Bicycles', 'Others'
    ];
    return Scaffold(
      appBar: AppBar(title: const Text('Select Interests')), 
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('What do you need most often?', style: TextStyle(fontSize: 16)),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              children: interests.map((interest) => FilterChip(
                label: Text(interest),
                selected: false,
                onSelected: (selected) {},
              )).toList(),
            ),
            const Spacer(),
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
            TextButton(
              onPressed: () {},
              child: const Text('Skip'),
            ),
          ],
        ),
      ),
    );
  }
}
