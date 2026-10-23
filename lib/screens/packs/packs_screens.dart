import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/word_bank.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/gs_colors.dart';
import '../../core/utils/ethiopic_calendar.dart';
import '../../data/progress.dart';
import '../../data/puzzle_bank.dart';
import '../../data/settings.dart';
import '../../game/game_config.dart';
import '../../game/game_controller.dart';
import '../../services/audio.dart';
import '../../widgets/gs_widgets.dart';
import '../board/board_screen.dart';
import '../home/home_screen.dart';

class PacksScreen extends StatelessWidget {
  const PacksScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.gs;
    return Scaffold(
      appBar: const GsAppBar(title: Text('Puzzle packs')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Discover a little more of Ethiopia, one puzzle at a time.',
              style: GsText.caption.copyWith(color: c.inkSecondary)),
          const SizedBox(height: 12),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 0.92,
            children: [
              for (final t in WordTheme.values) PackCard(theme: t),
            ],
          ),
          const SizedBox(height: 12),
          Center(
            child: Text('Every pack is free to play in this version.',
                style: GsText.micro.copyWith(color: c.inkSecondary)),
          ),
        ],
      ),
    );
  }
}

class PackDetailScreen extends ConsumerWidget {
  const PackDetailScreen({super.key, required this.theme});
  final WordTheme theme;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.gs;
    final progress = ref.watch(progressProvider);
    ref.watch(gameProvider);
    final saved = ref.read(gameProvider.notifier).peekSaved();
    final bank = ref.watch(puzzleBankProvider);
    final words = WordBank.forTheme(theme);
    final done = words.where((w) => progress.collection.containsKey(w.id)).length;
    final sizes = {for (final w in words) w.gridSize}.length;

    return Scaffold(
      appBar: GsAppBar(title: Text('${theme.label} pack')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.asset(theme.image,
                  width: 104, height: 88, fit: BoxFit.cover, cacheWidth: 320),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(theme.tagline,
                    style: GsText.titleSmall.copyWith(color: c.ink, fontSize: 20)),
                const SizedBox(height: 4),
                Text(
                    '${words.length} puzzles · ${sizes == 3 ? 'All three sizes' : '$sizes sizes'}',
                    style: GsText.caption.copyWith(color: c.inkSecondary)),
                Text('$done / ${words.length} words discovered',
                    style: GsText.caption.copyWith(color: c.primary)),
              ]),
            ),
          ]),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: words.isEmpty ? 0 : done / words.length,
              minHeight: 4,
              color: c.gold,
              backgroundColor: c.outline,
            ),
          ),
          const SizedBox(height: 16),
          SectionTitle('Your puzzles',
              trailing: Text('Recent & next',
                  style: GsText.caption.copyWith(color: c.inkSecondary))),
          const SizedBox(height: 8),
          for (final (i, w) in words.indexed) ...[
            Builder(builder: (context) {
              final config = bank.pack(w);
              final solved = progress.collection.containsKey(w.id);
              final unlocked = i == 0 || progress.collection.containsKey(words[i - 1].id) || solved;
              final inProgress = saved != null &&
                  saved.config.source == PuzzleSource.pack &&
                  saved.config.wordId == w.id;
              final title = solved ? w.word : 'Puzzle ${(i + 1).toString().padLeft(2, '0')}';
              final status = solved
                  ? '✓ Solved · ${w.meaning}'
                  : inProgress
                      ? 'In progress · ${formatClock(saved.elapsed)}'
                      : unlocked
                          ? 'Ready when you are'
                          : 'Locked · Solve puzzle ${i.toString().padLeft(2, '0')}';
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: GsCard(
                  padding: const EdgeInsets.all(12),
                  onTap: !unlocked
                      ? null
                      : () => context.push('/play',
                          extra: inProgress
                              ? const PlayArgs.resume()
                              : PlayArgs.start(config)),
                  child: Row(children: [
                    MiniGrid(size: w.gridSize, dimension: 44),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(title,
                              style: solved
                                  ? GsText.fidel(16).copyWith(color: c.ink)
                                  : GsText.bodyStrong.copyWith(color: c.ink)),
                          Text('${config.sizeLabel} · ${config.gradeLabel}',
                              style: GsText.micro.copyWith(color: c.inkSecondary)),
                          Text(status,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GsText.micro.copyWith(
                                  color: solved ? c.guessedInk : c.inkSecondary)),
                        ],
                      ),
                    ),
                    Icon(unlocked ? Icons.chevron_right : Icons.lock_outline,
                        color: c.primary),
                  ]),
                ),
              );
            }),
          ],
          const SizedBox(height: 8),
          Center(
            child: Text('Completed words stay in your collection.',
                style: GsText.micro.copyWith(color: c.inkSecondary)),
          ),
        ],
      ),
    );
  }
}

