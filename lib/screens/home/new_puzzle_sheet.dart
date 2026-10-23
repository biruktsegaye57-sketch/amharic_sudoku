import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sudoku_core/sudoku_core.dart';

import '../../core/constants/word_bank.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/gs_colors.dart';
import '../../core/utils/ethiopic_calendar.dart';
import '../../data/progress.dart';
import '../../data/puzzle_bank.dart';
import '../../widgets/gs_widgets.dart';
import 'home_screen.dart';

/// "New puzzle" bottom sheet: pace (size), difficulty, theme.
/// Pops with a GameConfig.
class NewPuzzleSheet extends ConsumerStatefulWidget {
  const NewPuzzleSheet({super.key});

  @override
  ConsumerState<NewPuzzleSheet> createState() => _NewPuzzleSheetState();
}

class _NewPuzzleSheetState extends ConsumerState<NewPuzzleSheet> {
  GridSize _size = GridSize.nine;
  DifficultyGrade _grade = DifficultyGrade.medium;
  WordTheme? _theme;

  static const _paces = {
    GridSize.four: 'Quick',
    GridSize.six: 'Relaxed',
    GridSize.nine: 'Classic',
  };

  static const _gradeHints = {
    DifficultyGrade.easy: 'Word row',
    DifficultyGrade.medium: 'Theme',
    DifficultyGrade.hard: 'No clues',
    DifficultyGrade.expert: 'X-wing',
  };

  @override
  Widget build(BuildContext context) {
    final c = context.gs;
    final progress = ref.watch(progressProvider);
    final themes = [
      for (final t in WordTheme.values)
        if (WordBank.forSize(_size, theme: t).isNotEmpty) t,
    ];
    if (_theme != null && !themes.contains(_theme)) _theme = null;

    Widget label(String t) => Padding(
          padding: const EdgeInsets.only(top: 16, bottom: 8),
          child: Text(t, style: GsText.bodyStrong.copyWith(color: c.ink)),
        );

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 32,
                height: 4,
                margin: const EdgeInsets.only(top: 12, bottom: 16),
                decoration: BoxDecoration(
                  color: c.inkDisabled,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Text('New puzzle', style: GsText.title.copyWith(color: c.ink)),
            label('Choose your pace'),
            Row(children: [
              for (final s in GridSize.values) ...[
                if (s != GridSize.four) const SizedBox(width: 8),
                Expanded(
                  child: _Choice(
                    selected: _size == s,
                    onTap: () => setState(() => _size = s),
                    child: Column(children: [
                      Text(sizeTitle(s),
                          style: GsText.titleSmall.copyWith(
                              fontWeight: FontWeight.w500,
                              color: _size == s ? c.primary : c.ink)),
                      Text(_paces[s]!,
                          style: GsText.caption.copyWith(color: c.inkSecondary)),
                    ]),
                  ),
                ),
              ],
            ]),
            label('Difficulty'),
            for (final g in _gradeHints.keys) ...[
              _Choice(
                selected: _grade == g,
                onTap: () => setState(() => _grade = g),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(children: [
                  SizedBox(
                    width: 96,
                    child: Text(gradeName(g),
                        style: GsText.body.copyWith(
                            fontSize: 15,
                            color: _grade == g ? c.primary : c.ink,
                            fontWeight: FontWeight.w500)),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_gradeHints[g]!,
                            style: GsText.caption.copyWith(color: c.ink)),
                        Text(_best(progress, g),
                            style: GsText.micro.copyWith(color: c.inkSecondary)),
                      ],
                    ),
                  ),
                  Icon(
                    _grade == g
                        ? Icons.radio_button_checked
                        : Icons.radio_button_unchecked,
                    size: 18,
                    color: _grade == g ? c.primary : c.inkSecondary,
                  ),
                ]),
              ),
              const SizedBox(height: 8),
            ],
            label('Theme'),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(children: [
                _chip('Any', _theme == null, () => setState(() => _theme = null)),
                for (final t in themes)
                  _chip(t.label, _theme == t, () => setState(() => _theme = t)),
              ]),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: PrimaryButton(
                label: 'Start puzzle',
                onPressed: () {
                  final config = ref.read(puzzleBankProvider).quick(
                        size: _size,
                        grade: _grade,
                        theme: _theme,
                        avoid: progress.recentPuzzles,
                      );
                  Navigator.of(context).pop(config);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _best(Progress p, DifficultyGrade g) {
    final t = bestTime(p, '${_size.n}', g);
    return t == null ? 'Not played' : 'Best ${formatClock(t)}';
  }

  Widget _chip(String text, bool selected, VoidCallback onTap) {
    final c = context.gs;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(text),
        selected: selected,
        onSelected: (_) => onTap(),
        showCheckmark: true,
        checkmarkColor: c.primary,
        selectedColor: c.tonal,
        backgroundColor: c.surface,
        side: BorderSide(color: selected ? c.tonal : c.outline),
        labelStyle: GsText.body.copyWith(
            color: selected ? c.primary : c.ink, fontWeight: FontWeight.w500),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}

String gradeName(DifficultyGrade g) => switch (g) {
      DifficultyGrade.easy => 'Easy',
      DifficultyGrade.medium => 'Medium',
      DifficultyGrade.hard => 'Hard',
      _ => 'Expert',
    };

class _Choice extends StatelessWidget {
  const _Choice({
    required this.selected,
    required this.onTap,
    required this.child,
    this.padding = const EdgeInsets.symmetric(vertical: 12),
  });

  final bool selected;
  final VoidCallback onTap;
  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final c = context.gs;
    return Material(
      color: selected ? c.tonal : c.sunken,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: selected ? c.primary : c.outline),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}
