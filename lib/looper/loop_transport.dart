import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter_soloud/flutter_soloud.dart';

import '../audio/midi_session.dart';
import 'loop_audio.dart';

enum TrackKind { midi, audio }

class LoopEvent {
  const LoopEvent(this.us, this.bytes);
  final int us;
  final Uint8List bytes;
}

class LoopTake {
  final events = <LoopEvent>[];
  AudioSource? sound;
  SoundHandle? voice;
  int cursor = 0;
  // Only release keys and pedals this take sent.
  final keys = <(int, int)>{};
  final pedals = <(int, int)>{};
}

class LoopTrack {
  LoopTrack(this.kind, this.number);
  final TrackKind kind;
  final int number;
  final takes = <LoopTake>[];
  bool muted = false;
  String get name => '${kind == TrackKind.midi ? 'MIDI' : 'Audio'} $number';
}

class LoopTransport extends ChangeNotifier {
  LoopTransport(this.midi, {LoopAudio? audio, Stopwatch? clock})
    : audio = audio ?? LoopAudio(),
      _clock = clock ?? Stopwatch() {
    _input = midi.performance.listen(_recordMessage);
    midi.addListener(_checkConnection);
    midi.beforeDisconnect = _beforeDisconnect;
  }
  final MidiSession midi;
  final LoopAudio audio;
  late final StreamSubscription<Uint8List> _input;
  final tracks = [LoopTrack(TrackKind.midi, 1)];
  LoopTrack? target;
  final Stopwatch _clock;
  Timer? _timer;
  int bpm = 100, beats = 4, denominator = 4, bars = 2;
  bool metronome = true, countIn = true;
  // 0 preserves channels, 4 selects the FP-30X panel tone.
  int outputChannel = 0;
  bool running = false, busy = false, _disposed = false;
  String? error;
  int beat = 0, bar = 1;
  int _origin = 0, _cycle = -1, _lastBeat = -100, _start = 0, _generation = 0;
  LoopTake? _pending;
  Uint8List? _pcm;
  int? _audioPosition;
  bool _captured = false;
  String? _deviceId;
  bool _waitingForMidi = false;
  Future<void>? _finishing, _starting;
  bool _acceptAudio = false;
  int get beatUs => (60000000 * 4 / bpm / denominator).round();
  int get lengthUs => beatUs * beats * bars;
  int get position => _clock.elapsedMicroseconds - _origin;
  bool get locked => running || busy || tracks.any((t) => t.takes.isNotEmpty);
  bool get recording => target != null && position >= _start && running;

  void _update() {
    if (!_disposed) notifyListeners();
  }

  void configure({int? tempo, int? numerator, int? unit, int? measures}) {
    if (locked) return;
    bpm = (tempo ?? bpm).clamp(40, 240);
    beats = numerator ?? beats;
    denominator = unit ?? denominator;
    bars = measures ?? bars;
    _update();
  }

  void add(TrackKind kind) {
    tracks.add(
      LoopTrack(kind, tracks.fold(0, (n, t) => math.max(n, t.number)) + 1),
    );
    _update();
  }

  void remove(LoopTrack track) {
    if (running || busy || track.takes.isNotEmpty) return;
    tracks.remove(track);
    _update();
  }

  void setClick(bool value) {
    metronome = value;
    if (running) audio.setMetronomeAudible(value);
    _update();
  }

  void setCountIn(bool value) {
    countIn = value;
    _update();
  }

  void setChannel(int channel) {
    if (!running) {
      outputChannel = channel;
      _update();
    }
  }

  void _beforeDisconnect() {
    if (running && _deviceId != null) unawaited(stop());
  }

  void _checkConnection() {
    if (_waitingForMidi && midi.canPlayBack) {
      _waitingForMidi = false;
      error = null;
      _update();
    }
    if (running && _deviceId != null && midi.selected?.id != _deviceId) {
      _waitingForMidi = true;
      error = 'MIDI keyboard disconnected.';
      unawaited(stop());
    }
  }

  Future<void> start({LoopTrack? record}) {
    if (busy || target != null || (running && record == null) || _disposed) {
      return Future.value();
    }
    return _starting = _prepareTransport(record);
  }

