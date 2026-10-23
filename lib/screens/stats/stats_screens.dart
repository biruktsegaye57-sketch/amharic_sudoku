import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sudoku_core/sudoku_core.dart';

import '../../core/constants/word_bank.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/gs_colors.dart';
import '../../core/utils/ethiopic_calendar.dart';
import '../../data/progress.dart';
import '../../widgets/gs_widgets.dart';
import '../home/home_screen.dart';

class StatsScreen extends ConsumerStatefulWidget {
  const StatsScreen({super.key});

  @override
  ConsumerState<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends ConsumerState<StatsScreen> {
  String _bucket = '9';
  DifficultyGrade _grade = DifficultyGrade.medium;

  @override
  Widget build(BuildContext context) {
    final c = context.gs;
    final p = ref.watch(progressProvider);
    final games = [
      for (final r in p.records)
        if (r.bucket == _bucket && r.grade == _grade) r,
    ];
    final wins = [for (final r in games) if (r.won) r];
    final times = [for (final r in wins) r.seconds];
    final best = times.isEmpty ? 0 : times.reduce(math.min);
    final avg = times.isEmpty ? 0 : times.reduce((a, b) => a + b) ~/ times.length;
    final winRate = games.isEmpty ? 0 : (wins.length * 100 / games.length).round();
    final wordWins = [for (final r in wins) if (r.isWord) r];
    final early = wordWins.isEmpty
        ? 0
        : (wordWins.where((r) => r.guessedEarly).length * 100 / wordWins.length).round();
    final last20 = times.length > 20 ? times.sublist(times.length - 20) : times;
    final (streak, bestStreak) = p.winStreak(_bucket, _grade);
    final rank = p.rank;

    Widget pair(String l1, String v1, String l2, String v2) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: GsCard(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(children: [
              Expanded(child: _Stat(label: l1, value: v1)),
              Expanded(child: _Stat(label: l2, value: v2)),
            ]),
          ),
        );

    String days(int n) => n == 0 ? '0' : '$n day${n == 1 ? '' : 's'}';
    String wins_(int n) => n == 0 ? '0' : '$n win${n == 1 ? '' : 's'}';
    String words(int n) => n == 0 ? '0' : '$n word${n == 1 ? '' : 's'}';

    return Scaffold(
      appBar: GsAppBar(
        title: const Text('Statistics'),
        showBack: false,
        actions: [
          IconButton(
            tooltip: 'Achievements',
            icon: Icon(Icons.emoji_events_outlined, color: c.primary),
            onPressed: () => context.go('/stats/achievements'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 4),
            child: GsCard(
              color: c.goldSoft,
              borderColor: Colors.transparent,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(children: [
                Icon(Icons.military_tech_outlined, color: c.gold),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('${rank.title} · ${rank.amharic}',
                      style: GsText.bodyStrong.copyWith(color: const Color(0xFF1D2433))),
                ),
                Text(
                  rank.next == null
                      ? '${p.wins.length} solved'
                      : '${p.wins.length} / ${rank.next} to next rank',
                  style: GsText.caption.copyWith(color: const Color(0xFF5E6678)),
                ),
              ]),
            ),
          ),
          _Tabs(
            values: const ['4', '6', '9', 'classic'],
            labels: const ['4 × 4', '6 × 6', '9 × 9', 'Classic'],
            selected: _bucket,
            onSelect: (v) => setState(() => _bucket = v),
          ),
          const SizedBox(height: 12),
          Row(children: [
            for (final g in const [
              DifficultyGrade.easy,
              DifficultyGrade.medium,
              DifficultyGrade.hard,
              DifficultyGrade.expert,
            ]) ...[
              if (g != DifficultyGrade.easy) const SizedBox(width: 6),
              Expanded(
                child: Material(
                  color: _grade == g ? c.tonal : c.surface,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: BorderSide(color: _grade == g ? c.tonal : c.outline),
                  ),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () => setState(() => _grade = g),
                    child: SizedBox(
                      height: 32,
                      child: Center(
                        child: Text(gradeLabelOf(g),
                            style: GsText.caption.copyWith(
                                color: _grade == g ? c.primary : c.ink)),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ]),
          const SizedBox(height: 8),
          pair('Solved', '${wins.length} of ${games.length}', 'Win rate', '$winRate%'),
          pair('Best time', formatClock(best), 'Average time', formatClock(avg)),
          pair('Win streak', wins_(streak), 'Best win streak', wins_(bestStreak)),
          pair('Day streak', days(p.dayStreak), 'Best day streak', days(p.bestDayStreak)),
          pair('Perfect wins', '${wins.where((r) => r.perfect).length}',
              'Words collected', '${p.collection.length}'),
          pair('Early guesses', '$early%', 'Guess streak', words(p.guessStreak)),
          GsCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(
                  child: Text('Last 20 solve times',
                      style: GsText.bodyStrong.copyWith(color: c.ink)),
                ),
                Text('minutes', style: GsText.micro.copyWith(color: c.inkSecondary)),
              ]),
              const SizedBox(height: 12),
              if (last20.length < 2)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: Column(children: [
                      Text(last20.isEmpty ? 'No solve times yet' : 'One solve so far',
                          style: GsText.body.copyWith(color: c.inkSecondary)),
                      const SizedBox(height: 4),
                      Text('Your first puzzle starts the story.',
                          style: GsText.caption.copyWith(color: c.inkSecondary)),
                      TextButton(
                        onPressed: () => startNewPuzzleFlow(context, ref),
                        child: const Text('Play your first puzzle →'),
                      ),
                    ]),
                  ),
                )
              else
                SizedBox(
                  height: 120,
                  child: CustomPaint(
                    size: Size.infinite,
                    painter: _LineChart(
                      [for (final t in last20) t / 60],
                      line: c.primary,
                      grid: c.outline,
                      label: c.inkSecondary,
                    ),
                  ),
                ),
            ]),
          ),
        ],
      ),
    );
  }
}

