// Word list maintenance.
//
//   dart run tool/words.dart validate   ../../assets/words/words.json
//   dart run tool/words.dart stats      ../../assets/words/words.json
//   dart run tool/words.dart export-csv ../../assets/words/words.json review.csv
//   dart run tool/words.dart import-csv ../../assets/words/words.json review.csv
//
// The CSV is for native-speaker reviewers (one row per word). Columns:
// id, word, theme, meaning_en, meaning_am, source, status, reviewers, disabled,
// rule_check, look_alike_pairs. Reviewers are separated by ';'. Import updates
// existing ids and appends new ones; run "validate" afterwards.
import 'dart:convert';
import 'dart:io';

import 'package:sudoku_core/sudoku_core.dart';

void main(List<String> args) {
  if (args.length < 2) {
    stderr.writeln('usage: words.dart validate|stats|export-csv|import-csv words.json [file.csv]');
    exit(64);
  }
  final file = File(args[1]);
  final list = WordList.parse(file.readAsStringSync());
  switch (args[0]) {
    case 'validate':
      final problems = list.validate();
      for (final p in problems) {
        stdout.writeln('✗ $p');
      }
      _stats(list);
      exit(problems.isEmpty ? 0 : 1);
    case 'stats':
      _stats(list);
    case 'export-csv':
      File(args[2]).writeAsStringSync(_toCsv(list));
      stdout.writeln('Wrote ${list.words.length} rows to ${args[2]}');
    case 'import-csv':
      final rows = _parseCsv(File(args[2]).readAsStringSync());
      final header = rows.first;
      final byId = {for (final w in list.words) w.id: w};
      int updated = 0, added = 0;
      for (final r in rows.skip(1)) {
        if (r.every((c) => c.trim().isEmpty)) continue;
        final m = {for (int i = 0; i < header.length && i < r.length; i++) header[i]: r[i]};
        final rec = WordRecord(
          id: m['id']!,
          word: m['word']!.trim(),
          theme: m['theme']!.trim(),
          meaningEn: m['meaning_en'] ?? '',
          meaningAm: m['meaning_am'] ?? '',
          source: m['source'] ?? '',
          status: (m['status'] ?? 'needs_review').trim(),
          reviewers: [
            for (final s in (m['reviewers'] ?? '').split(';'))
              if (s.trim().isNotEmpty) s.trim(),
          ],
          disabled: (m['disabled'] ?? '').trim().toLowerCase() == 'true',
        );
        byId.containsKey(rec.id) ? updated++ : added++;
        byId[rec.id] = rec;
      }
      final raw = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      raw['words'] = [for (final w in byId.values) w.toJson()];
      file.writeAsStringSync(const JsonEncoder.withIndent('  ').convert(raw));
      stdout.writeln('Updated $updated, added $added. Now run validate.');
    default:
      stderr.writeln('unknown command ${args[0]}');
      exit(64);
  }
}

void _stats(WordList list) {
  final playable = list.playable;
  stdout.writeln('${list.words.length} words, ${playable.length} playable, '
      '${list.words.where((w) => w.approved).length} approved by two reviewers');
  for (final n in WordRules.sizes) {
    final bySize = playable.where((w) => w.length == n).toList();
    final themes = <String, int>{};
    for (final w in bySize) {
      themes[w.theme] = (themes[w.theme] ?? 0) + 1;
    }
    stdout.writeln('  $n×$n: ${bySize.length}  $themes');
  }
}

String _toCsv(WordList list) {
  String q(Object? v) => '"${'$v'.replaceAll('"', '""')}"';
  final sb = StringBuffer()
    ..writeln('id,word,theme,meaning_en,meaning_am,source,status,reviewers,disabled,rule_check,look_alike_pairs');
  for (final w in list.words) {
    final problems = WordRules.check(w.word);
    sb.writeln([
      w.id, w.word, w.theme, w.meaningEn, w.meaningAm, w.source, w.status,
      w.reviewers.join(';'), w.disabled,
      problems.isEmpty ? 'ok' : problems.join(' | '),
      WordRules.lookAlikePairs(w.word),
    ].map(q).join(','));
  }
  return sb.toString();
}

List<List<String>> _parseCsv(String s) {
  final rows = <List<String>>[];
  var row = <String>[];
  final cell = StringBuffer();
  bool quoted = false;
  for (int i = 0; i < s.length; i++) {
    final ch = s[i];
    if (quoted) {
      if (ch == '"') {
        if (i + 1 < s.length && s[i + 1] == '"') {
          cell.write('"');
          i++;
        } else {
          quoted = false;
        }
      } else {
        cell.write(ch);
      }
    } else if (ch == '"') {
      quoted = true;
    } else if (ch == ',') {
      row.add(cell.toString());
      cell.clear();
    } else if (ch == '\n' || ch == '\r') {
      if (ch == '\r' && i + 1 < s.length && s[i + 1] == '\n') i++;
      row.add(cell.toString());
      cell.clear();
      rows.add(row);
      row = <String>[];
    } else {
      cell.write(ch);
    }
  }
  if (cell.isNotEmpty || row.isNotEmpty) {
    row.add(cell.toString());
    rows.add(row);
  }
  return rows;
}
