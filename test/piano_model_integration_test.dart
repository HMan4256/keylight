import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:keylight/audio/microphone_audio_buffer.dart';
import 'package:keylight/audio/piano_inference_worker.dart';
import 'package:keylight/audio/piano_model.dart';

import 'support/wav_fixture.dart';

// Opt-in: requires a native TFLite C runtime for the host Flutter test runner.
// See docs/polyphonic_detection.md for reproducible setup and fixture source.
const enabled = bool.fromEnvironment('PIANO_MODEL_INTEGRATION');
const recording = String.fromEnvironment('PIANO_TEST_WAV');

void main() {
  test(
    'bundled native model detects simultaneous notes in a piano recording',
    () async {
      expect(
        recording,
        isNotEmpty,
        reason: 'Pass --dart-define=PIANO_TEST_WAV=/path/to/piano.wav',
      );
      final worker = PianoInferenceWorker();
      await worker.start(await File(PianoModel.asset).readAsBytes());
      try {
        final (rate, channels, pcm) = readWav(
          await File(recording).readAsBytes(),
        );
        final buffer = MicrophoneAudioBuffer(
          sampleRate: rate,
          channels: channels,
        );
        final windows = <PianoAudioWindow>[];
        for (var offset = 0; offset < pcm.length; offset += 1601) {
          buffer.add(
            Uint8List.sublistView(
              pcm,
              offset,
              (offset + 1601).clamp(0, pcm.length),
            ),
            windows.add,
          );
        }
        final durations = <int>[];
        var largestChord = 0;
        var foundChord = false;
        final pitches = <int>{};
        for (final window in windows) {
          final result = (await worker.analyze(window))!;
          final keys = result.notes.map((n) => n.note.midi).toSet();
          pitches.addAll(keys);
          if (keys.length > largestChord) largestChord = keys.length;
          if (keys.containsAll({60, 64, 72})) foundChord = true;
          expect(keys.every((n) => n >= 21 && n <= 108), isTrue);
          expect(result.notes.every((n) => n.frequency == null), isTrue);
          if (result.inferenceMicroseconds > 0) {
            durations.add(result.inferenceMicroseconds);
          }
        }
        expect(
          foundChord,
          isTrue,
          reason: 'The recorded excerpt includes C4/E4/C5 together.',
        );
        expect(largestChord, greaterThanOrEqualTo(4));
        expect(pitches, containsAll([57, 60, 64, 69, 71, 72, 76, 81, 83, 84]));
        // The noise gate releases every note immediately and cannot replay old
        // onsets when the stream restarts with a new sample clock/epoch.
        final silence = PianoAudioWindow(
          Float32List(17920),
          windows.last.endSample + 2048,
          0,
          const [],
        );
        expect((await worker.analyze(silence))!.notes, isEmpty);
        expect((await worker.analyze(windows.first, epoch: 1))!.notes, isEmpty);
        final random = math.Random(42);
        final noise = Float32List.fromList(
          List.generate(
            PianoModel.inputSamples,
            (_) => (random.nextDouble() - .5) * .12,
          ),
        );
        expect(
          (await worker.analyze(
            PianoAudioWindow(noise, PianoModel.inputSamples, .035, const []),
            epoch: 2,
          ))!.notes,
          isEmpty,
        );
        durations.sort();
        // ignore: avoid_print
        print(
          'Recorded piano: ${windows.length} windows, $largestChord simultaneous notes, ${pitches.length} distinct pitches; native inference median ${(durations[durations.length ~/ 2] / 1000).toStringAsFixed(1)} ms, max ${(durations.last / 1000).toStringAsFixed(1)} ms. Host timings are not phone benchmarks.',
        );
      } finally {
        await worker.dispose();
      }
    },
    skip: !enabled,
    timeout: const Timeout(Duration(minutes: 3)),
  );

  test(
    'invalid model startup fails and cleans up instead of hanging',
    () async {
      final worker = PianoInferenceWorker();
      await expectLater(
        worker.start(Uint8List(16)),
        throwsA(isA<PianoModelException>()),
      );
      await worker.dispose();
    },
    skip: !enabled,
  );
}
