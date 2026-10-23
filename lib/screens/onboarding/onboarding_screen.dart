import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/gs_colors.dart';
import '../../data/puzzle_bank.dart';
import '../../data/settings.dart';
import '../../services/reminders.dart';
import '../board/board_screen.dart';
import '../../widgets/gs_widgets.dart';

/// Splash → three "How to play" pages → first 4 × 4 (or straight to 9 × 9).
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  int _page = 0;

  void _finish({bool nine = false, bool play = true}) {
    ref.read(settingsProvider.notifier).update((s) => s.copyWith(onboarded: true));
    // The daily reminder is on by default; Android 13+ needs permission.
    if (ref.read(settingsProvider).dailyReminder) Reminders.requestPermission();
    context.go('/');
    if (!play) return;
    final bank = ref.read(puzzleBankProvider);
    context.push('/play',
        extra: PlayArgs.start(nine ? bank.onboarding9() : bank.onboarding4()));
  }

  @override
  Widget build(BuildContext context) {
    final c = context.gs;
    return Scaffold(
      body: SafeArea(
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 8, 0),
            child: Row(children: [
              Expanded(
                child: Text('HOW TO PLAY · ${_page + 1} OF 3',
                    style: GsText.caption.copyWith(
                        color: c.inkSecondary, letterSpacing: 0.4)),
              ),
              if (_page < 2)
                TextButton(
                  onPressed: () => _finish(play: false),
                  child: const Text('Skip'),
                ),
              if (_page == 2) const SizedBox(height: 48),
            ]),
          ),
          const TibebDivider(),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
              child: switch (_page) {
                0 => _RulesPage(onNext: () => setState(() => _page = 1)),
                1 => _WordPage(onNext: () => setState(() => _page = 2)),
                _ => _HunchPage(
                    onStart4: () => _finish(),
                    onStart9: () => _finish(nine: true),
                  ),
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (int i = 0; i < 3; i++)
                  Container(
                    width: 6,
                    height: 6,
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: i == _page ? c.primary : c.outline,
                    ),
                  ),
              ],
            ),
          ),
        ]),
      ),
    );
  }
}

/// 3 × 3 fidel mark with gold frame (splash and launcher artwork).
class AppMark extends StatelessWidget {
  const AppMark({super.key, this.size = 150});
  final double size;

  @override
  Widget build(BuildContext context) {
    final c = context.gs;
    const tiles = ['ጎ', 'በ', 'ዝ', 'ተ', 'ማ', 'ሪ', 'ና', 'ች', 'ሁ'];
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(size * 0.12),
        border: Border.all(color: c.gold, width: 1.5),
      ),
      clipBehavior: Clip.antiAlias,
      child: GridView.count(
        crossAxisCount: 3,
        physics: const NeverScrollableScrollPhysics(),
        padding: EdgeInsets.zero,
        children: [
          for (final (i, t) in tiles.indexed)
            Container(
              decoration: BoxDecoration(
                border: Border(
                  right: i % 3 < 2 ? BorderSide(color: c.outline) : BorderSide.none,
                  bottom: i < 6 ? BorderSide(color: c.outline) : BorderSide.none,
                ),
              ),
              alignment: Alignment.center,
              child: Text(t,
                  style: GsText.fidel(size * 0.17).copyWith(color: c.primary)),
            ),
        ],
      ),
    );
  }
}

/// Static 4 × 4 demo board (ዶሮ ወጥ).
class DemoBoard extends StatelessWidget {
  const DemoBoard({super.key, this.highlightRow});
  final int? highlightRow;

  static const rows = [
    ['ወ', 'ጥ', 'ዶ', 'ሮ'],
    ['ዶ', 'ሮ', 'ወ', 'ጥ'],
    ['ጥ', 'ወ', 'ሮ', 'ዶ'],
    ['ሮ', 'ዶ', 'ጥ', 'ወ'],
  ];

  @override
  Widget build(BuildContext context) {
    final c = context.gs;
    return AspectRatio(
      aspectRatio: 1,
      child: LayoutBuilder(builder: (context, box) => Container(
        decoration: BoxDecoration(border: Border.all(color: c.boardThick, width: 1.5)),
        child: Column(children: [
          for (int r = 0; r < 4; r++)
            Expanded(
              child: Row(children: [
                for (int col = 0; col < 4; col++)
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: r == highlightRow ? c.wordBand : c.cell,
                        border: Border(
                          right: col == 3
                              ? BorderSide.none
                              : BorderSide(
                                  color: col == 1 ? c.boardThick : c.boardThin,
                                  width: col == 1 ? 1.5 : 0.5),
                          bottom: r == 3
                              ? BorderSide.none
                              : BorderSide(
                                  color: r == 1 ? c.boardThick : c.boardThin,
                                  width: r == 1 ? 1.5 : 0.5),
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Text(rows[r][col],
                          style: GsText.fidel(box.maxWidth / 4 * 0.42).copyWith(
                              color: r == highlightRow
                                  ? const Color(0xFF1D2433)
                                  : c.given)),
                    ),
                  ),
              ]),
            ),
        ]),
      )),
    );
  }
}

