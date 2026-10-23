import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/gs_colors.dart';
import '../../data/progress.dart';
import '../../services/audio.dart';
import '../../widgets/gs_widgets.dart';
import 'lessons.dart';

class LearnScreen extends ConsumerWidget {
  const LearnScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.gs;
    final lessons = ref.watch(progressProvider).lessons;
    final started = lessons.length;
    final done = lessons.values.where((v) => v == 'done').length;

    return Scaffold(
      appBar: const GsAppBar(title: Text('Learn fidel')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('A little language, every day',
              style: GsText.headline.copyWith(color: c.ink)),
          const SizedBox(height: 8),
          Text('Short lessons to help you read the letters on your board.',
              style: GsText.body.copyWith(color: c.inkSecondary)),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: c.tonal,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(children: [
              Icon(Icons.school_outlined, color: c.primary),
              const SizedBox(width: 16),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Your fidel journey',
                    style: GsText.bodyStrong.copyWith(color: c.ink)),
                Text(
                  done > 0
                      ? '$done of ${kLessons.length} lessons complete'
                      : '$started of ${kLessons.length} lessons started',
                  style: GsText.caption.copyWith(color: c.inkSecondary),
                ),
              ]),
            ]),
          ),
          const SizedBox(height: 12),
          for (final l in kLessons)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: GsCard(
                onTap: () => context.push('/lesson/${l.id}'),
                child: Row(children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: c.goldSoft,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    alignment: Alignment.center,
                    child: Text(l.icon,
                        style: GsText.fidel(l.icon.length > 2 ? 16 : 20)
                            .copyWith(color: const Color(0xFF1D2433))),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(l.title, style: GsText.bodyStrong.copyWith(color: c.ink)),
                      Text(l.meta, style: GsText.micro.copyWith(color: c.inkSecondary)),
                      Text(
                        switch (lessons[l.id]) {
                          'done' => 'Completed · Review',
                          'started' => 'Continue lesson',
                          _ => 'Start lesson',
                        },
                        style: GsText.caption.copyWith(color: c.primary),
                      ),
                    ]),
                  ),
                  Icon(Icons.chevron_right, color: c.primary),
                ]),
              ),
            ),
        ],
      ),
    );
  }
}

class LessonScreen extends ConsumerStatefulWidget {
  const LessonScreen({super.key, required this.lesson});
  final Lesson lesson;

  @override
  ConsumerState<LessonScreen> createState() => _LessonScreenState();
}

class _LessonScreenState extends ConsumerState<LessonScreen> {
  late int _selected = widget.lesson.items.length - 1;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) =>
        ref.read(progressProvider.notifier).setLesson(widget.lesson.id, 'started'));
  }

  @override
  Widget build(BuildContext context) {
    final c = context.gs;
    final l = widget.lesson;
    final index = kLessons.indexOf(l) + 1;
    final item = l.items[_selected];
    return Scaffold(
      appBar: GsAppBar(title: Text(l.title)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('LESSON $index · READ & LISTEN',
              style: GsText.caption.copyWith(color: c.inkSecondary, letterSpacing: 0.4)),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: (_selected + 1) / l.items.length,
              minHeight: 4,
            ),
          ),
          const SizedBox(height: 20),
          Text(l.heading, style: GsText.headline.copyWith(color: c.ink, fontSize: 24)),
          const SizedBox(height: 8),
          Text(l.intro, style: GsText.body.copyWith(color: c.inkSecondary)),
          const SizedBox(height: 16),
          SizedBox(
            height: 92,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: l.items.length,
              separatorBuilder: (_, __) => const SizedBox(width: 4),
              itemBuilder: (context, i) {
                final it = l.items[i];
                final sel = i == _selected;
                return GestureDetector(
                  onTap: () => setState(() => _selected = i),
                  child: Container(
                    width: it.glyph.runes.length > 2 ? 76 : 44,
                    decoration: BoxDecoration(
                      color: sel ? c.goldSoft : c.surface,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Column(children: [
                      Expanded(
                        child: FittedBox(
                          child: Text(it.glyph,
                              style: GsText.fidel(26).copyWith(
                                  color: sel ? const Color(0xFF1D2433) : c.ink)),
                        ),
                      ),
                      Text(it.label,
                          maxLines: 1,
                          style: GsText.micro.copyWith(
                              color: sel ? const Color(0xFF5E6678) : c.inkSecondary)),
                      Text('${i + 1}',
                          style: GsText.micro.copyWith(
                              fontSize: 9,
                              color: sel ? const Color(0xFF5E6678) : c.inkSecondary)),
                    ]),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          GsCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Container(
                  constraints: const BoxConstraints(minWidth: 72),
                  height: 72,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    color: c.goldSoft,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  alignment: Alignment.center,
                  child: Text(item.glyph,
                      style: GsText.fidel(item.glyph.runes.length > 2 ? 22 : 36)
                          .copyWith(color: const Color(0xFF1D2433))),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(item.label, style: GsText.headline.copyWith(color: c.ink)),
                    Text(item.detail,
                        style: GsText.caption.copyWith(color: c.inkSecondary)),
                  ]),
                ),
                IconButton(
                  tooltip: 'Pronunciation',
                  icon: Icon(Icons.volume_up_outlined, color: c.primary),
                  onPressed: () => GameAudio.speak(item.glyph, fallback: item.say),
                ),
              ]),
              const SizedBox(height: 8),
              Text('Read the sound, then say it aloud.',
                  style: GsText.caption.copyWith(color: c.primary)),
            ]),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: c.tonal,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(l.tipTitle, style: GsText.bodyStrong.copyWith(color: c.ink)),
              const SizedBox(height: 4),
              Text(l.tip, style: GsText.caption.copyWith(color: c.inkSecondary)),
            ]),
          ),
          const SizedBox(height: 24),
          PrimaryButton(
            label: 'Try a quick quiz',
            onPressed: () => context.pushReplacement('/lesson/${l.id}/quiz'),
          ),
        ],
      ),
    );
  }
}

