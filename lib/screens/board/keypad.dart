import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/gs_colors.dart';
import '../../game/game_session.dart';
import '../../game/symbols.dart';

/// One row of N keys in keypad order, with remaining counts.
class Keypad extends StatelessWidget {
  const Keypad({
    super.key,
    required this.session,
    required this.onKey,
    this.onLongPress,
    this.showCounts = true,
    this.enabled = true,
  });

  final GameSession session;
  final ValueChanged<int> onKey;
  final ValueChanged<int>? onLongPress;
  final bool showCounts;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final s = session;
    final n = s.n;
    final gap = n == 9 ? 3.0 : 4.0;
    final height = n == 4 ? 64.0 : 56.0;
    return SizedBox(
      height: height,
      child: Row(children: [
        for (final (k, d) in s.keypadDigits.indexed) ...[
          if (k > 0) SizedBox(width: gap),
          Expanded(
            child: _Key(
              key: ValueKey('key-$d'),
              glyph: s.glyph(d),
              count: s.remaining(d),
              showCount: showCounts,
              notes: s.notesMode,
              armed: s.armedDigit == d,
              enabled: enabled,
              glyphSize: n == 9 ? 22 : 26,
              onTap: () => onKey(d),
              onLongPress: onLongPress == null ? null : () => onLongPress!(d),
            ),
          ),
        ],
      ]),
    );
  }
}

class _Key extends StatefulWidget {
  const _Key({
    super.key,
    required this.glyph,
    required this.count,
    required this.showCount,
    required this.notes,
    required this.armed,
    required this.enabled,
    required this.glyphSize,
    required this.onTap,
    this.onLongPress,
  });

  final String glyph;
  final int count;
  final bool showCount;
  final bool notes;
  final bool armed;
  final bool enabled;
  final double glyphSize;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  @override
  State<_Key> createState() => _KeyState();
}

class _KeyState extends State<_Key> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final c = context.gs;
    final completed = widget.count <= 0;
    final bg = _pressed || widget.armed
        ? c.keyPressed
        : widget.notes
            ? c.surface
            : c.key;
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 200),
      opacity: completed && !widget.notes ? 0.3 : 1,
      child: Semantics(
        button: true,
        label: '${widget.glyph}, ${widget.count} left',
        child: GestureDetector(
          onTapDown: widget.enabled ? (_) => setState(() => _pressed = true) : null,
          onTapUp: widget.enabled ? (_) => setState(() => _pressed = false) : null,
          onTapCancel: () => setState(() => _pressed = false),
          onTap: widget.enabled ? widget.onTap : null,
          onLongPress: widget.enabled ? widget.onLongPress : null,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 100),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(8),
              border: widget.notes
                  ? Border.all(color: c.primary, width: 1.5)
                  : null,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                FittedBox(
                  child: Text(widget.glyph,
                      style: GsText.fidel(widget.glyphSize, weight: FontWeight.w700)
                          .copyWith(color: c.entry, height: 1.15)),
                ),
                if (widget.showCount) ...[
                  const SizedBox(height: 2),
                  Text('${widget.count.clamp(0, 99)}',
                      style: GsText.micro.copyWith(color: c.inkSecondary)),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Undo · Erase · Notes · Hint · Guess word.
class ActionRow extends StatelessWidget {
  const ActionRow({
    super.key,
    required this.session,
    required this.onUndo,
    required this.onErase,
    required this.onNotes,
    required this.onHint,
    this.onGuess,
    this.onNotesLongPress,
  });

  /// Auto-notes (helper; can be turned off in settings).
  final VoidCallback? onNotesLongPress;

  final GameSession session;
  final VoidCallback onUndo;
  final VoidCallback onErase;
  final VoidCallback onNotes;
  final VoidCallback onHint;
  final VoidCallback? onGuess;

  @override
  Widget build(BuildContext context) {
    final s = session;
    final guessEnabled = s.guessesLeft > 0 && !s.wordFound;
    return Row(children: [
      _Action(icon: Icons.undo, label: 'Undo', onTap: s.canUndo ? onUndo : null),
      _Action(icon: Icons.delete, label: 'Erase', onTap: onErase),
      _Action(
        icon: Icons.edit,
        label: s.notesMode ? 'Notes ON' : 'Notes',
        active: s.notesMode,
        onTap: onNotes,
        onLongPress: onNotesLongPress,
      ),
      _Action(
        icon: Icons.lightbulb_outline,
        label: 'Hint ${s.hintsLeft}',
        onTap: onHint,
      ),
      if (onGuess != null)
        _Action(
          icon: Icons.document_scanner_outlined,
          label: 'Guess word ${s.wordFound ? 0 : s.guessesLeft}',
          onTap: guessEnabled ? onGuess : null,
        ),
    ]);
  }
}

class _Action extends StatelessWidget {
  const _Action({
    required this.icon,
    required this.label,
    required this.onTap,
    this.active = false,
    this.onLongPress,
  });

  final VoidCallback? onLongPress;
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final c = context.gs;
    final enabled = onTap != null;
    final color = enabled ? c.ink : c.inkDisabled;
    return Expanded(
      child: Material(
        color: active ? c.tonal : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          onLongPress: onLongPress,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(icon, size: 22, color: active ? c.onTonal : color),
              const SizedBox(height: 4),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(label,
                  maxLines: 1,
                  style: GsText.micro.copyWith(
                      fontSize: 11,
                      color: active ? c.onTonal : (enabled ? c.inkSecondary : c.inkDisabled))),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}
