import 'package:conquest/l10n/generated/app_localizations.dart';
import 'package:conquest/profile/match_persistence.dart';
import 'package:conquest/profile/storage_lease.dart';
import 'package:conquest/ui/my_page.dart';
import 'package:conquest/ui/tactical_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/profile_fixture.dart';
import 'support/profile_widget_io.dart';

void main() {
  for (final error in const [
    StorageAlreadyOwned(),
    StorageUnavailable('Storage cannot be opened'),
  ]) {
    testWidgets('My Page promptly exposes $error and recovers on Retry', (
      tester,
    ) async {
      final fixture = ProfileFixture()..openError = error;
      await tester.runAsync(fixture.runtime.prepare);
      expect(fixture.runtime.initializationError, same(error));
      Future<void> close() async {
        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
        await runProfileIo(
          tester,
          () => Future<void>.delayed(const Duration(milliseconds: 100)),
        );
        await runProfileIo(tester, fixture.runtime.close);
        await runProfileIo(tester, fixture.store.close);
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
            home: const MyPageScreen(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.textContaining('Could not load saved data'), findsOneWidget);
      expect(find.text('Retry').hitTestable(), findsOneWidget);
      expect(find.byKey(const ValueKey('edit-profile')), findsNothing);
      await tester.tap(find.text('Retry'));
      await tester.pump();
      await tester.pump();
      expect(find.text('Retry').hitTestable(), findsOneWidget);
      expect(fixture.runtime.profile, isNull);
      fixture.openError = null;
      await tester.tap(find.text('Retry'));
      await runProfileIo(
        tester,
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('Could not load saved data'), findsNothing);
      expect(find.byKey(const ValueKey('edit-profile')), findsOneWidget);
      expect(find.text('Total XP: 0'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await close();
    });
  }
}