// ───────────────────────── Collection ─────────────────────────

class CollectionScreen extends ConsumerStatefulWidget {
  const CollectionScreen({super.key});

  @override
  ConsumerState<CollectionScreen> createState() => _CollectionScreenState();
}

class _CollectionScreenState extends ConsumerState<CollectionScreen> {
  String _query = '';
  WordTheme? _theme;
  int? _size;

  @override
  Widget build(BuildContext context) {
    final c = context.gs;
    final progress = ref.watch(progressProvider);
    final items = progress.collection.values.toList()
      ..sort((a, b) => b.date.compareTo(a.date));

    if (items.isEmpty) {
      return Scaffold(
        appBar: const GsAppBar(title: Text('My collection')),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text('0 words · A new collection begins here',
                style: GsText.caption.copyWith(color: c.inkSecondary)),
            const SizedBox(height: 64),
            Center(
              child: Container(
                width: 192,
                height: 160,
                decoration: BoxDecoration(
                  color: c.goldSoft,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.menu_book_outlined, size: 56, color: c.primary),
                    const SizedBox(height: 8),
                    Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      for (int i = 0; i < 3; i++)
                        Container(
                          width: 28,
                          height: 2,
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          color: c.gold,
                        ),
                    ]),
                    const SizedBox(height: 8),
                    Icon(Icons.auto_awesome_outlined, size: 18, color: c.gold),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text('Your first word is waiting',
                textAlign: TextAlign.center,
                style: GsText.headline.copyWith(color: c.ink)),
            const SizedBox(height: 12),
            Text('Solve a puzzle to collect your first word.',
                textAlign: TextAlign.center,
                style: GsText.body.copyWith(color: c.inkSecondary)),
            const SizedBox(height: 24),
            PrimaryButton(
              label: 'Play a puzzle',
              onPressed: () => startNewPuzzleFlow(context, ref),
            ),
            const SizedBox(height: 64),
            Text('Every discovery is saved here, with its meaning and pronunciation.',
                textAlign: TextAlign.center,
                style: GsText.caption.copyWith(color: c.inkSecondary)),
          ],
        ),
      );
    }

    final q = _query.trim().toLowerCase();
    final filtered = [
      for (final it in items)
        if (WordBank.byId(it.wordId) case final w?)
          if ((_theme == null || w.theme == _theme) &&
              (_size == null || it.size.n == _size) &&
              (q.isEmpty ||
                  w.word.contains(q) ||
                  w.meaning.toLowerCase().contains(q) ||
                  w.pronunciation.toLowerCase().contains(q)))
            (it, w),
    ];

    return Scaffold(
      appBar: const GsAppBar(title: Text('My collection')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(children: [
            Expanded(
              child: Text('${items.length} word${items.length == 1 ? '' : 's'} discovered',
                  style: GsText.bodyStrong.copyWith(color: c.ink)),
            ),
            Icon(Icons.menu_book_outlined, color: c.primary),
          ]),
          const SizedBox(height: 12),
          TextField(
            onChanged: (v) => setState(() => _query = v),
            decoration: InputDecoration(
              hintText: 'Search words or meanings',
              prefixIcon: const Icon(Icons.search),
              filled: true,
              fillColor: c.surface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(28),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(spacing: 8, runSpacing: 8, children: [
            _MenuChip<WordTheme?>(
              label: _theme?.label ?? 'All themes',
              values: [null, ...WordTheme.values],
              labelOf: (t) => t?.label ?? 'All themes',
              onSelected: (t) => setState(() => _theme = t),
            ),
            _MenuChip<int?>(
              label: _size == null ? 'All sizes' : '$_size × $_size',
              values: const [null, 4, 6, 9],
              labelOf: (s) => s == null ? 'All sizes' : '$s × $s',
              onSelected: (s) => setState(() => _size = s),
            ),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
              child: Text('Most recently collected',
                  style: GsText.micro.copyWith(color: c.inkSecondary)),
            ),
            Text('★ Guessed early', style: GsText.micro.copyWith(color: c.gold)),
          ]),
          const SizedBox(height: 8),
          if (filtered.isEmpty)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Text('No words match. Clear the filters to see them all.',
                  textAlign: TextAlign.center,
                  style: GsText.body.copyWith(color: c.inkSecondary)),
            ),
          for (final (it, w) in filtered)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: GsCard(
                onTap: () => context.go('/collection/${w.id}'),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Expanded(
                      child: Text(w.word, style: GsText.fidel(20).copyWith(color: c.ink)),
                    ),
                    if (it.guessedEarly) Icon(Icons.star, color: c.gold, size: 20),
                  ]),
                  const SizedBox(height: 4),
                  Text(w.meaning, style: GsText.body.copyWith(color: c.ink)),
                  Text(w.pronunciation,
                      style: GsText.caption.copyWith(
                          color: c.inkSecondary, fontStyle: FontStyle.italic)),
                  const SizedBox(height: 4),
                  Text(
                      '${w.theme.label} · ${it.size.n} × ${it.size.n} · ${longGregorian(it.date)}',
                      style: GsText.micro.copyWith(color: c.inkSecondary)),
                ]),
              ),
            ),
        ],
      ),
    );
  }
}

