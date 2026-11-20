/// The bundled Magenta Onsets and Frames unidirectional piano model.
abstract final class PianoModel {
  static const asset = 'assets/models/piano_onsets_frames.tflite';
  static const sampleRate = 16000;
  static const inputSamples = 17920;
  static const frameSamples = 512;
  static const spectralWindow = 2048;
  static const outputFrames = 32;
  static const keyCount = 88;
  static const firstMidi = 21;
  static const hopSamples = 512;
}

class PianoModelException implements Exception {
  const PianoModelException(this.message);
  final String message;
  @override
  String toString() => message;
}
