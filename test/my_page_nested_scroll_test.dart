import 'package:conquest/audio/bgm_player.dart';
import 'package:conquest/game/game_state.dart';
import 'package:conquest/home.dart';
import 'package:conquest/main.dart';
import 'package:conquest/profile/match_persistence.dart';
import 'package:conquest/profile/profile_read_providers.dart';
import 'package:conquest/profile/profile_repository.dart';
import 'package:conquest/ui/my_page_destinations.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'my_page_history_test.dart' show choose, drain, id;
import 'profile_repository_test.dart' show finish;
import 'support/match_setup.dart';
import 'support/profile_fixture.dart';
import 'support/profile_widget_io.dart';

final class _SilentBgm implements BgmPlayer {
  @override
  Future<void> prepare() async {}
  @override
  Future<void> playFromStart() async {}
  @override
  Future<void> pause() async {}
  @override
  Future<void> resume() async {}
  @override
  Future<void> stopAndReset() async {}
  @override
  Future<void> dispose() async {}
}

void main() {
  testWidgets(
    'detail back restores a displaced nested history viewport and loaded pages',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1133, 744));
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final fixture = (await tester.runAsync(() async {
        final fixture = ProfileFixture();
        await fixture.ready();
        for (var i = 1; i <= 65; i++) {
          await finish(fixture, i, difficulty: CpuDifficulty.hard);
        }
        return fixture;
      }))!;
      final profileId = fixture.runtime.profile!.profileId;
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox());
        await runProfileIo(tester, fixture.runtime.close);
      });
      await tester.pumpWidget(
        ProviderScope(
          retry: (_, _) => null,
          overrides: [
            matchPersistenceProvider.overrideWithValue(fixture.runtime),
            bgmPlayerProvider.overrideWithValue(_SilentBgm()),
            menuBgmPlayerProvider.overrideWithValue(_SilentBgm()),
          ],
          child: const MyApp(locale: Locale('ja')),
        ),
      );
      await drain(tester);
      await runProfileIo(
        tester,
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pumpAndSettle();
      await openMatchSetup(tester);
      final myPage = find.byKey(const ValueKey('open-my-page'));
      await tester.ensureVisible(myPage);
      await tester.tap(myPage);
      await runProfileIo(
        tester,
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('my-page-history-tab')));
      await tester.pumpAndSettle();
      await runProfileIo(
        tester,
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await choose(tester, 'history-difficulty', 'Hard');
      await runProfileIo(
        tester,
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      final list = find.descendant(
        of: find.byType(MyPageHistoryTab),
        matching: find.byType(Scrollable),
      );
      final nested = tester.state<NestedScrollViewState>(
        find.byType(NestedScrollView),
      );
      final history = matchHistoryProvider((
        profileId: profileId,
        filter: MatchHistoryFilter(difficulty: CpuDifficulty.hard),
      ));
      final container = ProviderScope.containerOf(
        tester.element(find.byType(MyPageHistoryTab)),
      );
      for (final count in [20, 40]) {
        final more = find.byKey(const ValueKey('history-load-more'));
        await tester.scrollUntilVisible(more, 500, scrollable: list);
        await tester.pumpAndSettle();
        final row = find.byKey(ValueKey('history-row-${id(66 - count)}'));
        await tester.ensureVisible(row);
        await tester.pumpAndSettle();
        final outerOffset = nested.outerController.offset;
        final innerOffset = nested.innerController.offset;
        expect(innerOffset, greaterThan(1000));
        await tester.tap(row);
        await runProfileIo(
          tester,
          () => Future<void>.delayed(const Duration(milliseconds: 100)),
        );
        await tester.pumpAndSettle();
        await tester.drag(
          find.byType(SingleChildScrollView),
          const Offset(0, -1000),
        );
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('my-page-match-detail')),
          findsOneWidget,
        );
        await runProfileIo(
          tester,
          () => Future<void>.delayed(const Duration(milliseconds: 100)),
        );
        if (count == 40) nested.outerController.jumpTo(0);
        await tester.tap(find.byType(BackButton));
        await runProfileIo(
          tester,
          () => Future<void>.delayed(const Duration(milliseconds: 100)),
        );
        await tester.pumpAndSettle();
        expect(nested.outerController.offset, closeTo(outerOffset, 0.1));
        expect(nested.innerController.offset, closeTo(innerOffset, 0.1));
        expect(row.hitTestable(), findsOneWidget);
        expect(container.read(history).requireValue.entries.length, count);
        await tester.scrollUntilVisible(more, 100, scrollable: list);
        await tester.tap(more);
        await drain(tester);
        await runProfileIo(
          tester,
          () => Future<void>.delayed(const Duration(milliseconds: 100)),
        );
        await tester.pumpAndSettle();
      }
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await drain(tester);
      await runProfileIo(tester, fixture.runtime.close);
      debugDefaultTargetPlatformOverride = null;
    },
  );
}
