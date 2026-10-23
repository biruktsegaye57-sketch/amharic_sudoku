import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/gs_colors.dart';
import '../../data/settings.dart';
import '../../services/audio.dart';

/// Animated launch screen.
///
/// 0.0–0.3 s  the card settles in
/// 0.2–1.0 s  nine fidel pop in, in reading order
/// 1.0–1.6 s  a gold sweep reads the hidden phrase ጎበዝ ተማሪ ናችሁ
/// 0.9–1.7 s  title, Ge'ez name, woven divider and tagline rise in
/// then continues to Home (or onboarding). Tap anywhere to skip.
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  static const _tiles = ['ጎ', 'በ', 'ዝ', 'ተ', 'ማ', 'ሪ', 'ና', 'ች', 'ሁ'];
  static const _total = Duration(milliseconds: 2400);

  late final AnimationController _c =
      AnimationController(vsync: this, duration: _total);
  bool _left = false;
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (MediaQuery.of(context).disableAnimations) {
      _c.value = 1;
      Future.delayed(const Duration(milliseconds: 900), _leave);
      return;
    }
    _c.forward().whenComplete(_leave);
    Future.delayed(const Duration(milliseconds: 250), () {
      if (mounted && ref.read(settingsProvider).sound) {
        GameAudio.play(Sfx.splash, volume: 0.7);
      }
    });
  }

  void _leave() {
    if (_left || !mounted) return;
    _left = true;
    context.go('/');
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  double _seg(double from, double to, [Curve curve = Curves.easeOutCubic]) {
    final ms = _c.value * _total.inMilliseconds;
    final t = ((ms - from * 1000) / ((to - from) * 1000)).clamp(0.0, 1.0);
    return curve.transform(t);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.gs;
    return Scaffold(
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _leave,
        child: AnimatedBuilder(
          animation: _c,
          builder: (context, _) {
            final card = _seg(0, 0.35);
            final title = _seg(0.9, 1.4);
            final divider = _seg(1.1, 1.6);
            final tagline = _seg(1.3, 1.8);
            return Stack(children: [
              // Warm glow behind the mark.
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: const Alignment(0, -0.25),
                      radius: 0.9,
                      colors: [
                        c.goldSoft.withValues(alpha: 0.9 * card),
                        c.background,
                      ],
                    ),
                  ),
                ),
              ),
              Positioned.fill(child: _DriftingFidel(progress: _c.value)),
              Positioned.fill(
                child: SafeArea(
                  child: Column(children: [
                    const Spacer(flex: 3),
                    Opacity(
                      opacity: card,
                      child: Transform.scale(
                        scale: 0.85 + 0.15 * card,
                        child: _mark(c),
                      ),
                    ),
                    const SizedBox(height: 28),
                    Opacity(
                      opacity: title,
                      child: Transform.translate(
                        offset: Offset(0, 16 * (1 - title)),
                        child: Column(children: [
                          Text('Ge’ez Sudoku',
                              style: GsText.display.copyWith(color: c.ink)),
                          const SizedBox(height: 4),
                          Text('ግዕዝ ሱዶኩ',
                              style:
                                  GsText.fidel(20).copyWith(color: c.primary)),
                        ]),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _divider(c, divider),
                    const SizedBox(height: 20),
                    Opacity(
                      opacity: tagline,
                      child: Text('Find the hidden word.',
                          style: GsText.body.copyWith(color: c.inkSecondary)),
                    ),
                    const Spacer(flex: 4),
                    Opacity(
                      opacity: tagline,
                      child: Text('A little logic. A little language.',
                          style:
                              GsText.caption.copyWith(color: c.inkSecondary)),
                    ),
                    const SizedBox(height: 24),
                  ]),
                ),
              ),
            ]);
          },
        ),
      ),
    );
  }

  Widget _mark(GsColors c) {
    const size = 168.0;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: c.gold, width: 2),
        boxShadow: [
          BoxShadow(
            color: c.gold.withValues(alpha: 0.25 * _seg(1.0, 1.6)),
            blurRadius: 24,
            spreadRadius: 2,
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(children: [
        for (int r = 0; r < 3; r++)
          Expanded(
            child: Row(children: [
              for (int col = 0; col < 3; col++)
                Expanded(child: _tile(c, r * 3 + col)),
            ]),
          ),
      ]),
    );
  }

  Widget _tile(GsColors c, int i) {
    // Pop-in, staggered in reading order.
    final pop = _seg(0.2 + i * 0.07, 0.55 + i * 0.07, Curves.elasticOut);
    // The reading sweep: each tile glows gold briefly, then settles.
    final sweepStart = 1.0 + i * 0.06;
    final up = _seg(sweepStart, sweepStart + 0.12);
    final down = _seg(sweepStart + 0.18, sweepStart + 0.5);
    final glow = (up - down).clamp(0.0, 1.0);
    return Container(
      decoration: BoxDecoration(
        color: Color.lerp(c.surface, c.glow.withValues(alpha: 0.6), glow),
        border: Border(
          right: i % 3 < 2 ? BorderSide(color: c.outline) : BorderSide.none,
          bottom: i < 6 ? BorderSide(color: c.outline) : BorderSide.none,
        ),
      ),
      alignment: Alignment.center,
      child: Transform.scale(
        scale: pop,
        child: Transform.translate(
          offset: Offset(0, -4 * glow),
          child: Text(_tiles[i],
              style: GsText.fidel(30).copyWith(
                  color: Color.lerp(c.primary, const Color(0xFF1D2433), glow))),
        ),
      ),
    );
  }

  Widget _divider(GsColors c, double t) {
    Widget diamond(Color color) => Transform.rotate(
          angle: math.pi / 4,
          child: Container(width: 5 * t, height: 5 * t, color: color),
        );
    return SizedBox(
      height: 10,
      width: 220,
      child: Row(children: [
        Expanded(
          child: Align(
            alignment: Alignment.centerRight,
            child: FractionallySizedBox(
              widthFactor: t,
              child: Container(height: 1, color: c.outline),
            ),
          ),
        ),
        const SizedBox(width: 6),
        diamond(c.primary),
        const SizedBox(width: 6),
        diamond(c.gold),
        const SizedBox(width: 6),
        diamond(c.primary),
        const SizedBox(width: 6),
        Expanded(
          child: Align(
            alignment: Alignment.centerLeft,
            child: FractionallySizedBox(
              widthFactor: t,
              child: Container(height: 1, color: c.outline),
            ),
          ),
        ),
      ]),
    );
  }
}

