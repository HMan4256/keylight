import 'dart:async';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:tflite_flutter/tflite_flutter.dart';

import 'microphone_audio_buffer.dart';
import 'note_input.dart';
import 'piano_model.dart';
import 'polyphonic_decoder.dart';

class PianoInferenceResult {
  const PianoInferenceResult(this.notes, this.inferenceMicroseconds);
  final List<DetectedNote> notes;
  final int inferenceMicroseconds;
}

class _Request {
  const _Request(this.window, this.noiseFloor, this.onsetThreshold, this.epoch);
  final PianoAudioWindow window;
  final double noiseFloor;
  final double onsetThreshold;
  final int epoch;
}

class _Failure {
  const _Failure(this.message);
  final String message;
}

/// A persistent inference isolate owns the native interpreter and decoder.
/// Only one request may be outstanding; audio capture retains the newest
/// pending window, never an unbounded queue of old microphone audio.
class PianoInferenceWorker {
  final _receive = ReceivePort();
  final _ready = Completer<void>();
  final _exited = Completer<void>();
  Isolate? _isolate;
  SendPort? _send;
  Completer<PianoInferenceResult?>? _pending;
  StreamSubscription<dynamic>? _subscription;
  bool _closing = false;
  bool _failed = false;

  Future<void> start(
    Uint8List modelBytes, {
    bool useAcceleration = true,
  }) async {
    _subscription = _receive.listen((dynamic message) {
      if (message is SendPort) {
        _send = message;
        if (!_ready.isCompleted) _ready.complete();
      } else if (message is PianoInferenceResult) {
        _pending?.complete(message);
        _pending = null;
      } else if (message == null) {
        if (!_exited.isCompleted) _exited.complete();
        if (!_closing) _fail('The piano analysis worker stopped unexpectedly.');
      } else {
        final reason = message is _Failure
            ? message.message
            : message.toString();
        _fail(reason);
      }
    });
    try {
      _isolate = await Isolate.spawn(
        _run,
        (
          _receive.sendPort,
          TransferableTypedData.fromList([modelBytes]),
          useAcceleration,
        ),
        onError: _receive.sendPort,
        onExit: _receive.sendPort,
      );
      await _ready.future.timeout(const Duration(seconds: 20));
    } catch (error) {
      await dispose();
      throw PianoModelException('Could not load piano detection: $error');
    }
  }

  void _fail(String reason) {
    final failure = PianoModelException(reason);
    if (!_ready.isCompleted) _ready.completeError(failure);
    _pending?.completeError(failure);
    _pending = null;
    _failed = true;
  }

  Future<PianoInferenceResult?> analyze(
    PianoAudioWindow window, {
    double noiseFloor = 0.0056,
    double onsetThreshold = 0.5,
    int epoch = 0,
  }) {
    if (_send == null || _pending != null || _closing || _failed) {
      return Future.value(null);
    }
    final pending = Completer<PianoInferenceResult?>();
    _pending = pending;
    _send!.send(_Request(window, noiseFloor, onsetThreshold, epoch));
    return pending.future;
  }

  Future<void> dispose() async {
    if (_closing) return;
    _closing = true;
    _send?.send('close');
    _send = null;
    _pending?.complete(null);
    _pending = null;
    if (_isolate != null && !_exited.isCompleted) {
      try {
        await _exited.future.timeout(const Duration(seconds: 2));
      } on TimeoutException {
        _isolate?.kill(priority: Isolate.immediate);
      }
    }
    await _subscription?.cancel();
    _receive.close();
  }

  static void _run((SendPort, TransferableTypedData, bool) initialization) {
    final (reply, modelData, useAcceleration) = initialization;
    Interpreter? interpreter;
    XNNPackDelegate? acceleration;
    try {
      final bytes = modelData.materialize().asUint8List();
      Interpreter create([XNNPackDelegate? delegate]) {
        final options = InterpreterOptions()..threads = 2;
        try {
          if (delegate != null) options.addDelegate(delegate);
          return Interpreter.fromBuffer(bytes, options: options);
        } finally {
          options.delete();
        }
      }

      if (useAcceleration) {
        try {
          // Native defaults avoid assumptions about the options struct ABI.
          acceleration = XNNPackDelegate();
          if (acceleration.base.address == 0) {
            acceleration = null;
          } else {
            interpreter = create(acceleration);
          }
        } catch (_) {
          // Some iOS/host runtimes do not export XNNPACK. Keep CPU support.
          acceleration?.delete();
          acceleration = null;
        }
      }
      interpreter ??= create();
      final model = interpreter;
      final input = model.getInputTensor(0);
      final outputs = {
        for (final tensor in model.getOutputTensors()) tensor.name: tensor,
      };
      final frames = outputs['frame_logits'];
      final onsets = outputs['onset_logits'];
      if (input.shape.length != 1 ||
          input.shape.single != PianoModel.inputSamples ||
          input.type != TensorType.float32 ||
          frames == null ||
          onsets == null ||
          !_validOutput(frames) ||
          !_validOutput(onsets)) {
        throw const PianoModelException(
          'The bundled piano model has incompatible tensors.',
        );
      }
      final decoder = PolyphonicDecoder();
      var epoch = -1;
      var hasSoundingNotes = false;
      final receive = ReceivePort();
      reply.send(receive.sendPort);
      receive.listen((dynamic message) {
        if (message == 'close') {
          model.close();
          acceleration?.delete();
          receive.close();
          Isolate.exit();
        }
        if (message is! _Request) return;
        try {
          if (message.epoch != epoch) {
            decoder.reset();
            hasSoundingNotes = false;
            epoch = message.epoch;
          }
          final window = message.window;
          // Keep analyzing a fading piano string below the attack gate.
          // The frame classifier can release individual notes in a chord.
          final gate = message.noiseFloor * (hasSoundingNotes ? .25 : 1);
          if (window.rms < gate) {
            hasSoundingNotes = false;
            decoder.silence(window.endSample);
            reply.send(const PianoInferenceResult([], 0));
            return;
          }
          input.data = window.samples.buffer.asUint8List(
            window.samples.offsetInBytes,
            window.samples.lengthInBytes,
          );
          final watch = Stopwatch()..start();
          model.invoke();
          final elapsed = watch.elapsedMicroseconds;
          final notes = decoder.decode(
            frameLogits: Float32List.sublistView(frames.data),
            onsetLogits: Float32List.sublistView(onsets.data),
            endSample: window.endSample,
            onsetThreshold: message.onsetThreshold,
          );
          hasSoundingNotes = notes.isNotEmpty;
          reply.send(PianoInferenceResult(notes, elapsed));
        } catch (error) {
          reply.send(_Failure('Piano analysis failed: $error'));
        }
      });
    } catch (error) {
      interpreter?.close();
      acceleration?.delete();
      reply.send(_Failure('Piano model initialization failed: $error'));
      Isolate.exit();
    }
  }

  static bool _validOutput(Tensor tensor) =>
      tensor.type == TensorType.float32 &&
      tensor.shape.length == 3 &&
      tensor.shape[0] == 1 &&
      tensor.shape[1] == PianoModel.outputFrames &&
      tensor.shape[2] == PianoModel.keyCount;
}