class _RulesPage extends StatelessWidget {
  const _RulesPage({required this.onNext});
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final c = context.gs;
    Widget chip(String t) => Expanded(
          child: Container(
            height: 40,
            margin: const EdgeInsets.symmetric(horizontal: 4),
            decoration: BoxDecoration(
              color: c.tonal,
              borderRadius: BorderRadius.circular(8),
            ),
            alignment: Alignment.center,
            child: Text('$t ✓', style: GsText.caption.copyWith(color: c.onTonal)),
          ),
        );
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Sudoku, with fidel.', style: GsText.title.copyWith(color: c.ink, fontSize: 26)),
      const SizedBox(height: 12),
      Text('Use ዶ ሮ ወ ጥ once in every row, column and 2 × 2 box. No repeats.',
          style: GsText.body.copyWith(color: c.inkSecondary)),
      const SizedBox(height: 20),
      Center(
        child: SizedBox(
          width: (MediaQuery.sizeOf(context).height * 0.36).clamp(160.0, 288.0),
          child: const DemoBoard(),
        ),
      ),
      const SizedBox(height: 20),
      Row(children: [chip('Row'), chip('Column'), chip('Box')]),
      const SizedBox(height: 20),
      Text("You don't need to read Amharic. Match the shapes and follow the logic.",
          style: GsText.body.copyWith(color: c.inkSecondary)),
      const SizedBox(height: 24),
      SizedBox(width: double.infinity, child: PrimaryButton(label: 'Next', onPressed: onNext)),
    ]);
  }
}

class _WordPage extends StatelessWidget {
  const _WordPage({required this.onNext});
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final c = context.gs;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('A word is waiting.', style: GsText.title.copyWith(color: c.ink, fontSize: 26)),
      const SizedBox(height: 12),
      Text('Finish the puzzle to discover the word hidden in the gold row.',
          style: GsText.body.copyWith(color: c.inkSecondary)),
      const SizedBox(height: 20),
      Center(
        child: SizedBox(
          width: (MediaQuery.sizeOf(context).height * 0.36).clamp(160.0, 288.0),
          child: const DemoBoard(highlightRow: 1),
        ),
      ),
      const SizedBox(height: 20),
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: c.goldSoft,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(children: [
          Text('ዶሮ ወጥ', style: GsText.fidel(20).copyWith(color: const Color(0xFF1D2433))),
          const SizedBox(height: 4),
          Text('Doro wat: chicken stew.',
              style: GsText.body.copyWith(color: const Color(0xFF5E6678))),
        ]),
      ),
      const SizedBox(height: 24),
      SizedBox(width: double.infinity, child: PrimaryButton(label: 'Next', onPressed: onNext)),
    ]);
  }
}

class _HunchPage extends StatelessWidget {
  const _HunchPage({required this.onStart4, required this.onStart9});
  final VoidCallback onStart4;
  final VoidCallback onStart9;

  @override
  Widget build(BuildContext context) {
    final c = context.gs;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Have a hunch?', style: GsText.title.copyWith(color: c.ink, fontSize: 26)),
      const SizedBox(height: 8),
      Text('Guess it early for a bonus.',
          style: GsText.body.copyWith(color: c.inkSecondary)),
      const SizedBox(height: 24),
      Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
        decoration: BoxDecoration(
          color: c.goldSoft,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(children: [
          Icon(Icons.document_scanner_outlined, color: c.gold, size: 36),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (int i = 0; i < 4; i++)
                Container(
                  width: 48,
                  height: 56,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: c.gold),
                  ),
                  alignment: Alignment.center,
                  child: Container(
                    width: 4,
                    height: 4,
                    decoration: BoxDecoration(color: c.gold, shape: BoxShape.circle),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 20),
          Text('+50 coins for an early discovery',
              style: GsText.bodyStrong.copyWith(color: const Color(0xFF2F4A9E))),
        ]),
      ),
      const SizedBox(height: 24),
      Text(
        "You have 3 word guesses per puzzle. Finding the word doesn't finish "
        "the board—there's still a puzzle to solve.",
        style: GsText.body.copyWith(color: c.inkSecondary),
      ),
      const SizedBox(height: 24),
      SizedBox(
          width: double.infinity,
          child: PrimaryButton(label: 'Start with 4 × 4', onPressed: onStart4)),
      const SizedBox(height: 16),
      SizedBox(
          width: double.infinity,
          child: TonalButton(label: 'I know Sudoku: go to 9 × 9', onPressed: onStart9)),
    ]);
  }
}
