import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_sizes.dart';
import '../../../core/widgets/app_error_view.dart';
import '../../../core/widgets/app_loading_indicator.dart';
import '../../../core/widgets/tag_chip.dart';
import '../../feed/widgets/post_card.dart';
import '../../feed/widgets/recipe_card.dart';
import '../../../shared/widgets/modern_ui_components.dart';
import '../application/search_controller.dart';
import '../data/search_repository.dart';
import 'widgets/ai_recipe_suggestion_card.dart';
import 'widgets/user_search_card.dart';

class SearchPage extends ConsumerStatefulWidget {
  const SearchPage({super.key, this.initialQuery});

  final String? initialQuery;

  @override
  ConsumerState<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends ConsumerState<SearchPage> {
  late final TextEditingController _controller;
  late final VoidCallback _controllerListener;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialQuery ?? '';
    _controller = TextEditingController(text: initial);
    _controllerListener = () {
      final query = _controller.text;
      ref.read(searchControllerProvider.notifier).setQuery(query);
      
      // Debounce search
      if (_debounce?.isActive ?? false) _debounce!.cancel();
      _debounce = Timer(const Duration(milliseconds: 500), () {
        if (mounted && query.isNotEmpty) {
          ref.read(searchControllerProvider.notifier).search(query);
        } else if (query.isEmpty) {
          ref.read(searchControllerProvider.notifier).search('');
        }
      });
      
      setState(() {});
    };
    _controller.addListener(_controllerListener);
    if (initial.isNotEmpty) {
      Future.microtask(() {
        final notifier = ref.read(searchControllerProvider.notifier);
        notifier.setQuery(initial);
        notifier.search(initial);
      });
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.removeListener(_controllerListener);
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    await ref.read(searchControllerProvider.notifier).search(_controller.text);
  }

  void _clear() {
    _controller.clear();
    ref.read(searchControllerProvider.notifier).search('');
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(searchControllerProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tìm kiếm'),
        actions: [
          IconButton.filledTonal(
            tooltip: 'Danh Sách Mua Sắm',
            onPressed: () => context.push('/shopping'),
            icon: const Icon(Icons.shopping_cart_outlined, size: 26),
            style: IconButton.styleFrom(
              backgroundColor: theme.colorScheme.primaryContainer,
              foregroundColor: theme.colorScheme.onPrimaryContainer,
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(AppSizes.md),
        child: Column(
          children: [
            TextField(
              controller: _controller,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _submit(),
              decoration: InputDecoration(
                hintText: 'Tìm món ăn, bài viết... (dùng @ để tìm tác giả)',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _controller.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: _clear,
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: AppSizes.md),
            Expanded(child: _buildResults(context, state)),
          ],
        ),
      ),
    );
  }

  Widget _buildResults(BuildContext context, SearchState state) {
    if (state.query.trim().isEmpty) {
      return const Center(
        child: Text('Nhập từ khoá để tìm món ăn/bài viết.\nDùng @ để tìm tác giả (vd: @thành)', textAlign: TextAlign.center),
      );
    }
    if (state.loading) {
      return const AppLoadingIndicator();
    }
    if (state.error != null) {
      return AppErrorView(
        message: state.error,
        onRetry: state.query.isNotEmpty ? _submit : null,
      );
    }
    if (state.results.isEmpty && state.userResults.isEmpty && state.aiSuggestions.isEmpty) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('Không tìm thấy kết quả.'),
          if (state.aiLoading)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: AppLoadingIndicator(message: 'Đang lấy gợi ý từ AI...'),
            )
          else if (state.aiError == null)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text('Đang lấy gợi ý từ AI cho từ khoá này...'),
            ),
          if (state.aiError != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                'Không lấy được gợi ý AI: ${state.aiError}',
                textAlign: TextAlign.center,
              ),
            ),
        ],
      );
    }

    return ListView(
      children: [
        if (state.userResults.isNotEmpty) ...[
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'Tác giả',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ),
          ...state.userResults.map((user) => UserSearchCard(user: user)),
          const SizedBox(height: 8),
        ],
        if (state.results.isNotEmpty) ...[
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'Kết quả từ cộng đồng',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          ...state.results.map((item) => SearchResultCard(item: item)),
        ],
        if (state.aiSuggestions.isNotEmpty) ...[
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 24, 16, 8),
            child: Text(
              'Gợi ý từ AI',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: state.aiSuggestions.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final suggestion = state.aiSuggestions[index];
              return AiRecipeSuggestionCard(
                suggestion: suggestion,
                onPreview: () => context.pushNamed(
                  'aiRecipePreview',
                  extra: suggestion,
                ),
                onUseAsTemplate: () => context.push(
                  '/create-recipe',
                  extra: {'fromAi': suggestion},
                ),
              );
            },
          ),
        ],
      ],
    );
  }
}

class SearchResultCard extends StatelessWidget {
  const SearchResultCard({super.key, required this.item});

  final SearchResultItem item;

  @override
  Widget build(BuildContext context) {
    switch (item.type) {
      case SearchResultType.post:
        final post = item.post!;
        return _ResultCard(
          label: 'Bài viết',
          child: PostCard(
            id: post.id,
            authorId: post.authorId,
            authorName: post.authorId,
            caption: post.title,
            imageUrl: post.photoURLs.isNotEmpty ? post.photoURLs.first : null,
            tags: post.tags,
            likesCount: post.likesCount,
            commentsCount: post.commentsCount,
            onTap: () => context.push('/post/${post.id}'),
            onAvatarTap: post.authorId.isNotEmpty
                ? () => context.push('/profile/${post.authorId}')
                : null,
          ),
        );
      case SearchResultType.recipe:
        final recipe = item.recipe!;
        return _ResultCard(
          label: 'Công thức',
          child: RecipeCard(
            recipe: recipe,
            onTap: () => context.push('/recipe/${recipe.id}'),
          ),
        );
      case SearchResultType.user:
        final user = item.user!;
        return _ResultCard(
          label: 'Người dùng',
          child: ListTile(
            leading: GradientAvatar(
              imageUrl: user.photoUrl ?? "",
              radius: 20,
              child: Text(
                (user.displayName ?? 'U')[0].toUpperCase(),
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            title: Text(user.displayName ?? 'User'),
            subtitle: Text(user.email ?? ''),
            onTap: () => context.push('/profile/${user.uid}'),
          ),
        );
    }
  }
}

class _ResultCard extends StatelessWidget {
  const _ResultCard({
    required this.label,
    required this.child,
  });

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(
              top: AppSizes.sm,
              left: AppSizes.sm,
            ),
            child: TagChip(label: label),
          ),
          child,
        ],
      ),
    );
  }
}
