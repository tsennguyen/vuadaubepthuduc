import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/services/ai_chef_service.dart';
import '../../../ai/application/chef_ai_controller.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../../app/l10n.dart';
import '../../../../app/language_controller.dart';

class FlippableDishCard extends ConsumerStatefulWidget {
  final String imageUrl;
  final String dishName;
  final String heroTag;
  final ValueChanged<bool>? onFlip;

  const FlippableDishCard({
    super.key,
    required this.imageUrl,
    required this.dishName,
    required this.heroTag,
    this.onFlip,
  });

  @override
  ConsumerState<FlippableDishCard> createState() => _FlippableDishCardState();
}

class _FlippableDishCardState extends ConsumerState<FlippableDishCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  bool _isFront = true;
  String? _funFact;
  bool _isLoadingFact = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _animation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOutBack),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _fetchFunFact() async {
    if (_funFact != null) return;

    setState(() {
      _isLoadingFact = true;
    });

    final isVi = ref.read(localeProvider).languageCode == 'vi';
    
    try {
      final userId = FirebaseAuth.instance.currentUser?.uid ?? 'anonymous';
      final aiService = ref.read(aiChefServiceProvider);
      
      final prompt = isVi 
        ? '''
Ngắn – đúng món – đúng văn hoá.
Viết 1 đoạn ngắn (2–3 câu), dễ hiểu, giới thiệu nguồn gốc hoặc câu chuyện thú vị liên quan đến món ăn "${widget.dishName}".
Không dùng từ học thuật, phù hợp người dùng phổ thông.
CHỈ trả về nội dung text, không thêm tiền tố hay hậu tố.
'''
        : '''
Short – accurate – culturally relevant.
Write a short paragraph (2-3 sentences), easy to understand, introducing the origin or an interesting story related to the dish "${widget.dishName}".
Avoid academic terms, suitable for general users.
Return ONLY text content, no prefix or suffix.
''';

      final result = await aiService.chat(
        userId: userId,
        message: prompt,
      );

      if (mounted) {
        setState(() {
          _funFact = result.trim();
          _isLoadingFact = false;
        });
      }
    } catch (e) {
      if (mounted) {
        final s = S(ref.read(localeProvider));
        setState(() {
          _funFact = s.noFactFound;
          _isLoadingFact = false;
        });
      }
    }
  }

  void _toggleCard() {
    final nextIsFront = !_isFront;
    if (_isFront) {
      _controller.forward();
      _fetchFunFact();
    } else {
      _controller.reverse();
    }
    setState(() {
      _isFront = nextIsFront;
    });
    widget.onFlip?.call(!nextIsFront); // flipped = true if back is showing
  }

  @override
  Widget build(BuildContext context) {
    return Hero(
      tag: widget.heroTag,
      child: GestureDetector(
        onTap: _toggleCard,
        child: AnimatedBuilder(
          animation: _animation,
          builder: (context, child) {
            final angle = _animation.value * pi;
            return Transform(
              transform: Matrix4.identity()
                ..setEntry(3, 2, 0.001) // perspective
                ..rotateY(angle),
              alignment: Alignment.center,
              child: angle < pi / 2
                  ? _buildFront()
                  : Transform(
                      transform: Matrix4.identity()..rotateY(pi),
                      alignment: Alignment.center,
                      child: _buildBack(),
                    ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildFront() {
    return ClipRRect(
      borderRadius: const BorderRadius.only(
        bottomLeft: Radius.circular(16),
        bottomRight: Radius.circular(16),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.network(
            widget.imageUrl,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(
              color: Colors.grey[300],
              child: const Icon(Icons.broken_image, size: 50),
            ),
          ),
          // Light overlay to indicate it's clickable
          Positioned(
            bottom: 12,
            right: 12,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.black45,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white24, width: 1),
              ),
              child: const Icon(Icons.auto_awesome, color: Colors.white, size: 20),
            ),
          ),
          Positioned(
            bottom: 12,
            left: 12,
            child: Consumer(
              builder: (context, ref, _) {
                final s = S(ref.watch(localeProvider));
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black45,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white24, width: 1),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.touch_app, color: Colors.white, size: 14),
                      const SizedBox(width: 4),
                      Text(
                        s.seeFunFact,
                        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBack() {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final s = S(ref.watch(localeProvider));
    
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            scheme.primaryContainer,
            scheme.secondaryContainer.withValues(alpha: 0.8),
          ],
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(16),
          bottomRight: Radius.circular(16),
        ),
        boxShadow: [
          BoxShadow(
            color: scheme.shadow.withValues(alpha: 0.1),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: scheme.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.auto_awesome,
              color: scheme.primary,
              size: 28,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            s.didYouKnow,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
              color: scheme.primary,
              letterSpacing: 0.5,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Expanded(
            child: Center(
              child: _isLoadingFact
                  ? Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          s.aiSearchingFact,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    )
                  : SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      child: Text(
                        _funFact ?? s.loading,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          height: 1.6,
                          fontWeight: FontWeight.w500,
                          color: scheme.onSurfaceVariant,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 8),
          Icon(
            Icons.touch_app_outlined,
            size: 16,
            color: scheme.primary.withValues(alpha: 0.5),
          ),
          Text(
            s.tapToFlipBack,
            style: theme.textTheme.labelSmall?.copyWith(
              color: scheme.primary.withValues(alpha: 0.5),
            ),
          ),
        ],
      ),
    );
  }
}
