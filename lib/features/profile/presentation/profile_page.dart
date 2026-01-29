import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/widgets/app_avatar.dart';
import '../../../core/widgets/app_empty_view.dart';
import '../../../core/widgets/app_error_view.dart';
import '../../../core/widgets/app_loading_indicator.dart';
import '../../../core/widgets/theme_toggle_button.dart';
import '../../../app/l10n.dart';
import '../../../app/language_controller.dart';
import '../../feed/widgets/post_card.dart';
import '../../chat/application/create_chat_controller.dart';
import '../../recipes/data/recipes_repository.dart';
import '../../recipes/widgets/recipe_card.dart';
import '../../auth/data/firebase_auth_repository.dart';
import '../../social/application/social_providers.dart';
import '../../social/widgets/friend_action_button.dart';
import '../application/profile_controller.dart';
import '../data/profile_repository.dart';
import '../data/profile_storage_service.dart';
import '../../reels/data/reel_model.dart';
import '../../reels/application/reels_controller.dart';
import '../../reels/presentation/widgets/reel_video_player.dart';

/// Profile page with fixed header + tabs. Works for /me (uid == null) or /profile/:uid.
class ProfilePage extends ConsumerStatefulWidget {
  const ProfilePage({super.key, this.uid});

  final String? uid;