  Future<void> _prepareTransport(LoopTrack? record) async {
    _waitingForMidi = false;
    error = null;
    final needsMidi =
        record?.kind == TrackKind.midi ||
        tracks.any(
          (t) => t.kind == TrackKind.midi && !t.muted && t.takes.isNotEmpty,
        );
    if (needsMidi && !midi.canPlayBack) {
      _waitingForMidi = true;
      error = midi.selected == null
          ? 'Connect a MIDI keyboard using MIDI above.'
          : '${midi.selected!.name} needs a MIDI input port to receive playback.';
      _update();
      return;
    }
    busy = true;
    final token = ++_generation;
    _update();
    try {
      await audio.prepare(beatUs: beatUs, beats: beats);
      if (token != _generation || _disposed) return;
      if (record?.kind == TrackKind.audio) {
        await audio.capture(_recordAudio, (e) {
          error = e.toString();
          unawaited(stop());
        });
      }
      if (token != _generation || _disposed) {
        await audio.endCapture();
        return;
      }
      if (needsMidi && !midi.canPlayBack) {
        throw StateError('MIDI keyboard disconnected.');
      }
      if (needsMidi) _deviceId = midi.selected!.id;
      if (!running) {
        final withCountIn = record != null && countIn;
        audio.startMetronome(countIn: withCountIn, audible: metronome);
        _origin = withCountIn ? beats * beatUs : 0;
        _clock.reset();
        _clock.start();
      }
      if (record != null) {
        target = record;
        _pending = LoopTake();
        _start = running
            ? (math.max(0, position ~/ lengthUs) + 1) * lengthUs
            : 0;
        _audioPosition = null;
        _pcm = null;
        _captured = false;
        _acceptAudio = record.kind == TrackKind.audio;
      }
      if (!running) {
        _cycle = -1;
        _lastBeat = -100;
        running = true;
        _tick();
        if (running) {
          _timer = Timer.periodic(
            const Duration(milliseconds: 3),
            (_) => _tick(),
          );
        }
      }
    } catch (e) {
      error = e.toString();
      if (!running) audio.stopMetronome();
      await audio.endCapture();
    } finally {
      busy = false;
      _update();
    }
  }

  void _recordMessage(Uint8List bytes) {
    if (!running || target?.kind != TrackKind.midi) return;
    final offset = position - _start;
    if (offset >= 0 && offset < lengthUs) {
      _pending!.events.add(LoopEvent(offset, Uint8List.fromList(bytes)));
    }
  }

  void _recordAudio(Uint8List bytes) {
    if (!_acceptAudio) return;
    final stride = audio.channels * 2;
    final capacity = (lengthUs * audio.rate / 1000000).round() * stride;
    final buffer = _pcm ??= Uint8List(capacity);
    // Anchor the first delivery to the transport, then use the sample clock
    // so callback jitter never opens gaps between adjacent chunks.
    final offset =
        _audioPosition ??
        ((position - _start) * audio.rate / 1000000).round() * stride -
            bytes.length;
    _audioPosition = offset + bytes.length;
    final from = math.max(0, offset),
        to = math.min(buffer.length, offset + bytes.length);
    if (to > from) {
      buffer.setRange(from, to, bytes, from - offset);
      _captured = true;
    }
  }

  void _tick() {
    if (!running) return;
    try {
      final now = position;
      final beatIndex = (now / beatUs).floor();
      final changed = beatIndex != _lastBeat;
      if (changed) {
        _lastBeat = beatIndex;
        beat = beatIndex % beats + 1;
        bar = now < 0 ? 0 : (beatIndex ~/ beats) % bars + 1;
      }
      if (now >= 0) {
        final cycle = now ~/ lengthUs, phase = now % lengthUs;
        if (_cycle >= 0 && cycle == _cycle + 1) _dispatch(lengthUs);

        if (target != null && now >= _start + lengthUs) {
          _finishing = _finishTake();
        }
        if (cycle != _cycle) {
          for (final track in tracks) {
            for (final take in track.takes) {
              _release(take);
              take.cursor = 0;
              if (!track.muted && take.sound != null) _playAudio(take, phase);
            }
          }
          _cycle = cycle;
        }
        _dispatch(phase);
      }
      if (changed) _update();
    } catch (e) {
      error = e.toString();
      unawaited(stop());
    }
  }

