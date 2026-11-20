import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:keylight/audio/microphone_audio_buffer.dart';
import 'package:keylight/audio/piano_model.dart';

Uint8List pcm(List<int> values) {
  final data = ByteData(values.length * 2);
  for (var i = 0; i < values.length; i++) {
    data.setInt16(i * 2, values[i], Endian.little);
  }
  return data.buffer.asUint8List();
}

void main() {
  test('odd PCM chunks preserve signed samples and padded model context', () {
    final values = List.generate(
      PianoModel.hopSamples,
      (i) => [-32768, -8192, 0, 8192, 32767][i % 5],
    );
    final bytes = pcm(values);
    final buffer = MicrophoneAudioBuffer(sampleRate: 16000);
    final windows = <PianoAudioWindow>[];
    buffer.add(Uint8List.sublistView(bytes, 0, 3), windows.add);
    buffer.add(Uint8List.sublistView(bytes, 3, 103), windows.add);
    expect(windows, isEmpty);
    buffer.add(Uint8List.sublistView(bytes, 103), windows.add);
    expect(windows.length, 1);
    expect(windows.single.endSample, PianoModel.hopSamples);
    expect(windows.single.samples.length, PianoModel.inputSamples);
    expect(
      windows.single.samples
          .take(17920 - PianoModel.hopSamples)
          .every((v) => v == 0),
      isTrue,
    );
    expect(
      windows.single.samples.skip(17920 - PianoModel.hopSamples),
      values.map((v) => v / 32768),
    );
    expect(windows.single.rms, greaterThan(.5));
  });

  test('stereo downmix preserves channel boundaries across chunks', () {
    final bytes = pcm(
      List.generate(PianoModel.hopSamples * 2, (i) => i.isEven ? 8192 : -8192),
    );
    final windows = <PianoAudioWindow>[];
    final buffer = MicrophoneAudioBuffer(sampleRate: 16000, channels: 2);
    buffer.add(Uint8List.sublistView(bytes, 0, 7), windows.add);
    buffer.add(Uint8List.sublistView(bytes, 7), windows.add);
    expect(windows.length, 1);
    expect(windows.single.rms, 0);
    expect(windows.single.samples.every((v) => v == 0), isTrue);
  });

  test(
    'hardware rates preserve duration and reject aliased high frequencies',
    () {
      for (final rate in [16000, 22050, 44100, 48000]) {
        final samples = <double>[];
        final resampler = StreamingResampler(rate, 16000);
        for (var i = 0; i < rate; i++) {
          resampler.add(
            .5 * math.sin(2 * math.pi * 1000 * i / rate),
            samples.add,
          );
        }
        expect(samples.length, closeTo(16000, 1), reason: '$rate Hz');
        final rms = math.sqrt(
          samples.skip(1000).map((x) => x * x).reduce((a, b) => a + b) /
              (samples.length - 1000),
        );
        expect(rms, closeTo(.5 / math.sqrt(2), .015));
      }
      final aliased = <double>[];
      final resampler = StreamingResampler(48000, 16000);
      for (var i = 0; i < 48000; i++) {
        resampler.add(
          .5 * math.sin(2 * math.pi * 10000 * i / 48000),
          aliased.add,
        );
      }
      final rms = math.sqrt(
        aliased.skip(1000).map((x) => x * x).reduce((a, b) => a + b) /
            (aliased.length - 1000),
      );
      expect(rms, lessThan(.005));
    },
  );

  test('window outputs do not depend on PCM delivery chunk sizes', () {
    final values = List.generate(
      16000,
      (i) => (12000 * math.sin(2 * math.pi * 440 * i / 22050)).round(),
    );
    final bytes = pcm(values);
    final whole = <PianoAudioWindow>[];
    final split = <PianoAudioWindow>[];
    MicrophoneAudioBuffer(sampleRate: 22050).add(bytes, whole.add);
    final buffer = MicrophoneAudioBuffer(sampleRate: 22050);
    for (var offset = 0; offset < bytes.length; offset += 711) {
      buffer.add(
        Uint8List.sublistView(
          bytes,
          offset,
          math.min(offset + 711, bytes.length),
        ),
        split.add,
      );
    }
    expect(split.length, whole.length);
    for (var i = 0; i < whole.length; i++) {
      expect(split[i].samples, whole[i].samples);
      expect(split[i].endSample, whole[i].endSample);
    }
  });
}