  @override
  ConsumerState<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends ConsumerState<ProfilePage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(_handleTabChange);
  }

  void _handleTabChange() {
    if (_tabController.indexIsChanging) return;
    setState(() {});
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabChange);
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authUser = FirebaseAuth.instance.currentUser;
    final currentUid = ref.watch(currentUserIdProvider);
    final targetUid = widget.uid ?? currentUid;
    final scheme = Theme.of(context).colorScheme;

    final state = ref.watch(profileControllerProvider(widget.uid));
    final controller = ref.read(profileControllerProvider(widget.uid).notifier);
    final locale = ref.watch(localeProvider);
    final isVi = locale.languageCode == 'vi';
    final s = S(locale);
    final isOwner = widget.uid == null || widget.uid == authUser?.uid;

    if (state.isLoading && state.profile == null) {
      return Scaffold(
        appBar: AppBar(title: Text(s.profile)),
        body: Center(
          child: AppLoadingIndicator(message: s.loading),
        ),
      );
    }

    if (state.error != null && state.profile == null) {
      return Scaffold(
        appBar: AppBar(title: Text(s.profile)),
        body: Center(
          child: AppErrorView(
            message: '${s.error}: ${state.error}',
            onRetry: controller.refresh,
          ),
        ),
      );
    }

    if (targetUid == null) {
      return Scaffold(
        appBar: AppBar(title: Text(s.profile)),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(s.needLoginToViewProfile),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () => context.go('/signin'),
                child: Text(s.login),
              ),
            ],
          ),
        ),
      );
    }

    final profile = state.profile;
    final displayName = profile?.displayName.isNotEmpty == true
        ? profile!.displayName
        : s.user;
    final email = profile?.email ?? authUser?.email ?? '';
    final bio = profile?.bio ?? '';
    final avatarUrl = profile?.photoUrl ?? authUser?.photoURL ?? '';
    final roleValue =
        (profile?.snapshot?.data()?['role'] as String?)?.toLowerCase();
    final isAdmin = roleValue == 'admin' &&
        (widget.uid == null || widget.uid == authUser?.uid);
    final heroTag = widget.uid ?? authUser?.uid ?? 'me';

    final statsAsync = ref.watch(userProfileStatsProvider(targetUid));
    final postsAsync = ref.watch(userPostsProvider(targetUid));
    final recipesAsync = ref.watch(userRecipesProvider(targetUid));
    final savedAsync = ref.watch(userSavedItemsProvider(targetUid));
    final stats = statsAsync.asData?.value ?? UserProfileStats.empty;
    final relationshipAsync =
        isOwner ? null : ref.watch(relationshipProvider(targetUid));
    final relationshipLabel = !isOwner && relationshipAsync != null
        ? relationshipAsync.maybeWhen(
            data: (state) => _relationshipLabel(state, displayName),
            orElse: () => null,
          )
        : null;

    final trailingAction = isOwner
        ? Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: state.isSaving
                    ? null
                    : () => _showEditSheet(
                          context,
                          controller,
                          profile,
                          authUser?.photoURL ?? '',
                        ),
                icon: const Icon(Icons.edit_outlined),
                label: Text(s.edit),
              ),
              OutlinedButton.icon(
                onPressed: () => context.push('/friends'),
                icon: const Icon(Icons.people_outline),
                label: Text(s.friends),
              ),
            ],
          )
        : relationshipAsync?.when(
            data: (state) => _buildProfileActions(
                  context,
                  state,
                  targetUid,
                  displayName,
                ),
            loading: () => const SizedBox(
              height: 36,
              width: 36,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            error: (e, _) => Text(
                  '${s.error}: $e',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: scheme.onSurfaceVariant),
                ),
          );

    return Scaffold(
      appBar: AppBar(
        title: Text(s.profile),
        actions: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 4),
            child: ThemeToggleButton(compact: true),
          ),
          if (isOwner)
            PopupMenuButton<int>(
              icon: Material(
                color: scheme.primaryContainer.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Icon(
                    Icons.more_vert_rounded,
                    color: scheme.primary,
                    size: 20,
                  ),
                ),
              ),
              tooltip: s.settings,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 4,
              offset: const Offset(0, 8),
              onSelected: (val) {
                if (val == 1) {
                  ref.read(localeProvider.notifier).toggleLanguage();
                } else if (val == 2) {
                  context.go('/admin/overview');
                } else if (val == 0) {
                  _handleLogout(context);
                }
              },
              itemBuilder: (ctx) => [
                PopupMenuItem<int>(
                  value: 1,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Material(
                    color: scheme.primaryContainer.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 18,
                            backgroundColor: scheme.primary.withValues(alpha: 0.1),
                            child: Icon(
                              Icons.language_rounded,
                              size: 18,
                              color: scheme.primary,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  s.language,
                                  style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: scheme.onSurface,
                                  ),
                                ),
                                Text(
                                  isVi ? 'English' : 'Tiếng Việt',
                                  style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                                    color: scheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            Icons.chevron_right_rounded,
                            size: 18,
                            color: scheme.onSurfaceVariant,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                if (isAdmin) ...[
                  const PopupMenuDivider(height: 4),
                  PopupMenuItem<int>(
                    value: 2,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: Material(
                      color: scheme.secondaryContainer.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 18,
                              backgroundColor:
                                  scheme.secondary.withValues(alpha: 0.1),
                              child: Icon(
                                Icons.admin_panel_settings_rounded,
                                size: 18,
                                color: scheme.secondary,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                s.admin,
                                style: Theme.of(ctx)
                                    .textTheme
                                    .bodyMedium
                                    ?.copyWith(
                                      fontWeight: FontWeight.w600,
                                      color: scheme.onSurface,
                                    ),
                              ),
                            ),
                            Icon(
                              Icons.chevron_right_rounded,
                              size: 18,
                              color: scheme.onSurfaceVariant,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
                const PopupMenuDivider(height: 4),
                PopupMenuItem<int>(
                  value: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Material(
                    color: scheme.errorContainer.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 18,
                            backgroundColor: scheme.error.withValues(alpha: 0.1),
                            child: Icon(
                              Icons.logout_rounded,
                              color: scheme.error,
                              size: 18,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              s.logout,
                              style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: scheme.error,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
      floatingActionButton: isOwner && _tabController.index < 3
          ? FloatingActionButton(
              onPressed: () {
                if (_tabController.index == 0) {
                  context.push('/create-post');
                } else if (_tabController.index == 1) {
                  context.push('/create-recipe');
                } else if (_tabController.index == 3) {
                  context.push('/create-reel');
                }
              },
              child: Icon(
                _tabController.index == 0 
                  ? Icons.add 
                  : (_tabController.index == 1 ? Icons.restaurant : Icons.video_call),
              ),
            )
          : null,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 900;
          final horizontal = isWide ? 32.0 : 16.0;
          const maxWidth = 960.0;

          final minHeight = constraints.hasBoundedHeight 
              ? constraints.maxHeight - 24 
              : 600.0;

          return SafeArea(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(horizontal: horizontal, vertical: 12),
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: maxWidth,
                    minHeight: minHeight,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ProfileHeader(
                        displayName: displayName,
                        email: email,
                        bio: bio,
                        avatarUrl: avatarUrl,
                        heroTag: null, // Disabled Hero to prevent duplicate tag conflicts
                        postsCount: stats.postsCount,
                        recipesCount: stats.recipesCount,
                        savedCount: stats.savedCount,
                        isAdmin: isAdmin,
                        secondaryLabel: relationshipLabel,
                        trailingAction: trailingAction,
                        onEdit: isOwner
                            ? null
                            : state.isSaving
                                ? null
                                : () => _showEditSheet(
                                      context,
                                      controller,
                                      profile,
                                      authUser?.photoURL ?? '',
                                    ),
                        onStatTap: (index) => _tabController.animateTo(index),
                        reelsCount: ref.watch(userReelsProvider(targetUid)).maybeWhen(
                              data: (reels) => reels.length,
                              orElse: () => 0,
                            ),
                      ),
                      if (statsAsync.hasError)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            s.cannotLoadStatsError(statsAsync.error.toString()),
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(color: scheme.onSurfaceVariant),
                          ),
                        ),
                      const SizedBox(height: 12),
                      Material(
                        color: Colors.transparent,
                        child: TabBar(
                          controller: _tabController,
                          labelColor: Theme.of(context).colorScheme.primary,
                          unselectedLabelColor: scheme.onSurfaceVariant,
                          indicatorColor: Theme.of(context).colorScheme.primary,
                          tabs: const [
                            Tab(icon: Icon(Icons.article_outlined)),
                            Tab(icon: Icon(Icons.restaurant_outlined)),
                            Tab(icon: Icon(Icons.bookmark_outline)),
                            Tab(icon: Icon(Icons.video_library_outlined)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      _buildTabContent(
                        targetUid: targetUid,
                        isOwner: isOwner,
                        displayName: displayName,
                        postsAsync: postsAsync,
                        recipesAsync: recipesAsync,
                        savedAsync: savedAsync,
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _handleLogout(BuildContext context) async {
    final s = S(ref.read(localeProvider));

    final confirmed = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(s.logoutConfirmTitle),
            content: Text(s.logoutConfirmMessage),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(s.cancel),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: FilledButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.error,
                ),
                child: Text(s.logoutConfirmTitle),
              ),
            ],
          ),
        ) ??
        false;

    if (!confirmed || !context.mounted) return;

    try {
      await ref.read(firebaseAuthRepositoryProvider).signOut();
      if (context.mounted) {
        context.go('/signin');
      }
    } catch (e) {
      if (context.mounted) {
        final s = S(ref.read(localeProvider));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${s.logoutError}: $e')),
        );
      }
    }
  }

  Widget _buildTabContent({
    required String targetUid,
    required bool isOwner,
    required String displayName,
    required AsyncValue<List<PostSummary>> postsAsync,
    required AsyncValue<List<RecipeSummary>> recipesAsync,
    required AsyncValue<List<SavedItem>> savedAsync,
  }) {
    switch (_tabController.index) {
      case 0:
        return _PostsTab(
          isOwner: isOwner,
          displayName: displayName,
          asyncValue: postsAsync,
          onCreate: () => context.push('/create-post'),
          onRetry: () => ref.refresh(userPostsProvider(targetUid)),
          onDeletePost: isOwner ? (postId) => _deletePost(context, postId, targetUid) : null,
          onEditPost: isOwner ? (postId) => context.push('/post/$postId/edit') : null,
        );
      case 1:
        return _RecipesTab(
          isOwner: isOwner,
          displayName: displayName,
          asyncValue: recipesAsync,
          onCreate: () => context.push('/create-recipe'),
          onRetry: () => ref.refresh(userRecipesProvider(targetUid)),
          onDeleteRecipe: isOwner ? (recipeId) => _deleteRecipe(context, recipeId, targetUid) : null,
          onEditRecipe: isOwner ? (recipeId) => context.push('/recipe/$recipeId/edit') : null,
        );
      case 2:
        return _SavedTab(
          asyncValue: savedAsync,
          onRetry: () => ref.refresh(userSavedItemsProvider(targetUid)),
        );
      case 3:
        return _ReelsTab(
          isOwner: isOwner,
          userId: targetUid,
          onDeleteReel: isOwner
              ? (reelId) => _deleteReel(context, reelId, targetUid)
              : null,
        );
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildProfileActions(
    BuildContext context,
    RelationshipState state,
    String targetUid,
    String targetName,
  ) {
    final s = S(ref.read(localeProvider));
    if (state.status == RelationshipStatus.pendingReceived) {
      return Wrap(
        spacing: 8,
        children: [
          FilledButton(
            onPressed: () => _acceptRequest(state, context),
            child: Text(s.accept),
          ),
          OutlinedButton(
            onPressed: () => _rejectRequest(state, context),
            child: Text(s.reject),
          ),
        ],
      );
    }
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        FilledButton.icon(
          onPressed: () => _startChatFromProfile(
            context,
            targetUid,
            targetName,
            state,
          ),
          icon: const Icon(Icons.chat_bubble_outline),
          label: Text(s.message),
        ),
        FriendActionButton(
          targetUid: targetUid,
          targetName: targetName,
        ),
      ],
    );
  }

  String? _relationshipLabel(RelationshipState state, String targetName) {
    final s = S(ref.read(localeProvider));
    switch (state.status) {
      case RelationshipStatus.friends:
        return s.friendsFollowing;
      case RelationshipStatus.following:
        return s.following;
      case RelationshipStatus.pendingReceived:
        return s.sentYouRequest;
      case RelationshipStatus.pendingSent:
        return s.waitingFor(targetName);
      case RelationshipStatus.none:
        return null;
    }
  }

  Future<void> _acceptRequest(
    RelationshipState state,
    BuildContext context,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final s = S(ref.read(localeProvider));
    final reqId = state.pendingRequest?.id;
    if (reqId == null) {
      messenger.showSnackBar(
        SnackBar(content: Text(s.requestNotFound)),
      );
      return;
    }
    try {
      await ref.read(friendRepositoryProvider).acceptFriendRequest(reqId);
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('${s.cannotAccept}: $e')),
      );
    }
  }

  Future<void> _rejectRequest(
    RelationshipState state,
    BuildContext context,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final s = S(ref.read(localeProvider));
    final reqId = state.pendingRequest?.id;
    if (reqId == null) {
      messenger.showSnackBar(
        SnackBar(content: Text(s.requestNotFound)),
      );
      return;
    }
    try {
      await ref.read(friendRepositoryProvider).rejectFriendRequest(reqId);
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('${s.cannotReject}: $e')),
      );
    }
  }

  Future<void> _startChatFromProfile(
    BuildContext context,
    String targetUid,
    String targetName,
    RelationshipState state,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final s = S(ref.read(localeProvider));
    if (state.status != RelationshipStatus.friends) {
      await showModalBottomSheet(
        context: context,
        builder: (ctx) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  s.needFriendToChat,
                  style: Theme.of(ctx)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Text(
                  s.sendFriendRequestToUnlock(targetName),
                  style: TextStyle(
                  color: Theme.of(ctx).colorScheme.onSurfaceVariant,
                ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      child: Text(s.close),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      onPressed: () async {
                        await ref
                            .read(friendRepositoryProvider)
                            .sendFriendRequest(targetUid);
                        if (ctx.mounted) Navigator.of(ctx).pop();
                      },
                      child: Text(s.sendFriendRequest),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
      return;
    }

    try {
      final chatId = await ref
          .read(chatFunctionsRepositoryProvider)
          .createDM(toUid: targetUid);
      if (mounted && context.mounted) {
        context.push('/chat/$chatId');
      }
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('${s.cannotCreateChat}: $e')),
      );
    }
  }

  Future<void> _showEditSheet(
    BuildContext context,
    ProfileController controller,
    AppUserProfile? current,
    String fallbackPhoto,
  ) async {
    final s = S(ref.read(localeProvider));
    final nameController =
        TextEditingController(text: current?.displayName ?? '');
    final bioController = TextEditingController(text: current?.bio ?? '');
    final photoController =
        TextEditingController(text: current?.photoUrl ?? fallbackPhoto);

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      isDismissible: true,
      enableDrag: true,
      useRootNavigator: false,
      builder: (ctx) {
        return _EditProfileSheet(
          nameController: nameController,
          bioController: bioController,
          photoController: photoController,
          controller: controller,
          currentPhotoUrl: current?.photoUrl ?? fallbackPhoto,
        );
      },
    );

    nameController.dispose();
    bioController.dispose();
    photoController.dispose();
  }

  Future<void> _deletePost(BuildContext context, String postId, String targetUid) async {
    final s = S(ref.read(localeProvider));
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(s.deletePost),
        content: Text(s.deletePostConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(s.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: Text(s.delete),
          ),
        ],
      ),
    ) ?? false;

    if (!confirmed || !context.mounted) return;

    try {
      await FirebaseFirestore.instance.collection('posts').doc(postId).delete();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(s.postDeleted)),
        );
        ref.invalidate(userPostsProvider(targetUid));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${s.cannotDelete}: $e')),
        );
      }
    }
  }

  Future<void> _deleteRecipe(BuildContext context, String recipeId, String targetUid) async {
    final s = S(ref.read(localeProvider));
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(s.deleteRecipe),
        content: Text(s.deleteRecipeConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(s.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: Text(s.delete),
          ),
        ],
      ),
    ) ?? false;

    if (!confirmed || !context.mounted) return;

    try {
      await FirebaseFirestore.instance.collection('recipes').doc(recipeId).delete();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(s.recipeDeleted)),
        );
        ref.invalidate(userRecipesProvider(targetUid));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${s.cannotDelete}: $e')),
        );
      }
    }
  }

  Future<void> _deleteReel(
      BuildContext context, String reelId, String targetUid) async {
    final s = S(ref.read(localeProvider));
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(isVi ? 'Xóa thước phim' : 'Delete Reel'),
            content: Text(isVi
                ? 'Bạn có chắc chắn muốn xóa thước phim này không?'
                : 'Are you sure you want to delete this reel?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(s.cancel),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: FilledButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.error,
                ),
                child: Text(s.delete),
              ),
            ],
          ),
        ) ??
        false;

    if (!confirmed || !context.mounted) return;

    try {
      await ref.read(reelsControllerProvider.notifier).deleteReel(reelId);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(isVi ? 'Đã xóa thước phim' : 'Reel deleted')),
        );
        ref.invalidate(userReelsProvider(targetUid));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${s.cannotDelete}: $e')),
        );
      }
    }
  }

  bool get isVi => ref.read(localeProvider).languageCode == 'vi';
}

