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
import '../../widgets/gs_widgets.dart';
import '../board/board_screen.dart';

int _solvedInMonth(Progress p, EthiopicDate month) {
  final first = month.firstOfMonth.toGregorian();
  int n = 0;
  for (int d = 0; d < month.monthLength; d++) {
    if (p.daily.containsKey(dayKey(first.add(Duration(days: d))))) n++;
  }
  return n;
}

class DailyCalendarScreen extends ConsumerStatefulWidget {
  const DailyCalendarScreen({super.key});

  @override
  ConsumerState<DailyCalendarScreen> createState() => _DailyCalendarScreenState();
}

class _DailyCalendarScreenState extends ConsumerState<DailyCalendarScreen> {
  late EthiopicDate _month;
  late DateTime _selected;

  @override
  void initState() {
    super.initState();
    _selected = dateOnly(DateTime.now());
    _month = EthiopicDate.fromGregorian(_selected).firstOfMonth;
  }

  @override
  Widget build(BuildContext context) {
    final c = context.gs;
    final progress = ref.watch(progressProvider);
    final geez = ref.watch(settingsProvider.select((s) => s.geezDates));
    final today = dateOnly(DateTime.now());
    final first = _month.toGregorian();
    final last = first.add(Duration(days: _month.monthLength - 1));
    final solved = _solvedInMonth(progress, _month);
    final leading = first.weekday % 7; // Sunday = 0
    final isCurrentMonth = _month == EthiopicDate.fromGregorian(today).firstOfMonth;

    return Scaffold(
      appBar: const GsAppBar(title: Text('Daily calendar'), showBack: false),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          Row(children: [
            IconButton(
              tooltip: 'Previous month',
              icon: Icon(Icons.arrow_back, color: c.primary),
              onPressed: () => setState(() => _month = _month.addMonths(-1)),
            ),
            Expanded(
              child: Column(children: [
                Text(_month.monthYear(geez: geez),
                    style: GsText.fidel(22, weight: FontWeight.w500).copyWith(color: c.ink)),
                Text('${shortGregorian(first)} – ${longGregorian(last)}',
                    style: GsText.caption.copyWith(color: c.inkSecondary)),
              ]),
            ),
            IconButton(
              tooltip: 'Next month',
              icon: const Icon(Icons.arrow_forward),
              onPressed: isCurrentMonth
                  ? null
                  : () => setState(() => _month = _month.addMonths(1)),
            ),
          ]),
          const SizedBox(height: 8),
          Material(
            color: c.goldSoft,
            borderRadius: BorderRadius.circular(8),
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () => context.go('/daily/trophies'),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(children: [
                  Icon(Icons.emoji_events_outlined, color: c.gold, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text('$solved / ${_month.monthLength} daily puzzles solved',
                        style: GsText.caption.copyWith(
                            color: const Color(0xFF1D2433), fontWeight: FontWeight.w600)),
                  ),
                  const Icon(Icons.arrow_forward, size: 18, color: Color(0xFF1D2433)),
                ]),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(children: [
            for (final d in const ['S', 'M', 'T', 'W', 'T', 'F', 'S'])
              Expanded(
                child: Center(
                  child: Text(d, style: GsText.micro.copyWith(color: c.inkSecondary)),
                ),
              ),
          ]),
          const SizedBox(height: 6),
          GridView.count(
            crossAxisCount: 7,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 8,
            crossAxisSpacing: 6,
            childAspectRatio: 1.35,
            children: [
              for (int i = 0; i < leading; i++) const SizedBox.shrink(),
              for (int d = 0; d < _month.monthLength; d++)
                _DayCell(
                  date: first.add(Duration(days: d)),
                  day: d + 1,
                  today: today,
                  solved: progress.daily.containsKey(dayKey(first.add(Duration(days: d)))),
                  selected: first.add(Duration(days: d)) == _selected,
                  geez: geez,
                  onTap: () => setState(() => _selected = first.add(Duration(days: d))),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text('✓ Solved', style: GsText.micro.copyWith(color: c.gold)),
            Text('○ Today', style: GsText.micro.copyWith(color: c.primary)),
            Text('– Missed', style: GsText.micro.copyWith(color: c.inkSecondary)),
            Text('Future', style: GsText.micro.copyWith(color: c.inkDisabled)),
          ]),
          const SizedBox(height: 16),
          _DayDetail(day: _selected),
          const SizedBox(height: 12),
          Center(
            child: TextButton(
              onPressed: () => context.go('/daily/trophies'),
              child: const Text('View trophy cabinet →'),
            ),
          ),
        ],
      ),
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.date,
    required this.day,
    required this.today,
    required this.solved,
    required this.selected,
    required this.onTap,
    this.geez = false,
  });

