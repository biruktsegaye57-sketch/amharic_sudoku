import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sudoku_core/sudoku_core.dart';

import '../../core/constants/word_bank.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/gs_colors.dart';
import '../../core/utils/ethiopic_calendar.dart';
import '../../data/progress.dart';
import '../../data/puzzle_bank.dart';
import '../../data/settings.dart';
import '../../game/game_config.dart';
import '../../game/game_controller.dart';
import '../../game/game_session.dart';
import '../../game/symbols.dart';
import '../../widgets/gs_widgets.dart';
import '../board/board_screen.dart';
import 'new_puzzle_sheet.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.gs;
    final progress = ref.watch(progressProvider);
    // Rebuild when a game is saved / finished.
    ref.watch(gameProvider);
    final saved = ref.read(gameProvider.notifier).peekSaved();
    final firstVisit = progress.records.isEmpty && saved == null;
    final streak = progress.dayStreak;

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.only(bottom: 16),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 8, 4),
              child: Row(children: [
                Expanded(
                  child: Text('Ge’ez Sudoku',
                      style: GsText.title.copyWith(color: c.ink)),
                ),
                Semantics(
                  label: '${progress.coins} coins',
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () => showToast(context,
                        'Coins: earn them by solving, spend them on hints and second chances.',
                        icon: Icons.monetization_on_outlined),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: c.goldSoft,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.monetization_on, size: 16, color: c.gold),
                        const SizedBox(width: 4),
                        Text('${progress.coins}',
                            style: GsText.label.copyWith(color: const Color(0xFF1D2433))),
                      ]),
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Achievements',
                  icon: Icon(Icons.emoji_events_outlined, color: c.primary),
                  onPressed: () => context.push('/stats/achievements'),
                ),
                IconButton(
                  tooltip: 'Settings',
                  icon: Icon(Icons.settings, color: c.ink),
                  onPressed: () => context.push('/settings'),
                ),
              ]),
            ),
            const TibebDivider(),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (firstVisit) ...[
                    Text('A little logic. A little language.',
                        style: GsText.headline.copyWith(color: c.ink)),
                    Text('Your next discovery starts with one letter.',
                        style: GsText.caption.copyWith(color: c.inkSecondary)),
                    const SizedBox(height: 12),
                  ],
                  _DailyCard(firstVisit: firstVisit),
                  const SizedBox(height: 12),
                  if (saved != null) ...[
                    _ContinueCard(session: saved),
                    const SizedBox(height: 12),
                  ],
                  TonalButton(
                    label: 'New puzzle',
                    onPressed: () => startNewPuzzleFlow(context, ref),
                  ),
                  const SizedBox(height: 20),
                  SectionTitle('Explore themes',
                      trailing: InkWell(
                        onTap: () => context.go('/packs'),
                        child: Text('View all →',
                            style: GsText.caption.copyWith(color: c.inkSecondary)),
                      )),
                  const SizedBox(height: 8),
                ],
              ),
            ),
            SizedBox(
              height: 150,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                scrollDirection: Axis.horizontal,
                itemCount: WordTheme.values.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, i) {
                  final t = WordTheme.values[i];
                  return SizedBox(
                    width: 104,
                    child: PackCard(theme: t, compact: true),
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(children: [
                Expanded(
                  child: _QuickTile(
                    icon: Icons.menu_book_outlined,
                    title: 'Collection',
                    subtitle: firstVisit
                        ? 'Your words'
                        : '${progress.collection.length} words',
                    onTap: () => context.go('/collection'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _QuickTile(
                    icon: Icons.grid_on,
                    title: 'Classic',
                    subtitle: 'Just the logic',
                    onTap: () => context.push('/classic'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _QuickTile(
                    icon: Icons.school_outlined,
                    title: 'Learn',
                    subtitle: 'Fidel guide',
                    onTap: () => context.go('/learn'),
                  ),
                ),
              ]),
            ),
            const SizedBox(height: 16),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.local_fire_department_outlined, size: 18, color: c.gold),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  streak > 0
                      ? '$streak day streak · Keep your spark going'
                      : "Start your streak with today's puzzle",
                  overflow: TextOverflow.ellipsis,
                  style: GsText.caption.copyWith(color: c.inkSecondary),
                ),
              ),
            ]),
          ],
        ),
      ),
    );
  }
}

/// Opens the New puzzle sheet, asking first if a puzzle is in progress.
Future<void> startNewPuzzleFlow(BuildContext context, WidgetRef ref) async {
  final saved = ref.read(gameProvider.notifier).peekSaved();
  if (saved != null) {
    final choice = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Resume your puzzle?'),
        content: Text(
            'You have a ${saved.config.sizeLabel} ${saved.config.gradeLabel} puzzle in progress.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Start new')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Continue')),
        ],
      ),
    );
    if (!context.mounted || choice == null) return;
    if (choice) {
      context.push('/play', extra: const PlayArgs.resume());
      return;
    }
  }
  if (!context.mounted) return;
  final config = await showModalBottomSheet<GameConfig>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    builder: (_) => const NewPuzzleSheet(),
  );
  if (config != null && context.mounted) {
    context.push('/play', extra: PlayArgs.start(config));
  }
}

class _DailyCard extends ConsumerWidget {
  const _DailyCard({required this.firstVisit});
  final bool firstVisit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.gs;
    final bank = ref.watch(puzzleBankProvider);
    final progress = ref.watch(progressProvider);
    final today = DateTime.now();
    final eth = EthiopicDate.fromGregorian(today);
    final first = eth.firstOfMonth.toGregorian();
    int solvedThisMonth = 0;
    for (int d = 0; d < eth.monthLength; d++) {
      if (progress.daily.containsKey(dayKey(first.add(Duration(days: d))))) {
        solvedThisMonth++;
      }
    }
    final word = bank.dailyWord(today);
    final result = progress.daily[dayKey(today)];
    final geez = ref.watch(settingsProvider.select((s) => s.geezDates));

