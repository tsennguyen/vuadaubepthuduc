import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../data/admin_content_repository.dart';
import 'admin_scaffold.dart';
import 'widgets/admin_page_actions.dart';

class AdminContentPage extends StatefulWidget {
  const AdminContentPage({super.key});

  @override
  State<AdminContentPage> createState() => _AdminContentPageState();
}

class _AdminContentPageState extends State<AdminContentPage> {
  late final AdminContentRepository _repository;

  ContentFilter _filter = ContentFilter.all;
  late Stream<List<AdminContentItem>> _postsStream;
  late Stream<List<AdminContentItem>> _recipesStream;
  late Stream<List<AdminContentItem>> _reelsStream;

  final Set<String> _busyIds = <String>{};

  @override
  void initState() {
    super.initState();
    _repository = FirestoreAdminContentRepository();
    _refreshStreams();
  }

  void _refreshStreams() {
    _postsStream = _repository.watchPosts(_filter);
    _recipesStream = _repository.watchRecipes(_filter);
    _reelsStream = _repository.watchReels(_filter);
  }

  void _setFilter(ContentFilter filter) {
    if (filter == _filter) return;
    setState(() {
      _filter = filter;
      _refreshStreams();
    });
  }

  String _busyKey(AdminContentItem item) => '${item.type.name}:${item.id}';

