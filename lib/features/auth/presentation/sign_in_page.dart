import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class SignInPage extends StatelessWidget {
  const SignInPage({super.key, required this.onSignedIn});

  final VoidCallback onSignedIn;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
                const SizedBox(height: 32),
              const Center(
                child: Column(
                  children: [
                    Icon(Icons.restaurant_menu, size: 64, color: Colors.deepOrange),
                    SizedBox(height: 12),
                    Text(
                      'Vua Đầu Bếp Thủ Đức',
                      style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 8),
                    Text('Đăng nhập để chia sẻ công thức nấu ăn'),
                  ],
                ),
              ),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: onSignedIn,
                icon: const Icon(Icons.login),
                label: const Text('Tiếp tục với Google'),
                style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: onSignedIn,
                icon: const Icon(Icons.email_outlined),
                label: const Text('Đăng nhập bằng Email'),
                style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () {
                  // TODO: toggle to sign-up view
                  context.go('/signin');
                },
                child: const Text('Tạo tài khoản mới'),
              ),
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }
}
