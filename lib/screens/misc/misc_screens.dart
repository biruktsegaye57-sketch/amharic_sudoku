import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sudoku_core/sudoku_core.dart';

import '../../core/constants/features.dart';
import '../../core/constants/links.dart';
import '../../core/constants/word_bank.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/gs_colors.dart';
import '../../data/progress.dart';
import '../../data/puzzle_bank.dart';
import '../../data/settings.dart';
import '../../game/game_config.dart';
import '../../widgets/gs_widgets.dart';
import '../board/board_screen.dart';
import '../onboarding/onboarding_screen.dart';

// ───────────────────────── Classic ─────────────────────────

class ClassicSetupScreen extends ConsumerStatefulWidget {
  const ClassicSetupScreen({super.key});

  @override
  ConsumerState<ClassicSetupScreen> createState() => _ClassicSetupScreenState();
}

class _ClassicSetupScreenState extends ConsumerState<ClassicSetupScreen> {
  SymbolSet _symbols = SymbolSet.geez;
  DifficultyGrade _grade = DifficultyGrade.medium;

  @override
  Widget build(BuildContext context) {
    final c = context.gs;
    Widget radioRow(bool selected, String title, String? sub, VoidCallback onTap) =>
        Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Material(
            color: selected ? c.tonal : c.surface,
            borderRadius: BorderRadius.circular(8),
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                child: Row(children: [
                  Icon(selected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                      color: selected ? c.primary : c.ink),
                  const SizedBox(width: 16),
                  Expanded(child: Text(title, style: GsText.body.copyWith(fontSize: 15, color: c.ink))),
                  if (sub != null)
                    Text(sub, style: GsText.micro.copyWith(color: c.inkSecondary)),
                ]),
              ),
            ),
          ),
        );

    return Scaffold(
      appBar: const GsAppBar(title: Text('Classic Sudoku')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Icon(Icons.grid_on, color: c.primary, size: 36),
          const SizedBox(height: 8),
          Text('Just the logic.', style: GsText.headline.copyWith(color: c.ink, fontSize: 24)),
          const SizedBox(height: 8),
          Text('Plain Sudoku, without a hidden word. Place each numeral once in every row, column and 3 × 3 box.',
              style: GsText.body.copyWith(color: c.inkSecondary)),
          const SizedBox(height: 20),
          Text('Choose your numerals', style: GsText.bodyStrong.copyWith(color: c.ink)),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(
              child: radioRow(_symbols == SymbolSet.geez, 'Ge’ez', null,
                  () => setState(() => _symbols = SymbolSet.geez)),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: radioRow(_symbols == SymbolSet.arabic, 'Arabic', null,
                  () => setState(() => _symbols = SymbolSet.arabic)),
            ),
          ]),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: c.goldSoft, borderRadius: BorderRadius.circular(8)),
            child: Column(children: [
              Text((_symbols == SymbolSet.geez ? kGeezNumerals : kArabicDigits).join('  '),
                  style: GsText.fidel(20).copyWith(color: const Color(0xFF1D2433))),
              Text(_symbols == SymbolSet.geez
                      ? 'Same values as 1–9, a different script.'
                      : 'The familiar digits 1–9.',
                  style: GsText.micro.copyWith(color: const Color(0xFF5E6678))),
            ]),
          ),
          const SizedBox(height: 20),
          Text('Difficulty', style: GsText.bodyStrong.copyWith(color: c.ink)),
          const SizedBox(height: 8),
          for (final (g, sub) in const [
            (DifficultyGrade.easy, 'A gentle start'),
            (DifficultyGrade.medium, 'Find your rhythm'),
            (DifficultyGrade.hard, 'A deeper challenge'),
            (DifficultyGrade.expert, 'For focused minds'),
          ])
            radioRow(_grade == g, gradeLabel(g), sub, () => setState(() => _grade = g)),
          const SizedBox(height: 16),
          PrimaryButton(
            label: 'Start classic puzzle',
            onPressed: () {
              final cfg = ref.read(puzzleBankProvider).classic(
                    grade: _grade,
                    symbols: _symbols,
                    avoid: ref.read(progressProvider).recentPuzzles,
                  );
              context.pushReplacement('/play', extra: PlayArgs.start(cfg));
            },
          ),
        ],
      ),
    );
  }
}

