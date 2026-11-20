import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data' show BytesBuilder, Endian;

import 'package:flutter/services.dart';
import 'package:flutter_soloud/flutter_soloud.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keylight/looper/loop_audio.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('native click spacing survives a Dart stall and repeated bar boundaries', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (_) async => Directory.systemTemp.path,
        );
    final audio = LoopAudio();
    final engine = SoLoud.instance;
    const sampleRate = 44100, beats = 7;
    final beatUs = (60000000 / 137 / 2).round(); // Eighth notes in 7/8.
    await engine.init(
      bufferSize: 512,
      linuxAudioBackend: LinuxAudioBackend.pulseAudio,
    );
    try {
      await audio.prepare(beatUs: beatUs, beats: beats);
      engine.setGlobalVolume(.0001);
      final captured = BytesBuilder(copy: false);
      final done = engine
          .startMixerOutputStream(
            sampleRate: sampleRate,
            channels: 2,
            chunkPCMFrames: 4096,
          )
          .forEach(captured.add);
      audio.startMetronome(countIn: true, audible: true);
      await Future<void>.delayed(const Duration(milliseconds: 400));
      sleep(const Duration(milliseconds: 650));
      await Future<void>.delayed(const Duration(milliseconds: 4000));
      audio.stopMetronome();
      engine.stopMixerOutputStream();
      await done;

      final pcm = ByteData.sublistView(captured.takeBytes());
      final attacks = <int>[];
      for (var frame = 0; frame * 8 < pcm.lengthInBytes; frame++) {
        if (pcm.getFloat32(frame * 8, Endian.little).abs() > .000001 &&
            (attacks.isEmpty || frame - attacks.last > 1024)) {
          attacks.add(frame);
        }
      }
      expect(attacks.length, greaterThan(3 * beats));
      final spacing = beatUs * sampleRate / 1000000;
      final errors = [
        for (var i = 1; i < attacks.length; i++)
          (attacks[i] - attacks[i - 1] - spacing).abs(),
      ];
      final worst = errors.reduce(math.max);
      stdout.writeln(
        '${attacks.length} clicks, worst spacing error ${worst.toStringAsFixed(2)} samples',
      );
      expect(worst, lessThan(3), reason: 'onset frames: $attacks');
    } finally {
      await audio.dispose();
    }
  }, skip: !const bool.fromEnvironment('METRONOME_MIXER_TEST'));
}
