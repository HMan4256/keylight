import 'dart:typed_data';

/// Minimal fixture reader: RIFF PCM16 or IEEE float32, mono or stereo.
/// Converts the published piano demo to the PCM16 stream a recorder supplies.
(int sampleRate, int channels, Uint8List pcm16) readWav(Uint8List bytes) {
  final data = ByteData.sublistView(bytes);
  String tag(int offset) =>
      String.fromCharCodes(bytes.sublist(offset, offset + 4));
  if (bytes.length < 12 || tag(0) != 'RIFF' || tag(8) != 'WAVE') {
    throw const FormatException('Expected a RIFF WAV fixture.');
  }
  var format = 0, channels = 0, rate = 0, bits = 0;
  Uint8List? audio;
  for (var offset = 12; offset + 8 <= bytes.length;) {
    final size = data.getUint32(offset + 4, Endian.little);
    final start = offset + 8;
    if (start + size > bytes.length) {
      throw const FormatException('Truncated WAV chunk.');
    }
    if (tag(offset) == 'fmt ') {
      format = data.getUint16(start, Endian.little);
      channels = data.getUint16(start + 2, Endian.little);
      rate = data.getUint32(start + 4, Endian.little);
      bits = data.getUint16(start + 14, Endian.little);
    } else if (tag(offset) == 'data') {
      audio = Uint8List.sublistView(bytes, start, start + size);
    }
    offset = start + size + size % 2;
  }
  if (audio == null || (channels != 1 && channels != 2) || rate <= 0) {
    throw const FormatException('Unsupported WAV fixture.');
  }
  if (format == 1 && bits == 16) return (rate, channels, audio);
  if (format != 3 || bits != 32) {
    throw const FormatException('Expected PCM16 or float32 WAV.');
  }
  final floats = ByteData.sublistView(audio);
  final pcm = ByteData(audio.length ~/ 2);
  for (var i = 0; i < audio.length ~/ 4; i++) {
    pcm.setInt16(
      i * 2,
      (floats.getFloat32(i * 4, Endian.little) * 32768).round().clamp(
        -32768,
        32767,
      ),
      Endian.little,
    );
  }
  return (rate, channels, pcm.buffer.asUint8List());
}
