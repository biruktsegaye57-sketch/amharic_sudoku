import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:sudoku_core/sudoku_core.dart';

import '../core/constants/word_bank.dart';
import '../core/theme/app_theme.dart';
import '../core/theme/gs_colors.dart';
import '../services/audio.dart';

/// Fine rule + indigo / gold / indigo diamonds (the "tibeb" signature).
class TibebDivider extends StatelessWidget {
  const TibebDivider({super.key, this.padding = 36});
  final double padding;

  @override
  Widget build(BuildContext context) {
    final c = context.gs;
    Widget diamond(Color color) => Transform.rotate(
          angle: 0.785398,
          child: Container(width: 3, height: 3, color: color),
        );
    return SizedBox(
      height: 8,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: padding),
        child: Row(children: [
          Expanded(child: Container(height: 1, color: c.outline)),
          const SizedBox(width: 4),
          diamond(c.primary),
          const SizedBox(width: 4),
          diamond(c.gold),
          const SizedBox(width: 4),
          diamond(c.primary),
          const SizedBox(width: 4),
          Expanded(child: Container(height: 1, color: c.outline)),
        ]),
      ),
    );
  }
}

/// Small app bar: back arrow, headline title, optional actions, tibeb rule.
class GsAppBar extends StatelessWidget implements PreferredSizeWidget {
  const GsAppBar({
    super.key,
    required this.title,
    this.actions,
    this.onBack,
    this.showBack = true,
  });

  final Widget title;
  final List<Widget>? actions;
  final VoidCallback? onBack;
  final bool showBack;

  @override
  Size get preferredSize => const Size.fromHeight(72);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      automaticallyImplyLeading: false,
      titleSpacing: showBack ? 4 : 24,
      toolbarHeight: 64,
      leading: showBack
          ? IconButton(
              icon: const Icon(Icons.arrow_back),
              tooltip: 'Back',
              onPressed: onBack ??
                  () => context.canPop() ? context.pop() : context.go('/'),
            )
          : null,
      title: DefaultTextStyle.merge(
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        child: title,
      ),
      actions: actions,
      bottom: const PreferredSize(
        preferredSize: Size.fromHeight(8),
        child: TibebDivider(),
      ),
    );
  }
}

/// Outlined surface card (radius 12).
class GsCard extends StatelessWidget {
  const GsCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
    this.color,
    this.borderColor,
    this.radius = 12,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color? color;
  final Color? borderColor;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final c = context.gs;
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(radius),
      side: BorderSide(color: borderColor ?? c.outline),
    );
    return Material(
      color: color ?? c.surface,
      shape: shape,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

class PrimaryButton extends StatelessWidget {
  const PrimaryButton({super.key, required this.label, this.onPressed, this.icon});
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final child = Text(label, maxLines: 1, overflow: TextOverflow.ellipsis);
    return icon == null
        ? FilledButton(onPressed: onPressed, child: child)
        : FilledButton.icon(
            onPressed: onPressed, icon: Icon(icon, size: 18), label: child);
  }
}

/// Light indigo "tonal" button (e.g. New puzzle).
class TonalButton extends StatelessWidget {
  const TonalButton({super.key, required this.label, this.onPressed, this.icon});
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final c = context.gs;
    final style = FilledButton.styleFrom(
      backgroundColor: c.tonal,
      foregroundColor: c.onTonal,
      disabledBackgroundColor: c.sunken,
      disabledForegroundColor: c.inkDisabled,
    );
    final child = Text(label, maxLines: 1, overflow: TextOverflow.ellipsis);
    return icon == null
        ? FilledButton(style: style, onPressed: onPressed, child: child)
        : FilledButton.icon(
            style: style,
            onPressed: onPressed,
            icon: Icon(icon, size: 18),
            label: child);
  }
}

class SecondaryButton extends StatelessWidget {
  const SecondaryButton({super.key, required this.label, this.onPressed});
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) =>
      OutlinedButton(onPressed: onPressed, child: Text(label));
}

/// Section heading used in lists ("Explore themes", "Difficulty", …).
class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key, this.trailing});
  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final c = context.gs;
    return Row(children: [
      Expanded(
        child: Text(text,
            style: GsText.bodyStrong.copyWith(color: c.ink, fontSize: 15)),
      ),
      if (trailing != null) trailing!,
    ]);
  }
}

/// Hollow dots for the hidden word; [filled] dots turn gold.
class WordDots extends StatelessWidget {
  const WordDots({
    super.key,
    required this.count,
    this.filled = 0,
    this.size = 5,
    this.color,
  });

  final int count;
  final int filled;
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = context.gs;
    final ring = color ?? c.inkSecondary;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (int i = 0; i < count; i++)
          Container(
            width: size,
            height: size,
            margin: EdgeInsets.symmetric(horizontal: size * 0.6),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: i < filled ? c.gold : null,
              border: Border.all(color: i < filled ? c.gold : ring, width: 1),
            ),
          ),
      ],
    );
  }
}

