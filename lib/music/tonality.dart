enum KeyMode { major, minor }

enum ScaleType {
  major('Major', [0, 2, 4, 5, 7, 9, 11], [0, 1, 2, 3, 4, 5, 6], KeyMode.major),
  naturalMinor(
    'Natural minor',
    [0, 2, 3, 5, 7, 8, 10],
    [0, 1, 2, 3, 4, 5, 6],
    KeyMode.minor,
  ),
  harmonicMinor(
    'Harmonic minor',
    [0, 2, 3, 5, 7, 8, 11],
    [0, 1, 2, 3, 4, 5, 6],
    KeyMode.minor,
  ),
  melodicMinor(
    'Melodic minor ↑',
    [0, 2, 3, 5, 7, 9, 11],
    [0, 1, 2, 3, 4, 5, 6],
    KeyMode.minor,
  ),
  majorPentatonic(
    'Major pentatonic',
    [0, 2, 4, 7, 9],
    [0, 1, 2, 4, 5],
    KeyMode.major,
  ),
  minorPentatonic(
    'Minor pentatonic',
    [0, 3, 5, 7, 10],
    [0, 2, 3, 4, 6],
    KeyMode.minor,
  ),
  minorBlues(
    'Minor blues',
    [0, 3, 5, 6, 7, 10],
    [0, 2, 3, 4, 4, 6],
    KeyMode.minor,
  );

  const ScaleType(this.label, this.intervals, this.letters, this.mode);
  final String label;
  final List<int> intervals;
  final List<int> letters;
  final KeyMode mode;
  List<SpelledPitch> tones(SpelledPitch root) => [
    for (var i = 0; i < intervals.length; i++)
      SpelledPitch.degree(
        root,
        letters[i],
        (root.pitchClass + intervals[i]) % 12,
      ),
  ];
  String degreeLabel(int index) {
    const major = [0, 2, 4, 5, 7, 9, 11];
    final degree = letters[index];
    final alteration = intervals[index] - major[degree];
    return '${alteration < 0 ? '♭' * -alteration : '♯' * alteration}${degree + 1}';
  }
}

class SpelledPitch {
  const SpelledPitch(this.letter, [this.accidental = 0]);
  static const letters = ['C', 'D', 'E', 'F', 'G', 'A', 'B'];
  static const natural = [0, 2, 4, 5, 7, 9, 11];
  final int letter;
  final int accidental;
  int get pitchClass => (natural[letter] + accidental) % 12;
  String get name =>
      '${letters[letter]}${accidental < 0 ? '♭' * -accidental : '♯' * accidental}';

  String labelForMidi(int midi) {
    final octaveShift = ((natural[letter] + accidental) / 12).floor();
    return '$name${midi ~/ 12 - 1 - octaveShift}';
  }

  factory SpelledPitch.parse(String name) => SpelledPitch(
    letters.indexOf(name[0]),
    '♯'.allMatches(name).length - '♭'.allMatches(name).length,
  );

  factory SpelledPitch.degree(SpelledPitch root, int steps, int pitchClass) {
    final letter = (root.letter + steps) % 7;
    final alteration = (pitchClass - natural[letter] + 6) % 12 - 6;
    return SpelledPitch(letter, alteration);
  }
}

class MusicalKey {
  const MusicalKey(this.fifths, [this.mode = KeyMode.major])
    : assert(fifths >= -7 && fifths <= 7);
  final int fifths;
  final KeyMode mode;
  static const circleFifths = [0, 1, 2, 3, 4, 5, 6, -5, -4, -3, -2, -1];
  static const _majorRoots = [
    'C♭',
    'G♭',
    'D♭',
    'A♭',
    'E♭',
    'B♭',
    'F',
    'C',
    'G',
    'D',
    'A',
    'E',
    'B',
    'F♯',
    'C♯',
  ];
  static const _minorRoots = [
    'A♭',
    'E♭',
    'B♭',
    'F',
    'C',
    'G',
    'D',
    'A',
    'E',
    'B',
    'F♯',
    'C♯',
    'G♯',
    'D♯',
    'A♯',
  ];
  SpelledPitch get root => SpelledPitch.parse(
    (mode == KeyMode.major ? _majorRoots : _minorRoots)[fifths + 7],
  );
  String get label => '${root.name} ${mode.name}';
  MusicalKey get relative =>
      MusicalKey(fifths, mode == KeyMode.major ? KeyMode.minor : KeyMode.major);
  MusicalKey get parallel {
    final other = mode == KeyMode.major ? KeyMode.minor : KeyMode.major;
    for (var f = -7; f <= 7; f++) {
      final key = MusicalKey(f, other);
      if (key.root.name == root.name) return key;
    }
    return MusicalKey.fromPitchClass(root.pitchClass, other);
  }

