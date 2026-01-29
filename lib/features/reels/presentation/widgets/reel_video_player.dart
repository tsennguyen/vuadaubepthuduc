import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:video_player/video_player.dart';
import 'package:share_plus/share_plus.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../data/reel_model.dart';
import '../../application/reels_controller.dart';
import '../../application/reel_interaction_controller.dart';
import '../../../profile/application/user_cache_controller.dart';
import '../../../social/application/social_providers.dart';
import '../../../social/domain/friend_repository.dart';
import '../../../../shared/widgets/avatar_with_follow_badge.dart';
import '../../../../core/widgets/app_avatar.dart';
import '../../../../core/utils/time_utils.dart';

class ReelVideoPlayer extends ConsumerStatefulWidget {
  const ReelVideoPlayer({
    super.key,
    required this.reel,
    required this.isActive,
  });

  final Reel reel;
  final bool isActive;

  @override
  ConsumerState<ReelVideoPlayer> createState() => _ReelVideoPlayerState();
}

class _ReelVideoPlayerState extends ConsumerState<ReelVideoPlayer> {
  VideoPlayerController? _controller;
  bool _isInitialized = false;
  bool _hasTrackedView = false;
  bool _showControls = false;

  @override
  void initState() {
    super.initState();
    _initializeVideo();
  }

