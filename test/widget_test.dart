// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vua_dau_bep_thu_duc/features/auth/presentation/sign_in_page.dart';

void main() {
  testWidgets('Sign-in page shows app title', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: SignInPage(onSignedIn: _noop),
      ),
    );
    expect(find.text('Vua Đầu Bếp Thủ Đức'), findsOneWidget);
  });
}

void _noop() {}