  final bool geez;
  final DateTime date;
  final int day;
  final DateTime today;
  final bool solved;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.gs;
    final isToday = date == today;
    final future = date.isAfter(today);
    final missed = !solved && !future && !isToday;
    Color bg = c.surface;
    Color ink = c.ink;
    if (solved) {
      bg = c.goldSoft;
      ink = const Color(0xFF1D2433);
    } else if (missed) {
      bg = c.sunken;
    } else if (future) {
      ink = c.inkDisabled;
    }
    return Material(
      color: bg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: selected || isToday
            ? BorderSide(color: c.primary, width: selected ? 2 : 1.5)
            : BorderSide.none,
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Center(
          child: Text(
            solved
                ? '${EthiopicDate.num(day, geez: geez)} ✓'
                : EthiopicDate.num(day, geez: geez),
            style: GsText.caption.copyWith(
              color: ink,
              decoration: isToday ? TextDecoration.underline : null,
              decorationColor: c.primary,
              decorationThickness: 2,
            ),
          ),
        ),
      ),
    );
  }
}

class _DayDetail extends ConsumerWidget {
  const _DayDetail({required this.day});
  final DateTime day;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.gs;
    final bank = ref.watch(puzzleBankProvider);
    final progress = ref.watch(progressProvider);
    final today = dateOnly(DateTime.now());
    final eth = EthiopicDate.fromGregorian(day);
    final geez = ref.watch(settingsProvider.select((s) => s.geezDates));
    final result = progress.daily[dayKey(day)];
    final word = bank.dailyWord(day);

    if (result != null) {
      final w = WordBank.byId(result.wordId) ?? word;
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.check, size: 16, color: c.guessedInk),
          const SizedBox(width: 4),
          Expanded(
            child: Text('${eth.label(geez: geez)} · Solved',
                style: GsText.caption.copyWith(
                    color: c.guessedInk, fontWeight: FontWeight.w600)),
          ),
          Text(formatClock(result.seconds),
              style: GsText.caption.copyWith(color: c.ink)),
        ]),
        const SizedBox(height: 8),
        RevealCard(word: w),
      ]);
    }

    final future = day.isAfter(today);
    final isToday = day == today;
    return GsCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(
          isToday
              ? 'Today · ${eth.label(geez: geez)} · ${shortGregorian(day)}'
              : '${eth.label(geez: geez)} · ${shortGregorian(day)}',
          style: GsText.titleSmall.copyWith(color: c.ink),
        ),
        const SizedBox(height: 4),
        Text(
          future
              ? 'Not yet. A new word arrives on ${shortGregorian(day)}.'
              : isToday
                  ? '${word.theme.label} · 9 × 9 · Medium'
                  : 'A missed day, a new chance to discover.',
          style: GsText.caption.copyWith(color: c.inkSecondary),
        ),
        if (!future) ...[
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: PrimaryButton(
              label: isToday ? 'Play 9 × 9' : 'Play this day',
              onPressed: () =>
                  context.push('/play', extra: PlayArgs.start(bank.daily(day))),
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: Text('A little logic. A new word, every day.',
                style: GsText.micro.copyWith(color: c.inkSecondary)),
          ),
        ],
      ]),
    );
  }
}

class TrophyCabinetScreen extends ConsumerWidget {
  const TrophyCabinetScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.gs;
    final progress = ref.watch(progressProvider);
    final now = EthiopicDate.fromGregorian(DateTime.now());
    final year = now.year;
    final months = [
      for (int m = 1; m <= 13; m++) EthiopicDate(year, m, 1),
    ];
    final counts = [for (final m in months) _solvedInMonth(progress, m)];
    final earned = [
      for (int i = 0; i < 13; i++) counts[i] >= months[i].monthLength,
    ];
    final earnedCount = earned.where((e) => e).length;

