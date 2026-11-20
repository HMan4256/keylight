import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:keylight/audio/microphone_note_input.dart';
import 'package:keylight/audio/note_input.dart';
import 'package:keylight/music/piano_note.dart';
import 'package:keylight/studio/studio_controller.dart';

import 'support/fake_note_input.dart';

NoteFrame frame(List<int> notes) => NoteFrame(
  notes: [
    for (final midi in notes)
      DetectedNote(
        note: PianoNote(midi),
        frequency: PianoNote(midi).frequency,
        confidence: .99,
      ),
  ],
);
Future<void> tick() => Future<void>.delayed(Duration.zero);

void main() {
  late FakeNoteInput input;
  late StudioController controller;
  setUp(() {
    input = FakeNoteInput();
    controller = StudioController(input);
  });
  tearDown(() async {
    controller.dispose();
    await tick();
  });

  test('processes live notes and releases on silence', () async {
    await controller.start();
    input.events.add(frame([60]));
    await tick();
    expect(controller.activeKeys, {60});
    input.events.add(frame([60]));
    await tick();
    expect(controller.activeKeys, {60});
    input.events.add(const NoteFrame());
    await Future<void>.delayed(const Duration(milliseconds: 180));
    expect(controller.activeKeys, isEmpty);
    expect(controller.currentNote, isNull);
  });

  test(
    'supports a polyphonic adapter and independent touch pointers',
    () async {
      await controller.start();
      input.events.add(frame([60, 64, 67]));
      await tick();
      controller.touchDown(1, 72);
      controller.touchDown(2, 76);
      expect(controller.activeKeys, {60, 64, 67, 72, 76});
      controller.touchUp(1);
      expect(controller.activeKeys, {60, 64, 67, 76});
      controller.releaseTouches();
      expect(controller.activeKeys, {60, 64, 67});
      await controller.stop();
      expect(controller.activeKeys, isEmpty);
      expect(input.running, isFalse);
    },
  );

  test('denied permission is recoverable', () async {
    input.startError = MicrophonePermissionException();
    await controller.start();
    expect(controller.state, ListeningState.error);
    expect(controller.error, contains('settings'));
    input.startError = null;
    await controller.start();
    expect(controller.listening, isTrue);
  });

  test(
    'event-driven notes remain held until an explicit note-off snapshot',
    () async {
      await controller.start();
      input.events.add(
        NoteFrame(notes: frame([60, 64]).notes, releaseAfter: null),
      );
      await tick();
      await Future<void>.delayed(const Duration(milliseconds: 180));
      expect(controller.activeKeys, {60, 64});
      input.events.add(const NoteFrame(releaseAfter: null));
      await tick();
      expect(controller.activeKeys, isEmpty);
    },
  );

  test(
    'stop during an outstanding permission/start request releases input',
    () async {
      input.startGate = Completer<void>();
      final starting = controller.start();
      await tick();
      final stopping = controller.stop();
      input.startGate!.complete();
      await starting;
      await stopping;
      expect(controller.state, ListeningState.idle);
      expect(input.running, isFalse);
    },
  );

  test('stream interruption releases notes and allows a restart', () async {
    await controller.start();
    input.events.add(frame([69]));
    await tick();
    input.events.addError(StateError('Disconnected'));
    await tick();
    expect(controller.state, ListeningState.error);
    expect(controller.activeKeys, isEmpty);
    expect(input.running, isFalse);
    await controller.start();
    expect(controller.listening, isTrue);
  });
}