/// Faint fidel drifting upward behind the mark.
class _DriftingFidel extends StatelessWidget {
  const _DriftingFidel({required this.progress});
  final double progress;

  static const _glyphs = [
    'ሀ',
    'ለ',
    'ሐ',
    'መ',
    'ረ',
    'ሰ',
    'ቀ',
    'በ',
    'ተ',
    'ነ',
    'አ',
    'ከ',
    'ወ',
    'ዘ',
    'የ',
    'ደ',
    'ገ',
    'ጠ',
  ];

  @override
  Widget build(BuildContext context) {
    final c = context.gs;
    return LayoutBuilder(builder: (context, box) {
      final rng = math.Random(19);
      return Stack(children: [
        for (int i = 0; i < _glyphs.length; i++)
          Builder(builder: (_) {
            final x = rng.nextDouble();
            final y0 = rng.nextDouble();
            final speed = 0.04 + rng.nextDouble() * 0.06;
            final size = 18.0 + rng.nextDouble() * 22;
            final y = (y0 - progress * speed * 3) % 1.0;
            return Positioned(
              left: x * (box.maxWidth - size),
              top: y * box.maxHeight,
              child: Opacity(
                opacity: 0.07 + 0.05 * math.sin((progress + i) * math.pi),
                child: Text(_glyphs[i],
                    style: GsText.fidel(size).copyWith(color: c.primary)),
              ),
            );
          }),
      ]);
    });
  }
}
