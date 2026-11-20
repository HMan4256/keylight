import 'tonality.dart';

enum HarmonicRole { tonic, prolongation, predominant, dominant, color }

class ChordType {
  const ChordType(
    this.id,
    this.label,
    this.symbol,
    this.intervals,
    this.degrees, {
    this.minor = false,
    this.diminished = false,
    this.augmented = false,
  });
  final String id, label, symbol;
  final List<int> intervals;
  final List<int> degrees;
  final bool minor, diminished, augmented;
  Set<int> get pitchClasses => intervals.map((i) => i % 12).toSet();
  bool get seventh =>
      intervals.contains(10) || intervals.contains(11) || id == 'dim7';
  bool get isDominant =>
      id == '7' ||
      id == '9' ||
      id == '11' ||
      id == '13' ||
      id == '7b9' ||
      id == '7#9';

  static const all = [
    ChordType('major', 'Major', '', [0, 4, 7], [0, 2, 4]),
    ChordType('minor', 'Minor', 'm', [0, 3, 7], [0, 2, 4], minor: true),
    ChordType(
      'dim',
      'Diminished',
      'dim',
      [0, 3, 6],
      [0, 2, 4],
      diminished: true,
    ),
    ChordType('aug', 'Augmented', '+', [0, 4, 8], [0, 2, 4], augmented: true),
    ChordType(
      'augMaj7',
      'Augmented major 7th',
      '+maj7',
      [0, 4, 8, 11],
      [0, 2, 4, 6],
      augmented: true,
    ),
    ChordType('sus2', 'Suspended 2nd', 'sus2', [0, 2, 7], [0, 1, 4]),
    ChordType('sus4', 'Suspended 4th', 'sus4', [0, 5, 7], [0, 3, 4]),
    ChordType('5', 'Open fifth (no third)', '5', [0, 7], [0, 4]),
    ChordType('7', 'Dominant 7th', '7', [0, 4, 7, 10], [0, 2, 4, 6]),
    ChordType('maj7', 'Major 7th', 'maj7', [0, 4, 7, 11], [0, 2, 4, 6]),
    ChordType(
      'm7',
      'Minor 7th',
      'm7',
      [0, 3, 7, 10],
      [0, 2, 4, 6],
      minor: true,
    ),
    ChordType(
      'mMaj7',
      'Minor major 7th',
      'm(maj7)',
      [0, 3, 7, 11],
      [0, 2, 4, 6],
      minor: true,
    ),
    ChordType(
      'halfDim',
      'Half-diminished 7th',
      'm7♭5',
      [0, 3, 6, 10],
      [0, 2, 4, 6],
      diminished: true,
    ),
    ChordType(
      'dim7',
      'Diminished 7th',
      'dim7',
      [0, 3, 6, 9],
      [0, 2, 4, 6],
      diminished: true,
    ),
    ChordType('6', 'Major 6th', '6', [0, 4, 7, 9], [0, 2, 4, 5]),
    ChordType('m6', 'Minor 6th', 'm6', [0, 3, 7, 9], [0, 2, 4, 5], minor: true),
    ChordType('add9', 'Add 9', 'add9', [0, 4, 7, 14], [0, 2, 4, 8]),
    ChordType(
      'mAdd9',
      'Minor add 9',
      'm(add9)',
      [0, 3, 7, 14],
      [0, 2, 4, 8],
      minor: true,
    ),
    ChordType('9', 'Dominant 9th', '9', [0, 4, 7, 10, 14], [0, 2, 4, 6, 8]),
    ChordType('maj9', 'Major 9th', 'maj9', [0, 4, 7, 11, 14], [0, 2, 4, 6, 8]),
    ChordType(
      'm9',
      'Minor 9th',
      'm9',
      [0, 3, 7, 10, 14],
      [0, 2, 4, 6, 8],
      minor: true,
    ),
    ChordType('7sus4', 'Dominant 7sus4', '7sus4', [0, 5, 7, 10], [0, 3, 4, 6]),
    ChordType(
      'm11',
      'Minor 11th',
      'm11',
      [0, 3, 7, 10, 14, 17],
      [0, 2, 4, 6, 8, 10],
      minor: true,
    ),
    ChordType(
      '11',
      'Dominant 11th',
      '11',
      [0, 4, 7, 10, 14, 17],
      [0, 2, 4, 6, 8, 10],
    ),
    ChordType(
      '13',
      'Dominant 13th (no 11)',
      '13',
      [0, 4, 7, 10, 14, 21],
      [0, 2, 4, 6, 8, 12],
    ),
    ChordType(
      '7b9',
      'Dominant 7 flat 9',
      '7♭9',
      [0, 4, 7, 10, 13],
      [0, 2, 4, 6, 8],
    ),
    ChordType(
      '7#9',
      'Dominant 7 sharp 9',
      '7♯9',
      [0, 4, 7, 10, 15],
      [0, 2, 4, 6, 8],
    ),
  ];
  static ChordType byId(String id) => all.firstWhere((c) => c.id == id);
}

