import 'dart:math' as math;
import 'dart:typed_data';

import '../music/piano_note.dart';
import 'note_input.dart';
import 'piano_model.dart';

/// Decodes every piano key independently. There is deliberately no top-K
/// selection or maximum chord size. Onsets start notes; frame probabilities
/// keep them held. Minimum duration and release hysteresis prevent flicker.
class PolyphonicDecoder {
  final _active = List.filled(PianoModel.keyCount, false);
  final _age = List.filled(PianoModel.keyCount, 0);
  final _quiet = List.filled(PianoModel.keyCount, 0);
  final _confidence = Float64List(PianoModel.keyCount);
  int _lastFrameSample = -1;

  List<DetectedNote> decode({
    required Float32List frameLogits,
    required Float32List onsetLogits,
    required int endSample,
    double onsetThreshold = 0.5,
  }) {
    const size = PianoModel.outputFrames * PianoModel.keyCount;
    if (frameLogits.length != size || onsetLogits.length != size) {
      throw const PianoModelException(
        'Unexpected piano prediction dimensions.',
      );
    }
    if (endSample - PianoModel.inputSamples > _lastFrameSample) {
      reset(); // A long processing gap must not leave old notes held.
    }
    for (var frame = 0; frame < PianoModel.outputFrames; frame++) {
      final sample =
          endSample -
          PianoModel.inputSamples +
          frame * PianoModel.frameSamples +
          PianoModel.spectralWindow ~/ 2;
      // Overlapping windows must not replay old onsets or advance release
      // counters twice. After a dropped window, process unseen history too.
      if (sample < 0 || sample <= _lastFrameSample) continue;
      _lastFrameSample = sample;
      for (var key = 0; key < PianoModel.keyCount; key++) {
        final index = frame * PianoModel.keyCount + key;
        final sounding = _sigmoid(frameLogits[index]);
        final onset = _sigmoid(onsetLogits[index]);
        final starts = onset >= onsetThreshold && sounding >= 0.3;
        if (starts) {
          _active[key] = true;
          _age[key] = 0;
        } else {
          _age[key]++;
        }
        _quiet[key] = sounding < 0.25 ? _quiet[key] + 1 : 0;
        if (_quiet[key] >= 2 && _age[key] >= 4) _active[key] = false;
        _confidence[key] = sounding;
      }
    }
    return [
      for (var key = 0; key < PianoModel.keyCount; key++)
        if (_active[key])
          DetectedNote(
            note: PianoNote(PianoModel.firstMidi + key),
            confidence: _confidence[key],
          ),
    ];
  }

  /// Advance the timeline while gated, so reopening the gate cannot replay
  /// onsets from the previous second of audio still in the context window.
  void silence(int endSample) {
    reset();
    _lastFrameSample = endSample - PianoModel.spectralWindow ~/ 2;
  }

  void reset() {
    _active.fillRange(0, _active.length, false);
    _age.fillRange(0, _age.length, 0);
    _quiet.fillRange(0, _quiet.length, 0);
    _confidence.fillRange(0, _confidence.length, 0);
    _lastFrameSample = -1;
  }

  double _sigmoid(double value) =>
      value.isFinite ? 1 / (1 + math.exp(-value.clamp(-60, 60))) : 0;
}