// ───────────────────────── Shop ─────────────────────────

class ShopScreen extends ConsumerWidget {
  const ShopScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.gs;
    final coins = ref.watch(progressProvider).coins;
    Widget priced(String title, String sub) => GsCard(
          padding: const EdgeInsets.all(12),
          onTap: () => showPurchaseUnavailable(context),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: GsText.bodyStrong.copyWith(color: c.ink)),
            Row(children: [
              Expanded(child: Text(sub, style: GsText.micro.copyWith(color: c.inkSecondary))),
              Text('\$—', style: GsText.caption.copyWith(color: c.primary)),
            ]),
          ]),
        );

    return Scaffold(
      appBar: GsAppBar(
        title: const Text('Shop'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Text('$coins coins',
                  style: GsText.caption.copyWith(color: c.gold, fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          GsCard(
            onTap: () => showPurchaseUnavailable(context),
            child: Row(children: [
              Icon(Icons.shield_outlined, color: c.primary),
              const SizedBox(width: 16),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Remove ads', style: GsText.bodyStrong.copyWith(color: c.ink)),
                  Text('One purchase. A quieter puzzle.',
                      style: GsText.caption.copyWith(color: c.inkSecondary)),
                ]),
              ),
              Text('\$—', style: GsText.caption.copyWith(color: c.primary)),
            ]),
          ),
          const SizedBox(height: 12),
          Text('Hint packs', style: GsText.bodyStrong.copyWith(color: c.ink)),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: priced('Small', '5 hints')),
            const SizedBox(width: 8),
            Expanded(child: priced('Everyday', '15 hints')),
            const SizedBox(width: 8),
            Expanded(child: priced('Generous', '40 hints')),
          ]),
          const SizedBox(height: 12),
          Text('Word packs', style: GsText.bodyStrong.copyWith(color: c.ink)),
          const SizedBox(height: 8),
          Row(children: [
            for (final t in [WordTheme.proverbs, WordTheme.holidays]) ...[
              if (t == WordTheme.holidays) const SizedBox(width: 8),
              Expanded(
                child: GsCard(
                  padding: EdgeInsets.zero,
                  onTap: () => context.go('/packs/${t.name}'),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Image.asset(t.image, height: 56, width: double.infinity,
                        fit: BoxFit.cover, cacheWidth: 400),
                    Padding(
                      padding: const EdgeInsets.all(8),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(t.label, style: GsText.bodyStrong.copyWith(color: c.ink)),
                        Text('Included · ${WordBank.forTheme(t).length} words',
                            style: GsText.micro.copyWith(color: c.inkSecondary)),
                      ]),
                    ),
                  ]),
                ),
              ),
            ],
          ]),
          const SizedBox(height: 12),
          Text('Board themes', style: GsText.bodyStrong.copyWith(color: c.ink)),
          const SizedBox(height: 8),
          Row(children: [
            for (final (mode, label) in const [
              (GsThemeMode.parchment, 'Parchment'),
              (GsThemeMode.light, 'Light'),
              (GsThemeMode.dark, 'Dark'),
            ]) ...[
              if (mode != GsThemeMode.parchment) const SizedBox(width: 8),
              Expanded(
                child: GsCard(
                  padding: const EdgeInsets.all(8),
                  onTap: () => ref
                      .read(settingsProvider.notifier)
                      .update((s) => s.copyWith(theme: mode)),
                  child: Column(children: [
                    Theme(
                      data: Theme.of(context).copyWith(extensions: [
                        switch (mode) {
                          GsThemeMode.dark => GsColors.dark,
                          GsThemeMode.parchment => GsColors.parchment,
                          _ => GsColors.light,
                        },
                      ]),
                      child: const MiniGrid(size: GridSize.nine, dimension: 64),
                    ),
                    const SizedBox(height: 4),
                    Text(label, style: GsText.caption.copyWith(color: c.ink)),
                    Text('Included', style: GsText.micro.copyWith(color: c.inkSecondary)),
                  ]),
                ),
              ),
            ],
          ]),
          const SizedBox(height: 12),
          GsCard(
            onTap: () => showAdUnavailable(context),
            child: Row(children: [
              Icon(Icons.play_arrow, color: c.primary),
              const SizedBox(width: 16),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Watch an ad · +1 free hint',
                      style: GsText.bodyStrong.copyWith(color: c.ink)),
                  Text('Rewards need an ad connection',
                      style: GsText.caption.copyWith(color: c.inkSecondary)),
                ]),
              ),
            ]),
          ),
          const SizedBox(height: 12),
          SecondaryButton(
            label: 'Restore purchases',
            onPressed: () => showPurchaseUnavailable(context),
          ),
          const SizedBox(height: 8),
          Center(
            child: Text('\$— = placeholder price. Final prices shown by store.',
                style: GsText.micro.copyWith(color: c.inkSecondary)),
          ),
        ],
      ),
    );
  }
}