String gradeLabelOf(DifficultyGrade g) => switch (g) {
      DifficultyGrade.easy => 'Easy',
      DifficultyGrade.medium => 'Medium',
      DifficultyGrade.hard => 'Hard',
      _ => 'Expert',
    };

class _Tabs extends StatelessWidget {
  const _Tabs({
    required this.values,
    required this.labels,
    required this.selected,
    required this.onSelect,
  });

  final List<String> values;
  final List<String> labels;
  final String selected;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    final c = context.gs;
    return Container(
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: c.outline))),
      child: Row(children: [
        for (final (i, v) in values.indexed)
          Expanded(
            child: InkWell(
              onTap: () => onSelect(v),
              child: Container(
                height: 48,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                        color: v == selected ? c.primary : Colors.transparent,
                        width: 2),
                  ),
                ),
                child: Text(labels[i],
                    style: GsText.body.copyWith(
                        fontSize: 15, color: v == selected ? c.primary : c.ink)),
              ),
            ),
          ),
      ]),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final c = context.gs;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: GsText.micro.copyWith(color: c.ink)),
      Text(value,
          style: GsText.titleSmall.copyWith(
              color: c.primary,
              fontWeight: FontWeight.w500,
              fontFeatures: const [FontFeature.tabularFigures()])),
    ]);
  }
}

class _LineChart extends CustomPainter {
  _LineChart(this.values, {required this.line, required this.grid, required this.label});
  final List<double> values;
  final Color line;
  final Color grid;
  final Color label;

  @override
  void paint(Canvas canvas, Size size) {
    const left = 24.0, bottom = 18.0;
    final maxV = (values.reduce(math.max) * 1.15).ceilToDouble().clamp(1, 1e9);
    final w = size.width - left;
    final h = size.height - bottom;
    final gridPaint = Paint()
      ..color = grid
      ..strokeWidth = 1;
    void text(String t, Offset o) {
      final tp = TextPainter(
        text: TextSpan(
            text: t,
            style: TextStyle(fontFamily: GsFonts.ui, fontSize: 9, color: label)),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, o - Offset(0, tp.height / 2));
    }

    for (final f in [0.0, 0.5, 1.0]) {
      final y = h - h * f;
      canvas.drawLine(Offset(left, y), Offset(size.width, y), gridPaint);
      text((maxV * f).round().toString(), Offset(0, y));
    }
    final path = Path();
    for (int i = 0; i < values.length; i++) {
      final x = left + (values.length == 1 ? 0 : w * i / (values.length - 1));
      final y = h - h * (values[i] / maxV);
      i == 0 ? path.moveTo(x, y) : path.lineTo(x, y);
    }
    canvas.drawPath(
        path,
        Paint()
          ..color = line
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..strokeJoin = StrokeJoin.round);
    text('1', Offset(left, size.height - 6));
    text('${values.length}', Offset(size.width - 12, size.height - 6));
  }