class IdentifiedChord {
  const IdentifiedChord(this.root, this.type, this.bass, this.midi);
  final int root, bass;
  final ChordType type;
  final List<int> midi;
  String name(MusicalKey key) =>
      '${key.nameFor(root)}${type.symbol}${bass == root ? '' : '/${key.nameFor(bass)}'}';
  String get identity => '$root:${type.id}:$bass';
  Set<int> get pitchClasses =>
      type.intervals.map((i) => (root + i) % 12).toSet();
  int get inversion =>
      type.intervals.indexWhere((i) => (root + i) % 12 == bass);
  String get inversionLabel => inversion == 0
      ? 'Root position'
      : '${const ['Root', '1st', '2nd', '3rd', '4th', '5th', '6th'][inversion.clamp(0, 6)]} inversion';
  List<SpelledPitch> spelledTones(MusicalKey key) {
    final tonic = SpelledPitch.parse(key.nameFor(root));
    return [
      for (var i = 0; i < type.intervals.length; i++)
        SpelledPitch.degree(
          tonic,
          type.degrees[i],
          (root + type.intervals[i]) % 12,
        ),
    ];
  }
}

class ChordRecognizer {
  const ChordRecognizer();
  static int _mask(Iterable<int> pitches) =>
      pitches.fold(0, (mask, pitch) => mask | (1 << (pitch % 12)));

  static final _voicings = _patterns();
  static Map<int, List<(int, ChordType)>> _patterns() {
    final patterns = <int, List<(int, ChordType)>>{};
    for (var root = 0; root < 12; root++) {
      for (final type in ChordType.all) {
        final mask = _mask(type.intervals.map((i) => i + root));
        (patterns[mask] ??= []).add((root, type));
      }
    }
    return patterns;
  }

  List<IdentifiedChord> identify(Iterable<int> midiNotes, MusicalKey key) {
    final midi = midiNotes.toSet().toList()..sort();
    if (midi.length < 2) return [];
    final bass = midi.first % 12;
    final matches = [
      for (final (root, type)
          in _voicings[_mask(midi)] ?? const <(int, ChordType)>[])
        IdentifiedChord(root, type, bass, midi),
    ];
    double rank(IdentifiedChord chord) =>
        (chord.root == bass ? 3 : 0) +
        (key.pitchClasses.containsAll(chord.pitchClasses) ? .4 : 0) +
        (chord.type.id.startsWith('sus') ? 0 : .2) -
        ChordType.all.indexOf(chord.type) * .001;
    matches.sort((a, b) => rank(b).compareTo(rank(a)));
    return matches;
  }
}

class ChordFunction {
  const ChordFunction(
    this.roman,
    this.role,
    this.explanation, {
    this.diatonic = true,
  });
  final String roman, explanation;
  final HarmonicRole role;
  final bool diatonic;
  String get roleLabel => switch (role) {
    HarmonicRole.tonic => 'Tonic · home',
    HarmonicRole.prolongation => 'Tonic prolongation',
    HarmonicRole.predominant => 'Predominant · prepares',
    HarmonicRole.dominant => 'Dominant · tension',
    HarmonicRole.color => 'Color / context dependent',
  };
  static const numerals = ['I', 'II', 'III', 'IV', 'V', 'VI', 'VII'];