class _MenuChip<T> extends StatelessWidget {
  const _MenuChip({
    required this.label,
    required this.values,
    required this.labelOf,
    required this.onSelected,
  });

  final String label;
  final List<T> values;
  final String Function(T) labelOf;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) {
    final c = context.gs;
    return PopupMenuButton<int>(
      onSelected: (i) => onSelected(values[i]),
      itemBuilder: (_) => [
        for (final (i, v) in values.indexed)
          PopupMenuItem(value: i, child: Text(labelOf(v))),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          border: Border.all(color: c.outline),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(label, style: GsText.body.copyWith(color: c.inkSecondary)),
      ),
    );
  }
}

class WordDetailScreen extends ConsumerWidget {
  const WordDetailScreen({super.key, required this.wordId});
  final String wordId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.gs;
    final word = WordBank.byId(wordId);
    final it = ref.watch(progressProvider).collection[wordId];
    if (word == null || it == null) {
      return const Scaffold(
        appBar: GsAppBar(title: Text('A word to keep')),
        body: Center(child: Text('This word is not in your collection yet.')),
      );
    }
    final eth = EthiopicDate.fromGregorian(it.date);
    return Scaffold(
      appBar: const GsAppBar(title: Text('A word to keep')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(children: [
            Icon(Icons.check, size: 16, color: c.guessedInk),
            const SizedBox(width: 6),
            Text('Added to collection',
                style: GsText.caption.copyWith(color: c.guessedInk)),
          ]),
          const SizedBox(height: 12),
          RevealCard(word: word),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
              child: Text(
                  '${word.theme.label} · ${it.size.n} × ${it.size.n} · ${gradeLabel(it.grade)}',
                  style: GsText.caption.copyWith(color: c.inkSecondary)),
            ),
            IconButton(
              tooltip: 'Learn fidel',
              icon: Icon(Icons.school_outlined, color: c.primary),
              onPressed: () => context.go('/learn'),
            ),
          ]),
          GsCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Your discovery', style: GsText.titleSmall.copyWith(color: c.ink, fontSize: 16)),
              const SizedBox(height: 8),
              Text('Collected on ${eth.label(geez: ref.watch(settingsProvider.select((s) => s.geezDates)))} · ${longGregorian(it.date)}',
                  style: GsText.caption.copyWith(color: c.inkSecondary)),
              if (it.guessedEarly) ...[
                const SizedBox(height: 8),
                Row(children: [
                  Icon(Icons.star, color: c.gold, size: 20),
                  const SizedBox(width: 8),
                  Text('Guessed early · +50 coins',
                      style: GsText.caption.copyWith(color: c.ink)),
                ]),
              ],
              const SizedBox(height: 8),
              Text(
                  '${formatClock(it.seconds)} time · ${it.mistakes} mistake${it.mistakes == 1 ? '' : 's'} · ${it.hints} hint${it.hints == 1 ? '' : 's'}',
                  style: GsText.caption.copyWith(color: c.inkSecondary)),
            ]),
          ),
          const SizedBox(height: 16),
          TonalButton(
            label: 'Listen again',
            onPressed: () => GameAudio.speak(word.word),
          ),
          TextButton(
            onPressed: () => context.push('/report/${word.id}'),
            child: const Text('Report this word'),
          ),
          const SizedBox(height: 8),
          Center(
            child: Text('Little by little, the letters become familiar.',
                style: GsText.caption.copyWith(color: c.inkSecondary)),
          ),
        ],
      ),
    );
  }
}
