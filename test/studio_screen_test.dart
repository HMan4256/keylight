import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:keylight/audio/note_input.dart';
import 'package:keylight/main.dart';
import 'package:keylight/music/piano_note.dart';
import 'package:keylight/studio/studio_controller.dart';
import 'package:keylight/ui/studio_theme.dart';

import 'support/fake_note_input.dart';

void main() {
  for (final size in [
    const Size(390, 844),
    const Size(320, 568),
    const Size(844, 390),
    const Size(1024, 1366),
  ]) {
    testWidgets('studio fits $size and starts listening', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final input = FakeNoteInput();
      final controller = StudioController(input);
      await tester.pumpWidget(KeylightApp(controller: controller));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final button = find.byKey(const ValueKey('microphone-toggle'));
      await tester.ensureVisible(button);
      await tester.tap(button);
      await tester.pumpAndSettle();
      expect(input.running, isTrue);
      expect(find.text('Listening'), findsOneWidget);
      input.events.add(
        NoteFrame(
          notes: [
            DetectedNote(
              note: const PianoNote(69),
              frequency: 440,
              confidence: .99,
            ),
          ],
        ),
      );
      await tester.pump();
      await tester.pump();
      expect(controller.activeKeys, {69});
      final highlightedKey = tester.widget<AnimatedContainer>(
        find.byKey(const ValueKey('piano-key-69')),
      );
      expect(
        (highlightedKey.decoration! as BoxDecoration).color,
        StudioColors.mint,
      );
      expect(find.text('A4'), findsWidgets);
      await tester.pump(const Duration(milliseconds: 180));
      expect(controller.activeKeys, isEmpty);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      controller.dispose();
      await tester.pumpAndSettle();
    });
  }

  testWidgets('touch notes release and settings toggle labels', (tester) async {
    final controller = StudioController(FakeNoteInput());
    await tester.pumpWidget(KeylightApp(controller: controller));
    await tester.pumpAndSettle();
    final key = find.byKey(const ValueKey('piano-key-60'));
    await tester.ensureVisible(key);
    await tester.pumpAndSettle();
    // The lower end of the white key is not covered by a black key.
    final gesture = await tester.startGesture(
      tester.getBottomLeft(key) + const Offset(15, -15),
    );
    await tester.pump();
    expect(controller.activeKeys, {60});
    await gesture.up();
    await tester.pumpAndSettle();
    expect(controller.activeKeys, isEmpty);
    final settings = find.byTooltip('Settings');
    await tester.ensureVisible(settings);
    await tester.tap(settings);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Note labels'));
    await tester.pumpAndSettle();
    expect(controller.showLabels, isFalse);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    controller.dispose();
    await tester.pumpAndSettle();
  });

  testWidgets('app backgrounding stops capture and releases keys', (
    tester,
  ) async {
    final input = FakeNoteInput();
    final controller = StudioController(input);
    await tester.pumpWidget(KeylightApp(controller: controller));
    await controller.start();
    controller.touchDown(1, 60);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pumpAndSettle();
    expect(input.running, isFalse);
    expect(controller.activeKeys, isEmpty);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpWidget(const SizedBox());
    controller.dispose();
    await tester.pumpAndSettle();
  });

  for (final size in [const Size(320, 568), const Size(1024, 1366)]) {
    testWidgets('all 88 detections render together at $size', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final input = FakeNoteInput();
      final controller = StudioController(input);
      await tester.pumpWidget(KeylightApp(controller: controller));
      await controller.start();
      input.events.add(
        NoteFrame(
          notes: [
            for (var midi = 21; midi <= 108; midi++)
              DetectedNote(note: PianoNote(midi), confidence: .9),
          ],
          releaseAfter: null,
        ),
      );
      await tester.pump();
      await tester.pumpAndSettle();
      expect(find.text('88 notes'), findsOneWidget);
      for (var midi = 21; midi <= 108; midi++) {
        expect(find.byKey(ValueKey('detected-note-$midi')), findsOneWidget);
        final key = tester.widget<AnimatedContainer>(
          find.byKey(ValueKey('piano-key-$midi')),
        );
        expect((key.decoration! as BoxDecoration).color, StudioColors.mint);
      }
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      controller.dispose();
      await tester.pumpAndSettle();
    });
  }

  testWidgets('piano classification does not manufacture frequency or tuning', (
    tester,
  ) async {
    final input = FakeNoteInput();
    final controller = StudioController(input);
    await tester.pumpWidget(KeylightApp(controller: controller));
    await controller.start();
    input.events.add(
      const NoteFrame(
        notes: [DetectedNote(note: PianoNote(60), confidence: .9)],
        releaseAfter: null,
      ),
    );
    await tester.pump();
    await tester.pumpAndSettle();
    expect(find.text('Degree 1 in C major'), findsOneWidget);
    expect(find.textContaining('Hz'), findsNothing);
    expect(find.text('IN TUNE'), findsNothing);
    await tester.pumpWidget(const SizedBox());
    controller.dispose();
    await tester.pumpAndSettle();
  });
}
