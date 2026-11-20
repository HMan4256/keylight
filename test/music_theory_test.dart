import 'package:flutter_test/flutter_test.dart';
import 'package:keylight/music/chords.dart';
import 'package:keylight/music/tonality.dart';
import 'package:keylight/studio/theory_controller.dart';

void main() {
  const recognize = ChordRecognizer();
  const c = MusicalKey(0);
  test(
    'recognizes inversions, doubled notes, extensions, and ambiguous names',
    () {
      final inverted = recognize.identify([52, 60, 64, 67, 72], c).first;
      expect(inverted.name(c), 'C/E');
      expect(inverted.inversionLabel, '1st inversion');
      expect(ChordFunction.analyze(inverted, c).roman, 'I');
      expect(recognize.identify([48, 52, 55, 59], c).first.name(c), 'Cmaj7');
      expect(recognize.identify([55, 59, 62, 65, 69], c).first.name(c), 'G9');
      final ambiguous = recognize
          .identify([48, 52, 55, 57], c)
          .map((n) => n.name(c));
      expect(ambiguous, containsAll(['C6', 'Am7/C']));
      expect(recognize.identify([60, 61, 62, 63], c), isEmpty);
      expect(recognize.identify([60], c), isEmpty);
    },
  );

  test('recognizes every supported chord in every transposition', () {
    for (var root = 0; root < 12; root++) {
      for (final type in ChordType.all) {
        final matches = recognize.identify([
          for (final interval in type.intervals) 48 + root + interval,
        ], c);
        expect(
          matches.any((m) => m.root == root && m.type.id == type.id),
          isTrue,
          reason: '$root ${type.id}',
        );
      }
    }
  });

  test('spells flat and sharp keys diatonically, including raised minor leading tones', () {
    expect(const MusicalKey(6).tones.map((n) => n.name), [
      'F♯',
      'G♯',
      'A♯',
      'B',
      'C♯',
      'D♯',
      'E♯',
    ]);
    expect(const MusicalKey(-5).tones.map((n) => n.name), [
      'D♭',
      'E♭',
      'F',
      'G♭',
      'A♭',
      'B♭',
      'C',
    ]);
    final dSharpMinor = const MusicalKey(6, KeyMode.minor);
    expect(ScaleType.harmonicMinor.tones(dSharpMinor.root).last.name, 'C♯♯');
    expect(const MusicalKey(-3).parallel.root.name, 'E♭');
    expect(const MusicalKey(0).relative.label, 'A minor');
    expect(const MusicalKey(0, KeyMode.minor).relative.label, 'C major');
    expect(SpelledPitch.parse('B♯').labelForMidi(60), 'B♯3');
    expect(SpelledPitch.parse('C♭').labelForMidi(59), 'C♭4');
    expect(SpelledPitch.parse('B♯♯').labelForMidi(61), 'B♯♯3');
    expect(SpelledPitch.parse('E♯').labelForMidi(65), 'E♯4');
    final theory = TheoryController();
    theory.selectKey(const MusicalKey(6));
    expect(theory.keyboardSpelling(0).labelForMidi(60), 'C4');
    theory.selectKey(const MusicalKey(4, KeyMode.minor));
    theory.setScale(ScaleType.harmonicMinor);
    expect(theory.keyboardSpelling(0).labelForMidi(60), 'B♯3');
    theory.dispose();
  });

  test('all seven-note scales harmonize to supported triads and sevenths in all keys', () {
    for (final mode in KeyMode.values) {
      for (final fifths in MusicalKey.circleFifths) {
        final key = MusicalKey(fifths, mode);
        for (final scale in ScaleType.values.where(
          (s) => s.intervals.length == 7,
        )) {
          for (var degree = 0; degree < 7; degree++) {
            for (final seventh in [false, true]) {
              final chord = diatonicChord(
                key,
                degree,
                seventh: seventh,
                scale: scale,
              );
              expect(
                scale
                    .tones(key.root)
                    .map((n) => n.pitchClass)
                    .toSet()
                    .containsAll(chord.pitchClasses),
                isTrue,
              );
              expect(chord.spelledTones(key).length, seventh ? 4 : 3);
            }
          }
        }
      }
    }
    expect(
      [
        for (var i = 0; i < 7; i++)
          ChordFunction.analyze(diatonicChord(c, i), c).roman,
      ],
      ['I', 'ii', 'iii', 'IV', 'V', 'vi', 'vii°'],
    );
  });

  test(
    'distinguishes function, secondary dominants, borrowed iv and minor V7',
    () {
      ChordFunction analyze(List<int> notes, MusicalKey key) =>
          ChordFunction.analyze(recognize.identify(notes, key).first, key);
      expect(analyze([50, 53, 57], c).role, HarmonicRole.predominant);
      expect(analyze([55, 59, 62, 65], c).roman, 'V7');
      expect(analyze([50, 54, 57, 60], c).roman, 'V7/V');
      expect(analyze([50, 54, 57, 60, 64], c).roman, 'V9/V');
      expect(analyze([48, 52, 55, 57], c).roman, 'I(add6)');
      expect(analyze([48, 52, 55, 58], c).roman, 'V7/IV');
      expect(c.nameFor(10), 'B♭');
      expect(analyze([53, 56, 60], c).roman, 'iv');
      expect(analyze([53, 56, 60], c).diatonic, isFalse);
      const a = MusicalKey(0, KeyMode.minor);
      expect(analyze([52, 56, 59, 62], a).roman, 'V7');
      expect(analyze([52, 56, 59, 62], a).role, HarmonicRole.dominant);
      expect(analyze([56, 59, 62, 65], a).roman, 'vii°7');
      expect(analyze([60, 67], c).role, HarmonicRole.color);
    },
  );

  test('intervals preserve compound size and octave doubling', () {
    expect(MusicalInterval(60, 64).shortName, 'M3');
    expect(MusicalInterval(60, 76).shortName, 'M10');
    expect(MusicalInterval(72, 60).name, 'Perfect octave');
    expect(MusicalInterval(60, 84).shortName, 'P15');
    expect(MusicalInterval(60, 66).name, 'Tritone');
  });

  test('manual key survives arbitrary playing and scale highlighting', () {
    final theory = TheoryController();
    addTearDown(theory.dispose);
    theory.selectKey(const MusicalKey(1));
    for (var frame = 0; frame < 100; frame++) {
      theory.observe(frame.isEven ? {60, 64, 67} : {55, 59, 62, 65});
    }
    expect(theory.key.label, 'G major');
    final before = theory.inputNotes;
    theory.setScale(ScaleType.harmonicMinor);
    expect(theory.key.label, 'G major');
    expect(theory.inputNotes, before);
    expect(theory.scaleTones.last.name, 'F♯');
    theory.setScale(null);
    expect(theory.scalePitchClasses, isEmpty);
    theory.selectKey(theory.key.parallel);
    expect(theory.key.label, 'G minor');
    expect(theory.inputNotes, before);
  });

  test(
    'parallel and relative keys remain distinct around the entire circle',
    () {
      for (final fifths in MusicalKey.circleFifths) {
        for (final mode in KeyMode.values) {
          final key = MusicalKey(fifths, mode);
          expect(key.parallel.root.pitchClass, key.root.pitchClass);
          expect(key.parallel.mode, isNot(key.mode));
          expect(key.relative.fifths, key.fifths);
          expect(key.relative.mode, isNot(key.mode));
          expect(key.parallel.parallel.sameSound(key), isTrue);
        }
      }
      expect(c.parallel.label, 'C minor');
      expect(c.relative.label, 'A minor');
    },
  );
}