/// Small grid thumbnail with optional glyphs.
class MiniGrid extends StatelessWidget {
  const MiniGrid({
    super.key,
    required this.size,
    this.glyphs,
    this.dimension = 48,
  });

  final GridSize size;

  /// Row-major glyphs ('' = empty).
  final List<String>? glyphs;
  final double dimension;

  @override
  Widget build(BuildContext context) {
    final c = context.gs;
    final n = size.n;
    return SizedBox.square(
      dimension: dimension,
      child: CustomPaint(
        painter: _MiniGridPainter(size, c.boardThin, c.boardThick, c.surface),
        child: glyphs == null
            ? null
            : GridView.count(
                crossAxisCount: n,
                physics: const NeverScrollableScrollPhysics(),
                padding: EdgeInsets.zero,
                children: [
                  for (final g in glyphs!)
                    Center(
                      child: Text(g,
                          style: GsText.fidel(dimension / n * 0.6,
                                  weight: FontWeight.w500)
                              .copyWith(color: c.ink, height: 1)),
                    ),
                ],
              ),
      ),
    );
  }
}

class _MiniGridPainter extends CustomPainter {
  _MiniGridPainter(this.size, this.thin, this.thick, this.bg);
  final GridSize size;
  final Color thin, thick, bg;

  @override
  void paint(Canvas canvas, Size s) {
    final n = size.n;
    final cell = s.width / n;
    canvas.drawRect(Offset.zero & s, Paint()..color = bg);
    final pThin = Paint()
      ..color = thin
      ..strokeWidth = 0.5;
    final pThick = Paint()
      ..color = thick
      ..strokeWidth = 1;
    for (int i = 1; i < n; i++) {
      final hp = i % size.boxRows == 0 ? pThick : pThin;
      final vp = i % size.boxCols == 0 ? pThick : pThin;
      canvas.drawLine(Offset(0, i * cell), Offset(s.width, i * cell), hp);
      canvas.drawLine(Offset(i * cell, 0), Offset(i * cell, s.height), vp);
    }
    canvas.drawRect(
        (Offset.zero & s).deflate(0.5),
        Paint()
          ..color = thick
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1);
  }

  @override
  bool shouldRepaint(_MiniGridPainter old) => false;
}

/// The gold reveal card: word, speaker, meaning, pronunciation, theme line.
class RevealCard extends StatelessWidget {
  const RevealCard({
    super.key,
    required this.word,
    this.footer,
    this.compact = false,
    this.animate = false,
  });

  final WordEntry word;
  final String? footer;
  final bool compact;

  /// Lift the fidel in one by one (the solve reveal).
  final bool animate;

  @override
  Widget build(BuildContext context) {
    final c = context.gs;
    final ink = const Color(0xFF1D2433);
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(compact ? 12 : 20),
      decoration: BoxDecoration(
        color: c.goldSoft,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(
              child: animate
                  ? LiftingWord(
                      word: word.word,
                      style: GsText.fidel(compact ? 22 : 26).copyWith(color: ink))
                  : Text(word.word,
                      style: GsText.fidel(compact ? 20 : 26).copyWith(color: ink)),
            ),
            SpeakerButton(word: word, color: ink),
          ]),
          SizedBox(height: compact ? 2 : 8),
          Text(word.meaning,
              style: GsText.body.copyWith(
                  color: ink, fontSize: compact ? 13 : 16)),
          if (word.meaningAm.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(word.meaningAm,
                style: GsText.fidel(compact ? 13 : 15, weight: FontWeight.w500)
                    .copyWith(fontFamily: GsFonts.ethiopic, color: ink)),
          ],
          const SizedBox(height: 4),
          Text(word.pronunciation,
              style: GsText.caption.copyWith(
                  color: ink, fontStyle: FontStyle.italic)),
          const SizedBox(height: 6),
          Text(
            footer ?? '${word.theme.label} · ${word.theme.amharic} · Added to collection',
            style: GsText.caption.copyWith(color: const Color(0xFF5E6678)),
          ),
        ],
      ),
    );
  }
}

/// The solved word: fidel rise 8 px and fade in with an 80 ms stagger
/// (static when the system asks for reduced motion).
class LiftingWord extends StatefulWidget {
  const LiftingWord({super.key, required this.word, required this.style});
  final String word;
  final TextStyle style;

  @override
  State<LiftingWord> createState() => _LiftingWordState();
}

