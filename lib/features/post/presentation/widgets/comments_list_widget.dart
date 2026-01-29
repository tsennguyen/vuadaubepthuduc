import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../shared/widgets/modern_ui_components.dart';
import '../../../notifications/application/notification_service.dart';
import '../../../profile/application/user_cache_controller.dart';

enum CommentSortType {
  newest,
  oldest,
  mostLikes,
}

// Separate StatefulWidget to cache future and prevent rebuild issues
class CommentsListWidget extends ConsumerStatefulWidget {
  const CommentsListWidget({super.key, required this.postId});
  
  final String postId;
  
  @override
  ConsumerState<CommentsListWidget> createState() => CommentsListWidgetState();
}

class CommentsListWidgetState extends ConsumerState<CommentsListWidget> {
  CommentSortType _sortType = CommentSortType.newest;
  String? _replyingToId;
  String? _replyingToName;
  final _replyController = TextEditingController();
  final _notificationService = NotificationService();
  Map<String, String?>? _postInfo;

  // Public getters for parent page to access
  String? get replyingToId => _replyingToId;
  String? get replyingToName => _replyingToName;

  // Method to cancel reply from outside
  void cancelReply() {
    setState(() {
      _replyingToId = null;
      _replyingToName = null;
    });
  }

  // Method to send reply (called from parent's input)
  Future<void> sendReplyFromParent(String text, {String? imageUrl}) async {
    if (_replyingToId == null) return;
    await _sendReply(text, imageUrl: imageUrl);
  }

  Future<Map<String, String?>> _loadPostInfo() async {
    if (_postInfo != null) return _postInfo!;
    _postInfo = await _notificationService.getContentInfo(
      contentId: widget.postId,
      contentType: 'post',
    );
    return _postInfo!;
  }

  @override
  void dispose() {
    _replyController.dispose();
    super.dispose();
  }