  static ChordFunction analyze(IdentifiedChord chord, MusicalKey key) {
    final keyTones = key.tones.map((n) => n.pitchClass).toList();
    var degree = keyTones.indexOf(chord.root);
    final inScale = key.pitchClasses.containsAll(chord.pitchClasses);
    final minorLeadingTone =
        key.mode == KeyMode.minor &&
        chord.root == (key.root.pitchClass + 11) % 12 &&
        chord.type.diminished;
    if (minorLeadingTone) {
      return ChordFunction(
        _roman(6, chord.type),
        HarmonicRole.dominant,
        'The raised leading tone pulls toward ${key.root.name}.',
        diatonic: false,
      );
    }
    if (degree == 4 && (chord.type.id == 'major' || chord.type.isDominant)) {
      return ChordFunction(
        _roman(4, chord.type),
        HarmonicRole.dominant,
        key.mode == KeyMode.minor
            ? 'A raised leading tone gives the dominant a stronger pull home.'
            : 'Often resolves to ${key.root.name}, the tonic.',
        diatonic: inScale,
      );
    }
    if (!inScale &&
        (degree != 0 || chord.type.isDominant) &&
        (chord.type.id == 'major' || chord.type.isDominant)) {
      for (var target = 1; target < 7; target++) {
        final targetChord = diatonicChord(key, target);
        if (targetChord.type.diminished ||
            chord.root != (targetChord.root + 7) % 12) {
          continue;
        }
        final targetRoman = _roman(target, targetChord.type);
        return ChordFunction(
          'V${chord.type.id == 'major' ? '' : chord.type.symbol}/$targetRoman',
          HarmonicRole.dominant,
          'Possible secondary dominant: points toward ${targetChord.name(key)} ($targetRoman).',
          diatonic: false,
        );
      }
    }
    var prefix = '';
    if (degree < 0) {
      // Prefer a lowered scale degree for chromatic roots (e.g. ♭VII).
      degree = keyTones.indexWhere((n) => (n - 1) % 12 == chord.root);
      if (degree >= 0) {
        prefix = '♭';
      } else {
        degree = keyTones.indexWhere((n) => (n + 1) % 12 == chord.root);
        prefix = '♯';
      }
    }
    if (degree < 0) {
      return const ChordFunction(
        '—',
        HarmonicRole.color,
        'This voicing needs more harmonic context.',
        diatonic: false,
      );
    }
    final roman = '$prefix${_roman(degree, chord.type)}';
    if (chord.type.id == '5' ||
        chord.type.id.startsWith('sus') ||
        chord.type.id == '7sus4') {
      return ChordFunction(
        roman,
        HarmonicRole.color,
        'Without a third, major/minor quality and function remain open.',
        diatonic: inScale,
      );
    }
    final expected = diatonicChord(key, degree).type;
    final qualityFits =
        chord.type.minor == expected.minor &&
        chord.type.diminished == expected.diminished &&
        chord.type.augmented == expected.augmented;
    if ((!inScale || !qualityFits) && degree != 0) {
      if (key.mode == KeyMode.major && degree == 3 && chord.type.minor) {
        return ChordFunction(
          roman,
          HarmonicRole.predominant,
          'Borrowed minor iv: a common color before returning home.',
          diatonic: false,
        );
      }
      return ChordFunction(
        roman,
        HarmonicRole.color,
        'Outside the reference scale; borrowed color or another key may explain it.',
        diatonic: false,
      );
    }
    final role = switch (degree) {
      0 => HarmonicRole.tonic,
      1 || 3 => HarmonicRole.predominant,
      4 => HarmonicRole.dominant,
      6 => chord.type.diminished ? HarmonicRole.dominant : HarmonicRole.color,
      _ => HarmonicRole.prolongation,
    };
    return ChordFunction(roman, role, switch (role) {
      HarmonicRole.tonic => 'The tonal center: a common place of rest.',
      HarmonicRole.prolongation =>
        'Shares tones with the tonic; often extends a feeling of home.',
      HarmonicRole.predominant => 'Often prepares a dominant chord.',
      HarmonicRole.dominant =>
        key.mode == KeyMode.minor && chord.type.minor
            ? 'Minor v is a weaker dominant; V or V7 adds the raised leading tone.'
            : 'Creates tension that often resolves to the tonic.',
      HarmonicRole.color => 'Its role depends on the surrounding progression.',
    }, diatonic: inScale);
  }

  static String _roman(int degree, ChordType type) {
    var numeral = numerals[degree];
    if (type.minor || type.diminished) numeral = numeral.toLowerCase();
    if (type.id == 'halfDim') return '$numeralø7';
    if (type.diminished) return '$numeral°${type.id == 'dim7' ? '7' : ''}';
    if (type.augmented) return '$numeral${type.symbol}';
    if (type.id == '6' || type.id == 'm6') return '$numeral(add6)';
    return '$numeral${type.symbol.replaceFirst('m', type.minor ? '' : 'm')}';
  }
}

IdentifiedChord diatonicChord(
  MusicalKey key,
  int degree, {
  bool seventh = false,
  ScaleType? scale,
}) {
  final tones =
      (scale != null && scale.intervals.length == 7 ? scale : key.basicScale)
          .tones(key.root);
  final root = tones[degree].pitchClass;
  final pcs = {
    for (var stack = 0; stack < (seventh ? 4 : 3); stack++)
      (tones[(degree + stack * 2) % 7].pitchClass - root) % 12,
  };
  final type = ChordType.all.firstWhere(
    (type) =>
        type.pitchClasses.length == pcs.length &&
        type.pitchClasses.containsAll(pcs),
  );
  final midi = [for (final interval in type.intervals) 60 + root + interval];
  return IdentifiedChord(root, type, root, midi);
}