class ProfileHeader extends StatelessWidget {
  const ProfileHeader({
    super.key,
    required this.displayName,
    required this.email,
    required this.bio,
    required this.avatarUrl,
    this.heroTag,
    required this.postsCount,
    required this.recipesCount,
    required this.savedCount,
    required this.isAdmin,
    this.secondaryLabel,
    this.trailingAction,
    this.onEdit,
    this.onStatTap,
    required this.reelsCount,
  });

  final String displayName;
  final String email;
  final String bio;
  final String avatarUrl;
  final String? heroTag;
  final int postsCount;
  final int recipesCount;
  final int savedCount;
  final int reelsCount;
  final bool isAdmin;
  final String? secondaryLabel;
  final Widget? trailingAction;
  final VoidCallback? onEdit;
  final void Function(int index)? onStatTap;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 450;
        final scheme = Theme.of(context).colorScheme;
        final gradientColors = scheme.brightness == Brightness.dark
            ? [
                Color.alphaBlend(
                  scheme.primary.withValues(alpha: 0.16),
                  scheme.surface,
                ),
                scheme.surfaceContainerHigh,
              ]
            : [
                scheme.primary.withValues(alpha: 0.14),
                scheme.surface,
              ];

        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: gradientColors,
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: scheme.primary.withValues(alpha: scheme.brightness == Brightness.dark ? 0.12 : 0.08),
            ),
          ),
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (isNarrow) ...[
                // Mobile layout: Avatar and Info in a row, buttons below
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppAvatar(
                      url: avatarUrl,
                      size: 80, // Slightly smaller for mobile
                      heroTag: null, // Removed to prevent duplicate GlobalKey
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildInfoColumn(context),
                    ),
                  ],
                ),
                if (trailingAction != null || onEdit != null) ...[
                  const SizedBox(height: 16),
                  if (trailingAction != null)
                    trailingAction!
                  else if (onEdit != null)
                    SizedBox(
                      width: double.infinity,
                      child: Consumer(
                        builder: (context, ref, _) {
                          final s = S(ref.watch(localeProvider));
                          return OutlinedButton.icon(
                            onPressed: onEdit,
                            icon: const Icon(Icons.edit_outlined),
                            label: Text(s.edit),
                          );
                        },
                      ),
                    ),
                ],
              ] else ...[
                // Desktop/Tablet layout: All in one row
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppAvatar(
                      url: avatarUrl,
                      size: 96,
                      heroTag: null, // Removed to prevent duplicate GlobalKey
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildInfoColumn(context),
                    ),
                    const SizedBox(width: 16),
                    if (trailingAction != null)
                      trailingAction!
                    else if (onEdit != null)
                      Consumer(
                        builder: (context, ref, _) {
                          final s = S(ref.watch(localeProvider));
                          return OutlinedButton.icon(
                            onPressed: onEdit,
                            icon: const Icon(Icons.edit_outlined),
                            label: Text(s.edit),
                          );
                        },
                      ),
                  ],
                ),
              ],
              const SizedBox(height: 16),
              Consumer(
                builder: (context, ref, _) {
                  final s = S(ref.watch(localeProvider));
                  return Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _StatTile(
                        label: s.posts,
                        value: postsCount,
                        onTap: () => onStatTap?.call(0),
                      ),
                      _StatTile(
                        label: s.recipes,
                        value: recipesCount,
                        onTap: () => onStatTap?.call(1),
                      ),
                      _StatTile(
                        label: s.saved,
                        value: savedCount,
                        onTap: () => onStatTap?.call(2),
                      ),
                      _StatTile(
                        label: 'Reels',
                        value: reelsCount,
                        onTap: () => onStatTap?.call(3),
                      ),

                    ],
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildInfoColumn(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          displayName,
          style: Theme.of(context)
              .textTheme
              .headlineSmall
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
        if (email.isNotEmpty)
          Text(
            email,
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: scheme.onSurfaceVariant),
          ),
        if (secondaryLabel != null && secondaryLabel!.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              secondaryLabel!,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ),
        if (bio.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            bio,
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ],
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.label,
    required this.value,
    this.onTap,
  });

  final String label;
  final int value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
          child: Column(
            children: [
              Text(
                value.toString(),
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PostsTab extends StatelessWidget {
  const _PostsTab({
    required this.isOwner,
    required this.displayName,
    required this.asyncValue,
    required this.onCreate,
    required this.onRetry,
    this.onDeletePost,
    this.onEditPost,
  });
  final bool isOwner;
  final String displayName;
  final AsyncValue<List<PostSummary>> asyncValue;
  final VoidCallback onCreate;
  final VoidCallback onRetry;
  final void Function(String postId)? onDeletePost;
  final void Function(String postId)? onEditPost;

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (context, ref, _) {
        final s = S(ref.watch(localeProvider));
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
              child: Text(
                s.userPosts(displayName),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
            asyncValue.when(
              data: (posts) {
                if (posts.isEmpty) {
                  return AppEmptyView(
                    title: s.noPostsYet,
                    subtitle: s.noPostsDesc,
                  );
                }
                return Column(
                  children: posts
                      .map(
                        (post) => Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 6),
                          child: PostCard(
                            id: post.id,
                            authorId: post.authorId,
                            authorName: displayName,
                            caption: post.title,
                            imageUrl: post.photoUrls.isNotEmpty
                                ? post.photoUrls.first
                                : null,
                            tags: post.tags,
                            likesCount: post.likesCount,
                            commentsCount: post.commentsCount,
                            avatarHeroTag: null,
                            onTap: () => context.push('/post/${post.id}'),
                            onAvatarTap: post.authorId.isNotEmpty
                                ? () => context.push('/profile/${post.authorId}')
                                : null,
                            onEdit: isOwner && onEditPost != null
                                ? () => onEditPost!(post.id)
                                : null,
                            onDelete: isOwner && onDeletePost != null
                                ? () => onDeletePost!(post.id)
                                : null,
                          ),
                        ),
                      )
                      .toList(),
                );
              },
              loading: () => Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: AppLoadingIndicator(message: s.loadingPosts),
              ),
              error: (e, _) => AppErrorView(
                message: s.cannotLoadPosts(e.toString()),
                onRetry: onRetry,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _RecipesTab extends StatelessWidget {
  const _RecipesTab({
    required this.isOwner,
    required this.displayName,
    required this.asyncValue,
    required this.onCreate,
    required this.onRetry,
    this.onDeleteRecipe,
    this.onEditRecipe,
  });
  final bool isOwner;
  final String displayName;
  final AsyncValue<List<RecipeSummary>> asyncValue;
  final VoidCallback onCreate;
  final VoidCallback onRetry;
  final void Function(String recipeId)? onDeleteRecipe;
  final void Function(String recipeId)? onEditRecipe;

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (context, ref, _) {
        final s = S(ref.watch(localeProvider));
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
              child: Text(
                s.userRecipes(displayName),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
            asyncValue.when(
              data: (recipes) {
                if (recipes.isEmpty) {
                  return AppEmptyView(
                    title: s.noRecipesYet,
                    subtitle: s.noRecipesDesc,
                  );
                }
                return Column(
                  children: recipes
                      .map(
                        (recipe) => Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 6),
                          child: RecipeCard(
                            heroTag: 'profile_recipes_${recipe.id}',
                            title: recipe.title,
                            imageUrl: recipe.photoUrl ?? '',
                            authorName:
                                recipe.authorId.isNotEmpty ? displayName : 'Chef',
                            authorId: recipe.authorId,
                            rating: recipe.avgRating,
                            cookMinutes: recipe.cookTimeMinutes,
                            likesCount: recipe.likesCount,
                            commentsCount: recipe.commentsCount,
                            avatarHeroTag: null,
                            tags: const [],
                            onTap: () => context.push('/recipe/${recipe.id}'),
                            onAvatarTap: recipe.authorId.isNotEmpty
                                ? () => context.push('/profile/${recipe.authorId}')
                                : null,
                            onEdit: isOwner && onEditRecipe != null
                                ? () => onEditRecipe!(recipe.id)
                                : null,
                            onDelete: isOwner && onDeleteRecipe != null
                                ? () => onDeleteRecipe!(recipe.id)
                                : null,
                          ),
                        ),
                      )
                      .toList(),
                );
              },
              loading: () => Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: AppLoadingIndicator(message: s.loadingRecipes),
              ),
              error: (e, _) => AppErrorView(
                message: s.cannotLoadRecipes(e.toString()),
                onRetry: onRetry,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _SavedTab extends StatelessWidget {
  const _SavedTab({
    required this.asyncValue,
    required this.onRetry,
  });
  final AsyncValue<List<SavedItem>> asyncValue;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (context, ref, _) {
        final locale = ref.watch(localeProvider);
        final isVi = locale.languageCode == 'vi';
        final s = S(locale);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
              child: Text(
                s.savedItems,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
            asyncValue.when(
              data: (items) {
                if (items.isEmpty) {
                  return AppEmptyView(
                    title: s.noSavedYet,
                    subtitle: s.noSavedDesc,
                  );
                }
                return Column(
                  children: items.map((item) {
                    if (item.targetType == 'recipe' && item.recipe != null) {
                      final recipe = item.recipe!;
                      return Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 6),
                        child: RecipeCard(
                          heroTag: 'profile_saved_${recipe.id}',
                          title: recipe.title,
                          imageUrl: recipe.photoUrl ?? '',
                          authorName: recipe.authorId.isNotEmpty
                              ? recipe.authorId
                              : 'Chef',
                          authorId: recipe.authorId,
                          rating: recipe.avgRating,
                          cookMinutes: recipe.cookTimeMinutes,
                          likesCount: recipe.likesCount,
                          commentsCount: recipe.commentsCount,
                          avatarHeroTag: null,
                          tags: const [],
                          onTap: () => context.push('/recipe/${recipe.id}'),
                          onAvatarTap: recipe.authorId.isNotEmpty
                              ? () => context.push('/profile/${recipe.authorId}')
                              : null,
                        ),
                      );
                    }

                    if (item.targetType == 'post' && item.post != null) {
                      final post = item.post!;
                      return Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 6),
                        child: PostCard(
                          id: post.id,
                          authorId: post.authorId,
                          authorName: '', // Will be preloaded in PostCard
                          caption: post.title,
                          imageUrl: post.photoUrls.isNotEmpty
                              ? post.photoUrls.first
                              : null,
                          tags: post.tags,
                          likesCount: post.likesCount,
                          commentsCount: post.commentsCount,
                          onTap: () => context.push('/post/${post.id}'),
                          onAvatarTap: () =>
                              context.push('/profile/${post.authorId}'),
                        ),
                      );
                    }

                    if (item.targetType == 'reel' && item.reel != null) {
                      final reel = item.reel!;
                      return Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 6),
                        child: Container(
                          height: 120,
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.1),
                            ),
                          ),
                          child: InkWell(
                            onTap: () {
                              showGeneralDialog(
                                context: context,
                                barrierDismissible: true,
                                barrierLabel: 'Reel',
                                barrierColor: Colors.black,
                                pageBuilder: (context, _, __) {
                                  return Scaffold(
                                    backgroundColor: Colors.black,
                                    appBar: AppBar(
                                      backgroundColor: Colors.transparent,
                                      leading: IconButton(
                                        icon: const Icon(Icons.close, color: Colors.white),
                                        onPressed: () => Navigator.pop(context),
                                      ),
                                    ),
                                    extendBodyBehindAppBar: true,
                                    body: ReelVideoPlayer(
                                      reel: reel,
                                      isActive: true,
                                    ),
                                  );
                                },
                              );
                            },
                            borderRadius: BorderRadius.circular(12),
                            child: Row(
                              children: [
                                ClipRRect(
                                  borderRadius: const BorderRadius.horizontal(left: Radius.circular(12)),
                                  child: SizedBox(
                                    width: 80,
                                    height: 120,
                                    child: Image.network(
                                      reel.thumbnailUrl,
                                      fit: BoxFit.cover,
                                      errorBuilder: (context, error, stackTrace) =>
                                          Container(color: Colors.grey),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        reel.title.isNotEmpty ? reel.title : 'Reel',
                                        style: const TextStyle(fontWeight: FontWeight.bold),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        reel.description,
                                        style: Theme.of(context).textTheme.bodySmall,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 8),
                                      Row(
                                        children: [
                                          const Icon(Icons.play_circle_outline, size: 16),
                                          const SizedBox(width: 4),
                                          Text(
                                            isVi ? 'Thước phim' : 'Reel',
                                            style: Theme.of(context).textTheme.labelSmall,
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                const Icon(Icons.chevron_right),
                                const SizedBox(width: 8),
                              ],
                            ),
                          ),
                        ),
                      );
                    }

                    return ListTile(
                      leading: const Icon(Icons.help_outline),
                      title: Text(s.itemNotFound(item.targetId)),
                    );
                  }).toList(),
                );
              },
              loading: () => Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: AppLoadingIndicator(message: s.loadingSaved),
              ),
              error: (e, _) => AppErrorView(
                message: s.cannotLoadSaved(e.toString()),
                onRetry: onRetry,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _ReelsTab extends ConsumerWidget {
  const _ReelsTab({
    required this.isOwner,
    required this.userId,
    this.onDeleteReel,
  });

  final bool isOwner;
  final String userId;
  final void Function(String reelId)? onDeleteReel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reelsAsync = ref.watch(userReelsProvider(userId));
    final s = S(ref.watch(localeProvider));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
          child: Text(
            isOwner
                ? (ref.watch(localeProvider).languageCode == 'vi'
                    ? 'Thước phim của bạn'
                    : 'Your Reels')
                : (ref.watch(localeProvider).languageCode == 'vi'
                    ? 'Thước phim'
                    : 'Reels'),
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
        reelsAsync.when(
          data: (reels) {
            if (reels.isEmpty) {
              return AppEmptyView(
                title: ref.watch(localeProvider).languageCode == 'vi'
                    ? 'Chưa có thước phim nào'
                    : 'No Reels yet',
                subtitle: ref.watch(localeProvider).languageCode == 'vi'
                    ? 'Các video ngắn sẽ xuất hiện ở đây.'
                    : 'Short videos will appear here.',
              );
            }

            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 8),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                childAspectRatio: 9 / 16,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
              ),
              itemCount: reels.length,
              itemBuilder: (context, index) {
                final reel = reels[index];
                return _ReelGridItem(
                  reel: reel,
                  isOwner: isOwner,
                  onDelete: () => onDeleteReel?.call(reel.id),
                );
              },
            );
          },
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 40),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (error, _) => AppErrorView(
            message: error.toString(),
            onRetry: () => ref.refresh(userReelsProvider(userId)),
          ),
        ),
      ],
    );
  }
}

class _ReelGridItem extends StatelessWidget {
  const _ReelGridItem({
    required this.reel,
    required this.isOwner,
    this.onDelete,
  });

  final Reel reel;
  final bool isOwner;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        // Show the reel in full screen
        showGeneralDialog(
          context: context,
          barrierDismissible: true,
          barrierLabel: 'Reel',
          barrierColor: Colors.black,
          pageBuilder: (context, _, __) {
            return Scaffold(
              backgroundColor: Colors.black,
              appBar: AppBar(
                backgroundColor: Colors.transparent,
                leading: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
              extendBodyBehindAppBar: true,
              body: ReelVideoPlayer(
                reel: reel,
                isActive: true,
              ),
            );
          },
        );
      },
      child: Stack(
        fit: StackFit.expand,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: reel.thumbnailUrl.isNotEmpty
                ? Image.network(
                    reel.thumbnailUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Colors.grey[800]!, Colors.grey[900]!],
                        ),
                      ),
                      child: const Icon(Icons.movie_creation_outlined,
                          color: Colors.white24, size: 40),
                    ),
                  )
                : Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.grey[800]!, Colors.grey[900]!],
                      ),
                    ),
                    child: const Icon(Icons.movie_creation_outlined,
                        color: Colors.white24, size: 40),
                  ),
          ),
          // Title overlay for better identification
          if (reel.title.isNotEmpty)
            Positioned(
              left: 4,
              right: 4,
              top: 4,
              child: Text(
                reel.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  shadows: [Shadow(blurRadius: 2, color: Colors.black54)],
                ),
              ),
            ),
          Positioned(
            bottom: 4,
            left: 4,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.play_arrow_outlined,
                      color: Colors.white, size: 12),
                  const SizedBox(width: 2),
                  Text(
                    _formatCount(reel.viewsCount),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (isOwner)
            Positioned(
              top: 0,
              right: 0,
              child: Material(
                color: Colors.black.withValues(alpha: 0.5),
                borderRadius:
                    const BorderRadius.only(bottomLeft: Radius.circular(8)),
                child: InkWell(
                  onTap: onDelete,
                  child: const Padding(
                    padding: EdgeInsets.all(4),
                    child: Icon(Icons.delete_outline,
                        color: Colors.white, size: 18),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _formatCount(int count) {
    if (count >= 1000000) {
      return '${(count / 1000000).toStringAsFixed(1)}M';
    } else if (count >= 1000) {
      return '${(count / 1000).toStringAsFixed(1)}K';
    }
    return count.toString();
  }
}


/// Edit Profile Sheet with Photo Picker
class _EditProfileSheet extends ConsumerStatefulWidget {
  const _EditProfileSheet({
    required this.nameController,
    required this.bioController,
    required this.photoController,
    required this.controller,
    required this.currentPhotoUrl,
  });

  final TextEditingController nameController;
  final TextEditingController bioController;
  final TextEditingController photoController;
  final ProfileController controller;
  final String currentPhotoUrl;

  @override
  ConsumerState<_EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends ConsumerState<_EditProfileSheet> {
  final ImagePicker _picker = ImagePicker();
  final ProfileStorageService _storageService = ProfileStorageService();
  bool _isUploading = false;
  String? _previewUrl;
  bool _showUrlField = false;

  @override
  void initState() {
    super.initState();
    _previewUrl = widget.currentPhotoUrl;
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: source,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 85,
      );

      if (image == null) return;

      setState(() => _isUploading = true);

      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) throw Exception('User not logged in');

      // Upload to Firebase Storage
      final downloadUrl = await _storageService.uploadProfileAvatar(
        userId: currentUser.uid,
        image: image,
      );

      setState(() {
        _previewUrl = downloadUrl;
        widget.photoController.text = downloadUrl;
        _isUploading = false;
      });
    } catch (e) {
      setState(() => _isUploading = false);
      if (mounted) {
        final s = S(ref.read(localeProvider));
        String errorMessage = '${s.error}: $e';
        
        // Check for Firebase Storage unauthorized error
        if (e.toString().contains('unauthorized') || 
            e.toString().contains('permission-denied')) {
          errorMessage = isVi 
              ? 'Không có quyền tải ảnh lên. Vui lòng kiểm tra cấu hình Firebase Storage Rules.'
              : 'No permission to upload images. Please check Firebase Storage Rules configuration.';
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: s.close,
              onPressed: () {},
            ),
          ),
        );
      }
    }
  }

  bool get isVi => ref.read(localeProvider).languageCode == 'vi';

  void _showPhotoSourcePicker() {
    final s = S(ref.read(localeProvider));
    final scheme = Theme.of(context).colorScheme;

    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: CircleAvatar(
                  backgroundColor: scheme.primaryContainer,
                  child: Icon(Icons.camera_alt, color: scheme.primary),
                ),
                title: Text(s.fromCamera),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickImage(ImageSource.camera);
                },
              ),
              ListTile(
                leading: CircleAvatar(
                  backgroundColor: scheme.secondaryContainer,
                  child: Icon(Icons.photo_library, color: scheme.secondary),
                ),
                title: Text(s.fromGallery),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickImage(ImageSource.gallery);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = S(ref.read(localeProvider));
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        top: 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            s.editProfile,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 20),

          // Avatar Section
          Center(
            child: Stack(
              children: [
                CircleAvatar(
                  radius: 56,
                  backgroundColor: scheme.surfaceContainerHighest,
                  backgroundImage: _previewUrl != null && _previewUrl!.isNotEmpty
                      ? NetworkImage(_previewUrl!)
                      : null,
                  child: _previewUrl == null || _previewUrl!.isEmpty
                      ? Icon(Icons.person, size: 56, color: scheme.onSurfaceVariant)
                      : null,
                ),
                if (_isUploading)
                  Positioned.fill(
                    child: CircleAvatar(
                      radius: 56,
                      backgroundColor: Colors.black54,
                      child: CircularProgressIndicator(
                        color: scheme.primary,
                        strokeWidth: 3,
                      ),
                    ),
                  ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Material(
                    color: scheme.primaryContainer,
                    shape: const CircleBorder(),
                    elevation: 2,
                    child: InkWell(
                      onTap: _isUploading ? null : _showPhotoSourcePicker,
                      customBorder: const CircleBorder(),
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: Icon(
                          Icons.camera_alt,
                          size: 20,
                          color: scheme.onPrimaryContainer,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: TextButton.icon(
              onPressed: () => setState(() => _showUrlField = !_showUrlField),
              icon: Icon(
                _showUrlField ? Icons.keyboard_arrow_up : Icons.link,
                size: 16,
              ),
              label: Text(
                _showUrlField ? s.avatarUrl : s.avatarUrl,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ),

          // URL Field (Collapsible)
          if (_showUrlField) ...[
            TextField(
              controller: widget.photoController,
              decoration: InputDecoration(
                labelText: s.avatarUrl,
                hintText: 'https://...',
                prefixIcon: const Icon(Icons.link),
                border: const OutlineInputBorder(),
              ),
              onChanged: (value) {
                setState(() => _previewUrl = value);
              },
            ),
            const SizedBox(height: 12),
          ],

          // Name Field
          TextField(
            controller: widget.nameController,
            decoration: InputDecoration(
              labelText: s.displayName,
              prefixIcon: const Icon(Icons.person_outline),
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),

          // Bio Field
          TextField(
            controller: widget.bioController,
            decoration: InputDecoration(
              labelText: s.bio,
              prefixIcon: const Icon(Icons.edit_note),
              border: const OutlineInputBorder(),
            ),
            maxLines: 3,
          ),
          const SizedBox(height: 20),

          // Action Buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () {
                  // Use root navigator to ensure proper pop
                  Navigator.of(context, rootNavigator: false).pop();
                },
                child: Text(s.cancel),
              ),
              const SizedBox(width: 12),
              FilledButton.icon(
                onPressed: _isUploading
                    ? null
                    : () async {
                        final name = widget.nameController.text.trim();
                        final bio = widget.bioController.text.trim();
                        final photo = widget.photoController.text.trim();

                        if (name.isEmpty) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(s.nameRequired)),
                            );
                          }
                          return;
                        }

                        try {
                          await widget.controller.updateProfile(
                            displayName: name,
                            bio: bio,
                            photoUrl: photo.isNotEmpty ? photo : null,
                          );

                          if (context.mounted) {
                            Navigator.of(context, rootNavigator: false).pop();
                            // Show success message
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  isVi ? 'Đã cập nhật hồ sơ' : 'Profile updated',
                                ),
                                backgroundColor: Colors.green,
                              ),
                            );
                          }
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('${s.error}: $e'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        }
                      },
                icon: const Icon(Icons.save),
                label: Text(s.save),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