class QuizScreen extends ConsumerStatefulWidget {
  const QuizScreen({super.key, required this.lesson});
  final Lesson lesson;

  @override
  ConsumerState<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends ConsumerState<QuizScreen> {
  int _q = 0;
  String? _choice;

  QuizQuestion get _question => widget.lesson.questions[_q];
  bool get _answered => _choice != null;
  bool get _correct => _choice == _question.answer;

  void _continue() {
    if (_q + 1 < widget.lesson.questions.length) {
      setState(() {
        _q++;
        _choice = null;
      });
    } else {
      ref.read(progressProvider.notifier).setLesson(widget.lesson.id, 'done');
      context.pushReplacement('/lesson/${widget.lesson.id}/done');
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.gs;
    final l = widget.lesson;
    final q = _question;
    final total = l.questions.length;

    Color panelBg = c.tonal;
    String panelTitle = 'Look closely at the shape';
    Color panelInk = c.primary;
    String panelBody = 'You have seen these in the lesson. Take your time and choose one.';
    if (_answered && _correct) {
      panelBg = c.guessed;
      panelTitle = 'That’s right!';
      panelInk = c.guessedInk;
      panelBody = q.explain;
    } else if (_answered) {
      panelBg = c.errorBg;
      panelTitle = 'Not quite — try once more';
      panelInk = c.error;
      panelBody = q.explain;
    }

    return Scaffold(
      appBar: const GsAppBar(title: Text('Quick quiz')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(children: [
            Expanded(
              child: Text(l.quizName,
                  style: GsText.caption.copyWith(color: c.inkSecondary)),
            ),
            Text('${_q + 1} / $total',
                style: GsText.caption.copyWith(color: c.inkSecondary)),
          ]),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(value: (_q + 1) / total, minHeight: 4),
          ),
          const SizedBox(height: 32),
          Text(q.prompt, style: GsText.headline.copyWith(fontSize: 28, height: 1.25, color: c.ink)),
          if (q.sound != null)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                style: TextButton.styleFrom(padding: EdgeInsets.zero),
                onPressed: () => GameAudio.speak(
                    _glyphFor(q) ?? q.sound!, fallback: q.sound),
                icon: const Icon(Icons.volume_up_outlined, size: 18),
                label: Text('Listen to the sound', style: GsText.caption),
              ),
            ),
          const SizedBox(height: 16),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.3,
            children: [
              for (final o in q.options)
                _Option(
                  glyph: o,
                  state: !_answered
                      ? _OptState.idle
                      : o == q.answer
                          ? _OptState.correct
                          : o == _choice
                              ? _OptState.wrong
                              : _OptState.idle,
                  onTap: _answered ? null : () => setState(() => _choice = o),
                ),
            ],
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: panelBg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(panelTitle, style: GsText.bodyStrong.copyWith(color: panelInk)),
              const SizedBox(height: 6),
              Text(panelBody, style: GsText.body.copyWith(color: c.inkSecondary)),
            ]),
          ),
          const SizedBox(height: 24),
          if (!_answered)
            const TonalButton(label: 'Choose an answer')
          else if (_correct)
            PrimaryButton(label: 'Continue', onPressed: _continue)
          else
            PrimaryButton(
              label: 'Try again',
              onPressed: () => setState(() => _choice = null),
            ),
        ],
      ),
    );
  }
}

