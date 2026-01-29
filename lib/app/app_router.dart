import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/admin/presentation/admin_chat_moderation_page.dart';
import '../features/admin/presentation/admin_content_page.dart';
import '../features/admin/presentation/admin_home_page.dart';
import '../features/admin/presentation/admin_reports_page.dart';
import '../features/admin/presentation/admin_settings_page.dart';
import '../features/admin/presentation/admin_users_page.dart';
import '../features/admin/presentation/admin_audit_logs_page.dart';
import '../features/admin/presentation/admin_ai_prompts_page.dart';
import '../features/ai/presentation/ai_assistant_page.dart';
import '../features/auth/presentation/forgot_password_screen.dart';
import '../features/auth/presentation/login_screen.dart';
import '../features/auth/presentation/register_screen.dart';
import '../features/auth/presentation/onboarding_page.dart';
import '../features/auth/presentation/splash_page.dart';
import '../features/intro/presentation/intro_screen.dart';
import '../features/chat/presentation/chat_list_page.dart';
import '../features/chat/presentation/chat_room_page.dart';
import '../features/feed/presentation/feed_page.dart';
import '../features/nutrition/presentation/macro_dashboard_page.dart';
import '../features/notifications/presentation/notifications_page.dart';
import '../features/planner/presentation/planner_page.dart';
import '../features/post/presentation/create_post_page.dart';
import '../features/post/presentation/edit_post_page.dart';
import '../features/post/presentation/post_detail_page.dart';
import '../features/profile/presentation/profile_page.dart';
import '../features/profile/presentation/settings_notifications_page.dart';
import '../features/reels/presentation/reels_page.dart';
import '../features/reels/presentation/create_reel_page.dart';
import '../features/recipe/presentation/create_recipe_page.dart';
import '../features/recipe/presentation/recipe_detail_page.dart';
import '../features/recipes/presentation/recipe_grid_page.dart';
import '../features/recipes/presentation/ai_recipe_preview_page.dart';
import '../features/search/domain/ai_recipe_suggestion.dart';
import '../features/search/presentation/search_page.dart';
import '../features/shopping/presentation/shopping_list_page.dart';
import '../features/social/presentation/friends_page.dart';
import 'app_scaffold.dart';
import 'router/admin_guard.dart';

class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<dynamic> stream) {
    _subscription = stream.asBroadcastStream().listen((_) => notifyListeners());
  }
  StreamSubscription<dynamic>? _subscription;

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}

final _auth = FirebaseAuth.instance;
final _firestore = FirebaseFirestore.instance;
final _routerRefresh = GoRouterRefreshStream(_auth.authStateChanges());

bool _parseBool(dynamic value) {
  if (value == null) return false;
  if (value is bool) return value;
  if (value is num) return value != 0;
  if (value is String) {
    final v = value.trim().toLowerCase();
    if (v == 'true' || v == '1' || v == 'yes') return true;
    if (v == 'false' || v == '0' || v == 'no') return false;
  }
  return false;
}

bool _isAdminFromUserDoc(DocumentSnapshot<Map<String, dynamic>>? doc) {
  final data = doc?.data();
  final role = (data?['role'] as String?)?.toLowerCase();
  final disabled = _parseBool(data?['disabled']);
  return role == 'admin' && !disabled;
}

bool _requiresAuth(String location) {
  const protectedPrefixes = <String>{
    '/feed',
    '/recipes',
    '/search',
    '/recipe',
    '/post',
    '/planner',
    '/shopping',
    '/chat',
    '/me',
    '/profile',
    '/friends',
    '/notifications',
    '/ai-assistant',
    '/create-post',
    '/create-recipe',
    '/macro-dashboard',
    '/settings',
    '/admin',
  };
  return protectedPrefixes.any((prefix) => location.startsWith(prefix));
}

bool _isAuthFlow(String location) {
  return location == '/signin' ||
      location == '/register' ||
      location == '/signup' ||
      location == '/forgot-password' ||
      location == '/onboarding';
}

bool _isSplash(String location) => location == '/splash';

CustomTransitionPage<T> _buildTransitionPage<T>({
  required GoRouterState state,
  required Widget child,
}) {
  return CustomTransitionPage<T>(
    key: state.pageKey,
    child: child,
    transitionDuration: const Duration(milliseconds: 280),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
      );
      final slideTween = Tween<Offset>(
        begin: const Offset(0.04, 0),
        end: Offset.zero,
      ).chain(CurveTween(curve: Curves.easeOutCubic));
      final scaleTween = Tween<double>(begin: 0.98, end: 1).animate(curved);

      return FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: animation.drive(slideTween),
          child: ScaleTransition(scale: scaleTween, child: child),
        ),
      );
    },
  );
}