  @override
  void didUpdateWidget(ReelVideoPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.reel.id != widget.reel.id) {
      _disposeController();
      _hasTrackedView = false;
      _initializeVideo();
    }
    if (oldWidget.isActive != widget.isActive) {
      if (widget.isActive) {
        _controller?.play();
        _trackView();
      } else {
        _controller?.pause();
      }
    }
  }

  Future<void> _initializeVideo() async {
    if (widget.reel.videoUrl.isEmpty) return;

    _controller = VideoPlayerController.networkUrl(
      Uri.parse(widget.reel.videoUrl),
      // Optimization for web to start buffering faster
      videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
    );

    try {
      // Start initialization
      final initFuture = _controller!.initialize();
      
      // If active, we wait for it to be ready to play
      if (widget.isActive) {
        await initFuture;
        _controller!.setLooping(true);
        await _controller!.play();
        _trackView();
      } else {
        // If not active, we still initialize in background but don't wait for it
        // and don't play yet. This allows pre-buffering.
        initFuture.then((_) {
          if (mounted) {
            _controller?.setLooping(true);
            setState(() {
              _isInitialized = true;
            });
          }
        });
        return; 
      }

      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
      }
    } catch (e) {
      debugPrint('Error initializing video: $e');
    }
  }

  void _trackView() {
    if (!_hasTrackedView) {
      _hasTrackedView = true;
      ref
          .read(reelsControllerProvider.notifier)
          .incrementViewCount(widget.reel.id);
    }
  }

  void _disposeController() {
    _controller?.dispose();
    _controller = null;
    _isInitialized = false;
  }

  @override
  void dispose() {
    _disposeController();
    super.dispose();
  }

  void _togglePlayPause() {
    if (_controller == null) return;
    setState(() {
      if (_controller!.value.isPlaying) {
        _controller!.pause();
      } else {
        _controller!.play();
      }
      _showControls = true;
    });
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) {
        setState(() {
          _showControls = false;
        });
      }
    });
  }

  Future<void> _handleLike() async {
    await ref
        .read(reelInteractionControllerProvider.notifier)
        .toggleLike(widget.reel.id);
  }

  Future<void> _handleSave() async {
    await ref
        .read(reelInteractionControllerProvider.notifier)
        .toggleSave(widget.reel.id);
  }

  Future<void> _handleShare() async {
    await ref
        .read(reelsControllerProvider.notifier)
        .incrementShareCount(widget.reel.id);
    
    // Share the reel
    await Share.share(
      'Check out this Reel: ${widget.reel.title}\n\n${widget.reel.description}',
      subject: widget.reel.title,
    );
  }

  void _showComments() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _CommentsSheet(reelId: widget.reel.id),
    );
  }

  @override
  Widget build(BuildContext context) {
    final userCache = ref.watch(userCacheProvider);
    final author = userCache[widget.reel.authorId];
    
    // Preload author if not in cache
    if (author == null) {
      Future.microtask(() {
        ref.read(userCacheProvider.notifier).preload({widget.reel.authorId});
      });
    }

    final hasLikedAsync = ref.watch(hasLikedReelProvider(widget.reel.id));
    final hasSavedAsync = ref.watch(hasSavedReelProvider(widget.reel.id));

    return GestureDetector(
      onTap: _togglePlayPause,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Video player with smooth transition
          Positioned.fill(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 500),
              child: (_isInitialized && _controller != null)
                  ? Center(
                      key: ValueKey('video_${widget.reel.id}'),
                      child: AspectRatio(
                        aspectRatio: _controller!.value.aspectRatio,
                        child: VideoPlayer(_controller!),
                      ),
                    )
                  : Container(
                      key: ValueKey('placeholder_${widget.reel.id}'),
                      color: Colors.black,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          if (widget.reel.thumbnailUrl.isNotEmpty)
                            Image.network(
                              widget.reel.thumbnailUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) =>
                                  _buildErrorPlaceholder(),
                            )
                          else
                            _buildErrorPlaceholder(),
                          // Only show spinner if active and not initialized
                          if (widget.isActive && !_isInitialized)
                            const Center(
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            ),
                        ],
                      ),
                    ),
            ),
          ),

          // Gradient overlay
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              height: 300,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.8),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          // Play/Pause icon
          if (_showControls)
            Center(
              child: Icon(
                _controller?.value.isPlaying ?? false
                    ? Icons.pause_circle_outline
                    : Icons.play_circle_outline,
                size: 80,
                color: Colors.white.withValues(alpha: 0.8),
              ),
            ),

          // Right side actions
          Positioned(
            right: 12,
            bottom: 100,
            child: Column(
              children: [
                // Author avatar with follow button
                if (author != null) ...[
                  AvatarWithFollowBadge(
                    url: author.photoUrl ?? '',
                    displayName: author.displayName ?? '',
                    targetUid: widget.reel.authorId,
                    size: 48,
                    onTap: () {
                      context.push('/profile/${widget.reel.authorId}');
                    },
                  ),
                  const SizedBox(height: 24),
                ] else
                  const SizedBox(height: 72),

                // Like button
                hasLikedAsync.when(
                  data: (hasLiked) => _ActionButton(
                    icon: hasLiked ? Icons.favorite : Icons.favorite_border,
                    label: _formatCount(widget.reel.likesCount),
                    onTap: _handleLike,
                    color: hasLiked ? Colors.red : Colors.white,
                  ),
                  loading: () => _ActionButton(
                    icon: Icons.favorite_border,
                    label: _formatCount(widget.reel.likesCount),
                    onTap: _handleLike,
                  ),
                  error: (_, __) => _ActionButton(
                    icon: Icons.favorite_border,
                    label: _formatCount(widget.reel.likesCount),
                    onTap: _handleLike,
                  ),
                ),
                const SizedBox(height: 20),

                // Comment button
                _ActionButton(
                  icon: Icons.comment_outlined,
                  label: _formatCount(widget.reel.commentsCount),
                  onTap: _showComments,
                ),
                const SizedBox(height: 20),

                // Share button
                _ActionButton(
                  icon: Icons.share_outlined,
                  label: _formatCount(widget.reel.sharesCount),
                  onTap: _handleShare,
                ),
                const SizedBox(height: 20),

                // Save button
                hasSavedAsync.when(
                  data: (hasSaved) => _ActionButton(
                    icon: hasSaved ? Icons.bookmark : Icons.bookmark_border,
                    label: '',
                    onTap: _handleSave,
                    color: hasSaved ? Colors.amber : Colors.white,
                  ),
                  loading: () => _ActionButton(
                    icon: Icons.bookmark_border,
                    label: '',
                    onTap: _handleSave,
                  ),
                  error: (_, __) => _ActionButton(
                    icon: Icons.bookmark_border,
                    label: '',
                    onTap: _handleSave,
                  ),
                ),
              ],
            ),
          ),

          // Bottom info
          Positioned(
            left: 16,
            right: 80,
            bottom: 100,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Author name
                if (author != null)
                  Text(
                    '@${author.displayName}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                const SizedBox(height: 8),

                // Title
                if (widget.reel.title.isNotEmpty)
                  Text(
                    widget.reel.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                const SizedBox(height: 4),

                // Description
                if (widget.reel.description.isNotEmpty)
                  Text(
                    widget.reel.description,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.9),
                      fontSize: 14,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                const SizedBox(height: 8),

                // Tags
                if (widget.reel.tags.isNotEmpty)
                  Wrap(
                    spacing: 8,
                    children: widget.reel.tags.take(3).map((tag) {
                      return Text(
                        '#$tag',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.8),
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      );
                    }).toList(),
                  ),
              ],
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

  Widget _buildErrorPlaceholder() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.grey[850]!, Colors.black],
        ),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.movie_creation_outlined,
                color: Colors.white24, size: 80),
            const SizedBox(height: 16),
            if (widget.reel.title.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: Text(
                  widget.reel.title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white24, fontSize: 16),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color = Colors.white,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Icon(
            icon,
            color: color,
            size: 32,
          ),
          if (label.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }
}


class _CommentsSheet extends ConsumerStatefulWidget {
  const _CommentsSheet({required this.reelId});

  final String reelId;

  @override
  ConsumerState<_CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends ConsumerState<_CommentsSheet> {
  final TextEditingController _commentController = TextEditingController();
  String? _replyToId;
  String? _replyToName;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  void _startReply(String id, String name) {
    setState(() {
      _replyToId = id;
      _replyToName = name;
    });
  }

  void _cancelReply() {
    setState(() {
      _replyToId = null;
      _replyToName = null;
    });
  }

  Future<void> _submitComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty) return;

