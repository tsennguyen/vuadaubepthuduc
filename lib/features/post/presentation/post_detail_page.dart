import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/widgets/tag_chip.dart';
import '../../feed/data/post_model.dart';
import '../../profile/application/user_cache_controller.dart';
import '../../profile/domain/user_summary.dart';
import '../../report/presentation/report_dialog.dart';
import '../application/post_interaction_controller.dart';
import '../data/post_interaction_repository.dart';
import '../../../shared/widgets/modern_ui_components.dart';
import 'widgets/comments_list_widget.dart';

class PostDetailPage extends ConsumerStatefulWidget {
  const PostDetailPage({super.key, required this.postId});

  final String postId;

  @override
  ConsumerState<PostDetailPage> createState() => _PostDetailPageState();
}

class _PostDetailPageState extends ConsumerState<PostDetailPage> {
  final _commentController = TextEditingController();
  final _commentsListKey = GlobalKey<CommentsListWidgetState>();
  XFile? _selectedImage;
  bool _isUploadingImage = false;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 70,
    );
    if (image != null) {
      setState(() => _selectedImage = image);
    }
  }

  void _showEmojiPicker() {
    final emojis = ['❤️', '🙌', '🔥', '👏', '😍', '🍛', '👨‍🍳', '✨'];
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Biểu cảm nhanh',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: emojis.map((e) => GestureDetector(
                onTap: () {
                  _commentController.text += e;
                  Navigator.pop(context);
                },
                child: Text(e, style: const TextStyle(fontSize: 32)),
              )).toList(),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Future<String?> _uploadCommentImage(String postId) async {
    if (_selectedImage == null) return null;
    setState(() => _isUploadingImage = true);
    try {
      final fileName = 'comment_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final ref = FirebaseStorage.instance
          .ref()
          .child('posts')
          .child(postId)
          .child(fileName); // Changed path to match working service
      
      final bytes = await _selectedImage!.readAsBytes();
      await ref.putData(
        bytes,
        SettableMetadata(contentType: 'image/jpeg'),
      );
      
      return await ref.getDownloadURL();
    } catch (e) {
      debugPrint('Error uploading comment image: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi tải ảnh: $e')),
        );
      }
      return null;
    } finally {
      setState(() => _isUploadingImage = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('posts')
          .doc(widget.postId)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final doc = snapshot.data!;
        if (!doc.exists) {
          return const Scaffold(body: Center(child: Text('Post not found')));
        }
        final post = Post.fromDoc(doc);
        ref.read(userCacheProvider.notifier).preload({post.authorId});
        final author = ref.watch(userCacheProvider)[post.authorId];
        final authorName = _displayName(author, post.authorId);
        final avatarUrl = author?.photoUrl ?? '';
        final params = PostInteractionParams(
          type: ContentType.post,
          contentId: post.id,
          initialLikesCount: post.likesCount,
          titleForShare: post.title,
          contentAuthorId: post.authorId,
        );
        final state = ref.watch(postInteractionControllerProvider(params));
        final controller =
            ref.read(postInteractionControllerProvider(params).notifier);

        return Scaffold(
          appBar: AppBar(
            title: const Text('Bài viết', style: TextStyle(fontWeight: FontWeight.bold)),
            flexibleSpace: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Theme.of(context).colorScheme.surface,
                    Theme.of(context).colorScheme.surfaceContainer,
                  ],
                ),
              ),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.flag_outlined),
                tooltip: 'Báo cáo',
                onPressed: () {
                  final user = FirebaseAuth.instance.currentUser;
                  if (user == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Vui lòng đăng nhập để báo cáo.'),
                      ),
                    );
                    return;
                  }

                  showDialog(
                    context: context,
                    builder: (_) => ReportDialog(
                      targetType: 'post',
                      targetId: post.id,
                    ),
                  );
                },
              ),
            ],
          ),
          body: Column(
            children: [
              Expanded(
                child: ListView(
                  padding: EdgeInsets.zero,
                  children: [
                    _PostCard(
                      post: post,
                      state: state,
                      authorName: authorName,
                      authorAvatarUrl: avatarUrl,
                      onLike: controller.toggleLike,
                    ),
                    const SizedBox(height: 4),

                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                      child: Text(
                        'Bình luận',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    // Use separate widget to prevent future recreation on rebuild
                    CommentsListWidget(
                      key: _commentsListKey,
                      postId: widget.postId,
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
              _CommentInput(
                controller: _commentController,
                isSending: state.isSendingComment || _isUploadingImage,
                selectedImage: _selectedImage,
                onPickImage: _pickImage,
                onRemoveImage: () => setState(() => _selectedImage = null),
                onShowEmoji: _showEmojiPicker,
                onSend: () async {
                  try {
                    final text = _commentController.text.trim();
                    if (text.isEmpty && _selectedImage == null) return;
                    
                    String? imageUrl;
                    if (_selectedImage != null) {
                      imageUrl = await _uploadCommentImage(widget.postId);
                      if (imageUrl == null) return; // Error already shown in _uploadCommentImage
                    }

                    // Check if replying
                    final commentsState = _commentsListKey.currentState;
                    if (commentsState != null && commentsState.replyingToId != null) {
                      // Send as reply
                      await commentsState.sendReplyFromParent(text, imageUrl: imageUrl);
                    } else {
                      // Send as normal comment
                      await controller.sendComment(text, imageUrl: imageUrl);
                    }
                    
                    if (mounted) {
                      _commentController.clear();
                      setState(() => _selectedImage = null);
                      // Provide visual feedback
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Đã gửi bình luận'), duration: Duration(seconds: 1)),
                      );
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Lỗi khi gửi bình luận: $e')),
                      );
                    }
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

String _displayName(UserSummary? user, String authorId) {
  if (user != null) {
    final name = user.displayName?.trim();
    if (name != null && name.isNotEmpty) return name;
    if (user.email != null && user.email!.isNotEmpty) {
      return user.email!.split('@').first;
    }
  }
  if (authorId.isNotEmpty) {
    final short = authorId.length > 6 ? authorId.substring(0, 6) : authorId;
    return 'User $short';
  }
  return 'Người dùng';
}

class _PostCard extends StatelessWidget {
  const _PostCard({
    required this.post,
    required this.state,
    required this.authorName,
    required this.authorAvatarUrl,
    required this.onLike,
  });

  final Post post;
  final PostInteractionState state;
  final String authorName;
  final String authorAvatarUrl;
  final VoidCallback onLike;

  String _formatTime(DateTime? time) {
    if (time == null) return '';
    final now = DateTime.now();
    final difference = now.difference(time);
    if (difference.inMinutes < 60) return '${difference.inMinutes} phút trước';
    if (difference.inHours < 24) return '${difference.inHours} giờ trước';
    return '${time.day}/${time.month}/${time.year}';
  }

  @override
  Widget build(BuildContext context) {
    final hasImage = post.photoURLs.isNotEmpty;

    return GlassCard(
      margin: const EdgeInsets.all(16),
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                GradientAvatar(
                  imageUrl: authorAvatarUrl,
                  radius: 24, // size 48 total
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        authorName,
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _formatTime(post.createdAt),
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                Consumer(
                  builder: (context, ref, _) {
                    final currentUid = FirebaseAuth.instance.currentUser?.uid;
                    final isOwner = currentUid == post.authorId;

                    if (!isOwner) {
                      return const SizedBox.shrink();
                    }

                    return PopupMenuButton<String>(
                      icon: const Icon(Icons.more_horiz),
                      onSelected: (value) async {
                        if (value == 'edit') {
                          context.push('/post/${post.id}/edit');
                        } else if (value == 'delete') {
                          final confirmed = await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text('Xóa bài viết'),
                              content: const Text(
                                'Bạn có chắc chắn muốn xóa bài viết này không?',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx, false),
                                  child: const Text('Hủy'),
                                ),
                                FilledButton(
                                  onPressed: () => Navigator.pop(ctx, true),
                                  style: FilledButton.styleFrom(
                                    backgroundColor: Theme.of(context).colorScheme.error,
                                  ),
                                  child: const Text('Xóa'),
                                ),
                              ],
                            ),
                          );

                          if (confirmed == true && context.mounted) {
                            try {
                              await FirebaseFirestore.instance
                                  .collection('posts')
                                  .doc(post.id)
                                  .delete();
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Đã xóa bài viết')),
                                );
                                Navigator.of(context).pop();
                              }
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Không thể xóa: $e')),
                                );
                              }
                            }
                          }
                        }
                      },
                      itemBuilder: (context) => [
                        if (isOwner) ...[
                          const PopupMenuItem<String>(
                            value: 'edit',
                            child: Row(
                              children: [
                                Icon(Icons.edit_outlined, size: 20),
                                SizedBox(width: 12),
                                Text('Chỉnh sửa'),
                              ],
                            ),
                          ),
                          const PopupMenuItem<String>(
                            value: 'delete',
                            child: Row(
                              children: [
                                Icon(Icons.delete_outline, size: 20, color: Colors.red),
                                SizedBox(width: 12),
                                Text('Xóa', style: TextStyle(color: Colors.red)),
                              ],
                            ),
                          ),
                        ],
                      ],
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              post.title,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(post.body, style: Theme.of(context).textTheme.bodyLarge),
            if (hasImage) ...[
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: Image.network(
                    post.photoURLs.first,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ],
            if (post.tags.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children:
                    post.tags.map((t) => TagChip(label: '#$t')).toList(),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                IconButton(
                  icon: Icon(
                    state.isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                    color: state.isLiked ? Colors.red : null,
                  ),
                  onPressed: onLike,
                ),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  transitionBuilder: (Widget child, Animation<double> animation) {
                    return ScaleTransition(
                      scale: animation,
                      child: FadeTransition(
                        opacity: animation,
                        child: child,
                      ),
                    );
                  },
                  child: Text(
                    '${state.likesCount}',
                    key: ValueKey<int>(state.likesCount),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 16),
                const Icon(Icons.chat_bubble_outline_rounded, size: 20),
                const SizedBox(width: 4),
                Text(
                    '${state.comments.asData?.value.length ?? post.commentsCount}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CommentInput extends StatelessWidget {
  const _CommentInput({
    required this.controller,
    required this.isSending,
    required this.onSend,
    required this.onPickImage,
    required this.onRemoveImage,
    required this.onShowEmoji,
    this.selectedImage,
  });

  final TextEditingController controller;
  final bool isSending;
  final VoidCallback onSend;
  final VoidCallback onPickImage;
  final VoidCallback onRemoveImage;
  final VoidCallback onShowEmoji;
  final XFile? selectedImage;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (selectedImage != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: Theme.of(context).colorScheme.surface,
              child: Row(
                children: [
                  Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: kIsWeb
                            ? Image.network(
                                selectedImage!.path,
                                width: 80,
                                height: 80,
                                fit: BoxFit.cover,
                              )
                            : Image.file(
                                File(selectedImage!.path),
                                width: 80,
                                height: 80,
                                fit: BoxFit.cover,
                              ),
                      ),
                      Positioned(
                        top: 2,
                        right: 2,
                        child: GestureDetector(
                          onTap: onRemoveImage,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: Colors.black54,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.close, size: 14, color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          Container(
            padding: const EdgeInsets.fromLTRB(8, 12, 16, 16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: Row(
              children: [
                IconButton(
                  icon: Icon(Icons.add_photo_alternate_outlined, color: Theme.of(context).colorScheme.primary),
                  onPressed: onPickImage,
                ),
                IconButton(
                  icon: Icon(Icons.emoji_emotions_outlined, color: Theme.of(context).colorScheme.primary),
                  onPressed: onShowEmoji,
                ),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: TextField(
                      controller: controller,
                      decoration: const InputDecoration(
                        hintText: 'Thêm bình luận...',
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                      ),
                      minLines: 1,
                      maxLines: 4,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Theme.of(context).colorScheme.primary,
                        Theme.of(context).colorScheme.tertiary,
                      ],
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    onPressed: isSending ? null : onSend,
                    icon: isSending
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
