import 'dart:async';

import 'package:keylight/audio/note_input.dart';

class FakeNoteInput implements NoteInput {
  final events = StreamController<NoteFrame>.broadcast();
  bool running = false;
  bool disposed = false;
  Object? startError;
  Completer<void>? startGate;
  @override
  Stream<NoteFrame> get frames => events.stream;
  @override
  Future<void> start() async {
    if (startError != null) throw startError!;
    await startGate?.future;
    running = true;
  }

  @override
  Future<void> stop() async {
    running = false;
  }

  @override
  Future<void> dispose() async {
    running = false;
    disposed = true;
    await events.close();
  }
}