class _LiftingWordState extends State<LiftingWord>
    with SingleTickerProviderStateMixin {
  late final List<String> _chars = [
    for (final r in widget.word.runes) String.fromCharCode(r),
  ];
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: Duration(milliseconds: 250 + 80 * _chars.length),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.of(context).disableAnimations) {
      _c.value = 1;
    } else if (!_c.isAnimating && _c.value == 0) {
      Future.delayed(const Duration(milliseconds: 400), () {
        if (mounted) _c.forward();
      });
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final total = _c.duration!.inMilliseconds;
    return Semantics(
      label: widget.word,
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) => Wrap(children: [
          for (final (i, ch) in _chars.indexed)
            Builder(builder: (_) {
              final start = 80 * i / total;
              final end = (80 * i + 250) / total;
              final t = Curves.easeOutBack.transform(
                  ((_c.value - start) / (end - start)).clamp(0.0, 1.0));
              return Opacity(
                opacity: t.clamp(0.0, 1.0),
                child: Transform.translate(
                  offset: Offset(0, 8 * (1 - t)),
                  child: Text(ch, style: widget.style),
                ),
              );
            }),
        ]),
      ),
    );
  }
}

/// Speaker icon: speaks the word (Amharic voice if installed, otherwise an
/// English voice reading a close romanisation).
class SpeakerButton extends StatelessWidget {
  const SpeakerButton({super.key, required this.word, this.color});
  final WordEntry word;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'Pronunciation',
      icon: Icon(Icons.volume_up_outlined, color: color),
      onPressed: () => GameAudio.speak(word.word),
    );
  }
}

void showToast(BuildContext context, String message, {IconData? icon}) {
  final c = context.gs;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      duration: const Duration(seconds: 3),
      content: Row(children: [
        if (icon != null) ...[
          Icon(icon, color: c.onToast, size: 20),
          const SizedBox(width: 12),
        ],
        Expanded(child: Text(message)),
      ]),
    ));
}

/// Centered dialog from the design (icon circle, eyebrow, title, body, actions).
Future<T?> showGsDialog<T>(
  BuildContext context, {
  required IconData icon,
  Color? iconColor,
  Color? iconBg,
  String? eyebrow,
  required String title,
  required String body,
  required String primary,
  VoidCallback? onPrimary,
  String? secondary,
  VoidCallback? onSecondary,
  bool dismissible = true,
}) {
  return showDialog<T>(
    context: context,
    barrierDismissible: dismissible,
    builder: (ctx) {
      final c = ctx.gs;
      return Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 24),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: iconBg ?? c.tonal,
                child: Icon(icon, color: iconColor ?? c.primary),
              ),
              if (eyebrow != null) ...[
                const SizedBox(height: 12),
                Text(eyebrow,
                    style: GsText.caption.copyWith(
                        color: c.primary, fontWeight: FontWeight.w600)),
              ],
              const SizedBox(height: 8),
              Text(title,
                  textAlign: TextAlign.center,
                  style: GsText.title.copyWith(color: c.ink)),
              const SizedBox(height: 12),
              Text(body,
                  textAlign: TextAlign.center,
                  style: GsText.body.copyWith(color: c.inkSecondary)),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: PrimaryButton(
                  label: primary,
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    onPrimary?.call();
                  },
                ),
              ),
              if (secondary != null) ...[
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: SecondaryButton(
                    label: secondary,
                    onPressed: () {
                      Navigator.of(ctx).pop();
                      onSecondary?.call();
                    },
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    },
  );
}

/// Shown wherever a rewarded video would play. No ad SDK is integrated, so no
/// reward is granted (design: "Rewards / Ad / Unavailable").
Future<void> showAdUnavailable(BuildContext context) => showGsDialog(
      context,
      icon: Icons.wifi_off_rounded,
      eyebrow: 'No reward granted',
      title: 'Ad unavailable',
      body: "We couldn't load an ad right now. No reward has been used. "
          'Your puzzle is still saved.',
      primary: 'Back to game',
      secondary: 'Try again later',
    );

/// Shown for store purchases until billing is integrated.
Future<void> showPurchaseUnavailable(BuildContext context) => showGsDialog(
      context,
      icon: Icons.shopping_bag_outlined,
      eyebrow: 'Store',
      title: 'Purchases unavailable',
      body: 'Purchases are not available in this build. All puzzles stay '
          'available to play.',
      primary: 'OK',
    );

/// Native share sheet / store links (Android, see MainActivity.kt).
class PlatformBridge {
  static const _channel = MethodChannel('geez_sudoku/platform');

  static Future<void> share(String text) async {
    try {
      await _channel.invokeMethod('share', {'text': text});
    } on PlatformException {
      await Clipboard.setData(ClipboardData(text: text));
    } on MissingPluginException {
      await Clipboard.setData(ClipboardData(text: text));
    }
  }

  static Future<bool> openStore() async {
    try {
      return await _channel.invokeMethod<bool>('openStore') ?? false;
    } on Exception {
      return false;
    }
  }

  static Future<bool> openUrl(String url) async {
    try {
      return await _channel.invokeMethod<bool>('openUrl', {'url': url}) ?? false;
    } on Exception {
      return false;
    }
  }
}
