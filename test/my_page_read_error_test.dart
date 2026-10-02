import 'package:conquest/l10n/generated/app_localizations.dart';
import 'package:conquest/profile/match_persistence.dart';
import 'package:conquest/profile/profile_repository.dart';
import 'package:conquest/ui/my_page.dart';
import 'package:conquest/ui/my_page_destinations.dart';
import 'package:conquest/ui/tactical_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'profile_repository_test.dart' show finish;
import 'support/profile_fixture.dart';
import 'support/profile_widget_io.dart';

void main() {
  for (final detail in [false, true]) {
    testWidgets('SQLite read errors promptly expose Retry (detail: $detail)', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(1200, 2400));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final seeded = (await tester.runAsync(() async {
        final fixture = ProfileFixture();
        await fixture.ready();
        final profileId = fixture.runtime.profile!.profileId;
        await fixture.repository.editProfile(
          profileId,
          ProfileEdit(displayName: 'Retained captain', avatarKey: 'island_04'),
        );
        final match = await finish(fixture, 1);
        final xp = await fixture.repository.watchTotalXp(profileId).first;
        for (final table in ['profiles', 'match_records']) {
          await fixture.store.database.customStatement(
            'ALTER TABLE $table RENAME TO ${table}_unavailable',
          );
        }
        return (fixture: fixture, match: match, profileId: profileId, xp: xp);
      }))!;
      final fixture = seeded.fixture;
      Future<void> close() async {
        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
        await runProfileIo(
          tester,
          () => Future<void>.delayed(const Duration(milliseconds: 100)),
        );
        await runProfileIo(tester, fixture.runtime.close);
      }

      addTearDown(close);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            matchPersistenceProvider.overrideWithValue(fixture.runtime),
          ],
          child: MaterialApp(
            locale: const Locale('en'),
            theme: buildTacticalTheme(),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: detail
                ? MyPageMatchDetailScreen(
                    profileId: seeded.profileId,
                    matchId: seeded.match.start.matchId,
                  )
                : const MyPageScreen(),
          ),
        ),
      );
      await runProfileIo(
        tester,
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.textContaining('Could not load saved data'), findsWidgets);
      expect(find.text('Retry').hitTestable(), findsWidgets);
      expect(find.text('No completed matches recorded yet.'), findsNothing);
      await tester.runAsync(() async {
        for (final table in ['profiles', 'match_records']) {
          await fixture.store.database.customStatement(
            'ALTER TABLE ${table}_unavailable RENAME TO $table',
          );
        }
      });
      for (var attempt = 0; attempt < 10; attempt++) {
        final retry = find.text('Retry');
        if (retry.evaluate().isEmpty) break;
        await tester.ensureVisible(retry.first);
        await tester.tap(retry.first);
        await runProfileIo(
          tester,
          () => Future<void>.delayed(const Duration(milliseconds: 100)),
        );
        await tester.pumpAndSettle();
      }
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.textContaining('Could not load saved data'), findsNothing);
      expect(find.text('Retry'), findsNothing);
      if (!detail) {
        tester
            .state<NestedScrollViewState>(find.byType(NestedScrollView))
            .outerController
            .jumpTo(0);
        await tester.pump();
      }
      expect(find.text(detail ? '77' : 'Retained captain'), findsOneWidget);
      await tester.runAsync(() async {
        expect(
          await fixture.repository.loadMatch(
            seeded.profileId,
            seeded.match.start.matchId,
          ),
          isNotNull,
        );
        expect(
          await fixture.repository.watchTotalXp(seeded.profileId).first,
          seeded.xp,
        );
      });
      expect(tester.takeException(), isNull);
      await close();
    });
  }
}
