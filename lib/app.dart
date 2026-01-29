import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app_router.dart';
import 'app/language_controller.dart';
import 'app/theme.dart';
import 'app/theme_controller.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

class MyApp extends ConsumerStatefulWidget {
  const MyApp({super.key});

  @override
  ConsumerState<MyApp> createState() => _MyAppState();
}

class _MyAppState extends ConsumerState<MyApp> {
  StreamSubscription<User?>? _authSubscription;
  final GlobalKey<ScaffoldMessengerState> _scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

  @override
  void initState() {
    super.initState();
    _setupAuthListener();
  }

  void _setupAuthListener() {
    _authSubscription = FirebaseAuth.instance.authStateChanges().listen((user) async {
      if (user != null) {
        // Check if user is banned or disabled
        try {
          final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
          final data = doc.data();
          
          if (data != null) {
            final disabled = data['disabled'] == true;
            final isBanned = data['isBanned'] == true;
            
            if (disabled) {
              await FirebaseAuth.instance.signOut();
              _showError('Tài khoản của bạn đã bị khóa bởi quản trị viên. Vui lòng liên hệ hỗ trợ để biết thêm chi tiết.');
            } else if (isBanned) {
              final banUntil = (data['banUntil'] as Timestamp?)?.toDate();
              
              // Check if temporary ban expired
              if (banUntil != null && DateTime.now().isAfter(banUntil)) {
                // Auto-unban
                await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
                  'isBanned': false,
                  'banReason': null,
                  'banUntil': null,
                });
                return;
              }
              
              await FirebaseAuth.instance.signOut();
              final banReason = data['banReason'] as String?;
              String message = banReason != null && banReason.isNotEmpty
                  ? 'Tài khoản bị cấm: $banReason'
                  : 'Tài khoản của bạn đã bị cấm bởi quản trị viên.';
              
              if (banUntil != null) {
                final daysLeft = banUntil.difference(DateTime.now()).inDays;
                message += ' Thời gian còn lại: $daysLeft ngày.';
              }
              
              _showError(message);
            }
          }
        } catch (e) {
          // Don't block login if there's an error checking status
          debugPrint('Error checking user status: $e');
        }
      }
    });
  }

  void _showError(String message) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scaffoldMessengerKey.currentState?.showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 6),
          action: SnackBarAction(
            label: 'Đóng',
            textColor: Colors.white,
            onPressed: () {},
          ),
        ),
      );
    });
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeModeProvider);
    final locale = ref.watch(localeProvider);

    return MaterialApp.router(
      title: 'Vua Đầu Bếp Thủ Đức',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      locale: locale,
      supportedLocales: const [
        Locale('vi'),
        Locale('en'),
      ],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      routerConfig: appRouter,
      scaffoldMessengerKey: _scaffoldMessengerKey,
    );
  }
}
