import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/theme/gs_colors.dart';

/// A one-shot burst of indigo, gold and green confetti with a few fidel
/// mixed in. Draws nothing when the system asks for reduced motion.
class ConfettiBurst extends StatefulWidget {
  const ConfettiBurst({super.key, this.duration = const Duration(milliseconds: 2600)});
  final Duration duration;

  @override
  State<ConfettiBurst> createState() => _ConfettiBurstState();
}

class _Piece {
  _Piece(math.Random r)
      : x = r.nextDouble(),
        vx = (r.nextDouble() - 0.5) * 0.5,
        vy = -0.9 - r.nextDouble() * 0.7,
        spin = (r.nextDouble() - 0.5) * 12,
        size = 5 + r.nextDouble() * 6,
        kind = r.nextInt(10),
        colorIndex = r.nextInt(4);
  final double x, vx, vy, spin, size;
  final int kind, colorIndex;
}

class _ConfettiBurstState extends State<ConfettiBurst>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: widget.duration);
  final _pieces = List.generate(70, (_) => _Piece(_rng));
  static final _rng = math.Random();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!MediaQuery.of(context).disableAnimations && !_c.isAnimating && _c.value == 0) {
      _c.forward();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.of(context).disableAnimations) return const SizedBox.shrink();
    final c = context.gs;
    final colors = [c.primary, c.gold, c.guessedInk, c.glow];
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) => CustomPaint(
          size: Size.infinite,
          painter: _ConfettiPainter(_pieces, _c.value, colors),
        ),
      ),
    );
  }
}

class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter(this.pieces, this.t, this.colors);
  final List<_Piece> pieces;
  final double t;
  final List<Color> colors;
  static const _fidel = ['ፊ', 'ደ', 'ል'];

  @override
  void paint(Canvas canvas, Size size) {
    if (t == 0 || t == 1) return;
    final fade = t < 0.8 ? 1.0 : (1 - t) / 0.2;
    for (final p in pieces) {
      // Launch from the top centre, then fall under gravity.
      final secs = t * 2.6;
      final x = size.width * (0.5 + (p.x - 0.5) * 0.3 + p.vx * secs);
      final y = size.height * (0.15 + p.vy * secs * 0.35 + 0.55 * secs * secs * 0.35);
      if (y > size.height + 20) continue;
      final color = colors[p.colorIndex].withValues(alpha: fade);
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(p.spin * secs);
      if (p.kind == 0) {
        final tp = TextPainter(
          text: TextSpan(
            text: _fidel[p.colorIndex % 3],
            style: TextStyle(
              fontFamily: 'NotoSerifEthiopic',
              fontSize: p.size * 2.2,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2));
      } else if (p.kind < 5) {
        canvas.drawRect(
            Rect.fromCenter(center: Offset.zero, width: p.size, height: p.size * 0.5),
            Paint()..color = color);
      } else {
        canvas.drawCircle(Offset.zero, p.size * 0.35, Paint()..color = color);
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) => old.t != t;
}