/// The fidel whose sound the question asks for (spoken by the speaker).
String? _glyphFor(QuizQuestion q) => q.sound == null ? null : q.answer;

enum _OptState { idle, correct, wrong }

class _Option extends StatelessWidget {
  const _Option({required this.glyph, required this.state, this.onTap});
  final String glyph;
  final _OptState state;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.gs;
    final (bg, border, ink, label) = switch (state) {
      _OptState.correct => (c.guessed, c.guessedInk, c.guessedInk, '✓ Correct'),
      _OptState.wrong => (c.errorBg, c.error, c.error, '× Your answer'),
      _OptState.idle => (c.surface, c.outline, c.ink, 'Tap to choose'),
    };
    return Material(
      color: bg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: border, width: state == _OptState.idle ? 1 : 1.5),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          FittedBox(
            child: Text(glyph,
                style: GsText.fidel(34).copyWith(
                    color: state == _OptState.idle ? c.ink : ink)),
          ),
          const SizedBox(height: 4),
          Text(label, style: GsText.micro.copyWith(color: state == _OptState.idle ? c.inkSecondary : ink)),
        ]),
      ),
    );
  }
}

class LessonCompleteScreen extends StatelessWidget {
  const LessonCompleteScreen({super.key, required this.lesson});
  final Lesson lesson;

  @override
  Widget build(BuildContext context) {
    final c = context.gs;
    return Scaffold(
      appBar: const GsAppBar(title: Text('Lesson complete')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Center(
            child: Container(
              width: 160,
              height: 160,
              decoration: BoxDecoration(
                color: c.goldSoft,
                shape: BoxShape.circle,
                border: Border.all(color: c.gold),
              ),
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(Icons.school_outlined, color: c.gold, size: 32),
                const SizedBox(height: 4),
                Text(lesson.items.last.glyph.runes.length > 2 ? lesson.items.first.glyph : lesson.items.last.glyph,
                    style: GsText.fidel(30).copyWith(color: const Color(0xFF2F4A9E))),
                const SizedBox(height: 4),
                Text(lesson.badge,
                    style: GsText.micro.copyWith(
                        color: const Color(0xFF2F4A9E), fontWeight: FontWeight.w600)),
              ]),
            ),
          ),
          const SizedBox(height: 24),
          Text(lesson.doneTitle,
              textAlign: TextAlign.center,
              style: GsText.headline.copyWith(color: c.ink, fontSize: 26)),
          const SizedBox(height: 12),
          Text(lesson.doneBody,
              textAlign: TextAlign.center,
              style: GsText.body.copyWith(color: c.inkSecondary)),
          const SizedBox(height: 24),
          GsCard(
            borderColor: Colors.transparent,
            child: Row(children: [
              Expanded(
                child: Column(children: [
                  Text('${lesson.items.length}',
                      style: GsText.titleSmall.copyWith(color: c.ink)),
                  Text('Forms explored',
                      style: GsText.caption.copyWith(color: c.inkSecondary)),
                ]),
              ),
              Expanded(
                child: Column(children: [
                  Text('${lesson.questions.length} / ${lesson.questions.length}',
                      style: GsText.titleSmall.copyWith(color: c.ink)),
                  Text('Quiz complete',
                      style: GsText.caption.copyWith(color: c.inkSecondary)),
                ]),
              ),
            ]),
          ),
          const SizedBox(height: 24),
          PrimaryButton(label: 'Back to learn', onPressed: () => context.go('/learn')),
          const SizedBox(height: 12),
          TonalButton(label: 'Home', onPressed: () => context.go('/')),
          const SizedBox(height: 24),
          Text('Keep noticing the shapes as you play.',
              textAlign: TextAlign.center,
              style: GsText.caption.copyWith(color: c.inkSecondary)),
        ],
      ),
    );
  }
}