  Future<void> _toggleLike(String commentId, bool isLiked) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Vui lòng đăng nhập')),
        );
      }
      return;
    }

    try {
      final commentRef = FirebaseFirestore.instance
          .collection('posts')
          .doc(widget.postId)
          .collection('comments')
          .doc(commentId);

      if (isLiked) {
        await commentRef.update({
          'likes': FieldValue.arrayRemove([user.uid]),
          'likesCount': FieldValue.increment(-1),
        });
      } else {
        await commentRef.update({
          'likes': FieldValue.arrayUnion([user.uid]),
          'likesCount': FieldValue.increment(1),
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi: $e')),
        );
      }
    }
  }

  Future<void> _sendReply(String text, {String? imageUrl}) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final replyText = text.trim();
    if (replyText.isEmpty && imageUrl == null) return;

    String? replyToAuthorId;
    if (_replyingToId != null) {
      try {
        final replyDoc = await FirebaseFirestore.instance
            .collection('posts')
            .doc(widget.postId)
            .collection('comments')
            .doc(_replyingToId)
            .get();
        replyToAuthorId = replyDoc.data()?['authorId'] as String?;
      } catch (_) {
        replyToAuthorId = null;
      }
    }

    try {
      await FirebaseFirestore.instance
          .collection('posts')
          .doc(widget.postId)
          .collection('comments')
          .add({
        'content': replyText,
        'imageUrl': imageUrl,
        'authorId': user.uid,
        'createdAt': FieldValue.serverTimestamp(),
        'likes': [],
        'likesCount': 0,
        'replyTo': _replyingToId,
        'replyToName': _replyingToName,
      });

      final info = await _loadPostInfo();
      final postAuthorId = info['authorId'];
      final title = info['title'];

      if (postAuthorId != null && postAuthorId.isNotEmpty) {
        _notificationService
            .notifyComment(
              contentId: widget.postId,
              contentType: 'post',
              contentAuthorId: postAuthorId,
              commentText: replyText,
              contentTitle: title,
            )
            .catchError((_) {});
      }

      if (replyToAuthorId != null &&
          replyToAuthorId.isNotEmpty &&
          replyToAuthorId != postAuthorId) {
        _notificationService
            .notifyCommentReply(
              contentId: widget.postId,
              contentType: 'post',
              commentAuthorId: replyToAuthorId,
              contentTitle: title,
              replyText: replyText,
            )
            .catchError((_) {});
      }

      setState(() {
        _replyingToId = null;
        _replyingToName = null;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Không thể gửi: $e')),
        );
      }
      rethrow;
    }
  }

  List<QueryDocumentSnapshot<Map<String, dynamic>>> _sortComments(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> comments,
  ) {
    final sorted = List<QueryDocumentSnapshot<Map<String, dynamic>>>.from(comments);
    
    try {
      switch (_sortType) {
        case CommentSortType.newest:
          sorted.sort((a, b) {
            final aTime = (a.data()['createdAt'] as Timestamp?)?.toDate();
            final bTime = (b.data()['createdAt'] as Timestamp?)?.toDate();
            // Handle null - put null timestamps at end
            if (aTime == null && bTime == null) return 0;
            if (aTime == null) return 1;
            if (bTime == null) return -1;
            return bTime.compareTo(aTime); // Descending
          });
          break;
        case CommentSortType.oldest:
          sorted.sort((a, b) {
            final aTime = (a.data()['createdAt'] as Timestamp?)?.toDate();
            final bTime = (b.data()['createdAt'] as Timestamp?)?.toDate();
            // Handle null - put null timestamps at end  
            if (aTime == null && bTime == null) return 0;
            if (aTime == null) return 1;
            if (bTime == null) return -1;
            return aTime.compareTo(bTime); // Ascending
          });
          break;
        case CommentSortType.mostLikes:
          sorted.sort((a, b) {
            final aLikes = a.data()['likesCount'] as int? ?? 0;
            final bLikes = b.data()['likesCount'] as int? ?? 0;
            return bLikes.compareTo(aLikes); // Descending
          });
          break;
      }
    } catch (e) {
      debugPrint('Error sorting comments: $e');
    }
    
    return sorted;
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('posts')
          .doc(widget.postId)
          .collection('comments')
          .snapshots(),
      builder: (context, snapshot) {
        // Check hasData FIRST before connectionState
        // Stream can be in waiting state but still have data
        if (snapshot.hasError) {
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                const Icon(Icons.error, color: Colors.red),
                const SizedBox(height: 8),
                Text(
                  'Lỗi: ${snapshot.error}',
                  style: const TextStyle(color: Colors.red),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }

        // Show loading ONLY if no data yet
        if (!snapshot.hasData) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        
        var comments = snapshot.data?.docs ?? [];
        
        if (comments.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'Chưa có bình luận. Hãy là người đầu tiên!',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
          );
        }

        // Sort comments
        comments = _sortComments(comments);
        final rootComments =
            comments.where((c) => c.data()['replyTo'] == null).toList();

        // Preload all comment authors (after frame to avoid rebuild loop)
        final authorIds = comments
            .map((doc) => doc.data()['authorId'] as String?)
            .where((id) => id != null && id.isNotEmpty)
            .toSet();
        
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            ref.read(userCacheProvider.notifier).preload(authorIds.cast<String>());
          }
        });
        

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Sort filter
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  const Text(
                    'Sắp xếp:',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _SortChip(
                            label: 'Mới nhất',
                            icon: Icons.sort,
                            isSelected: _sortType == CommentSortType.newest,
                            onTap: () => setState(() => _sortType = CommentSortType.newest),
                          ),
                          const SizedBox(width: 8),
                          _SortChip(
                            label: 'Cũ nhất',
                            icon: Icons.history,
                            isSelected: _sortType == CommentSortType.oldest,
                            onTap: () => setState(() => _sortType = CommentSortType.oldest),
                          ),
                          const SizedBox(width: 8),
                          _SortChip(
                            label: 'Nhiều like',
                            icon: Icons.favorite,
                            isSelected: _sortType == CommentSortType.mostLikes,
                            onTap: () => setState(() => _sortType = CommentSortType.mostLikes),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Reply indicator (prominent green banner)
            if (_replyingToId != null)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFD4F4DD), // Light green like image
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.reply,
                      size: 20,
                      color: Color(0xFF2E7D32), // Dark green
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Dang tra loi $_replyingToName',
                        style: const TextStyle(
                          color: Color(0xFF2E7D32), // Dark green
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 20),
                      color: const Color(0xFF2E7D32),
                      onPressed: () => setState(() {
                        _replyingToId = null;
                        _replyingToName = null;
                      }),
                      padding: EdgeInsets.zero,
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ),
              ),

            // Separate root comments and replies
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: rootComments.length,
              itemBuilder: (context, rootIndex) {
                final rootDoc = rootComments[rootIndex];

                // Get replies for this root comment
                final replies = comments
                    .where((c) => c.data()['replyTo'] == rootDoc.id)
                    .toList();

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Root comment
                    _buildCommentCard(rootDoc, false),

                    // Replies (indented)
                    ...replies.map(
                      (replyDoc) => _buildCommentCard(replyDoc, true),
                    ),
                  ],
                );
              },
            ),
          ],
        );
      },
    );
  }
  
  Widget _buildCommentCard(QueryDocumentSnapshot<Map<String, dynamic>> doc, bool isReply) {
    final data = doc.data();
    final content = data['content'] as String? ?? '';
    final authorId = data['authorId'] as String? ?? '';
    final timestamp = data['createdAt'] as Timestamp?;
    final isEdited = data['isEdited'] as bool? ?? false;
    
    // Safe parsing for likes (handle old comments)
    List<String> likes = [];
    try {
      final likesData = data['likes'];
      if (likesData is List) {
        likes = List<String>.from(likesData);
      }
    } catch (e) {
      debugPrint('Error parsing likes: $e');
    }
    
    final likesCount = data['likesCount'] as int? ?? 0;
    final replyToName = data['replyToName'] as String?;
    final imageUrl = data['imageUrl'] as String?;
    
    final userCache = ref.watch(userCacheProvider);
    final author = userCache[authorId];
    final authorName = author?.displayName ?? 
        (author?.email?.split('@').first) ?? 
        (authorId.isNotEmpty ? 'User ${authorId.substring(0, 6)}' : 'Người dùng');
    final avatarUrl = author?.photoUrl ?? '';
    
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    final isLiked = currentUserId != null && likes.contains(currentUserId);
    final isOwner = currentUserId != null && currentUserId == authorId;
    
    return _CommentCard(
      content: content,
      authorName: authorName,
      avatarUrl: avatarUrl,
      timestamp: timestamp?.toDate(),
      isEdited: isEdited,
      likesCount: likesCount,
      isLiked: isLiked,
      imageUrl: imageUrl,
      replyTo: isReply ? replyToName : null, // Only show tag for actual replies
      isIndented: isReply,
      isOwner: isOwner,
      onLike: () => _toggleLike(doc.id, isLiked),
      onReply: () {
        // Always set to THIS comment's info
        setState(() {
          _replyingToId = doc.id;
          _replyingToName = authorName;
        });
      },
      onEdit: isOwner ? () => _editComment(doc.id, content) : null,
      onDelete: isOwner ? () => _deleteComment(doc.id) : null,
    );
  }
  
  Future<void> _editComment(String commentId, String currentContent) async {
    final controller = TextEditingController(text: currentContent);
    
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Chỉnh sửa bình luận'),
        content: TextField(
          controller: controller,
          maxLines: 3,
          decoration: const InputDecoration(
            hintText: 'Nhập nội dung bình luận...',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Hủy'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Lưu'),
          ),
        ],
      ),
    );
    
    controller.dispose();
    
    if (result == null || result.isEmpty || result == currentContent) return;
    
    try {
      await FirebaseFirestore.instance
          .collection('posts')
          .doc(widget.postId)
          .collection('comments')
          .doc(commentId)
          .update({
        'content': result,
        'updatedAt': FieldValue.serverTimestamp(),
        'isEdited': true,
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã cập nhật bình luận')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi khi cập nhật: $e')),
        );
      }
    }
  }
  
  Future<void> _deleteComment(String commentId) async {
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
    
    if (confirm != true) return;
    
    try {
      await FirebaseFirestore.instance
          .collection('posts')
          .doc(widget.postId)
          .collection('comments')
          .doc(commentId)
          .delete();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã xóa bình luận')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi khi xóa: $e')),
        );
      }
    }
  }
  
}

