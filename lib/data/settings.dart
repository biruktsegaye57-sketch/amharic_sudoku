import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/theme/gs_colors.dart';
import '../services/audio.dart';

enum MistakeLimit { three, none, hidden }

enum InputOrder { cellFirst, letterFirst }

class Settings {
  const Settings({
    this.mistakeLimit = MistakeLimit.three,
    this.easyWordRow = true,
    this.autoRemoveNotes = true,
    this.highlightDuplicates = true,
    this.highlightSameFidel = true,
    this.pronunciation = true,
    this.showTimer = true,
    this.inputOrder = InputOrder.cellFirst,
    this.theme = GsThemeMode.light,
    this.largeFidel = false,
    this.sound = true,
    this.vibration = true,
    this.onboarded = false,
    this.learningHints = true,
    this.autoNotes = true,
    this.geezDates = false,
    this.dailyReminder = true,
  });

  final MistakeLimit mistakeLimit;
  final bool easyWordRow;
  final bool autoRemoveNotes;
  final bool highlightDuplicates;
  final bool highlightSameFidel;
  final bool pronunciation;
  final bool showTimer;
  final InputOrder inputOrder;
  final GsThemeMode theme;
  final bool largeFidel;
  final bool sound;
  final bool vibration;
  final bool onboarded;

  /// Arabic digit in the corner of Ge'ez numerals.
  final bool learningHints;

  /// Long-press Notes to fill every candidate.
  final bool autoNotes;

  /// Daily dates written with Ge'ez numerals (ጥቅምት ፱).
  final bool geezDates;

  /// One reminder at 19:00 if the daily puzzle is unsolved.
  final bool dailyReminder;

  Settings copyWith({
    MistakeLimit? mistakeLimit,
    bool? easyWordRow,
    bool? autoRemoveNotes,
    bool? highlightDuplicates,
    bool? highlightSameFidel,
    bool? pronunciation,
    bool? showTimer,
    InputOrder? inputOrder,
    GsThemeMode? theme,
    bool? largeFidel,
    bool? sound,
    bool? vibration,
    bool? onboarded,
    bool? learningHints,
    bool? autoNotes,
    bool? geezDates,
    bool? dailyReminder,
  }) =>
      Settings(
        mistakeLimit: mistakeLimit ?? this.mistakeLimit,
        easyWordRow: easyWordRow ?? this.easyWordRow,
        autoRemoveNotes: autoRemoveNotes ?? this.autoRemoveNotes,
        highlightDuplicates: highlightDuplicates ?? this.highlightDuplicates,
        highlightSameFidel: highlightSameFidel ?? this.highlightSameFidel,
        pronunciation: pronunciation ?? this.pronunciation,
        showTimer: showTimer ?? this.showTimer,
        inputOrder: inputOrder ?? this.inputOrder,
        theme: theme ?? this.theme,
        largeFidel: largeFidel ?? this.largeFidel,
        sound: sound ?? this.sound,
        vibration: vibration ?? this.vibration,
        onboarded: onboarded ?? this.onboarded,
        learningHints: learningHints ?? this.learningHints,
        autoNotes: autoNotes ?? this.autoNotes,
        geezDates: geezDates ?? this.geezDates,
        dailyReminder: dailyReminder ?? this.dailyReminder,
      );

  Map<String, dynamic> toJson() => {
        'mistakeLimit': mistakeLimit.name,
        'easyWordRow': easyWordRow,
        'autoRemoveNotes': autoRemoveNotes,
        'highlightDuplicates': highlightDuplicates,
        'highlightSameFidel': highlightSameFidel,
        'pronunciation': pronunciation,
        'showTimer': showTimer,
        'inputOrder': inputOrder.name,
        'theme': theme.name,
        'largeFidel': largeFidel,
        'sound': sound,
        'vibration': vibration,
        'onboarded': onboarded,
        'learningHints': learningHints,
        'autoNotes': autoNotes,
        'geezDates': geezDates,
        'dailyReminder': dailyReminder,
      };

