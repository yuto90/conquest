import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:conquest/faction_presentation.dart';
import 'package:conquest/game/game_state.dart';
import 'package:conquest/moving_force.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

MovingForce _force(
  int strength,
  Faction faction, {
  double dx = 1,
  double dy = 0,
}) => MovingForce(
  sourceIslandId: 7,
  destinationIslandId: 9,
  faction: faction,
  strength: strength,
  deltaX: dx,
  deltaY: dy,
);

Future<void> _pump(
  WidgetTester tester,
  int strength, {
  Faction faction = Faction.player,
  GameMode mode = GameMode.playerVsCpu,
  double dx = 1,
  double dy = 0,
  double textScale = 1,
  VoidCallback? onTap,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
        child: Center(
          child: SizedBox.square(
            dimension: 120,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Positioned.fill(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: onTap,
                    child: const SizedBox.expand(),
                  ),
                ),
                MovingForceWidget(
                  force: _force(strength, faction, dx: dx, dy: dy),
                  boardSize: const Size(320, 568),
                  presentation: FactionPresentation.forMode(mode, faction),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

CustomPainter _painter(
  WidgetTester tester,
  AircraftIllustration illustration,
) => tester.widget<CustomPaint>(find.byKey(ValueKey(illustration))).painter!;

void main() {
  const boundaries = <int, AircraftIllustration>{
    1: AircraftIllustration.singleEngine,
    23: AircraftIllustration.singleEngine,
    24: AircraftIllustration.singleEngine,
    25: AircraftIllustration.twinEngine,
    26: AircraftIllustration.twinEngine,
    48: AircraftIllustration.twinEngine,
    49: AircraftIllustration.twinEngine,
    50: AircraftIllustration.transport,
    51: AircraftIllustration.transport,
    100: AircraftIllustration.transport,
    123456: AircraftIllustration.transport,
  };

  test(
    'presentation table classifies before, at, and after both boundaries',
    () {
      for (final entry in boundaries.entries) {
        expect(AircraftIllustration.forStrength(entry.key), entry.value);
      }
    },
  );

  testWidgets(
    'all modes and factions use troop strength and retain exact labels',
    (tester) async {
      final semantics = tester.ensureSemantics();
      for (final mode in GameMode.values) {
        for (final faction in [Faction.player, Faction.cpu]) {
          final presentation = FactionPresentation.forMode(mode, faction);
          for (final entry in boundaries.entries) {
            await _pump(tester, entry.key, faction: faction, mode: mode);
            expect(find.byKey(ValueKey(entry.value)), findsOneWidget);
            expect(find.text(entry.key.toString()), findsOneWidget);
            expect(find.text(presentation.marker), findsOneWidget);
            final semantics = tester.getSemantics(
              find.byType(MovingForceWidget),
            );
            expect(semantics.label, contains(entry.key.toString()));
            expect(semantics.label, contains(presentation.semanticName));
            expect(
              tester.getSize(find.byType(MovingForceWidget)),
              const Size(30, 30),
            );
            expect(
              tester.getSize(find.byKey(ValueKey(entry.value))),
              const Size(36, 22),
            );
          }
        }
      }
      semantics.dispose();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'tier changes repaint; same-tier strength only updates the label',
    (tester) async {
      await _pump(tester, 24);
      final small = _painter(tester, AircraftIllustration.singleEngine);
      await _pump(tester, 25);
      final medium = _painter(tester, AircraftIllustration.twinEngine);
      expect(medium.shouldRepaint(small), isTrue);
      await _pump(tester, 49);
      final mediumAgain = _painter(tester, AircraftIllustration.twinEngine);
      expect(mediumAgain.shouldRepaint(medium), isFalse);
      expect(find.text('49'), findsOneWidget);
      await _pump(tester, 50);
      final large = _painter(tester, AircraftIllustration.transport);
      expect(large.shouldRepaint(mediumAgain), isTrue);
      await _pump(tester, 50, faction: Faction.cpu);
      expect(
        _painter(tester, AircraftIllustration.transport).shouldRepaint(large),
        isTrue,
      );
    },
  );

  testWidgets(
    'each faction and tier paints a distinct image in the same canvas',
    (tester) async {
      final pixels = <String>{};
      for (final faction in [Faction.player, Faction.cpu]) {
        for (final strength in [24, 25, 50]) {
          await _pump(tester, strength, faction: faction);
          final painter = _painter(
            tester,
            AircraftIllustration.forStrength(strength),
          );
          final recorder = ui.PictureRecorder();
          painter.paint(Canvas(recorder), const Size(36, 22));
          final picture = recorder.endRecording();
          await tester.runAsync(() async {
            final image = await picture.toImage(36, 22);
            final bytes = await image.toByteData();
            expect(bytes, isNotNull);
            pixels.add(bytes!.buffer.asUint8List().join(','));
            image.dispose();
          });
          picture.dispose();
        }
      }
      expect(pixels, hasLength(6));
    },
  );

  testWidgets(
    'all tiers keep upright labels, heading and taps on a small screen',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 568));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      for (final strength in [24, 25, 50, 100]) {
        for (final direction in [
          const Offset(1, 0),
          const Offset(0, 1),
          const Offset(-1, -1),
        ]) {
          var taps = 0;
          await _pump(
            tester,
            strength,
            dx: direction.dx,
            dy: direction.dy,
            textScale: 2,
            onTap: () => taps++,
          );
          final transform = tester.widget<Transform>(
            find.descendant(
              of: find.byType(MovingForceWidget),
              matching: find.byType(Transform),
            ),
          );
          final angle = math.atan2(
            direction.dy * (568 - 30),
            direction.dx * (320 - 30),
          );
          expect(
            transform.transform.storage[0],
            closeTo(math.cos(angle), 1e-10),
          );
          expect(
            transform.transform.storage[1],
            closeTo(math.sin(angle), 1e-10),
          );
          for (final label in [strength.toString(), 'P']) {
            expect(
              find.ancestor(
                of: find.text(label),
                matching: find.byType(Transform),
              ),
              findsNothing,
            );
          }
          await tester.tapAt(tester.getCenter(find.byType(MovingForceWidget)));
          expect(taps, 1);
          expect(tester.takeException(), isNull);
        }
      }
    },
  );
}