    return Scaffold(
      appBar: const GsAppBar(title: Text('Trophy cabinet')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('${EthiopicDate.num(year, geez: ref.watch(settingsProvider.select((s) => s.geezDates)))} · የዓመቱ ስብስብ',
              style: GsText.fidel(22, weight: FontWeight.w500).copyWith(color: c.ink)),
          const SizedBox(height: 4),
          Text('Thirteen months. A year of small discoveries.',
              style: GsText.caption.copyWith(color: c.inkSecondary)),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: c.goldSoft,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(children: [
              Icon(Icons.emoji_events_outlined, color: c.gold),
              const SizedBox(width: 8),
              Text('$earnedCount earned · ${13 - earnedCount} still to discover',
                  style: GsText.bodyStrong.copyWith(color: const Color(0xFF1D2433))),
            ]),
          ),
          const SizedBox(height: 12),
          GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 1.3,
            children: [
              for (int i = 0; i < 13; i++)
                Container(
                  decoration: BoxDecoration(
                    color: earned[i] ? c.goldSoft : c.surface,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        earned[i] ? Icons.emoji_events_outlined : Icons.lock_outline,
                        color: earned[i] ? c.gold : c.inkDisabled,
                      ),
                      const SizedBox(height: 4),
                      Text(EthiopicDate.monthNames[i],
                          style: GsText.fidel(12, weight: FontWeight.w500).copyWith(
                              color: earned[i] ? const Color(0xFF1D2433) : c.ink)),
                      Text(
                        earned[i]
                            ? '${counts[i]} / ${months[i].monthLength} · Earned'
                            : counts[i] > 0
                                ? '${counts[i]} / ${months[i].monthLength}'
                                : 'Locked',
                        style: GsText.micro.copyWith(
                            color: earned[i]
                                ? const Color(0xFF5E6678)
                                : c.inkSecondary),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Center(
            child: Text(
              'Complete every daily puzzle in a month to earn its trophy.',
              textAlign: TextAlign.center,
              style: GsText.caption.copyWith(color: c.inkSecondary),
            ),
          ),
        ],
      ),
    );
  }
}

/// "Today's puzzle is already solved".
class DailyDoneScreen extends ConsumerWidget {
  const DailyDoneScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.gs;
    final progress = ref.watch(progressProvider);
    final bank = ref.watch(puzzleBankProvider);
    final today = dateOnly(DateTime.now());
    final result = progress.daily[dayKey(today)];
    final word = result == null
        ? bank.dailyWord(today)
        : (WordBank.byId(result.wordId) ?? bank.dailyWord(today));
    final eth = EthiopicDate.fromGregorian(today);
    final first = eth.firstOfMonth.toGregorian();
    final solved = _solvedInMonth(progress, eth);

    return Scaffold(
      appBar: const GsAppBar(title: Text('Daily puzzle')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Center(
            child: CircleAvatar(
              radius: 28,
              backgroundColor: c.tonal,
              child: Icon(Icons.check, color: c.ink),
            ),
          ),
          const SizedBox(height: 12),
          Text("Today's puzzle is already solved",
              textAlign: TextAlign.center,
              style: GsText.title.copyWith(color: c.ink)),
          const SizedBox(height: 4),
          Text('${shortGregorian(today)} · 9 × 9 · Medium',
              textAlign: TextAlign.center,
              style: GsText.caption.copyWith(color: c.inkSecondary)),
          const SizedBox(height: 16),
          GsCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('✓ Word earned · Added to collection',
                  style: GsText.caption.copyWith(color: c.primary, fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              Text(word.word, style: GsText.fidel(22).copyWith(color: c.ink)),
              Text(word.meaning, style: GsText.body.copyWith(color: c.ink)),
              const SizedBox(height: 4),
              Row(children: [
                Expanded(
                  child: Text('${word.theme.label} · ${word.theme.amharic}',
                      style: GsText.caption.copyWith(color: c.inkSecondary)),
                ),
                if (result != null)
                  Text('Time ${formatClock(result.seconds)}',
                      style: GsText.caption.copyWith(
                          color: c.ink, fontWeight: FontWeight.w600)),
              ]),
            ]),
          ),
          const SizedBox(height: 12),
          GsCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(
                  child: Text('Your daily rhythm',
                      style: GsText.bodyStrong.copyWith(color: c.ink)),
                ),
                Text('$solved / ${eth.monthLength}',
                    style: GsText.caption.copyWith(color: c.inkSecondary)),
              ]),
              const SizedBox(height: 8),
              Wrap(spacing: 6, runSpacing: 6, children: [
                for (int d = 0; d < eth.monthLength; d++)
                  Container(
                    width: 36,
                    height: 22,
                    decoration: BoxDecoration(
                      color: progress.daily.containsKey(
                              dayKey(first.add(Duration(days: d))))
                          ? c.tonal
                          : c.sunken,
                      borderRadius: BorderRadius.circular(11),
                    ),
                    alignment: Alignment.center,
                    child: progress.daily
                            .containsKey(dayKey(first.add(Duration(days: d))))
                        ? Icon(Icons.check, size: 12, color: c.primary)
                        : Text('${d + 1}',
                            style: GsText.micro.copyWith(color: c.inkSecondary)),
                  ),
              ]),
            ]),
          ),
          const SizedBox(height: 16),
          PrimaryButton(label: 'Return to daily', onPressed: () => context.go('/daily')),
        ],
      ),
    );
  }
}
