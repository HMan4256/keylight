import '../music/piano_note.dart';

class DetectedNote {
  const DetectedNote({
    required this.note,
    this.frequency,
    required this.confidence,
  });
  final PianoNote note;

  /// Only present when a source actually measures frequency. A piano-key
  /// classifier or MIDI source must not manufacture precise tuning values.
  final double? frequency;
  final double confidence;
  double? get cents => frequency == null ? null : note.centsFrom(frequency!);
}

/// A set of sounding notes lets future USB/BLE MIDI sources support polyphony
/// without changing the keyboard or session controller.
class NoteFrame {
  const NoteFrame({
    this.notes = const [],
    this.rms = 0,
    this.waveform = const [],
    this.releaseAfter = const Duration(milliseconds: 150),
  });
  final List<DetectedNote> notes;
  final double rms;
  final List<double> waveform;

  /// Watchdog expiration if a source stops delivering snapshots. Empty frames
  /// explicitly release notes. Event-driven MIDI sources can use null.
  final Duration? releaseAfter;
}

abstract interface class NoteInput {
  Stream<NoteFrame> get frames;
  Future<void> start();
  Future<void> stop();
  Future<void> dispose();
}