    await ref
        .read(reelInteractionControllerProvider.notifier)
        .addComment(
          widget.reelId,
          text,
          replyTo: _replyToId,
          replyToName: _replyToName,
        );
    
    _commentController.clear();
    _cancelReply();
  }

  Future<void> _handleDeleteComment(String commentId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xóa bình luận'),
        content: const Text('Bạn có chắc chắn muốn xóa bình luận này?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await ref
          .read(reelInteractionControllerProvider.notifier)
          .deleteComment(widget.reelId, commentId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final commentsAsync = ref.watch(reelCommentsProvider(widget.reelId));

    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.symmetric(vertical: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Title
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Text(
                  'Comments',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // Comments list
          Expanded(
            child: commentsAsync.when(
              data: (comments) {
                if (comments.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.comment_outlined,
                          size: 64,
                          color: Theme.of(context)
                              .colorScheme
                              .outline
                              .withValues(alpha: 0.5),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No comments yet',
                          style: TextStyle(
                            color: Theme.of(context)
                                .colorScheme
                                .outline
                                .withValues(alpha: 0.7),
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                final rootComments = comments.where((c) => c['replyTo'] == null).toList();
                final userCache = ref.watch(userCacheProvider);

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: rootComments.length,
                  itemBuilder: (context, index) {
                    final comment = rootComments[index];
                    final commentId = comment['id'] as String;
                    final replies = comments.where((c) => c['replyTo'] == commentId).toList();
                    
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _CommentItem(
                          comment: comment,
                          onReply: () => _startReply(
                            commentId,
                            userCache[comment['userId']]?.displayName ?? 'User',
                          ),
                          onDelete: () => _handleDeleteComment(commentId),
                        ),
                        ...replies.map((reply) => Padding(
                          padding: const EdgeInsets.only(left: 44),
                          child: _CommentItem(
                            comment: reply,
                            onReply: () => _startReply(
                              commentId, // Always reply to root for 1-level nesting
                              userCache[reply['userId']]?.displayName ?? 'User',
                            ),
                            onDelete: () => _handleDeleteComment(reply['id'] as String),
                          ),
                        )),
                      ],
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Center(child: Text('Error: $error')),
            ),
          ),

          // Reply indicator
          if (_replyToId != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3),
              child: Row(
                children: [
                  Text(
                    'Replying to $_replyToName',
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: _cancelReply,
                    child: Icon(
                      Icons.close,
                      size: 16,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ],
              ),
            ),

          // Comment input
          Container(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 8,
              bottom: MediaQuery.of(context).viewInsets.bottom + 8,
            ),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              border: Border(
                top: BorderSide(
                  color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
                ),
              ),
            ),
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _commentController,
                      autofocus: _replyToId != null,
                      decoration: InputDecoration(
                        hintText: _replyToId != null ? 'Reply...' : 'Add a comment...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: Theme.of(context)
                            .colorScheme
                            .surfaceContainerHighest,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                      ),
                      maxLines: null,
                      textCapitalization: TextCapitalization.sentences,
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: _submitComment,
                    icon: const Icon(Icons.send),
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CommentItem extends ConsumerWidget {
  const _CommentItem({
    required this.comment,
    required this.onReply,
    required this.onDelete,
  });

  final Map<String, dynamic> comment;
  final VoidCallback onReply;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    final userId = comment['userId'] as String;
    final text = comment['text'] as String;
    final createdAt = comment['createdAt'] as Timestamp?;
    
    final userCache = ref.watch(userCacheProvider);
    final user = userCache[userId];

    if (user == null) {
      Future.microtask(() {
        ref.read(userCacheProvider.notifier).preload({userId});
      });
      return const SizedBox(height: 48);
    }

    final timeAgo = TimeUtils.formatTimeAgo(createdAt?.toDate(), context, compact: true);

    return InkWell(
      onLongPress: currentUserId == userId
          ? () {
              showModalBottomSheet(
                context: context,
                builder: (context) => SafeArea(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ListTile(
                        leading: const Icon(Icons.delete_outline, color: Colors.red),
                        title: const Text(
                          'Xóa bình luận',
                          style: TextStyle(color: Colors.red),
                        ),
                        onTap: () {
                          Navigator.pop(context);
                          onDelete();
                        },
                      ),
                    ],
                  ),
                ),
              );
            }
          : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppAvatar(
              url: user.photoUrl ?? '',
              fallbackText: user.displayName,
              size: 32,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        user.displayName ?? '',
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        timeAgo,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    text,
                    style: const TextStyle(fontSize: 14),
                  ),
                  const SizedBox(height: 4),
                  GestureDetector(
                    onTap: onReply,
                    child: Text(
                      'Phản hồi',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
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
