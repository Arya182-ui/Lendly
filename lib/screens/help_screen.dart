import 'package:flutter/material.dart';

class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Help & FAQ')),
      body: Center(
        child: Text('Support and FAQs', style: Theme.of(context).textTheme.titleLarge),
      ),
    );
  }
}