// ───────────────────────── Settings ─────────────────────────

class _Segmented<T> extends StatelessWidget {
  const _Segmented({
    required this.values,
    required this.labels,
    required this.selected,
    required this.onChanged,
  });

  final List<T> values;
  final List<String> labels;
  final T selected;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.gs;
    return Row(children: [
      for (final (i, v) in values.indexed)
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 1),
            child: Material(
              color: v == selected ? c.primary : c.tonal,
              borderRadius: BorderRadius.circular(20),
              child: InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: () => onChanged(v),
                child: SizedBox(
                  height: 36,
                  child: Center(
                    child: Text(labels[i],
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GsText.caption.copyWith(
                            fontSize: 13,
                            color: v == selected ? c.onPrimary : c.onTonal)),
                  ),
                ),
              ),
            ),
          ),
        ),
    ]);
  }
}

class _SwitchTile extends StatelessWidget {
  const _SwitchTile(this.title, this.subtitle, this.value, this.onChanged);
  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.gs;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GsCard(
        borderColor: Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        onTap: () => onChanged(!value),
        child: Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: GsText.body.copyWith(fontSize: 15, color: c.ink)),
              if (subtitle != null)
                Text(subtitle!, style: GsText.micro.copyWith(color: c.inkSecondary)),
            ]),
          ),
          Switch(value: value, onChanged: onChanged),
        ]),
      ),
    );
  }
}

class GameplaySettingsScreen extends ConsumerWidget {
  const GameplaySettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.gs;
    final s = ref.watch(settingsProvider);
    void set(Settings Function(Settings) f) =>
        ref.read(settingsProvider.notifier).update(f);

