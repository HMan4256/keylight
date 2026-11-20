import 'dart:async';

import 'package:flutter/foundation.dart';

import '../audio/microphone_note_input.dart';
import '../audio/note_input.dart';
import '../audio/midi_session.dart';
import '../audio/piano_model.dart';
import '../music/piano_note.dart';
import 'theory_controller.dart';

enum ListeningState { idle, starting, listening, stopping, error }

class StudioController extends ChangeNotifier {
  StudioController(this.input) {
    _subscription = input.frames.listen(_onFrame, onError: _onError);
    midi.addListener(_notify);
    theory.addListener(_relayTheory);
  }

  final NoteInput input;
  final midi = MidiSession();
  final theory = TheoryController();
  StreamSubscription<NoteFrame>? _subscription;
  Future<void> _operation = Future.value();
  Timer? _release;
  bool _disposed = false;
  bool _wanted = false;
  final Map<int, int> _touches = {};
  final Set<int> _latched = {};
  bool latchTouches = false;
  List<DetectedNote> _detected = [];
  ListeningState state = ListeningState.idle;
  String? error;
  double rms = 0;
  List<double> waveform = const [];
  bool followNote = true;
  bool showLabels = true;

  bool get listening => state == ListeningState.listening;
  bool get busy =>
      state == ListeningState.starting || state == ListeningState.stopping;
  Set<int> get activeKeys => {
    ..._detected.map((n) => n.note.midi),
    ..._touches.values,
    ..._latched,
    ...midi.keys.notes,
  };
  PianoNote? get currentNote => _touches.isNotEmpty
      ? PianoNote(_touches.values.last)
      : _latched.isNotEmpty
      ? PianoNote(_latched.last)
      : _detected.firstOrNull?.note;
  DetectedNote? get liveNote =>
      !touching && _detected.length == 1 ? _detected.single : null;
  bool get touching => _touches.isNotEmpty || _latched.isNotEmpty;
  int? get followMidi {
    if (touching) return null;
    final notes = activeKeys.toList()..sort();
    if (notes.isEmpty) return null;
    return notes[notes.length ~/ 2];
  }

  Future<void> _enqueue(Future<void> Function() action) {
    _operation = _operation.then((_) => action());
    return _operation;
  }

  Future<void> start() {
    if (_disposed || _wanted) return _operation;
    if (midi.selected != null) midi.disconnect();
    _wanted = true;
    error = null;
    state = ListeningState.starting;
    _notify();
    return _enqueue(() async {
      if (!_wanted || _disposed) return;
      try {
        await input.start();
        if (_disposed || !_wanted) return;
        state = ListeningState.listening;
        _notify();
      } on MicrophonePermissionException {
        _onError(
          'Microphone access is off. Enable it in your device’s app settings, then try again.',
        );
      } on PianoModelException {
        _onError(
          'Piano detection could not start. Restart the app and try again.',
        );
      } catch (_) {
        _onError(
          'Couldn’t start the microphone. Check that it is available and try again.',
        );
      }
    });
  }

  Future<void> stop() {
    _wanted = false;
    _release?.cancel();
    _detected = [];
    rms = 0;
    waveform = const [];
    state = ListeningState.stopping;
    _notify();
    return _enqueue(() async {
      try {
        await input.stop();
        state = ListeningState.idle;
      } catch (_) {
        state = ListeningState.error;
        error = 'Couldn’t release the microphone. Try again.';
      }
      _notify();
    });
  }

  void _onFrame(NoteFrame frame) {
    if (_disposed || !listening || !_wanted) return;
    final previous = activeKeys;
    rms = frame.rms;
    waveform = frame.waveform;
    _detected = frame.notes;
    _release?.cancel();
    final timeout = frame.releaseAfter;
    if (timeout != null && frame.notes.isNotEmpty) {
      _release = Timer(timeout, () {
        _detected = [];
        _notify();
      });
    }
    // Confidence and waveform updates do not change this interface.
    if (!setEquals(previous, activeKeys)) _notify();
  }

  void _onError(Object problem) {
    if (_disposed) return;
    _wanted = false;
    _release?.cancel();
    _detected = [];
    rms = 0;
    waveform = const [];
    state = ListeningState.error;
    error = problem is String
        ? problem
        : 'Microphone interrupted. Tap Listen to reconnect.';
    unawaited(
      _enqueue(() async {
        try {
          await input.stop();
        } catch (_) {}
      }),
    );
    _notify();
  }

  void touchDown(int pointer, int midi) {
    if (latchTouches) {
      if (!_latched.remove(midi)) _latched.add(midi);
    } else {
      _touches[pointer] = midi;
    }
    _notify();
  }

  void touchUp(int pointer) {
    _touches.remove(pointer);
    _notify();
  }

  void cancelTouchPointers() {
    _touches.clear();
    _notify();
  }

  void releaseTouches() {
    _touches.clear();
    _latched.clear();
    _notify();
  }

  void setLatchTouches(bool value) {
    latchTouches = value;
    releaseTouches();
  }

  void setFollow(bool value) {
    followNote = value;
    _notify();
  }

  void setLabels(bool value) {
    showLabels = value;
    _notify();
  }

  void setNoiseFloor(double db) {
    if (input case final MicrophoneNoteInput microphone) {
      microphone.noiseFloorDb = db;
    }
    _notify();
  }

  void setOnsetThreshold(double value) {
    if (input case final MicrophoneNoteInput microphone) {
      microphone.onsetThreshold = value.clamp(0.2, 0.85);
    }
    _notify();
  }

  void _notify() {
    if (!_disposed) {
      theory.observe(activeKeys);
      notifyListeners();
    }
  }

  void _relayTheory() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _wanted = false;
    _release?.cancel();
    theory.removeListener(_relayTheory);
    midi.removeListener(_notify);
    midi.dispose();
    theory.dispose();
    unawaited(_subscription?.cancel());
    unawaited(_enqueue(input.dispose));
    super.dispose();
  }
}
