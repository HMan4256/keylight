import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:keylight/audio/piano_model.dart';
import 'package:keylight/audio/polyphonic_decoder.dart';

Float32List predictions(Iterable<int> notes, {bool lastFrameOnly = false}) {
  final data = Float32List(32 * 88)..fillRange(0, 32 * 88, -12);
  for (var frame = lastFrameOnly ? 31 : 0; frame < 32; frame++) {
    for (final midi in notes) {
      data[frame * 88 + midi - 21] = 6;
    }
  }
  return data;
}

void main() {
  test('supports all 88 independent activations without a chord-size cap', () {
    final decoder = PolyphonicDecoder();
    final keys = List.generate(88, (i) => i + 21);
    final detected = decoder.decode(
      frameLogits: predictions(keys),
      onsetLogits: predictions(keys, lastFrameOnly: true),
      endSample: 17920,
    );
    expect(detected.map((n) => n.note.midi), keys);
    expect(
      detected.every((n) => n.frequency == null && n.cents == null),
      isTrue,
    );
  });

  test(
    'holds a dense chord and releases individual voices, not the whole chord',
    () {
      final decoder = PolyphonicDecoder();
      const chord = [36, 48, 55, 60, 64, 67, 72, 76, 79, 84, 88, 91];
      decoder.decode(
        frameLogits: predictions(chord),
        onsetLogits: predictions(chord, lastFrameOnly: true),
        endSample: 17920,
      );
      final retained = chord.where((key) => key != 60 && key != 88).toList();
      final result = decoder.decode(
        frameLogits: predictions(retained),
        onsetLogits: predictions([]),
        endSample: 19968,
      );
      expect(result.map((n) => n.note.midi), retained);
      expect(
        decoder.decode(
          frameLogits: predictions([]),
          onsetLogits: predictions([]),
          endSample: 22016,
        ),
        isEmpty,
      );
    },
  );

  test('frame energy alone cannot invent a harmonic note without an onset', () {
    final decoder = PolyphonicDecoder();
    decoder.decode(
      frameLogits: predictions([48]),
      onsetLogits: predictions([48], lastFrameOnly: true),
      endSample: 17920,
    );
    final result = decoder.decode(
      frameLogits: predictions([48, 60, 67, 72]),
      onsetLogits: predictions([]),
      endSample: 19968,
    );
    expect(result.map((n) => n.note.midi), [48]);
  });

  test('overlap never replays onsets or counts release frames twice', () {
    final decoder = PolyphonicDecoder();
    final frames = predictions([60], lastFrameOnly: true);
    final onsets = predictions([60], lastFrameOnly: true);
    decoder.decode(frameLogits: frames, onsetLogits: onsets, endSample: 17920);
    for (var i = 0; i < 10; i++) {
      final result = decoder.decode(
        frameLogits: predictions([]),
        onsetLogits: predictions([]),
        endSample: 17920,
      );
      expect(result.map((n) => n.note.midi), [60]);
    }
    expect(
      decoder.decode(
        frameLogits: predictions([]),
        onsetLogits: predictions([]),
        endSample: 19968,
      ),
      isEmpty,
    );
  });

  test(
    'silence advances time so old context cannot resurrect released notes',
    () {
      final decoder = PolyphonicDecoder();
      decoder.silence(17920);
      final frames = predictions([]);
      final onsets = predictions([]);
      // Previous note exists in context but predates the silence snapshot.
      frames[20 * 88 + 60 - 21] = 6;
      onsets[20 * 88 + 60 - 21] = 6;
      expect(
        decoder.decode(
          frameLogits: frames,
          onsetLogits: onsets,
          endSample: 19968,
        ),
        isEmpty,
      );
    },
  );

  test('a processing gap recovers unseen attacks from retained history', () {
    final decoder = PolyphonicDecoder();
    decoder.silence(17920);
    final frames = predictions([60, 64, 67]);
    final onsets = predictions([]);
    for (final key in [60, 64, 67]) {
      onsets[25 * 88 + key - 21] = 6;
    }
    final result = decoder.decode(
      frameLogits: frames,
      onsetLogits: onsets,
      endSample: 22016,
    );
    expect(result.map((n) => n.note.midi), [60, 64, 67]);
  });

  test('rejects invalid tensor sizes and non-finite activations', () {
    final decoder = PolyphonicDecoder();
    expect(
      () => decoder.decode(
        frameLogits: Float32List(88),
        onsetLogits: predictions([]),
        endSample: 17920,
      ),
      throwsA(isA<PianoModelException>()),
    );
    final invalid = predictions([])..[31 * 88 + 39] = double.nan;
    expect(
      decoder.decode(
        frameLogits: invalid,
        onsetLogits: invalid,
        endSample: 17920,
      ),
      isEmpty,
    );
  });
}
