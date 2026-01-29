import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../app/l10n.dart';
import '../../../app/language_controller.dart';
import 'package:video_player/video_player.dart';
import '../application/reel_form_controller.dart';

class CreateReelPage extends ConsumerStatefulWidget {
  const CreateReelPage({super.key});

  @override
  ConsumerState<CreateReelPage> createState() => _CreateReelPageState();
}

class _CreateReelPageState extends ConsumerState<CreateReelPage> {
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _tagsController;
  VideoPlayerController? _videoPlayerController;

  @override
  void initState() {
    super.initState();
    final state = ref.read(reelFormControllerProvider);
    _titleController = TextEditingController(text: state.title);
    _descriptionController = TextEditingController(text: state.description);
    _tagsController = TextEditingController(text: state.tags.join(', '));
    
    // Auto pick video if none selected
    if (state.videoFile == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(reelFormControllerProvider.notifier).pickVideo();
      });
    } else {
      _initVideoPlayer(state.videoFile!.path);
    }
  }

  void _initVideoPlayer(String path) {
    _videoPlayerController?.dispose();
    if (kIsWeb) {
      _videoPlayerController = VideoPlayerController.networkUrl(Uri.parse(path));
    } else {
      // In a real app we'd use File, but for web testing we use network
      _videoPlayerController = VideoPlayerController.networkUrl(Uri.parse(path));
    }
    _videoPlayerController!.initialize().then((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _videoPlayerController?.dispose();
    _titleController.dispose();
    _descriptionController.dispose();
    _tagsController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final s = S(ref.read(localeProvider));
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(s.pleaseLogin)),
      );
      return;
    }

    final controller = ref.read(reelFormControllerProvider.notifier);
    controller.setTitle(_titleController.text);
    controller.setDescription(_descriptionController.text);
    controller.setTagsFromString(_tagsController.text);

    try {
      final reelId = await controller.submit(uid);
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Reel published successfully!'),
          backgroundColor: Colors.green,
        ),
      );
      context.pop();
    } catch (e) {
      if (!mounted) return;
      String errorMsg = e.toString();
      if (errorMsg.contains('permission-denied')) {
        errorMsg = s.isVi 
          ? 'Lỗi: Chưa có quyền ghi vào bộ sưu tập "reels". Vui lòng kiểm tra cấu hình Firebase Rules.'
          : 'Error: No permission to write to "reels" collection. Please check Firebase Rules.';
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMsg),
          backgroundColor: Theme.of(context).colorScheme.error,
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(reelFormControllerProvider.select((s) => s.videoFile), (previous, next) {
      if (next != null && next.path != previous?.path) {
        _initVideoPlayer(next.path);
      }
    });

    final state = ref.watch(reelFormControllerProvider);
    final controller = ref.read(reelFormControllerProvider.notifier);
    final s = S(ref.watch(localeProvider));
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: Text(s.isVi ? 'Tạo thước phim' : 'Create Reel', 
            style: const TextStyle(fontWeight: FontWeight.bold)),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => context.pop(),
        ),
        actions: [
          if (state.videoFile != null)
            TextButton(
              onPressed: state.isSubmitting ? null : _submit,
              child: state.isSubmitting 
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : Text(s.isVi ? 'Tiếp' : 'Next', style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
        ],
      ),
      body: state.videoFile == null
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.video_library_outlined, size: 80, color: theme.colorScheme.primary.withValues(alpha: 0.5)),
                  const SizedBox(height: 16),
                  Text(s.isVi ? 'Chọn một video để bắt đầu' : 'Select a video to start',
                      style: theme.textTheme.titleMedium),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: controller.pickVideo,
                    icon: const Icon(Icons.add_a_photo),
                    label: Text(s.isVi ? 'Chọn từ thiết bị' : 'Pick from device'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(s.isVi ? '(Không giới hạn thời gian)' : '(No duration limit)',
                      style: theme.textTheme.bodySmall),
                ],
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Video Preview Section
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 120,
                        height: 180,
                        decoration: BoxDecoration(
                          color: Colors.black,
                          borderRadius: BorderRadius.circular(12),
                          image: state.thumbnailFile != null && !kIsWeb
                              ? DecorationImage(
                                  image: FileImage(File(state.thumbnailFile!.path)),
                                  fit: BoxFit.cover,
                                )
                              : null,
                          border: Border.all(color: theme.colorScheme.outline.withValues(alpha: 0.2)),
                        ),
                        child: _videoPlayerController != null && _videoPlayerController!.value.isInitialized
                          ? GestureDetector(
                              onTap: () {
                                setState(() {
                                  _videoPlayerController!.value.isPlaying
                                      ? _videoPlayerController!.pause()
                                      : _videoPlayerController!.play();
                                });
                              },
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: AspectRatio(
                                      aspectRatio: _videoPlayerController!.value.aspectRatio,
                                      child: VideoPlayer(_videoPlayerController!),
                                    ),
                                  ),
                                  if (!_videoPlayerController!.value.isPlaying)
                                    const Icon(Icons.play_circle_fill, color: Colors.white70, size: 50),
                                ],
                              ),
                            )
                          : const Center(child: Icon(Icons.movie_filter, color: Colors.white54, size: 40)),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          children: [
                            TextField(
                              controller: _titleController,
                              decoration: InputDecoration(
                                hintText: s.isVi ? 'Nhập tiêu đề...' : 'Enter title...',
                                border: InputBorder.none,
                              ),
                              maxLines: 4,
                            ),
                            const Divider(),
                            TextField(
                              controller: _tagsController,
                              decoration: InputDecoration(
                                hintText: s.isVi ? 'Thêm hashtag #monngon...' : 'Add hashtags...',
                                border: InputBorder.none,
                                prefixIcon: const Icon(Icons.tag, size: 20),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                  
                  // FB-like Cover selection
                  Text(s.isVi ? 'Ảnh bìa' : 'Cover Image', style: theme.textTheme.titleSmall),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 100,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        // "Select from video" button (mocking FB behavior)
                        _ThumbnailOption(
                          icon: Icons.video_stable,
                          label: s.isVi ? 'Chọn từ video' : 'From video',
                          onTap: controller.pickThumbnail, // For now, reuse thumbnail picker
                          isSelected: state.thumbnailFile == null,
                        ),
                        const SizedBox(width: 12),
                        // Frame snapshots would go here in a real implementation
                        _ThumbnailOption(
                          icon: Icons.add_photo_alternate_outlined,
                          label: s.isVi ? 'Tải ảnh lên' : 'Upload image',
                          onTap: controller.pickThumbnail,
                          isSelected: state.thumbnailFile != null,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  OutlinedButton.icon(
                    onPressed: controller.clearVideo,
                    icon: const Icon(Icons.refresh),
                    label: Text(s.isVi ? 'Chọn video khác' : 'Change video'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 50),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

class _ThumbnailOption extends StatelessWidget {
  const _ThumbnailOption({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.isSelected,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 100,
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? theme.colorScheme.primary : theme.colorScheme.outline.withValues(alpha: 0.1),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: isSelected ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant),
            const SizedBox(height: 4),
            Text(label, style: theme.textTheme.labelSmall),
          ],
        ),
      ),
    );
  }
}
