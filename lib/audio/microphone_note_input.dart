import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:record/record.dart';

import 'microphone_audio_buffer.dart';
import 'note_input.dart';
import 'piano_inference_worker.dart';
import 'piano_model.dart';

class MicrophonePermissionException implements Exception {}

class MicrophoneNoteInput implements NoteInput {
  final _frames = StreamController<NoteFrame>.broadcast();
  AudioRecorder? _recorder;
  StreamSubscription<Uint8List>? _subscription;
  StreamSubscription<RecordState>? _stateSubscription;
  PianoInferenceWorker? _worker;
  MicrophoneAudioBuffer _buffer = MicrophoneAudioBuffer(
    sampleRate: PianoModel.sampleRate,
  );
  int _sampleRate = PianoModel.sampleRate;
  int _channels = 1;
  int _bufferEpoch = 0;
  (PianoAudioWindow, int)? _nextWindow;
  bool _running = false;
  bool _busy = false;
  int _generation = 0;
  double noiseFloorDb = -45;
  double onsetThreshold = 0.5;

  @override
  Stream<NoteFrame> get frames => _frames.stream;

  @override
  Future<void> start() async {
    if (_running) return;
    final recorder = _recorder ??= AudioRecorder();
    if (!await recorder.hasPermission()) throw MicrophonePermissionException();
    final worker = PianoInferenceWorker();
    _worker = worker;
    try {
      final model = await rootBundle.load(PianoModel.asset);
      await worker.start(
        model.buffer.asUint8List(model.offsetInBytes, model.lengthInBytes),
      );
      _sampleRate = PianoModel.sampleRate;
      _channels = 1;
      _bufferEpoch++;
      _buffer = MicrophoneAudioBuffer(sampleRate: _sampleRate);
      await recorder.setOnConfigChanged((config) {
        if (_sampleRate != config.sampleRate ||
            _channels != config.numChannels) {
          _sampleRate = config.sampleRate;
          _channels = config.numChannels;
          _bufferEpoch++;
          _nextWindow = null;
          _buffer = MicrophoneAudioBuffer(
            sampleRate: _sampleRate,
            channels: _channels,
          );
        }
      });
      final stream = await recorder.startStream(
        const RecordConfig(
          encoder: AudioEncoder.pcm16bits,
          sampleRate: PianoModel.sampleRate,
          numChannels: 1,
          androidConfig: AndroidRecordConfig(manageBluetooth: false),
          streamBufferSize: 512,
        ),
      );
      _running = true;
      _generation++;
      _stateSubscription = recorder.onStateChanged().listen((state) {
        if (_running && state != RecordState.record) {
          _frames.addError(
            StateError('Microphone interrupted. Tap Listen to reconnect.'),
          );
        }
      }, onError: (Object error) => _frames.addError(error));
      _subscription = stream.listen(
        (bytes) => _buffer.add(bytes, (window) {
          _nextWindow = (window, _bufferEpoch);
          unawaited(_drainWindows());
        }),
        onError: (Object error) => _frames.addError(error),
        onDone: () {
          if (_running) {
            _frames.addError(
              StateError('The microphone disconnected. Try starting again.'),
            );
          }
        },
      );
    } catch (_) {
      await stop();
      rethrow;
    }
  }

  Future<void> _drainWindows() async {
    if (_busy || !_running) return;
    _busy = true;
    final generation = _generation;
    try {
      while (_running && generation == _generation && _nextWindow != null) {
        final (window, epoch) = _nextWindow!;
        _nextWindow = null;
        final result = await _worker?.analyze(
          window,
          noiseFloor: math.pow(10, noiseFloorDb / 20).toDouble(),
          onsetThreshold: onsetThreshold,
          epoch: epoch,
        );
        if (!_running || generation != _generation) return;
        if (result == null || epoch != _bufferEpoch) continue;
        _frames.add(
          NoteFrame(
            notes: result.notes,
            rms: window.rms,
            waveform: window.waveform,
            // Decoder handles individual note releases; this is a watchdog for
            // a stalled input/worker, longer than the 32 ms analysis hop.
            releaseAfter: const Duration(milliseconds: 600),
          ),
        );
      }
    } catch (error) {
      if (_running && generation == _generation) _frames.addError(error);
    } finally {
      if (generation == _generation) _busy = false;
    }
  }

  @override
  Future<void> stop() async {
    _running = false;
    _generation++;
    _busy = false;
    _nextWindow = null;
    await _stateSubscription?.cancel();
    _stateSubscription = null;
    await _subscription?.cancel();
    _subscription = null;
    await _worker?.dispose();
    _worker = null;
    await _recorder?.stop();
  }

  @override
  Future<void> dispose() async {
    await stop();
    await _recorder?.dispose();
    await _frames.close();
  }
}
