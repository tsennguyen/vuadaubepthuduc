import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:shared_preferences/shared_preferences.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  @override
  void initState() {
    super.initState();
    _checkSession();
  }

  Future<void> _checkSession() async {
    await Future<void>.delayed(const Duration(milliseconds: 2000));
    if (!mounted) return;

    // Check if intro completed
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    final introCompleted = prefs.getBool('intro_completed') ?? false;

    if (!introCompleted) {
      context.go('/intro');
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      context.go('/signin');
      return;
    }
    context.go('/feed');
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 12),
            Text('Đang kiểm tra phiên đăng nhập...'),
          ],
        ),
      ),
    );
  }
}