    return Scaffold(
      appBar: const GsAppBar(title: Text('Gameplay')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Mistake limit', style: GsText.bodyStrong.copyWith(color: c.ink)),
          const SizedBox(height: 8),
          _Segmented(
            values: MistakeLimit.values,
            labels: const ['3', 'No limit', 'Hide mistakes'],
            selected: s.mistakeLimit,
            onChanged: (v) => set((x) => x.copyWith(mistakeLimit: v)),
          ),
          const SizedBox(height: 8),
          Text('Three chances per puzzle. Hiding mistakes also hides the counter.',
              style: GsText.micro.copyWith(color: c.inkSecondary)),
          const SizedBox(height: 12),
          _SwitchTile('Easy word row', 'Highlight the hidden-word row on Easy',
              s.easyWordRow, (v) => set((x) => x.copyWith(easyWordRow: v))),
          _SwitchTile('Auto-remove notes', 'Clear matching notes after placing a fidel',
              s.autoRemoveNotes, (v) => set((x) => x.copyWith(autoRemoveNotes: v))),
          _SwitchTile('Highlight duplicates', 'Show conflicts in a row, column or box',
              s.highlightDuplicates, (v) => set((x) => x.copyWith(highlightDuplicates: v))),
          _SwitchTile('Highlight same fidel', 'Find every matching letter on the board',
              s.highlightSameFidel, (v) => set((x) => x.copyWith(highlightSameFidel: v))),
          _SwitchTile('Pronunciation on long press', 'Hold a fidel to see its sound',
              s.pronunciation, (v) => set((x) => x.copyWith(pronunciation: v))),
          _SwitchTile('Auto-notes', 'Long-press Notes to fill every candidate (1 hint on Hard and Expert)',
              s.autoNotes, (v) => set((x) => x.copyWith(autoNotes: v))),
          _SwitchTile('Learning hints', 'Show Arabic digits small in Ge’ez numeral cells',
              s.learningHints, (v) => set((x) => x.copyWith(learningHints: v))),
          _SwitchTile('Show timer', null, s.showTimer,
              (v) => set((x) => x.copyWith(showTimer: v))),
          const SizedBox(height: 8),
          Text('Input order', style: GsText.bodyStrong.copyWith(color: c.ink)),
          const SizedBox(height: 8),
          _Segmented(
            values: InputOrder.values,
            labels: const ['Cell first', 'Letter first'],
            selected: s.inputOrder,
            onChanged: (v) => set((x) => x.copyWith(inputOrder: v)),
          ),
          const SizedBox(height: 8),
          Text(
            s.inputOrder == InputOrder.cellFirst
                ? 'Choose a cell, then tap a fidel to place it.'
                : 'Choose a fidel, then tap cells to place it.',
            style: GsText.micro.copyWith(color: c.inkSecondary),
          ),
          const SizedBox(height: 16),
          GsCard(
            onTap: () => context.push('/settings/appearance'),
            child: Row(children: [
              Expanded(
                child: Text('Appearance & other',
                    style: GsText.body.copyWith(fontSize: 15, color: c.ink)),
              ),
              Icon(Icons.chevron_right, color: c.primary),
            ]),
          ),
        ],
      ),
    );
  }
}

class AppearanceSettingsScreen extends ConsumerWidget {
  const AppearanceSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.gs;
    final s = ref.watch(settingsProvider);
    void set(Settings Function(Settings) f) =>
        ref.read(settingsProvider.notifier).update(f);

