import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:keylight/main.dart';
import 'package:keylight/music/chords.dart';
import 'package:keylight/music/tonality.dart';
import 'package:keylight/studio/studio_controller.dart';
import 'package:keylight/ui/studio_theme.dart';

import 'support/fake_note_input.dart';

void main() {
  testWidgets(
    'played chord follows manual key; circle selects parallel and relative keys',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final controller = StudioController(FakeNoteInput());
      await tester.pumpWidget(KeylightApp(controller: controller));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Hold touch notes'));
      await tester.pumpAndSettle();
      for (final midi in [60, 64, 67]) {
        final key = find.byKey(ValueKey('piano-key-$midi'));
        await tester.ensureVisible(key);
        await tester.pumpAndSettle();
        await tester.tapAt(tester.getBottomLeft(key) + const Offset(15, -15));
        await tester.pumpAndSettle();
      }
      expect(controller.activeKeys, {60, 64, 67});
      expect(find.text('I · Tonic in C major'), findsOneWidget);
      await tester.tap(find.text('Circle'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('circle-1-major')));
      await tester.pumpAndSettle();
      expect(controller.theory.key.label, 'G major');
      expect(controller.activeKeys, {60, 64, 67});
      expect(
        ChordFunction.analyze(
          controller.theory.chord!,
          controller.theory.key,
        ).roman,
        'IV',
      );
      controller.theory.selectKey(const MusicalKey(0));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('parallel-key')));
      await tester.pumpAndSettle();
      expect(controller.theory.key.label, 'C minor');
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('circle--3-minor')),
          matching: find.text('[Cm]'),
        ),
        findsOneWidget,
      );
      await tester.tap(find.text('Major'));
      await tester.pumpAndSettle();
      expect(controller.theory.key.label, 'C major');
      await tester.tap(find.byKey(const ValueKey('relative-key')));
      await tester.pumpAndSettle();
      expect(controller.theory.key.label, 'A minor');
      expect(controller.activeKeys, {60, 64, 67});
      await tester.tap(find.text('Identify'));
      await tester.pumpAndSettle();
      expect(find.text('III · Tonic prolongation in A minor'), findsOneWidget);
      expect(find.byType(NavigationDestination), findsNWidgets(3));
      expect(find.text('Scales'), findsNothing);
      expect(find.text('Chords'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      controller.dispose();
      await tester.pumpAndSettle();
    },
  );

  testWidgets('scale selection only shades keys and starts off', (
    tester,
  ) async {
    final controller = StudioController(FakeNoteInput());
    await tester.pumpWidget(KeylightApp(controller: controller));
    await tester.pumpAndSettle();
    expect(controller.theory.scale, isNull);
    await tester.tap(find.byKey(const ValueKey('scale-highlight')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Harmonic minor').last);
    await tester.pumpAndSettle();
    expect(controller.theory.scale, ScaleType.harmonicMinor);
    expect(controller.theory.key.label, 'C major');
    expect(controller.activeKeys, isEmpty);
    expect(controller.theory.chord, isNull);
    final color =
        (tester
                    .widget<AnimatedContainer>(
                      find.byKey(const ValueKey('piano-key-63')),
                    )
                    .decoration!
                as BoxDecoration)
            .color;
    expect(color, isNot(StudioColors.mint));
    await tester.tap(find.byKey(const ValueKey('scale-highlight')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Scale: off').last);
    await tester.pumpAndSettle();
    expect(controller.theory.scale, isNull);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    controller.dispose();
    await tester.pumpAndSettle();
  });

  testWidgets(
    'both tabs and key controls fit small, landscape and tablet viewports',
    (tester) async {
      for (final size in [
        const Size(320, 568),
        const Size(844, 390),
        const Size(1024, 1366),
      ]) {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        final controller = StudioController(FakeNoteInput());
        await tester.pumpWidget(KeylightApp(controller: controller));
        await tester.pumpAndSettle();
        for (final tab in ['Circle', 'Identify']) {
          await tester.tap(find.text(tab));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull, reason: '$tab at $size');
          if (tab == 'Circle') {
            for (final fifths in MusicalKey.circleFifths) {
              for (final mode in KeyMode.values) {
                expect(
                  find
                      .byKey(ValueKey('circle-$fifths-${mode.name}'))
                      .hitTestable(),
                  findsOneWidget,
                  reason: '${mode.name} at $fifths must be reachable at $size',
                );
              }
            }
            expect(
              find.byKey(const ValueKey('parallel-key')).hitTestable(),
              findsOneWidget,
            );
            expect(
              find.byKey(const ValueKey('relative-key')).hitTestable(),
              findsOneWidget,
            );
          }
        }
        await tester.tap(find.byKey(const ValueKey('key-root')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('D♭').hitTestable().first);
        await tester.pumpAndSettle();
        expect(controller.theory.key.label, 'D♭ major');
        await tester.tap(find.text('Minor'));
        await tester.pumpAndSettle();
        expect(controller.theory.key.label, 'C♯ minor');
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        controller.dispose();
        await tester.pumpAndSettle();
      }
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    },
  );
}