  factory Settings.fromJson(Map<String, dynamic> j) {
    T pick<T extends Enum>(List<T> values, Object? name, T fallback) {
      for (final v in values) {
        if (v.name == name) return v;
      }
      return fallback;
    }

    const d = Settings();
    return Settings(
      mistakeLimit: pick(MistakeLimit.values, j['mistakeLimit'], d.mistakeLimit),
      easyWordRow: j['easyWordRow'] as bool? ?? d.easyWordRow,
      autoRemoveNotes: j['autoRemoveNotes'] as bool? ?? d.autoRemoveNotes,
      highlightDuplicates:
          j['highlightDuplicates'] as bool? ?? d.highlightDuplicates,
      highlightSameFidel:
          j['highlightSameFidel'] as bool? ?? d.highlightSameFidel,
      pronunciation: j['pronunciation'] as bool? ?? d.pronunciation,
      showTimer: j['showTimer'] as bool? ?? d.showTimer,
      inputOrder: pick(InputOrder.values, j['inputOrder'], d.inputOrder),
      theme: pick(GsThemeMode.values, j['theme'], d.theme),
      largeFidel: j['largeFidel'] as bool? ?? d.largeFidel,
      sound: j['sound'] as bool? ?? d.sound,
      vibration: j['vibration'] as bool? ?? d.vibration,
      onboarded: j['onboarded'] as bool? ?? d.onboarded,
      learningHints: j['learningHints'] as bool? ?? d.learningHints,
      autoNotes: j['autoNotes'] as bool? ?? d.autoNotes,
      geezDates: j['geezDates'] as bool? ?? d.geezDates,
      dailyReminder: j['dailyReminder'] as bool? ?? d.dailyReminder,
    );
  }
}

/// Overridden in main() with the loaded instance.
final prefsProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError('prefsProvider must be overridden'),
);

class SettingsController extends Notifier<Settings> {
  static const _key = 'settings.v1';

  @override
  Settings build() {
    final raw = ref.read(prefsProvider).getString(_key);
    if (raw == null) return const Settings();
    try {
      return Settings.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return const Settings();
    }
  }

  void update(Settings Function(Settings) change) {
    state = change(state);
    ref.read(prefsProvider).setString(_key, jsonEncode(state.toJson()));
  }
}

final settingsProvider =
    NotifierProvider<SettingsController, Settings>(SettingsController.new);

/// Haptics and sound effects, honouring Settings (sound / vibration).
class Feedback {
  Feedback(this.settings);
  final Settings settings;

  void _sfx(Sfx s, {double volume = 1}) {
    if (settings.sound) GameAudio.play(s, volume: volume);
  }

  /// Selecting a cell or a button.
  void tap() {
    if (settings.vibration) HapticFeedback.selectionClick();
    _sfx(Sfx.tap, volume: .5);
  }

  /// A correct placement.
  void place() {
    if (settings.vibration) HapticFeedback.lightImpact();
    _sfx(Sfx.place);
  }

  void note() => _sfx(Sfx.note, volume: .6);

  void error() {
    if (settings.vibration) HapticFeedback.heavyImpact();
    _sfx(Sfx.error);
  }

  /// A row, column or box completed.
  void unit() {
    if (settings.vibration) HapticFeedback.mediumImpact();
    _sfx(Sfx.unit);
  }

  void hint() => _sfx(Sfx.hint);
  void coin() => _sfx(Sfx.coin);

  void word() {
    if (settings.vibration) HapticFeedback.mediumImpact();
    _sfx(Sfx.word);
  }

  void win() {
    if (settings.vibration) HapticFeedback.heavyImpact();
    _sfx(Sfx.win);
  }

  void lose() {
    if (settings.vibration) HapticFeedback.vibrate();
    _sfx(Sfx.lose);
  }

  /// Kept for older call sites: a quiet success cue.
  void success() => place();
}

final feedbackProvider =
    Provider<Feedback>((ref) => Feedback(ref.watch(settingsProvider)));
