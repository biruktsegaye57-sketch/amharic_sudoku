import 'dart:async';
import 'dart:io';

import 'package:amharic_sudoku/core/constants/word_bank.dart';
import 'package:flutter/services.dart';

/// Loads the bundled fonts so widget tests lay out text like the device does.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  Future<void> load(String family, List<String> files) async {
    final loader = FontLoader(family);
    for (final f in files) {
      final bytes = File('assets/fonts/$f').readAsBytesSync();
      loader.addFont(Future.value(ByteData.view(Uint8List.fromList(bytes).buffer)));
    }
    await loader.load();
  }

  await load('Inter', ['Inter-Regular.ttf', 'Inter-Medium.ttf', 'Inter-SemiBold.ttf', 'Inter-Bold.ttf']);
  await load('NotoSansEthiopic', [
    'NotoSansEthiopic-Regular.ttf', 'NotoSansEthiopic-Medium.ttf',
    'NotoSansEthiopic-SemiBold.ttf', 'NotoSansEthiopic-Bold.ttf',
  ]);
  await load('NotoSerifEthiopic', ['NotoSerifEthiopic-Medium.ttf', 'NotoSerifEthiopic-Bold.ttf']);
  final icons = File('${Platform.environment['FLUTTER_ROOT'] ?? '${Platform.environment['HOME']}/flutter/flutter'}'
      '/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf');
  if (icons.existsSync()) {
    final loader = FontLoader('MaterialIcons')
      ..addFont(Future.value(
          ByteData.view(Uint8List.fromList(icons.readAsBytesSync()).buffer)));
    await loader.load();
  }
  WordBank.load(File('assets/words/words.json').readAsStringSync());
  await testMain();
}
