import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class OnboardingPage extends StatelessWidget {
  const OnboardingPage({super.key});

  void _goNext(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final next = user == null ? '/signin' : '/feed';
    context.go(next);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Onboarding')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Spacer(),
            Text(
              'Xin chao!',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 12),
            const Text(
              'Day la man gioi thieu ngan. TODO: thu thap so thich va che do an de goi y tot hon.',
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _goNext(context),
                icon: const Icon(Icons.fastfood_outlined),
                label: const Text('Bat dau'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
