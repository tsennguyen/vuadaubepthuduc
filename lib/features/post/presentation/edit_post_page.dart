import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../feed/data/post_model.dart';
import '../application/post_form_controller.dart';
import '../../profile/domain/user_ban_guard.dart';

class EditPostPage extends ConsumerStatefulWidget {
  const EditPostPage({super.key, required this.postId});

  final String postId;

  @override
  ConsumerState<EditPostPage> createState() => _EditPostPageState();
}

class _EditPostPageState extends ConsumerState<EditPostPage> {
  final _titleController = TextEditingController();
  final _bodyController = TextEditingController();
  final _tagsController = TextEditingController();
  Post? _post;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final repo = ref.read(postRepositoryProvider);
    final post = await repo.getPostById(widget.postId);
    setState(() {
      _post = post;
      _loading = false;
    });
    if (post != null) {
      _titleController.text = post.title;
      _bodyController.text = post.body;
      _tagsController.text = post.tags.join(', ');
      await ref.read(postFormControllerProvider.notifier).loadFromPost(post);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    _tagsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(postFormControllerProvider);
    final controller = ref.read(postFormControllerProvider.notifier);

    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_post == null) {
      return const Scaffold(body: Center(child: Text('Post not found')));
    }

    Future<void> submit() async {
      final messenger = ScaffoldMessenger.of(context);
      final navigator = Navigator.of(context);
      controller.setTitle(_titleController.text);
      controller.setBody(_bodyController.text);
      controller.setTagsFromString(_tagsController.text);
      try {
        await controller.submitUpdate(widget.postId);
        if (!mounted) return;
        messenger.showSnackBar(const SnackBar(content: Text('Da luu thay doi')));
        navigator.pop(widget.postId);
      } catch (e) {
        if (e is UserBannedException) {
          messenger.showSnackBar(SnackBar(content: Text(e.message)));
          return;
        }
        if (mounted) {
          messenger.showSnackBar(SnackBar(content: Text('Loi: $e')));
        }
      }
    }

    Future<void> softDelete() async {
      final messenger = ScaffoldMessenger.of(context);
      final navigator = Navigator.of(context);
      await controller.softDelete(widget.postId);
      if (!mounted) return;
      messenger.showSnackBar(const SnackBar(content: Text('Đã ẩn bài viết')));
      navigator.pop();
    }

    Future<void> hardDelete() async {
      final messenger = ScaffoldMessenger.of(context);
      final navigator = Navigator.of(context);
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != _post!.authorId) {
        messenger.showSnackBar(
            const SnackBar(content: Text('Chỉ tác giả mới xoá vĩnh viễn')));
        return;
      }
      await controller.hardDelete(widget.postId);
      if (!mounted) return;
      messenger.showSnackBar(const SnackBar(content: Text('Đã xoá vĩnh viễn')));
      navigator.pop();
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Chỉnh sửa bài viết')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(labelText: 'Tiêu đề'),
              onChanged: controller.setTitle,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _bodyController,
              decoration: const InputDecoration(labelText: 'Nội dung'),
              maxLines: 5,
              onChanged: controller.setBody,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _tagsController,
              decoration: const InputDecoration(
                  labelText: 'Tags (phân tách bởi dấu phẩy)'),
              onChanged: controller.setTagsFromString,
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ...state.existingImageUrls.map(
                  (url) => Chip(
                    label: Text(url.split('/').last),
                  ),
                ),
                ...state.newImages.map((file) => Chip(label: Text(file.name))),
              ],
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: state.isSubmitting ? null : controller.pickImages,
              icon: const Icon(Icons.image),
              label: const Text('Chọn thêm ảnh'),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: state.isSubmitting ? null : submit,
                child: state.isSubmitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Lưu thay đổi'),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                  ),
                  onPressed: state.isSubmitting ? null : softDelete,
                  child: const Text('Ẩn bài viết'),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                  ),
                  onPressed: state.isSubmitting
                      ? null
                      : () async {
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text('Xoá vĩnh viễn?'),
                              content: const Text(
                                  'Bạn chắc chắn muốn xoá bài viết này?'),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx, false),
                                  child: const Text('Huỷ'),
                                ),
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx, true),
                                  child: const Text('Xoá'),
                                ),
                              ],
                            ),
                          );
                          if (confirm == true) {
                            await hardDelete();
                          }
                        },
                  child: const Text('Xoá vĩnh viễn'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}



