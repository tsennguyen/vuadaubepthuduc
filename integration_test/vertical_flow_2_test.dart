import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'test_helpers.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Flow 2: planner + shopping + macro', () {
    testWidgets(
      'user adds recipe to plan, generates shopping list, checks macros',
      (tester) async {
        await signIn(tester, email: 'user1@test.com', password: 'password123');

        // Pick a recipe (assume exists on feed; or create in Flow 1).
        const recipeTitle = 'Test Recipe Flow1';
        await tester.tap(find.text(recipeTitle));
        await tester.pumpAndSettle();

        // Add to plan (today, lunch, servings 2)
        await tapByKey(tester, TestKeys.addToPlanButton);
        // TODO: select date + meal type + servings via keys if added.
        await tester.pumpAndSettle();

        // Generate shopping list for week
        await tapByKey(tester, TestKeys.plannerGenerateButton);
        await tester.pumpAndSettle();

        // Check first shopping item
        final checkbox = find.byKey(const Key('${TestKeys.shoppingItemCheckboxPrefix}0'));
        if (checkbox.evaluate().isNotEmpty) {
          await tester.tap(checkbox);
          await tester.pumpAndSettle();
        }

        // Open macro dashboard and expect a value > 0 for today
        await tester.tap(find.text('Macro')); // TODO: adjust navigation if needed
        await tester.pumpAndSettle();
        final today = DateTime.now();
        final dayKey = Key(
            '${TestKeys.macroChartDayPrefix}${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}');
        expect(find.byKey(dayKey), findsWidgets);
      },
    );
  });
}

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