  void _dispatch(int throughUs) {
    // Merge track timelines before dispatch so dense interleaved chords,
    // controllers and same-tick note-offs preserve their recorded order.
    final due = <(LoopTake, LoopEvent, int)>[];
    for (final track in tracks) {
      for (final take in track.takes) {
        while (take.cursor < take.events.length &&
            take.events[take.cursor].us <= throughUs) {
          final event = take.events[take.cursor++];
          if (!track.muted) due.add((take, event, due.length));
        }
      }
    }
    due.sort((a, b) {
      final order = a.$2.us.compareTo(b.$2.us);
      return order == 0 ? a.$3.compareTo(b.$3) : order;
    });
    for (final entry in due) {
      _send(entry.$1, entry.$2.bytes);
    }
  }

  void _playAudio(LoopTake take, int phase) {
    audio.stopVoice(take.voice);
    take.voice = audio.play(take.sound!, phase);
  }

  Iterable<LoopTake> get _takes => tracks.expand((t) => t.takes);
  void _send(LoopTake take, Uint8List source) {
    final data = Uint8List.fromList(source);
    final channel = outputChannel == 0 ? data[0] & 15 : outputChannel - 1;
    final type = data[0] & 0xf0;
    data[0] = type | channel;
    if (data.length >= 3) {
      final id = (channel, data[1]);
      if (type == 0x90 && data[2] > 0) {
        take.keys.add(id);
      } else if (type == 0x80 || (type == 0x90 && data[2] == 0)) {
        take.keys.remove(id);
        if (_takes.any((other) => other.keys.contains(id))) return;
      } else if (type == 0xb0 && const {64, 66, 67}.contains(data[1])) {
        if (data[2] >= 64) {
          take.pedals.add(id);
        } else {
          take.pedals.remove(id);
          if (_takes.any((other) => other.pedals.contains(id))) return;
        }
      }
    }
    midi.sendPerformance(data);
  }

  void _release(LoopTake take) {
    for (final id in take.keys.toList()) {
      take.keys.remove(id);
      if (!_takes.any((other) => other.keys.contains(id))) {
        midi.sendPerformance(Uint8List.fromList([0x80 | id.$1, id.$2, 0]));
      }
    }
    for (final id in take.pedals.toList()) {
      take.pedals.remove(id);
      if (!_takes.any((other) => other.pedals.contains(id))) {
        midi.sendPerformance(Uint8List.fromList([0xb0 | id.$1, id.$2, 0]));
      }
    }
  }

  Future<void> _finishTake() async {
    final track = target, take = _pending;
    if (track == null || take == null) return;
    target = null;
    _pending = null;
    if (track.kind == TrackKind.midi) {
      if (take.events.isNotEmpty) track.takes.add(take);
    } else {
      busy = true;
      final rate = audio.rate, channels = audio.channels;
      try {
        await audio.endCapture();
        final pcm = _pcm;
        if (!_disposed && _captured && pcm != null) {
          take.sound = await audio.load(pcm, rate, channels);
          if (_disposed) {
            await audio.unload(take.sound!);
            return;
          }
          track.takes.add(take);
          if (running && !track.muted) _playAudio(take, position % lengthUs);
        }
      } catch (e) {
        error = e.toString();
      } finally {
        _acceptAudio = false;
        _pcm = null;
        busy = false;
      }
    }
    _update();
  }

  Future<void> stop() async {
    ++_generation;
    _timer?.cancel();
    _timer = null;
    running = false;
    _clock.stop();
    audio.stopMetronome();
    _deviceId = null;
    for (final take in _takes) {
      _release(take);
      audio.stopVoice(take.voice);
      take.voice = null;
    }
    if (target != null) _finishing = _finishTake();
    await _starting;
    await _finishing;
    _update();
  }

  void mute(LoopTrack track) {
    track.muted = !track.muted;
    for (final take in track.takes) {
      if (track.muted) _release(take);
      if (running && take.sound != null && position >= 0) {
        if (track.muted) {
          audio.stopVoice(take.voice);
          take.voice = null;
        } else {
          _playAudio(take, position % lengthUs);
        }
      }
    }
    _update();
  }

  void undo(LoopTrack track) {
    if (running || busy || track.takes.isEmpty) return;
    final sound = track.takes.removeLast().sound;
    if (sound != null) unawaited(audio.unload(sound));
    _update();
  }

  @override
  void dispose() {
    _disposed = true;
    midi.beforeDisconnect = null;
    midi.removeListener(_checkConnection);
    _input.cancel();
    unawaited(stop().then((_) => audio.dispose()));
    super.dispose();
  }
}
