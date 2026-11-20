import 'dart:math' as math;

/// MIDI numbering is shared by microphone, touch, and future MIDI adapters.
class PianoNote {
  const PianoNote(this.midi) : assert(midi >= 21 && midi <= 108);

  final int midi;
  static const names = [
    'C',
    'C♯',
    'D',
    'D♯',
    'E',
    'F',
    'F♯',
    'G',
    'G♯',
    'A',
    'A♯',
    'B',
  ];
  static const flats = [
    'C',
    'D♭',
    'D',
    'E♭',
    'E',
    'F',
    'G♭',
    'G',
    'A♭',
    'A',
    'B♭',
    'B',
  ];

  int get pitchClass => midi % 12;
  int get octave => midi ~/ 12 - 1;
  String get name => names[pitchClass];
  String get label => '$name$octave';
  String get alternateName => isBlack ? flats[pitchClass] : name;
  bool get isBlack => const {1, 3, 6, 8, 10}.contains(pitchClass);
  double get frequency => 440.0 * math.pow(2, (midi - 69) / 12);

  static PianoNote? fromFrequency(double hz) {
    if (!hz.isFinite || hz <= 0) return null;
    final midi = (69 + 12 * math.log(hz / 440) / math.ln2).round();
    return midi >= 21 && midi <= 108 ? PianoNote(midi) : null;
  }

  double centsFrom(double hz) => 1200 * math.log(hz / frequency) / math.ln2;
}