final appRouter = GoRouter(
  initialLocation: '/splash',
  refreshListenable: _routerRefresh,
  redirect: (context, state) {
    final user = _auth.currentUser;
    final location = state.matchedLocation;

    if (_isSplash(location)) return null;

    if (user == null && _requiresAuth(location)) return '/signin';
    if (user != null && _isAuthFlow(location)) return '/feed';
    return null;
  },
  routes: [
    GoRoute(
      path: '/',
      redirect: (context, state) => '/splash',
    ),
    // -------- User auth/onboarding routes --------
    GoRoute(
      path: '/signin',
      pageBuilder: (context, state) => _buildTransitionPage(
        state: state,
        child: const LoginScreen(),
      ),
    ),
    GoRoute(
      path: '/signup',
      pageBuilder: (context, state) => _buildTransitionPage(
        state: state,
        child: const RegisterScreen(),
      ),
    ),
    GoRoute(
      path: '/register',
      redirect: (context, state) => '/signup',
    ),
    GoRoute(
      path: '/forgot-password',
      pageBuilder: (context, state) => _buildTransitionPage(
        state: state,
        child: const ForgotPasswordScreen(),
      ),
    ),
    GoRoute(
      path: '/onboarding',
      pageBuilder: (context, state) => _buildTransitionPage(
        state: state,
        child: const OnboardingPage(),
      ),
    ),
    GoRoute(
      path: '/splash',
      pageBuilder: (context, state) => _buildTransitionPage(
        state: state,
        child: const SplashPage(),
      ),
    ),
    GoRoute(
      path: '/intro',
      pageBuilder: (context, state) => _buildTransitionPage(
        state: state,
        child: const IntroScreen(),
      ),
    ),

    // -------- User shell + main tabs --------
    GoRoute(
      path: '/home',
      redirect: (context, state) => '/feed',
    ),
    ShellRoute(
      builder: (context, state, child) {
        final user = _auth.currentUser;
        if (user == null) {
          final index = indexForLocation(state.matchedLocation, isAdmin: false);
          return AppScaffold(
            currentIndex: index,
            isAdmin: false,
            onTabSelected: (newIndex) {
              final path = pathForIndex(newIndex, isAdmin: false);
              if (path != state.matchedLocation) context.go(path);
            },
            child: child,
          );
        }

        return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: _firestore.collection('users').doc(user.uid).snapshots(),
          builder: (context, snapshot) {
            final isAdmin = _isAdminFromUserDoc(snapshot.data);
            final index =
                indexForLocation(state.matchedLocation, isAdmin: isAdmin);
            return AppScaffold(
              currentIndex: index,
              isAdmin: isAdmin,
              onTabSelected: (newIndex) {
                final path = pathForIndex(newIndex, isAdmin: isAdmin);
                if (path != state.matchedLocation) context.go(path);
              },
              child: child,
            );
          },
        );
      },
      routes: [
        GoRoute(
          path: '/feed',
          builder: (context, state) => const FeedPage(),
        ),
        GoRoute(
          path: '/recipes',
          builder: (context, state) => const RecipeGridPage(),
        ),
        GoRoute(
          path: '/reels',
          builder: (context, state) => const ReelsPage(),
        ),
        GoRoute(
          path: '/search',
          name: 'search',
          pageBuilder: (context, state) {
            final initialQuery = state.uri.queryParameters['q'];
            return MaterialPage(
              key: state.pageKey,
              child: SearchPage(initialQuery: initialQuery),
            );
          },
        ),
        GoRoute(
          path: '/planner',
          builder: (context, state) => const PlannerPage(),
        ),
        GoRoute(
          path: '/shopping',
          builder: (context, state) => const ShoppingListPage(),
        ),
        GoRoute(
          path: '/chat',
          builder: (context, state) => const ChatListPage(),
        ),
        GoRoute(
          path: '/chat/:cid',
          pageBuilder: (context, state) {
            final chatId = state.pathParameters['cid'] ??
                state.pathParameters['chatId'] ??
                '';
            final extra = state.extra;
            final child = chatId.isEmpty
                ? const ChatListPage()
                : ChatRoomPage(chatId: chatId, chat: extra);
            return _buildTransitionPage(state: state, child: child);
          },
        ),
        GoRoute(
          path: '/post/:id',
          pageBuilder: (context, state) => _buildTransitionPage(
            state: state,
            child: PostDetailPage(postId: state.pathParameters['id']!),
          ),
        ),
        GoRoute(
          path: '/recipe/:id',
          pageBuilder: (context, state) => _buildTransitionPage(
            state: state,
            child: RecipeDetailPage(recipeId: state.pathParameters['id']!),
          ),
        ),
        GoRoute(
          path: '/friends',
          builder: (context, state) => const FriendsPage(),
        ),
        GoRoute(
          path: '/profile/:uid',
          builder: (context, state) =>
              ProfilePage(uid: state.pathParameters['uid']),
        ),
        GoRoute(
          path: '/profile',
          builder: (context, state) => ProfilePage(
            uid: _auth.currentUser?.uid,
          ),
        ),
        GoRoute(
          path: '/me',
          builder: (context, state) => ProfilePage(
            uid: _auth.currentUser?.uid,
          ),
        ),
        GoRoute(
          path: '/create-post',
          builder: (context, state) => const CreatePostPage(),
        ),
        GoRoute(
          path: '/create-recipe',
          builder: (context, state) {
            final extra = state.extra as Map<String, dynamic>?;
            final fromAi = extra?['fromAi'] as AiRecipeSuggestion?;
            final initialCoverPath = extra?['initialCoverPath'] as String?;
            return CreateRecipePage(
              fromAi: fromAi,
              initialCoverPath: initialCoverPath,
            );
          },
        ),
        GoRoute(
          path: '/post/:postId/edit',
          pageBuilder: (context, state) => _buildTransitionPage(
            state: state,
            child: EditPostPage(postId: state.pathParameters['postId']!),
          ),
        ),
        GoRoute(
          path: '/recipe/:recipeId/edit',
          pageBuilder: (context, state) => _buildTransitionPage(
            state: state,
            child: EditRecipePage(recipeId: state.pathParameters['recipeId']!),
          ),
        ),
        GoRoute(
          path: '/ai-recipe-preview',
          name: 'aiRecipePreview',
          builder: (context, state) {
            final suggestion = state.extra as AiRecipeSuggestion;
            return AiRecipePreviewPage(suggestion: suggestion);
          },
        ),
        GoRoute(
          path: '/macro-dashboard',
          builder: (context, state) => const MacroDashboardPage(),
        ),
        GoRoute(
          path: '/shopping-list',
          redirect: (context, state) => '/shopping',
        ),
        GoRoute(
          path: '/notifications',
          builder: (context, state) => const NotificationsPage(),
        ),
        GoRoute(
          path: '/settings/notifications',
          builder: (context, state) => const SettingsNotificationsPage(),
        ),
        GoRoute(
          path: '/ai-assistant',
          pageBuilder: (context, state) => _buildTransitionPage(
            state: state,
            child: const AiAssistantPage(),
          ),
        ),
        GoRoute(
          path: '/create-reel',
          builder: (context, state) => const CreateReelPage(),
        ),
      ],
    ),
    // -------- Admin routes --------
    GoRoute(
      path: '/admin',
      redirect: (context, state) async {
        final guard = await adminOnlyRedirect(context, state);
        if (guard != null) return guard;
        if (state.uri.path == '/admin') return '/admin/overview';
        return null;
      },
      routes: [
        GoRoute(
          path: 'overview',
          builder: (context, state) => const AdminHomePage(),
        ),
        GoRoute(
          path: 'users',
          builder: (context, state) => const AdminUsersPage(),
        ),
        GoRoute(
          path: 'content',
          builder: (context, state) => const AdminContentPage(),
        ),
        GoRoute(
          path: 'posts',
          redirect: (context, state) => '/admin/content',
        ),
        GoRoute(
          path: 'reports',
          builder: (context, state) => const AdminReportsPage(),
        ),
        GoRoute(
          path: 'chats',
          builder: (context, state) => const AdminChatModerationPage(),
        ),
        GoRoute(
          path: 'ai-prompts',
          builder: (context, state) => const AdminAiPromptsPage(),
        ),
        GoRoute(
          path: 'settings',
          builder: (context, state) => const AdminSettingsPage(),
        ),
        GoRoute(
          path: 'audit-logs',
          builder: (context, state) => const AdminAuditLogsPage(),
        ),
      ],
    ),
  ],
);