    return GsCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
              child: Text('Daily ፊደል',
                  style: GsText.headline.copyWith(color: c.ink)),
            ),
            Text('$solvedThisMonth / ${eth.monthLength}',
                style: GsText.caption.copyWith(color: c.inkSecondary)),
          ]),
          const SizedBox(height: 4),
          Text('${eth.label(geez: geez)} • ${shortGregorian(today)}',
              style: GsText.caption.copyWith(color: c.ink)),
          const SizedBox(height: 8),
          if (result != null) ...[
            Row(children: [
              Icon(Icons.check, size: 14, color: c.guessedInk),
              const SizedBox(width: 4),
              Expanded(
                child: Text('Completed · ${formatClock(result.seconds)}',
                    style: GsText.caption.copyWith(color: c.guessedInk)),
              ),
              Text(word.theme.label,
                  style: GsText.caption.copyWith(color: c.inkSecondary)),
            ]),
            const SizedBox(height: 4),
            Row(children: [
              Expanded(
                child: Text(word.word, style: GsText.fidel(20).copyWith(color: c.ink)),
              ),
              SpeakerButton(word: word),
            ]),
            Text(word.meaning, style: GsText.body.copyWith(color: c.ink)),
            const SizedBox(height: 8),
            InkWell(
              onTap: () => context.go('/daily'),
              child: Text('Added to collection · View daily calendar →',
                  style: GsText.micro.copyWith(color: c.inkSecondary)),
            ),
          ] else ...[
            Row(children: [
              Text('Theme: ${word.theme.label}',
                  style: GsText.caption.copyWith(color: c.ink)),
              const SizedBox(width: 12),
              WordDots(count: word.length, color: c.gold, size: 4),
            ]),
            if (firstVisit) ...[
              const SizedBox(height: 8),
              Text("Solve the board to reveal today's hidden word.",
                  style: GsText.caption.copyWith(color: c.inkSecondary)),
            ],
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: PrimaryButton(
                label: 'Play daily puzzle',
                onPressed: () => context.push('/play',
                    extra: PlayArgs.start(bank.daily(today))),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ContinueCard extends StatelessWidget {
  const _ContinueCard({required this.session});
  final GameSession session;

  @override
  Widget build(BuildContext context) {
    final c = context.gs;
    final s = session;
    return GsCard(
      padding: const EdgeInsets.all(12),
      onTap: () => context.push('/play', extra: const PlayArgs.resume()),
      child: Row(children: [
        MiniGrid(
          size: s.data.size,
          dimension: 44,
          glyphs: [for (final v in s.values) s.glyph(v)],
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Continue puzzle', style: GsText.bodyStrong.copyWith(color: c.ink, fontSize: 15)),
            Text('${s.config.sizeLabel} • ${s.config.gradeLabel} · ${formatClock(s.elapsed)}',
                style: GsText.caption.copyWith(color: c.inkSecondary)),
          ]),
        ),
        Icon(Icons.chevron_right, color: c.primary),
      ]),
    );
  }
}

class _QuickTile extends StatelessWidget {
  const _QuickTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.gs;
    return GsCard(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
      borderColor: Colors.transparent,
      onTap: onTap,
      child: Column(children: [
        Icon(icon, color: c.primary, size: 22),
        const SizedBox(height: 4),
        Text(title, style: GsText.bodyStrong.copyWith(color: c.ink, fontSize: 13)),
        Text(subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GsText.micro.copyWith(color: c.inkSecondary)),
      ]),
    );
  }
}

/// Theme pack card with photograph.
class PackCard extends ConsumerWidget {
  const PackCard({super.key, required this.theme, this.compact = false});
  final WordTheme theme;
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.gs;
    final progress = ref.watch(progressProvider);
    final words = WordBank.forTheme(theme);
    final done = words.where((w) => progress.collection.containsKey(w.id)).length;
    return GsCard(
      padding: EdgeInsets.zero,
      onTap: () => context.go('/packs/${theme.name}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.asset(theme.image,
                height: compact ? 72 : 84,
                width: double.infinity,
                fit: BoxFit.cover,
                cacheWidth: 480),
          ),
          Flexible(
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(theme.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GsText.bodyStrong.copyWith(color: c.ink)),
                  if (!compact)
                    Text(_sizes(words),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GsText.micro.copyWith(color: c.inkSecondary)),
                  Text('$done / ${words.length}${compact ? '' : ' puzzles'}',
                      maxLines: 1,
                      style: GsText.micro.copyWith(
                          color: done > 0 ? c.primary : c.inkSecondary)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  static String _sizes(List<WordEntry> words) {
    final sizes = {for (final w in words) w.gridSize}.toList()
      ..sort((a, b) => a.n.compareTo(b.n));
    return sizes.map((s) => '${s.n} × ${s.n}').join(' · ');
  }
}

/// Size label helper used by sheets.
String sizeTitle(GridSize s) => '${s.n} × ${s.n}';

/// Best time (seconds) for a stats bucket and grade, or null.
int? bestTime(Progress p, String bucket, DifficultyGrade g) {
  int? best;
  for (final r in p.wins) {
    if (r.bucket == bucket && r.grade == g) {
      if (best == null || r.seconds < best) best = r.seconds;
    }
  }
  return best;
}