    Widget link(IconData icon, String label, VoidCallback onTap) => InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            child: Row(children: [
              Icon(icon, color: c.primary, size: 20),
              const SizedBox(width: 12),
              Expanded(child: Text(label, style: GsText.body.copyWith(fontSize: 15, color: c.ink))),
              Icon(Icons.chevron_right, size: 18, color: c.inkSecondary),
            ]),
          ),
        );

    return Scaffold(
      appBar: const GsAppBar(title: Text('Appearance & other')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Theme', style: GsText.bodyStrong.copyWith(color: c.ink)),
          const SizedBox(height: 8),
          _Segmented(
            values: const [GsThemeMode.light, GsThemeMode.dark, GsThemeMode.parchment, GsThemeMode.system],
            labels: const ['Light', 'Dark', 'Parchment', 'System'],
            selected: s.theme,
            onChanged: (v) => set((x) => x.copyWith(theme: v)),
          ),
          const SizedBox(height: 16),
          Row(children: [
            SizedBox(
              width: 90,
              child: Text('Fidel size', style: GsText.body.copyWith(fontSize: 15, color: c.ink)),
            ),
            Expanded(
              child: _Segmented(
                values: const [false, true],
                labels: const ['Normal', 'Large'],
                selected: s.largeFidel,
                onChanged: (v) => set((x) => x.copyWith(largeFidel: v)),
              ),
            ),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
              child: _SwitchTile('Sound', null, s.sound,
                  (v) => set((x) => x.copyWith(sound: v))),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _SwitchTile('Vibration', null, s.vibration,
                  (v) => set((x) => x.copyWith(vibration: v))),
            ),
          ]),
          _SwitchTile('Daily reminder', 'One reminder at 7:00 PM if today’s puzzle is unsolved',
              s.dailyReminder, (v) => set((x) => x.copyWith(dailyReminder: v))),
          _SwitchTile('Ethiopian dates in Ge’ez numerals', 'ጥቅምት ፱ instead of ጥቅምት 9',
              s.geezDates, (v) => set((x) => x.copyWith(geezDates: v))),
          if (kAmharicUiEnabled) ...[
            const SizedBox(height: 8),
            Text('Language', style: GsText.bodyStrong.copyWith(color: c.ink)),
            const SizedBox(height: 8),
            _Segmented(
              values: const ['en', 'am'],
              labels: const ['English', 'አማርኛ'],
              selected: 'en',
              onChanged: (v) {
                if (v == 'am') {
                  showToast(context, 'The Amharic interface is coming in a later version.');
                }
              },
            ),
          ],
          const SizedBox(height: 16),
          Text('Help & information', style: GsText.bodyStrong.copyWith(color: c.ink)),
          const SizedBox(height: 8),
          GsCard(
            padding: EdgeInsets.zero,
            borderColor: Colors.transparent,
            child: Column(children: [
              link(Icons.menu_book_outlined, 'How to play', () => context.push('/help')),
              link(Icons.flag_outlined, 'Report word', () => context.push('/report/s9a')),
              if (kMonetizationEnabled)
                link(Icons.storefront_outlined, 'Shop', () => context.push('/shop')),
              link(Icons.shield_outlined, 'Privacy', () => context.push('/legal/privacy')),
              link(Icons.description_outlined, 'Terms', () => context.push('/legal/terms')),
              link(Icons.replay, 'Replay introduction', () {
                ref.read(settingsProvider.notifier).update((x) => x.copyWith(onboarded: false));
                context.go('/welcome');
              }),
            ]),
          ),
          const SizedBox(height: 12),
          Center(
            child: Text('Ge’ez Sudoku · Version 1.0.0',
                style: GsText.micro.copyWith(color: c.inkSecondary)),
          ),
          Center(
            child: Text('A little logic. A little language.',
                style: GsText.micro.copyWith(color: c.inkSecondary)),
          ),
        ],
      ),
    );
  }
}

// ───────────────────────── Help ─────────────────────────

class HowToPlayScreen extends StatelessWidget {
  const HowToPlayScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.gs;
    Widget card(Widget art, String title, String body) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: GsCard(
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              SizedBox(width: 88, child: art),
              const SizedBox(width: 16),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(title, style: GsText.bodyStrong.copyWith(color: c.ink, fontSize: 15)),
                  const SizedBox(height: 4),
                  Text(body, style: GsText.caption.copyWith(color: c.inkSecondary)),
                ]),
              ),
            ]),
          ),
        );
    return Scaffold(
      appBar: const GsAppBar(title: Text('How to play')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          card(const SizedBox(width: 72, child: DemoBoard()), 'One fidel, one place',
              'Each row, column and box needs every fidel exactly once, with no repeats.'),
          card(const SizedBox(width: 72, child: DemoBoard(highlightRow: 1)), 'Find the hidden word',
              'Fidel replace digits. Solve the board to reveal a word from the theme in one row.'),
          card(
            Text('ሁ ማ ሪ\nበ ተ ች\nና ዝ ጎ',
                style: GsText.fidel(18).copyWith(color: c.primary, height: 1.4)),
            'Guess early, earn a bonus',
            'Arrange the letters before you finish. A correct early guess earns +50 coins.',
          ),
          card(
            Container(
              height: 64,
              decoration: BoxDecoration(
                color: c.tonal,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: c.primary),
              ),
              alignment: Alignment.center,
              child: Text('ሁ  ተ\nሪ  ና', style: GsText.fidel(14).copyWith(color: c.primary)),
            ),
            'Make room for possibilities',
            'Use Notes for candidates. A Hint explains the next step, not just the answer.',
          ),
          PrimaryButton(
            label: 'Back to puzzle',
            onPressed: () => context.canPop() ? context.pop() : context.go('/'),
          ),
        ],
      ),
    );
  }
}

class ReportWordScreen extends ConsumerStatefulWidget {
  const ReportWordScreen({super.key, required this.wordId});
  final String wordId;

