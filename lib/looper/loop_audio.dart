import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_soloud/flutter_soloud.dart';
import 'package:record/record.dart';

/// PCM16 WAV in the negotiated microphone format.
Uint8List pcmWave(Uint8List pcm, int rate, int channels) {
  final bytes = Uint8List(44 + pcm.length);
  final h = ByteData.sublistView(bytes);
  void tag(int at, String value) => bytes.setAll(at, value.codeUnits);
  void u16(int at, int n) => h.setUint16(at, n, Endian.little);
  void u32(int at, int n) => h.setUint32(at, n, Endian.little);
  tag(0, 'RIFF');
  u32(4, bytes.length - 8);
  tag(8, 'WAVE');
  tag(12, 'fmt ');
  u32(16, 16);
  u16(20, 1);
  u16(22, channels);
  u32(24, rate);
  u32(28, rate * channels * 2);
  u16(32, channels * 2);
  u16(34, 16);
  tag(36, 'data');
  u32(40, pcm.length);
  bytes.setRange(44, bytes.length, pcm);
  return bytes;
}

const _clickRate = 44100;

/// One mono PCM16 bar. Round each onset from the bar origin, including its
/// end, so fractional sample intervals do not accumulate within the pattern.
Uint8List metronomeBar(int beatUs, int beats) {
  int frameAt(int beat) => (beat * beatUs * _clickRate + 500000) ~/ 1000000;
  final pcm = ByteData(frameAt(beats) * 2);
  for (var beat = 0; beat < beats; beat++) {
    final start = frameAt(beat);
    final frequency = beat == 0 ? 1650 : 950;
    final length = math.min(1024, frameAt(beat + 1) - start);
    for (var i = 0; i < length; i++) {
      final sample =
          14000 *
          math.exp(-i / 160) *
          math.sin(i * frequency * 2 * math.pi / _clickRate);
      pcm.setInt16((start + i) * 2, sample.round(), Endian.little);
    }
  }
  return pcm.buffer.asUint8List();
}

class LoopAudio {
  SoLoud get engine => SoLoud.instance;
  bool _preparedEngine = false;
  AudioRecorder? _recorder;
  StreamSubscription<Uint8List>? _input;
  AudioSource? _bar;
  (int, int)? _meter;
  SoundHandle? _countInVoice, _clickVoice;
  int rate = 44100, channels = 1;
  int _serial = 0;

  Future<void> prepare({required int beatUs, required int beats}) async {
    if (_meter == (beatUs, beats)) return;
    if (!engine.isInitialized) await engine.init(bufferSize: 512);
    _preparedEngine = true;
    final pcm = metronomeBar(beatUs, beats);
    final source = await engine.loadMem(
      'click-$beatUs-$beats',
      pcmWave(pcm, _clickRate, 1),
    );
    final old = _bar;
    _bar = source;
    _meter = (beatUs, beats);
    if (old != null) await engine.disposeSource(old);
  }

  void startMetronome({required bool countIn, required bool audible}) {
    final bar = _bar!;
    final start = engine.getEngineTime();
    var firstBar = start;
    if (countIn) {
      _countInVoice = engine.playScheduled(bar, start, volume: .65);
      firstBar += engine.getLength(bar);
    }
    // The repeating voice advances even when muted. Re-enabling the click
    // changes its gain without starting a new beat or resetting the phase.
    _clickVoice = engine.playScheduled(
      bar,
      firstBar,
      volume: audible ? .65 : 0,
      looping: true,
    );
    engine.setProtectVoice(_clickVoice!, true);
  }

  void setMetronomeAudible(bool audible) {
    final voice = _clickVoice;
    if (voice != null) engine.setVolume(voice, audible ? .65 : 0);
  }

  void stopMetronome() {
    stopVoice(_countInVoice);
    stopVoice(_clickVoice);
    _countInVoice = null;
    _clickVoice = null;
  }

  Future<void> capture(
    void Function(Uint8List) onData,
    void Function(Object) onError,
  ) async {
    final recorder = _recorder ??= AudioRecorder();
    if (!await recorder.hasPermission()) {
      throw StateError('Allow microphone access to record an audio track.');
    }
    rate = 44100;
    channels = 1;
    var delivered = false;
    await recorder.setOnConfigChanged((config) {
      if (delivered &&
          (config.sampleRate != rate || config.numChannels != channels)) {
        onError(StateError('Audio input changed during recording.'));
        return;
      }
      rate = config.sampleRate;
      channels = config.numChannels;
    });
    final stream = await recorder.startStream(
      const RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: 44100,
        numChannels: 1,
        streamBufferSize: 1024,
        androidConfig: AndroidRecordConfig(manageBluetooth: false),
      ),
    );
    _input = stream.listen(
      (chunk) {
        delivered = true;
        onData(chunk);
      },
      onError: onError,
      onDone: () {
        if (_input != null) onError(StateError('Microphone disconnected.'));
      },
    );
  }

  Future<void> endCapture() async {
    final sub = _input;
    _input = null;
    if (sub == null) return;
    try {
      await _recorder?.stop();
    } finally {
      await sub.cancel();
    }
  }

  Future<AudioSource> load(Uint8List pcm, int rate, int channels) =>
      engine.loadMem('loop-${_serial++}', pcmWave(pcm, rate, channels));
  SoundHandle play(AudioSource source, int offsetUs) {
    final handle = engine.play(source, paused: offsetUs > 0);
    if (offsetUs > 0) {
      engine.seek(handle, Duration(microseconds: offsetUs));
      engine.setPause(handle, false);
    }
    return handle;
  }

  void stopVoice(SoundHandle? handle) {
    if (handle != null && engine.getIsValidVoiceHandle(handle)) {
      unawaited(engine.stop(handle));
    }
  }

  Future<void> unload(AudioSource source) => engine.disposeSource(source);

  Future<void> dispose() async {
    await endCapture();
    await _recorder?.dispose();
    stopMetronome();
    final bar = _bar;
    if (bar != null) await engine.disposeSource(bar);
    if (_preparedEngine && engine.isInitialized) await engine.deinitAsync();
  }
}
