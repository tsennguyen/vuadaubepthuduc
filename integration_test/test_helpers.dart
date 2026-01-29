import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Common keys we expect to add to the app for testing.
/// Add these keys to the corresponding widgets in the app code for
/// reliable integration tests.
abstract class TestKeys {
  static const emailField = Key('auth_email');
  static const passwordField = Key('auth_password');
  static const signInButton = Key('auth_sign_in');
  static const signOutButton = Key('auth_sign_out');

  static const createRecipeButton = Key('btn_create_recipe');
  static const recipeTitleField = Key('field_recipe_title');
  static const recipeDescriptionField = Key('field_recipe_description');
  static const recipeIngredientField = Key('field_recipe_ingredient_0');
  static const recipeStepField = Key('field_recipe_step_0');
  static const recipeSubmitButton = Key('btn_submit_recipe');

  static const likeButtonPrefix = 'btn_like_recipe_'; // append recipeId/title
  static const commentField = Key('field_recipe_comment');
  static const commentSubmit = Key('btn_submit_comment');
  static const reportButton = Key('btn_report_recipe');
  static const reportReasonOptionPrefix = 'report_reason_'; // append reason code
  static const reportSubmit = Key('btn_submit_report');

  static const adminMenuReports = Key('admin_menu_reports');
  static const adminMenuContent = Key('admin_menu_content');
  static const adminResolveReport = Key('admin_resolve_report');
  static const adminHideContent = Key('admin_hide_content');
  static const adminAuditTab = Key('admin_audit_tab');

  static const addToPlanButton = Key('btn_add_to_plan');
  static const plannerGenerateButton = Key('btn_generate_shopping_list');
  static const shoppingItemCheckboxPrefix = 'shopping_item_checkbox_';
  static const macroChartDayPrefix = 'macro_chart_day_'; // append yyyy-MM-dd
}

/// Helper to enter text into a TextField found by key.
Future<void> enterTextByKey(
  WidgetTester tester,
  Key key,
  String text,
) async {
  await tester.enterText(find.byKey(key), text);
  await tester.pumpAndSettle();
}

/// Helper to tap a widget by key.
Future<void> tapByKey(WidgetTester tester, Key key) async {
  await tester.tap(find.byKey(key));
  await tester.pumpAndSettle();
}

/// Helper to expect text somewhere on screen.
void expectText(String text) {
  expect(find.textContaining(text), findsOneWidget);
}

