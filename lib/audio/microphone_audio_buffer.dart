import 'dart:math' as math;
import 'dart:typed_data';

import 'piano_model.dart';

class PianoAudioWindow {
  const PianoAudioWindow(this.samples, this.endSample, this.rms, this.waveform);
  final Float32List samples;
  final int endSample;
  final double rms;
  final List<double> waveform;
}

/// Stateful, band-limited sample-rate conversion. A windowed-sinc low-pass
/// filter rejects frequencies above the new Nyquist limit before downsampling.
class StreamingResampler {
  StreamingResampler(this.sourceRate, this.targetRate) {
    if (sourceRate <= 0 || targetRate <= 0) {
      throw ArgumentError('Sample rates must be positive.');
    }
    if (sourceRate == targetRate) return;
    const taps = 63;
    final cutoff = 0.45 * math.min(sourceRate, targetRate) / sourceRate;
    _coefficients = Float64List(taps);
    _history = Float64List(taps);
    var sum = 0.0;
    for (var i = 0; i < taps; i++) {
      final x = i - (taps - 1) / 2;
      final sinc = x == 0
          ? 2 * cutoff
          : math.sin(2 * math.pi * cutoff * x) / (math.pi * x);
      final window =
          .42 -
          .5 * math.cos(2 * math.pi * i / (taps - 1)) +
          .08 * math.cos(4 * math.pi * i / (taps - 1));
      _coefficients[i] = sinc * window;
      sum += _coefficients[i];
    }
    for (var i = 0; i < taps; i++) {
      _coefficients[i] /= sum;
    }
  }

  final int sourceRate;
  final int targetRate;
  Float64List _coefficients = Float64List(0);
  Float64List _history = Float64List(0);
  int _write = 0;
  int _inputIndex = 0;
  double _nextOutput = 0;
  double _previous = 0;

  void add(double sample, void Function(double) onSample) {
    if (sourceRate == targetRate) {
      onSample(sample);
      return;
    }
    _history[_write] = sample;
    var filtered = 0.0;
    for (var tap = 0; tap < _history.length; tap++) {
      filtered +=
          _coefficients[tap] *
          _history[(_write - tap + _history.length) % _history.length];
    }
    _write = (_write + 1) % _history.length;
    while (_nextOutput <= _inputIndex) {
      final fraction = (_nextOutput - (_inputIndex - 1)).clamp(0.0, 1.0);
      onSample(_previous + (filtered - _previous) * fraction);
      _nextOutput += sourceRate / targetRate;
    }
    _previous = filtered;
    _inputIndex++;
  }
}

/// PCM16 framing, stereo downmix, resampling, and rolling model context.
/// Leading zeros allow inference after the first hop instead of waiting for
/// an entire 1.12-second context to fill. Chunk boundaries never reset DSP state.
class MicrophoneAudioBuffer {
  MicrophoneAudioBuffer({required int sampleRate, this.channels = 1})
    : _resampler = StreamingResampler(sampleRate, PianoModel.sampleRate) {
    if (channels < 1 || channels > 2) {
      throw ArgumentError('Expected mono or stereo PCM.');
    }
  }

  final int channels;
  final StreamingResampler _resampler;
  final _ring = Float32List(PianoModel.inputSamples);
  int? _lowByte;
  int _channel = 0;
  double _channelSum = 0;
  int _write = 0;
  int _samples = 0;

  void add(Uint8List bytes, void Function(PianoAudioWindow) onWindow) {
    for (final byte in bytes) {
      if (_lowByte == null) {
        _lowByte = byte;
        continue;
      }
      var value = _lowByte! | (byte << 8);
      _lowByte = null;
      if (value >= 32768) value -= 65536;
      _channelSum += value / 32768;
      _channel++;
      if (_channel != channels) continue;
      final mono = _channelSum / channels;
      _channel = 0;
      _channelSum = 0;
      _resampler.add(mono, (sample) {
        _ring[_write] = sample;
        _write = (_write + 1) % _ring.length;
        _samples++;
        if (_samples % PianoModel.hopSamples != 0) return;
        final window = Float32List(_ring.length);
        final tailLength = _ring.length - _write;
        window.setRange(0, tailLength, _ring, _write);
        window.setRange(tailLength, window.length, _ring);
        var mean = 0.0;
        final start = window.length - PianoModel.hopSamples;
        for (var i = start; i < window.length; i++) {
          mean += window[i];
        }
        mean /= PianoModel.hopSamples;
        var energy = 0.0;
        for (var i = start; i < window.length; i++) {
          energy += math.pow(window[i] - mean, 2);
        }
        final waveform = List.generate(
          64,
          (i) => window[start + i * (PianoModel.hopSamples - 1) ~/ 63],
        );
        onWindow(
          PianoAudioWindow(
            window,
            _samples,
            math.sqrt(energy / PianoModel.hopSamples),
            waveform,
          ),
        );
      });
    }
  }
}
