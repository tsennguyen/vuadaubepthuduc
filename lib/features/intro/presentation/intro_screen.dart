import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../app/l10n.dart';
import '../../../app/language_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class IntroScreen extends ConsumerStatefulWidget {
  const IntroScreen({super.key});

  @override
  ConsumerState<IntroScreen> createState() => _IntroScreenState();
}

class _IntroScreenState extends ConsumerState<IntroScreen> {
  late final PageController _pageController;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _completeIntro() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('intro_completed', true);
    if (mounted) {
      context.go('/signin');
    }
  }

  @override
  Widget build(BuildContext context) {
    final locale = ref.watch(localeProvider);
    final s = S(locale);
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final isDark = scheme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: scheme.surface,
      body: Stack(
        children: [
          PageView(
            controller: _pageController,
            onPageChanged: (index) => setState(() => _currentIndex = index),
            children: _buildSlides(scheme, textTheme, s),
          ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    scheme.surface,
                    scheme.surface.withValues(alpha: isDark ? 0.92 : 0.9),
                    scheme.surface.withValues(alpha: 0.0),
                  ],
                  stops: const [0.0, 0.6, 1.0],
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(4, (index) {
                      final isActive = _currentIndex == index;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        height: 8,
                        width: isActive ? 32 : 8,
                        decoration: BoxDecoration(
                          color: isActive
                              ? scheme.primary
                              : scheme.onSurfaceVariant.withValues(alpha: 0.32),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 32),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      if (_currentIndex == 0)
                        TextButton(
                          onPressed: _completeIntro,
                          child: Text(
                            s.skip,
                            style: GoogleFonts.lexend(
                              color: scheme.onSurfaceVariant,
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        )
                      else
                        IconButton.filledTonal(
                          onPressed: () {
                            _pageController.previousPage(
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeInOut,
                            );
                          },
                          icon: const Icon(Icons.arrow_back),
                          style: IconButton.styleFrom(
                            backgroundColor:
                                scheme.surfaceContainerHigh.withValues(alpha: 0.7),
                            foregroundColor: scheme.onSurface,
                          ),
                        ),
                      if (_currentIndex == 3)
                        FilledButton.icon(
                          onPressed: _completeIntro,
                          label: Text(s.start),
                          style: FilledButton.styleFrom(
                            backgroundColor: scheme.primary,
                            foregroundColor: scheme.onPrimary,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 14,
                            ),
                            textStyle: GoogleFonts.lexend(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        )
                      else
                        IconButton.filled(
                          onPressed: () {
                            _pageController.nextPage(
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeInOut,
                            );
                          },
                          icon: const Icon(Icons.arrow_forward),
                          style: IconButton.styleFrom(
                            backgroundColor: scheme.primary,
                            foregroundColor: scheme.onPrimary,
                            padding: const EdgeInsets.all(16),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildSlides(ColorScheme scheme, TextTheme textTheme, S s) {
    return [
      _buildSlide(
        scheme: scheme,
        textTheme: textTheme,
        title: s.slide1Title,
        description: s.slide1Desc,
        icon: Icons.restaurant_menu_rounded,
        accent: scheme.primary,
        accentAlt: scheme.secondary,
      ),
      _buildSlide(
        scheme: scheme,
        textTheme: textTheme,
        title: s.slide2Title,
        description: s.slide2Desc,
        icon: Icons.search_rounded,
        accent: scheme.secondary,
        accentAlt: scheme.primary,
      ),
      _buildSlide(
        scheme: scheme,
        textTheme: textTheme,
        title: s.slide3Title,
        description: s.slide3Desc,
        icon: Icons.menu_book_rounded,
        accent: scheme.tertiary,
        accentAlt: scheme.secondary,
      ),
      _buildSlide(
        scheme: scheme,
        textTheme: textTheme,
        title: s.slide4Title,
        description: s.slide4Desc,
        icon: Icons.favorite_rounded,
        accent: scheme.primary,
        accentAlt: scheme.tertiary,
      ),
    ];
  }

  Widget _buildSlide({
    required String title,
    required String description,
    required IconData icon,
    required Color accent,
    required Color accentAlt,
    required ColorScheme scheme,
    required TextTheme textTheme,
  }) {
    final baseSurface = scheme.surface;
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.alphaBlend(accent.withValues(alpha: 0.18), baseSurface),
            Color.alphaBlend(accentAlt.withValues(alpha: 0.12), scheme.surfaceContainerHighest),
          ],
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Spacer(),
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: scheme.surface,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: accent.withValues(alpha: 0.18),
                    blurRadius: 40,
                    spreadRadius: 10,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Center(
                child: Icon(
                  icon,
                  size: 56,
                  color: accent,
                ),
              ),
            ),
            const SizedBox(height: 64),
            Text(
              title.toUpperCase(),
              textAlign: TextAlign.center,
              style: GoogleFonts.lexend(
                fontSize: 21,
                fontWeight: FontWeight.w800,
                height: 1.3,
                letterSpacing: 0.8,
                color: scheme.onSurface,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              description,
              textAlign: TextAlign.center,
              style: GoogleFonts.lexend(
                fontSize: 14,
                color: scheme.onSurfaceVariant,
                height: 1.6,
                fontWeight: FontWeight.w500,
              ),
            ),

            const Spacer(),
            const SizedBox(height: 100),
          ],
        ),
      ),
    );
  }
}