  Future<void> _approve(AdminContentItem item) async {
    final key = _busyKey(item);
    if (_busyIds.contains(key)) return;
    setState(() => _busyIds.add(key));
    try {
      await _repository.approveContent(item);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Duyệt thất bại: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _busyIds.remove(key));
      }
    }
  }

  Future<void> _hide(AdminContentItem item) async {
    final key = _busyKey(item);
    if (_busyIds.contains(key)) return;
    setState(() => _busyIds.add(key));
    try {
      await _repository.hideContent(item);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ẩn thất bại: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _busyIds.remove(key));
      }
    }
  }

  Future<void> _delete(AdminContentItem item) async {
    final confirmed = await _confirmDelete(item);
    if (!confirmed) return;

    final key = _busyKey(item);
    if (_busyIds.contains(key)) return;
    setState(() => _busyIds.add(key));
    try {
      await _repository.deleteContent(item);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Xóa thất bại: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _busyIds.remove(key));
      }
    }
  }

  Future<bool> _confirmDelete(AdminContentItem item) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Xóa nội dung?'),
          content: Text(
            'Bạn chắc chắn muốn xóa vĩnh viễn "${item.title}"?\n'
            'Hành động này không thể hoàn tác.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Hủy'),
            ),
            FilledButton.tonal(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Xóa'),
            ),
          ],
        );
      },
    );
    return result ?? false;
  }

  Future<void> _view(AdminContentItem item) async {
    await showDialog<void>(
      context: context,
      builder: (context) => _ContentDetailDialog(item: item),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AdminShell(
      actions: [
        AdminPageActions(
          onRefresh: () {
            setState(() {
              _refreshStreams();
            });
          },
        ),
      ],
      child: DefaultTabController(
        length: 3,
        child: Column(
          children: [
            Container(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                border: Border(
                  bottom: BorderSide(
                    color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.1),
                    width: 1,
                  ),
                ),
              ),
              child: Column(
                children: [
                  const TabBar(
                    tabs: [
                      Tab(
                        icon: Icon(Icons.article_rounded),
                        text: 'Bài viết',
                      ),
                      Tab(
                        icon: Icon(Icons.restaurant_menu_rounded),
                        text: 'Công thức',
                      ),
                      Tab(
                        icon: Icon(Icons.movie_filter_rounded),
                        text: 'Reels',
                      ),
                    ],
                    labelStyle: TextStyle(fontWeight: FontWeight.w700),
                    unselectedLabelStyle: TextStyle(fontWeight: FontWeight.w500),
                  ),
                  _FilterBar(
                    value: _filter,
                    onChanged: _setFilter,
                  ),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                children: [
                  _ContentListView(
                    stream: _postsStream,
                    emptyText: 'Không tìm thấy bài viết nào.',
                    busyIds: _busyIds,
                    onView: _view,
                    onApprove: _approve,
                    onHide: _hide,
                    onDelete: _delete,
                  ),
                  _ContentListView(
                    stream: _recipesStream,
                    emptyText: 'Không tìm thấy công thức nào.',
                    busyIds: _busyIds,
                    onView: _view,
                    onApprove: _approve,
                    onHide: _hide,
                    onDelete: _delete,
                  ),
                  _ContentListView(
                    stream: _reelsStream,
                    emptyText: 'Không tìm thấy reels nào.',
                    busyIds: _busyIds,
                    onView: _view,
                    onApprove: _approve,
                    onHide: _hide,
                    onDelete: _delete,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterBar extends StatelessWidget {
  const _FilterBar({required this.value, required this.onChanged});

  final ContentFilter value;
  final ValueChanged<ContentFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.filter_list_rounded,
              size: 20,
              color: theme.colorScheme.outline,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: ContentFilter.values.map((filter) {
                  final selected = filter == value;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      selected: selected,
                      label: Text(filter.name),
                      onSelected: (_) => onChanged(filter),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ContentDetailDialog extends StatefulWidget {
  const _ContentDetailDialog({required this.item});

  final AdminContentItem item;

  @override
  State<_ContentDetailDialog> createState() => _ContentDetailDialogState();
}

class _ContentDetailDialogState extends State<_ContentDetailDialog> {
  late Future<_DetailData> _dataFuture;

  bool get isRecipe => widget.item.type == AdminContentType.recipe;

  @override
  void initState() {
    super.initState();
    _dataFuture = _loadData();
  }

  Future<_DetailData> _loadData() async {
    final firestore = FirebaseFirestore.instance;
    final collection = switch (widget.item.type) {
      AdminContentType.post => 'posts',
      AdminContentType.recipe => 'recipes',
      AdminContentType.reel => 'reels',
    };

    final contentDoc =
        await firestore.collection(collection).doc(widget.item.id).get();
    final contentData = contentDoc.data();

    String authorName = widget.item.authorName;
    // If authorName is empty or looks like an ID, try to fetch
    if (authorName.isEmpty || authorName == widget.item.authorId) {
      final authorId = widget.item.authorId;
      if (authorId.isNotEmpty) {
        final userDoc = await firestore.collection('users').doc(authorId).get();
        final userData = userDoc.data();
        if (userData != null) {
          authorName = userData['displayName'] ?? userData['name'] ?? authorId;
        }
      }
    }

    return _DetailData(content: contentData, authorName: authorName);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Dialog(
      child: Container(
        width: 800,
        height: MediaQuery.of(context).size.height * 0.85,
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer.withValues(alpha: 0.1),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(24),
                  topRight: Radius.circular(24),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: widget.item.type == AdminContentType.post
                          ? Colors.orange.shade500
                          : Colors.green.shade500,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: (widget.item.type == AdminContentType.post
                                  ? Colors.orange
                                  : Colors.green)
                              .withValues(alpha: 0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Icon(
                      widget.item.type == AdminContentType.post
                          ? Icons.article_rounded
                          : widget.item.type == AdminContentType.recipe
                              ? Icons.restaurant_menu_rounded
                              : Icons.movie_filter_rounded,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.item.title,
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          'Chi tiết ${widget.item.type.name}',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                    tooltip: 'Đóng',
                  ),
                ],
              ),
            ),
            // Content
            Expanded(
              child: FutureBuilder<_DetailData>(
                future: _dataFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.error_outline,
                              size: 48, color: theme.colorScheme.error),
                          const SizedBox(height: 16),
                          Text('Lỗi: ${snapshot.error}'),
                        ],
                      ),
                    );
                  }

                  final data = snapshot.data;
                  if (data == null || data.content == null) {
                    return const Center(child: Text('Không tìm thấy nội dung.'));
                  }

                  return _buildContent(context, data.content!, data.authorName);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(
      BuildContext context, Map<String, dynamic> content, String authorName) {
    final type = widget.item.type;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Metadata Section
          _buildMetadataSection(context, content, authorName),
          const SizedBox(height: 24),

          // Images Section
          _buildImagesSection(context, content, type == AdminContentType.recipe),

          // Content Section  
          if (type == AdminContentType.post) _buildPostContent(context, content),
          
          if (type == AdminContentType.reel) _buildReelContent(context, content),

          // Recipe-specific sections
          if (isRecipe) ...[
            _buildRecipeDescription(context, content),
            const SizedBox(height: 24),
            _buildIngredientsSection(context, content),
            const SizedBox(height: 24),
            _buildStepsSection(context, content),
            const SizedBox(height: 24),
            _buildNutritionSection(context, content),
            const SizedBox(height: 24),
            _buildTagsSection(context, content),
          ],
        ],
      ),
    );
  }

  Widget _buildMetadataSection(
      BuildContext context, Map<String, dynamic> content, String authorName) {
    final theme = Theme.of(context);
    final status = content['status'] as String? ?? 'unknown';
    final hidden = content['hidden'] as bool? ?? false;
    final likes = content['likesCount'] ?? 0;
    final comments = content['commentsCount'] ?? 0;
    final ratings = content['ratingsCount'] ?? 0;
    final avgRating = content['avgRating'] ?? 0.0;

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.info_outline, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'Thông tin',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const Divider(),
            _InfoRow(label: 'Tác giả', value: authorName),
            _InfoRow(
                label: 'Ngày tạo', value: _formatDate(widget.item.createdAt)),
            _InfoRow(label: 'Trạng thái', value: status),
            _InfoRow(label: 'Ẩn', value: hidden ? 'Có' : 'Không'),
            _InfoRow(label: 'Lượt thích', value: '$likes'),
            _InfoRow(label: 'Bình luận', value: '$comments'),
            if (ratings > 0)
              _InfoRow(label: 'Đánh giá', value: '$ratings (⭐ ${avgRating.toStringAsFixed(1)})'),
            _InfoRow(label: 'Báo cáo', value: '${widget.item.reportsCount}'),
          ],
        ),
      ),
    );
  }

  Widget _buildImagesSection(
      BuildContext context, Map<String, dynamic> content, bool isRecipe) {
    final theme = Theme.of(context);

    // Collect all image URLs
    final images = <String>[];

    if (isRecipe) {
      // For recipes: coverUrl/coverURL + photoURLs
      final coverUrl =
          content['coverUrl'] as String? ?? content['coverURL'] as String?;
      if (coverUrl != null && coverUrl.isNotEmpty) {
        images.add(coverUrl);
      }

      final photoURLs = content['photoURLs'] as List?;
      if (photoURLs != null) {
        for (var img in photoURLs) {
          if (img is String && img.isNotEmpty && !images.contains(img)) {
            images.add(img);
          }
        }
      }
    } else if (widget.item.type == AdminContentType.reel) {
      // For reels: thumbnailUrl
      final thumbnailUrl = content['thumbnailUrl'] as String?;
      if (thumbnailUrl != null && thumbnailUrl.isNotEmpty) {
        images.add(thumbnailUrl);
      }
    } else {
      // For posts: photoURLs
      final photoURLs = content['photoURLs'] as List?;
      if (photoURLs != null) {
        for (var img in photoURLs) {
          if (img is String && img.isNotEmpty) {
            images.add(img);
          }
        }
      }
    }

    if (images.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.image_rounded, color: theme.colorScheme.primary),
            const SizedBox(width: 8),
            Text(
              'Hình ảnh (${images.length})',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1,
          ),
          itemCount: images.length,
          itemBuilder: (context, index) {
            return ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(
                images[index],
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  color: theme.colorScheme.surfaceContainerHighest,
                  child: const Icon(Icons.broken_image_outlined),
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildReelContent(BuildContext context, Map<String, dynamic> content) {
    final theme = Theme.of(context);
    final description = content['description'] as String? ?? '';
    final videoUrl = content['videoUrl'] as String? ?? '';
    final duration = content['duration'] ?? 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.movie_filter_outlined, color: theme.colorScheme.primary),
            const SizedBox(width: 8),
            Text(
              'Nội dung Reel',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (videoUrl.isNotEmpty) ...[
                  _InfoRow(label: 'Video URL', value: videoUrl),
                  const SizedBox(height: 8),
                ],
                _InfoRow(label: 'Thời lượng', value: '$duration giây'),
                if (description.isNotEmpty) ...[
                  const Divider(height: 24),
                  Text(
                    'Mô tả:',
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.outline,
                    ),
                  ),
                  const SizedBox(height: 4),
                  SelectableText(
                    description,
                    style: theme.textTheme.bodyMedium,
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildPostContent(BuildContext context, Map<String, dynamic> content) {
    final theme = Theme.of(context);
    final body = content['body'] as String? ?? '';
    
    if (body.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.article_outlined, color: theme.colorScheme.primary),
            const SizedBox(width: 8),
            Text(
              'Nội dung bài viết',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: SelectableText(
              body,
              style: theme.textTheme.bodyMedium,
            ),
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildRecipeDescription(
      BuildContext context, Map<String, dynamic> content) {
    final theme = Theme.of(context);
    final description = content['description'] as String? ?? '';

    if (description.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.description_outlined, color: theme.colorScheme.primary),
            const SizedBox(width: 8),
            Text(
              'Mô tả',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: SelectableText(
              description,
              style: theme.textTheme.bodyMedium,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildIngredientsSection(
      BuildContext context, Map<String, dynamic> content) {
    final theme = Theme.of(context);
    final ingredients = content['ingredients'] as List?;

    if (ingredients == null || ingredients.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.food_bank_rounded, color: theme.colorScheme.primary),
            const SizedBox(width: 8),
            Text(
              'Nguyên liệu',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: ingredients.asMap().entries.map((entry) {
                final index = entry.key;
                final ingredient = entry.value;
                
                if (ingredient is Map) {
                  final name = ingredient['name'] ?? '';
                  final quantity = ingredient['quantity'] ?? '';
                  final unit = ingredient['unit'] ?? '';
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Container(
                          width: 24,
                          height: 24,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primaryContainer,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${index + 1}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            '$name: $quantity $unit',
                            style: theme.textTheme.bodyMedium,
                          ),
                        ),
                      ],
                    ),
                  );
                }
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text('• $ingredient'),
                );
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStepsSection(BuildContext context, Map<String, dynamic> content) {
    final theme = Theme.of(context);
    final steps = content['steps'] as List?;

    if (steps == null || steps.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.format_list_numbered_rounded,
                color: theme.colorScheme.primary),
            const SizedBox(width: 8),
            Text(
              'Các bước thực hiện',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...steps.asMap().entries.map((entry) {
          final index = entry.key;
          final step = entry.value;
          
          String stepText = '';
          if (step is String) {
            stepText = step;
          } else if (step is Map) {
            stepText = step['description'] ?? step['text'] ?? '';
          }

          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color:
                              theme.colorScheme.primary.withValues(alpha: 0.3),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Text(
                      '${index + 1}',
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: SelectableText(
                      stepText,
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildNutritionSection(
      BuildContext context, Map<String, dynamic> content) {
    final theme = Theme.of(context);
    
    // Nutrition values are direct fields in Recipe model
    final calories = content['calories'];
    final protein = content['protein'];
    final carbs = content['carbs'];
    final fat = content['fat'];

    // Check if any nutrition data exists
    if (calories == null && protein == null && carbs == null && fat == null) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.favorite_rounded, color: theme.colorScheme.primary),
            const SizedBox(width: 8),
            Text(
              'Thông tin dinh dưỡng',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Wrap(
              spacing: 16,
              runSpacing: 12,
              children: [
                if (calories != null)
                  _NutritionChip(
                    label: 'Calories',
                    value: '$calories kcal',
                    icon: Icons.local_fire_department_rounded,
                  ),
                if (protein != null)
                  _NutritionChip(
                    label: 'Protein',
                    value: '${protein}g',
                    icon: Icons.egg_rounded,
                  ),
                if (carbs != null)
                  _NutritionChip(
                    label: 'Carbs',
                    value: '${carbs}g',
                    icon: Icons.grain_rounded,
                  ),
                if (fat != null)
                  _NutritionChip(
                    label: 'Fat',
                    value: '${fat}g',
                    icon: Icons.breakfast_dining_rounded,
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTagsSection(BuildContext context, Map<String, dynamic> content) {
    final theme = Theme.of(context);
    final tags = content['tags'] as List?;

    if (tags == null || tags.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.label_rounded, color: theme.colorScheme.primary),
            const SizedBox(width: 8),
            Text(
              'Tags',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: tags.map((tag) {
            return Chip(
              label: Text(tag.toString()),
              backgroundColor: theme.colorScheme.secondaryContainer,
            );
          }).toList(),
        ),
      ],
    );
  }
}

class _DetailData {
  final Map<String, dynamic>? content;
  final String authorName;
  _DetailData({this.content, required this.authorName});
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: RichText(
        text: TextSpan(
          style: Theme.of(context).textTheme.bodyMedium,
          children: [
            TextSpan(
                text: '$label: ',
                style: const TextStyle(fontWeight: FontWeight.bold)),
            TextSpan(text: value),
          ],
        ),
      ),
    );
  }
}

class _NutritionChip extends StatelessWidget {
  const _NutritionChip({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: theme.colorScheme.primary),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                  fontSize: 10,
                ),
              ),
              Text(
                value,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ContentListView extends StatelessWidget {
  const _ContentListView({
    required this.stream,
    required this.emptyText,
    required this.busyIds,
    required this.onView,
    required this.onApprove,
    required this.onHide,
    required this.onDelete,
  });

  final Stream<List<AdminContentItem>> stream;
  final String emptyText;
  final Set<String> busyIds;
  final ValueChanged<AdminContentItem> onView;
  final ValueChanged<AdminContentItem> onApprove;
  final ValueChanged<AdminContentItem> onHide;
  final ValueChanged<AdminContentItem> onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return StreamBuilder<List<AdminContentItem>>(
      stream: stream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Lỗi: ${snapshot.error}'));
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final items = snapshot.data!;
        if (items.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(emptyText, textAlign: TextAlign.center),
            ),
          );
        }

        return ListView.builder(
          itemCount: items.length,
          itemBuilder: (context, index) {
            final item = items[index];
            final isBusy = busyIds.contains('${item.type.name}:${item.id}');
            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: ListTile(
                title: Text(item.title),
                subtitle: Text(
                  '${item.type.name.toUpperCase()} • ${_formatDate(item.createdAt)} • Reports: ${item.reportsCount}',
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: 'Xem chi tiết',
                      icon: const Icon(Icons.visibility_outlined),
                      onPressed: () => onView(item),
                    ),
                    IconButton(
                      tooltip: 'Duyệt',
                      icon: const Icon(Icons.check_circle_outline),
                      onPressed: isBusy ? null : () => onApprove(item),
                      color: theme.colorScheme.primary.withValues(alpha: 0.8),
                    ),
                    IconButton(
                      tooltip: item.hidden ? 'Bỏ ẩn' : 'Ẩn',
                      icon: Icon(item.hidden ? Icons.visibility : Icons.visibility_off),
                      onPressed: isBusy ? null : () => onHide(item),
                      color: theme.colorScheme.outline,
                    ),
                    IconButton(
                      tooltip: 'Xóa',
                      icon: const Icon(Icons.delete_outline),
                      onPressed: isBusy ? null : () => onDelete(item),
                      color: theme.colorScheme.error.withValues(alpha: 0.7),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

String _formatDate(DateTime dateTime) {
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(dateTime.day)}/${two(dateTime.month)}/${dateTime.year} '
      '${two(dateTime.hour)}:${two(dateTime.minute)}';
}
