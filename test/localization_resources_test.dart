import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'English and Japanese ARB resources keep keys and placeholders aligned',
    () {
      final english = _readArb('app_en.arb');
      final japanese = _readArb('app_ja.arb');

      final englishMessages = _messageKeys(english);
      final japaneseMessages = _messageKeys(japanese);
      expect(japaneseMessages, orderedEquals(englishMessages));

      for (final key in englishMessages) {
        expect(english[key], isA<String>(), reason: '$key must be a message');
        expect(japanese[key], isA<String>(), reason: '$key must be a message');
        expect(japanese[key], isNotEmpty, reason: '$key must be translated');
        expect(
          english['@$key'],
          isA<Map<String, dynamic>>(),
          reason: '$key needs metadata',
        );
        expect(
          japanese['@$key'],
          isA<Map<String, dynamic>>(),
          reason: '$key needs metadata',
        );
        expect(
          _placeholderNames(english[key]! as String),
          orderedEquals(_placeholderNames(japanese[key]! as String)),
          reason: '$key placeholder names must match',
        );
        expect(
          _placeholderTypes(english['@$key']! as Map<String, dynamic>),
          orderedEquals(
            _placeholderTypes(japanese['@$key']! as Map<String, dynamic>),
          ),
          reason: '$key placeholder types must match',
        );
      }

      expect(english['brandName'], 'CONQUEST');
      expect(japanese['brandName'], 'CONQUEST');
      expect(english['startWord'], 'START');
      expect(japanese['startWord'], 'START');
      for (final key in <String>[
        'difficultyVeryEasy',
        'difficultyEasy',
        'difficultyNormal',
        'difficultyHard',
      ]) {
        expect(
          japanese[key],
          english[key],
          reason: '$key is a stable difficulty name',
        );
      }

      const stableValues = <String>{
        'brandName',
        'startWord',
        'difficultyVeryEasy',
        'difficultyEasy',
        'difficultyNormal',
        'difficultyHard',
        'factionCpu',
        'factionPlayerOne',
        'factionPlayerTwo',
      };
      final identicalValues = englishMessages
          .where((key) => english[key] == japanese[key])
          .toSet();
      expect(
        identicalValues,
        stableValues,
        reason:
            'Only explicitly stable brand, start, CPU, numeric, and difficulty values may remain identical.',
      );
    },
  );
}

Map<String, dynamic> _readArb(String name) {
  final file = File('lib/l10n/$name');
  return jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
}

List<String> _messageKeys(Map<String, dynamic> arb) {
  return arb.keys.where((key) => !key.startsWith('@')).toList()..sort();
}

List<String> _placeholderNames(String message) {
  final names = RegExp(
    r'\{([a-zA-Z][a-zA-Z0-9_]*)\}',
  ).allMatches(message).map((match) => match.group(1)!).toSet().toList();
  names.sort();
  return names;
}

List<String> _placeholderTypes(Map<String, dynamic> metadata) {
  final placeholders = metadata['placeholders'] as Map<String, dynamic>?;
  if (placeholders == null) return const [];
  final entries = placeholders.entries
      .map(
        (entry) =>
            '${entry.key}:${(entry.value as Map<String, dynamic>)['type']}',
      )
      .toList();
  entries.sort();
  return entries;
}
