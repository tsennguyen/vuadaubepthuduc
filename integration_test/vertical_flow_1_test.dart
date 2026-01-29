import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'test_helpers.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Flow 1: social + moderation', () {
    testWidgets(
      'user creates recipe, other interacts, admin hides and resolves report',
      (tester) async {
        // TODO: Ensure app is launched, Firebase initialized, and emulator is used.
        // For now, this test is a skeleton describing the steps.

        // 1) Sign in user1
        await signIn(tester, email: 'user1@test.com', password: 'password123');

        // 2) Create recipe
        const recipeTitle = 'Test Recipe Flow1';
        await createRecipe(tester, title: recipeTitle);

        // 3) Sign out user1 → sign in user2
        await tapByKey(tester, TestKeys.signOutButton);
        await signIn(tester, email: 'user2@test.com', password: 'password123');

        // 4) Like + comment
        await likeRecipeOnFeed(tester, recipeTitle);
        await commentOnRecipe(tester, recipeTitle, 'Test comment');

        // 5) Report recipe
        await reportRecipe(tester, recipeTitle, reasonCode: 'inappropriate');

        // 6) Sign out user2 → sign in admin
        await tapByKey(tester, TestKeys.signOutButton);
        await signIn(tester, email: 'admin@test.com', password: 'password123');

        // 7) Admin resolve report + hide content
        await handleReportAsAdmin(tester, recipeTitle);

        // 8) Check audit log (stub)
        await verifyAuditLog(tester, containsText: 'hide recipe');
      },
    );
  });
}

// --- Helper flows (skeletons) ---

Future<void> signIn(
  WidgetTester tester, {
  required String email,
  required String password,
}) async {
  await enterTextByKey(tester, TestKeys.emailField, email);
  await enterTextByKey(tester, TestKeys.passwordField, password);
  await tapByKey(tester, TestKeys.signInButton);
  await tester.pumpAndSettle();
}

Future<void> createRecipe(WidgetTester tester, {required String title}) async {
  await tapByKey(tester, TestKeys.createRecipeButton);
  await enterTextByKey(tester, TestKeys.recipeTitleField, title);
  await enterTextByKey(
    tester,
    TestKeys.recipeDescriptionField,
    'Test description',
  );
  await enterTextByKey(tester, TestKeys.recipeIngredientField, '1 egg');
  await enterTextByKey(tester, TestKeys.recipeStepField, 'Mix and cook');
  await tapByKey(tester, TestKeys.recipeSubmitButton);
  await tester.pumpAndSettle();
  expect(find.text(title), findsOneWidget);
}

Future<void> likeRecipeOnFeed(WidgetTester tester, String title) async {
  final likeButton = find.byKey(
    Key('${TestKeys.likeButtonPrefix}$title'),
  );
  await tester.tap(likeButton);
  await tester.pumpAndSettle();
}

Future<void> commentOnRecipe(
  WidgetTester tester,
  String title,
  String comment,
) async {
  await tester.tap(find.text(title));
  await tester.pumpAndSettle();
  await enterTextByKey(tester, TestKeys.commentField, comment);
  await tapByKey(tester, TestKeys.commentSubmit);
  expect(find.textContaining(comment), findsOneWidget);
}

Future<void> reportRecipe(
  WidgetTester tester,
  String title, {
  required String reasonCode,
}) async {
  await tester.tap(find.text(title));
  await tester.pumpAndSettle();
  await tapByKey(tester, TestKeys.reportButton);
  await tester.tap(find.byKey(Key('${TestKeys.reportReasonOptionPrefix}$reasonCode')));
  await tester.pumpAndSettle();
  await tapByKey(tester, TestKeys.reportSubmit);
  await tester.pumpAndSettle();
}

Future<void> handleReportAsAdmin(
  WidgetTester tester,
  String recipeTitle,
) async {
  await tapByKey(tester, TestKeys.adminMenuReports);
  // Locate the report row by title (requires key/text).
  await tester.tap(find.textContaining(recipeTitle));
  await tester.pumpAndSettle();
  await tapByKey(tester, TestKeys.adminResolveReport);
  await tester.pumpAndSettle();

  await tapByKey(tester, TestKeys.adminMenuContent);
  await tester.tap(find.textContaining(recipeTitle));
  await tester.pumpAndSettle();
  await tapByKey(tester, TestKeys.adminHideContent);
  await tester.pumpAndSettle();
}

Future<void> verifyAuditLog(
  WidgetTester tester, {
  required String containsText,
}) async {
  await tapByKey(tester, TestKeys.adminAuditTab);
  await tester.pumpAndSettle();
  expect(find.textContaining(containsText), findsWidgets);
}