  @override
  ConsumerState<ReportWordScreen> createState() => _ReportWordScreenState();
}

class _ReportWordScreenState extends ConsumerState<ReportWordScreen> {
  String _reason = 'Wrong spelling';
  final _details = TextEditingController();

  @override
  void dispose() {
    _details.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.gs;
    final word = WordBank.byId(widget.wordId) ?? WordBank.all.last;
    return Scaffold(
      appBar: const GsAppBar(title: Text('Report word')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          GsCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(word.word, style: GsText.fidel(22).copyWith(color: c.ink)),
              Text(word.meaning, style: GsText.body.copyWith(color: c.ink)),
              Text('${word.theme.label} · From your collection',
                  style: GsText.caption.copyWith(color: c.inkSecondary)),
            ]),
          ),
          const SizedBox(height: 16),
          Text('Help us care for the words. What needs a closer look?',
              style: GsText.body.copyWith(fontSize: 15, color: c.inkSecondary)),
          const SizedBox(height: 8),
          GsCard(
            padding: const EdgeInsets.symmetric(vertical: 4),
            borderColor: Colors.transparent,
            child: RadioGroup<String>(
              groupValue: _reason,
              onChanged: (v) => setState(() => _reason = v ?? _reason),
              child: Column(children: [
                for (final r in const ['Wrong spelling', 'Wrong meaning', 'Offensive', 'Other'])
                  RadioListTile<String>(value: r, title: Text(r)),
              ]),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _details,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: 'Details (optional)',
              hintText: 'Add a little more detail',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 4),
          Text("Please don't include personal information.",
              style: GsText.micro.copyWith(color: c.inkSecondary)),
          const SizedBox(height: 16),
          PrimaryButton(
            label: 'Send',
            onPressed: () {
              final text = 'Word report — ${word.id} ${word.word}\n'
                  'Reason: $_reason\n${_details.text}'.trim();
              ref.read(progressProvider.notifier).addReport();
              PlatformBridge.share(text);
              showToast(context, 'Thank you. Every report is a chance to improve.');
              context.pop();
            },
          ),
          const SizedBox(height: 8),
          SecondaryButton(label: 'Cancel', onPressed: () => context.pop()),
          const SizedBox(height: 12),
          Center(
            child: Text('Thank you. Every report is a chance to improve.',
                style: GsText.micro.copyWith(color: c.inkSecondary)),
          ),
        ],
      ),
    );
  }
}

class LegalScreen extends StatelessWidget {
  const LegalScreen({super.key, required this.kind});
  final String kind;

  @override
  Widget build(BuildContext context) {
    final c = context.gs;
    final privacy = kind == 'privacy';
    return Scaffold(
      appBar: GsAppBar(title: Text(privacy ? 'Privacy' : 'Terms')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(
            privacy
                ? 'Ge’ez Sudoku works offline. Your puzzles, statistics, collection and '
                    'settings are stored only on this device. The app has no account, '
                    'no analytics and no advertising SDK in this version.\n\n'
                    'Pronunciation uses your device’s built-in text-to-speech engine. '
                    'The app does not record audio.\n\n'
                    'Word reports open your device’s share sheet; nothing is sent '
                    'unless you choose an app to send it with.'
                : 'Ge’ez Sudoku is provided as is, for learning and enjoyment. Word '
                    'meanings are short glosses and may simplify the Amharic.',
            style: GsText.body.copyWith(color: c.ink),
          ),
          if (privacy) ...[
            const SizedBox(height: 24),
            SecondaryButton(
              label: 'Read the full privacy policy',
              onPressed: () async {
                if (await PlatformBridge.openUrl(kPrivacyPolicyUrl)) return;
                await Clipboard.setData(const ClipboardData(text: kPrivacyPolicyUrl));
                if (context.mounted) showToast(context, 'Link copied: $kPrivacyPolicyUrl');
              },
            ),
            const SizedBox(height: 8),
            SelectableText(kPrivacyPolicyUrl,
                style: GsText.caption.copyWith(color: c.inkSecondary)),
          ],
        ],
      ),
    );
  }
}
