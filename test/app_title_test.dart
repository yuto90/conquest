import 'dart:convert';
import 'dart:io';

import 'package:conquest/game/game_loop.dart';
import 'package:conquest/l10n/generated/app_localizations_en.dart';
import 'package:conquest/l10n/generated/app_localizations_ja.dart';
import 'package:conquest/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/match_setup.dart';

const _appTitle = 'CONQUEST ISLES';

void main() {
  test('Web entry points use the app title without changing the manifest', () {
    final index = File('web/index.html').readAsStringSync();
    expect(
      index,
      contains('<meta name="apple-mobile-web-app-title" content="$_appTitle">'),
    );
    expect(index, contains('<title>$_appTitle</title>'));

    final manifest =
        jsonDecode(File('web/manifest.json').readAsStringSync())
            as Map<String, dynamic>;
    expect(manifest['name'], _appTitle);
    expect(manifest['short_name'], _appTitle);
    expect(manifest['start_url'], '.');
    expect(manifest['background_color'], '#84C9C6');
    expect(manifest['theme_color'], '#84C9C6');
    expect(manifest['icons'], <Map<String, String>>[
      <String, String>{
        'src': 'icons/Icon-192.png',
        'sizes': '192x192',
        'type': 'image/png',
      },
      <String, String>{
        'src': 'icons/Icon-512.png',
        'sizes': '512x512',
        'type': 'image/png',
      },
    ]);
  });

  test('localized app titles and the HUD brand name remain distinct', () {
    expect(AppLocalizationsEn().appTitle, _appTitle);
    expect(AppLocalizationsJa().appTitle, _appTitle);
    expect(AppLocalizationsEn().brandName, 'CONQUEST');
    expect(AppLocalizationsJa().brandName, 'CONQUEST');

    final english = _readArb('app_en.arb');
    final japanese = _readArb('app_ja.arb');
    expect(english['appTitle'], _appTitle);
    expect(japanese['appTitle'], _appTitle);
    final englishMetadata = english['@appTitle'] as Map<String, dynamic>;
    final japaneseMetadata = japanese['@appTitle'] as Map<String, dynamic>;
    expect(englishMetadata['description'], isNotEmpty);
    expect(japaneseMetadata['description'], isNotEmpty);
  });

  testWidgets('Flutter keeps the app title through settings and a match', (
    tester,
  ) async {
    final loop = ManualGameLoop();
    addTearDown(loop.stop);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [gameLoopProvider.overrideWithValue(loop)],
        child: const MyApp(locale: Locale('en')),
      ),
    );
    expect(_runtimeTitle(tester), _appTitle);

    await openMatchSetup(tester);
    expect(find.byKey(const ValueKey('settings-view')), findsOneWidget);
    expect(_runtimeTitle(tester), _appTitle);

    await tester.tap(find.byKey(const ValueKey('start-game')));
    await tester.pump();
    expect(_runtimeTitle(tester), _appTitle);

    for (var tick = 0; tick < 60; tick++) {
      loop.tick();
    }
    await tester.pump();
    expect(find.byKey(const ValueKey('island-0')), findsOneWidget);
    expect(_runtimeTitle(tester), _appTitle);
  });
}

String _runtimeTitle(WidgetTester tester) {
  final title = tester.widget<Title>(find.byType(Title));
  return title.title;
}

Map<String, dynamic> _readArb(String name) {
  return jsonDecode(File('lib/l10n/$name').readAsStringSync())
      as Map<String, dynamic>;
}
