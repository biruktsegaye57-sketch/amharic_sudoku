import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'core/constants/word_bank.dart';
import 'data/puzzle_bank.dart';
import 'data/settings.dart';
import 'services/reminders.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  final results = await Future.wait([
    SharedPreferences.getInstance(),
    PuzzleBank.load(),
    rootBundle.loadString('assets/words/words.json'),
  ]);
  WordBank.load(results[2] as String);
  await Reminders.init();
  runApp(ProviderScope(
    overrides: [
      prefsProvider.overrideWithValue(results[0] as SharedPreferences),
      puzzleBankProvider.overrideWithValue(results[1] as PuzzleBank),
    ],
    child: const GeezSudokuApp(),
  ));
}