  ScaleType get basicScale =>
      mode == KeyMode.major ? ScaleType.major : ScaleType.naturalMinor;
  List<SpelledPitch> get tones => basicScale.tones(root);
  Set<int> get pitchClasses => tones.map((n) => n.pitchClass).toSet();
  bool get prefersFlats => fifths < 0;
  String get signature => fifths == 0
      ? 'No sharps or flats'
      : '${fifths.abs()} ${fifths > 0 ? 'sharp' : 'flat'}${fifths.abs() == 1 ? '' : 's'}';
  String get accidentals => fifths == 0
      ? '—'
      : (fifths > 0
                ? ['F♯', 'C♯', 'G♯', 'D♯', 'A♯', 'E♯', 'B♯']
                : ['B♭', 'E♭', 'A♭', 'D♭', 'G♭', 'C♭', 'F♭'])
            .take(fifths.abs())
            .join('  ');

  factory MusicalKey.fromPitchClass(int pc, KeyMode mode) {
    for (final fifths in circleFifths) {
      final key = MusicalKey(fifths, mode);
      if (key.root.pitchClass == pc % 12) return key;
    }
    throw ArgumentError('Invalid tonic.');
  }

  String nameFor(int pc) {
    for (final note in tones) {
      if (note.pitchClass == pc % 12) return note.name;
    }
    // Spell altered degrees relative to the tonic, rather than calling a
    // borrowed ♭VII in C "A♯" or a minor-key leading tone by its neighbor.
    final offset = (pc - root.pitchClass) % 12;
    final degree = (mode == KeyMode.major
        ? const {1: 1, 3: 2, 8: 5, 10: 6}
        : const {1: 1, 4: 2, 9: 5, 11: 6})[offset];
    if (degree != null) return SpelledPitch.degree(root, degree, pc % 12).name;
    const sharps = [
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
    const flats = [
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
    return (prefersFlats ? flats : sharps)[pc % 12];
  }

  bool sameSound(MusicalKey other) =>
      root.pitchClass == other.root.pitchClass && mode == other.mode;
  @override
  bool operator ==(Object other) =>
      other is MusicalKey && fifths == other.fifths && mode == other.mode;
  @override
  int get hashCode => Object.hash(fifths, mode);
}

class MusicalInterval {
  MusicalInterval(int firstMidi, int secondMidi)
    : semitones = (firstMidi - secondMidi).abs();
  final int semitones;
  static const _qualities = [
    'Perfect',
    'Minor',
    'Major',
    'Minor',
    'Major',
    'Perfect',
    'Tritone',
    'Perfect',
    'Minor',
    'Major',
    'Minor',
    'Major',
  ];
  static const _numbers = [1, 2, 2, 3, 3, 4, 4, 5, 6, 6, 7, 7];
  static const _short = [
    'P',
    'm',
    'M',
    'm',
    'M',
    'P',
    'TT',
    'P',
    'm',
    'M',
    'm',
    'M',
  ];
  int get number => _numbers[semitones % 12] + 7 * (semitones ~/ 12);
  String get shortName => semitones % 12 == 6
      ? 'TT${semitones >= 12 ? ' + ${semitones ~/ 12} oct.' : ''}'
      : '${_short[semitones % 12]}$number';
  String get name => semitones == 0
      ? 'Unison'
      : semitones == 12
      ? 'Perfect octave'
      : semitones % 12 == 6
      ? 'Tritone${semitones >= 12 ? ' + octave' : ''}'
      : '${_qualities[semitones % 12]} ${number <= 8 ? const ['unison', '2nd', '3rd', '4th', '5th', '6th', '7th', 'octave'][number - 1] : '${number}th'}';
}