class _SortChip extends StatelessWidget {
  const _SortChip({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? Theme.of(context).colorScheme.primaryContainer
              : Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? Theme.of(context).colorScheme.primary
                : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                color: isSelected
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CommentCard extends StatelessWidget {
  const _CommentCard({
    required this.content,
    required this.authorName,
    required this.avatarUrl,
    required this.timestamp,
    required this.likesCount,
    required this.isLiked,
    required this.onLike,
    required this.onReply,
    this.imageUrl,
    this.replyTo,
    this.isIndented = false,
    this.isEdited = false,
    this.isOwner = false,
    this.onEdit,
    this.onDelete,
  });

  final String content;
  final String authorName;
  final String avatarUrl;
  final String? imageUrl;
  final DateTime? timestamp;
  final bool isEdited;
  final int likesCount;
  final bool isLiked;
  final VoidCallback onLike;
  final VoidCallback onReply;
  final String? replyTo;
  final bool isIndented;
  final bool isOwner;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  String _formatTime(DateTime? time) {
    if (time == null) return '';
    final now = DateTime.now();
    final diff = now.difference(time);
    
    if (diff.inDays > 0) return '${diff.inDays} ngày trước';
    if (diff.inHours > 0) return '${diff.inHours} giờ trước';
    if (diff.inMinutes > 0) return '${diff.inMinutes} phút trước';
    return 'Vừa xong';
  }

  @override
  Widget build(BuildContext context) {
    // Use isIndented parameter for consistent grouping
    final leftIndent = isIndented ? 40.0 : 16.0;
    
    return Container(
      margin: EdgeInsets.only(
        left: leftIndent,
        right: 16,
        top: 4,
        bottom: 4,
      ),
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color:
                Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.5),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  GradientAvatar(imageUrl: avatarUrl, radius: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(
                              authorName,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                            // Inline reply tag (only if both indented AND has replyTo name)
                            if (isIndented && replyTo != null)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFE8F5E9),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.subdirectory_arrow_right,
                                      size: 12,
                                      color: Color(0xFF2E7D32),
                                    ),
                                    const SizedBox(width: 2),
                                    Text(
                                      replyTo!,
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: Color(0xFF2E7D32),
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                        if (timestamp != null)
                          Row(
                            children: [
                              Text(
                                _formatTime(timestamp),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                ),
                              ),
                              if (isEdited) ...[
                                const SizedBox(width: 4),
                                Text(
                                  '(đã chỉnh sửa)',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        if (imageUrl != null && imageUrl!.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxHeight: 250),
                              child: Image.network(
                                imageUrl!,
                                width: double.infinity,
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  // Edit/Delete menu for comment owner
                  if (isOwner && (onEdit != null || onDelete != null))
                    PopupMenuButton<String>(
                      icon: Icon(
                        Icons.more_vert,
                        size: 20,
                        color: Colors.grey[600],
                      ),
                      onSelected: (value) {
                        if (value == 'edit' && onEdit != null) {
                          onEdit!();
                        } else if (value == 'delete' && onDelete != null) {
                          onDelete!();
                        }
                      },
                      itemBuilder: (context) => [
                        if (onEdit != null)
                          const PopupMenuItem(
                            value: 'edit',
                            child: Row(
                              children: [
                                Icon(Icons.edit, size: 18),
                                SizedBox(width: 8),
                                Text('Chỉnh sửa'),
                              ],
                            ),
                          ),
                        if (onDelete != null)
                          const PopupMenuItem(
                            value: 'delete',
                            child: Row(
                              children: [
                                Icon(Icons.delete, size: 18, color: Colors.red),
                                SizedBox(width: 8),
                                Text('Xóa', style: TextStyle(color: Colors.red)),
                              ],
                            ),
                          ),
                      ],
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                content,
                style: const TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  // Like button
                  InkWell(
                    onTap: onLike,
                    borderRadius: BorderRadius.circular(16),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isLiked ? Icons.favorite : Icons.favorite_border,
                            size: 18,
                            color: isLiked ? Colors.red : Colors.grey[600],
                          ),
                          if (likesCount > 0) ...[
                            const SizedBox(width: 4),
                            Text(
                              '$likesCount',
                              style: TextStyle(
                                fontSize: 13,
                                color: isLiked ? Colors.red : Colors.grey[600],
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Reply button (green like image)

                  InkWell(
                    onTap: onReply,
                    borderRadius: BorderRadius.circular(16),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.reply,
                            size: 18,
                            color: Color(0xFF2E7D32), // Green like image
                          ),
                          SizedBox(width: 4),
                          Text(
                            'Trả lời',
                            style: TextStyle(
                              fontSize: 13,
                              color: Color(0xFF2E7D32), // Green
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