  @override
  bool shouldRepaint(_LineChart old) => old.values != values || old.line != line;
}

// ───────────────────────── Achievements ─────────────────────────

class _Badge {
  const _Badge(this.icon, this.title, this.body, this.progress, this.target, this.suffix);
  final IconData icon;
  final String title;
  final String body;
  final int progress;
  final int target;
  final String suffix;
  bool get earned => progress >= target;
}

class AchievementsScreen extends ConsumerWidget {
  const AchievementsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.gs;
    final p = ref.watch(progressProvider);
    final words = p.collection.length;
    final foodWords = WordBank.forTheme(WordTheme.food);
    final foodDone = foodWords.where((w) => p.collection.containsKey(w.id)).length;
    final expert9 = p.wins
        .where((r) => r.bucket == '9' && r.grade == DifficultyGrade.expert)
        .length;
    final months = {
      for (final k in p.daily.keys)
        EthiopicDate.fromGregorian(DateTime.parse(k)).month,
    }.length;
    final now = EthiopicDate.fromGregorian(DateTime.now());
    int bestMonth = 0;
    final byMonth = <String, int>{};
    for (final k in p.daily.keys) {
      final e = EthiopicDate.fromGregorian(DateTime.parse(k));
      final key = '${e.year}-${e.month}';
      byMonth[key] = (byMonth[key] ?? 0) + 1;
      bestMonth = math.max(bestMonth, byMonth[key]!);
    }
    final lessonsDone = p.lessons['vowels'] == 'done' ? 1 : 0;

    final badges = [
      _Badge(Icons.menu_book_outlined, 'First word', 'Discover your first word',
          words, 1, 'words'),
      _Badge(Icons.document_scanner_outlined, 'Guess streak 10',
          'Guess 10 words in a row before solving', p.bestGuessStreak, 10, 'in a row'),
      _Badge(Icons.menu_book_outlined, '${WordBank.all.length} words',
          'Grow your collection', words, WordBank.all.length, 'words'),
      _Badge(Icons.inventory_2_outlined, 'Complete a pack', 'Every word, one theme',
          foodDone, foodWords.length, 'Food'),
      _Badge(Icons.calendar_month_outlined, '30 day daily', 'A month of daily puzzles',
          bestMonth, now.monthLength, 'days'),
      _Badge(Icons.emoji_events_outlined, 'Expert 9 × 9', 'Solve at Expert difficulty',
          expert9, 1, 'puzzle'),
      _Badge(Icons.record_voice_over_outlined, 'Fidel reader',
          'Finish the vowel forms lesson', lessonsDone, 1, 'lesson'),
      _Badge(Icons.event_note_outlined, '13 months', 'Play in all Ethiopian months',
          months, 13, 'months'),
    ];
    final earned = badges.where((b) => b.earned).length;

    return Scaffold(
      appBar: const GsAppBar(title: Text('Achievements')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(children: [
            Expanded(
              child: Text('Small steps. Lasting discoveries.',
                  style: GsText.bodyStrong.copyWith(color: c.ink)),
            ),
            Text('$earned / ${badges.length}',
                style: GsText.caption.copyWith(color: c.primary)),
          ]),
          const SizedBox(height: 12),
          GridView(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              mainAxisExtent: 144,
            ),
            children: [
              for (final b in badges)
                GsCard(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Icon(b.icon, color: b.earned ? c.gold : c.ink),
                      const Spacer(),
                      Icon(b.earned ? Icons.star : Icons.star_border,
                          size: 18, color: c.ink),
                    ]),
                    const Spacer(),
                    Text(b.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GsText.bodyStrong.copyWith(color: c.ink)),
                    Text(b.body,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GsText.micro.copyWith(color: c.inkSecondary)),
                    const SizedBox(height: 4),
                    Text(
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      b.earned
                          ? '✓ Unlocked'
                          : 'Locked · ${math.min(b.progress, b.target)} / ${b.target} ${b.suffix}',
                      style: GsText.micro.copyWith(
                          color: b.earned ? c.primary : c.inkSecondary),
                    ),
                  ]),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Center(
            child: Text('Every puzzle adds to your story.',
                style: GsText.caption.copyWith(color: c.inkSecondary)),
          ),
        ],
      ),
    );
  }
}
