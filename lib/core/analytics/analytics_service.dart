import 'package:firebase_analytics/firebase_analytics.dart';

abstract class AnalyticsService {
  Future<void> logEvent(
    String name, {
    Map<String, Object>? parameters,
  });

  Future<void> logViewRecipe(String recipeId);
  Future<void> logCreatePost(String postId);
  Future<void> logAddToPlan(String recipeId);
  Future<void> logAddToShoppingList(String recipeId);
  Future<void> logReportContent(String targetType, String targetId);
  Future<void> logSendMessage(String chatId);
  Future<void> logViewLeaderboard();
}

class FirebaseAnalyticsService implements AnalyticsService {
  FirebaseAnalyticsService(this._analytics);

  final FirebaseAnalytics _analytics;

  @override
  Future<void> logEvent(
    String name, {
    Map<String, Object>? parameters = const <String, Object>{},
  }) {
    return _analytics.logEvent(name: name, parameters: parameters);
  }

  @override
  Future<void> logViewRecipe(String recipeId) {
    return logEvent('view_recipe', parameters: {'recipe_id': recipeId});
  }

  @override
  Future<void> logCreatePost(String postId) {
    return logEvent('create_post', parameters: {'post_id': postId});
  }

  @override
  Future<void> logAddToPlan(String recipeId) {
    return logEvent('add_to_plan', parameters: {'recipe_id': recipeId});
  }

  @override
  Future<void> logAddToShoppingList(String recipeId) {
    return logEvent('add_to_shopping_list', parameters: {'recipe_id': recipeId});
  }

  @override
  Future<void> logReportContent(String targetType, String targetId) {
    return logEvent('report_content', parameters: {
      'target_type': targetType,
      'target_id': targetId,
    });
  }

  @override
  Future<void> logSendMessage(String chatId) {
    return logEvent('send_message', parameters: {'chat_id': chatId});
  }

  @override
  Future<void> logViewLeaderboard() {
    return logEvent('view_leaderboard');
  }
}

final analytics = FirebaseAnalyticsService(FirebaseAnalytics.instance);
