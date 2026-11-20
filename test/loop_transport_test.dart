import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_midi_command/flutter_midi_command.dart';
import 'package:flutter_midi_command_platform_interface/method_channel_midi_command.dart';
import 'package:flutter_midi_command_platform_interface/src/pigeon/midi_api.g.dart'
    as native;
import 'package:flutter_soloud/flutter_soloud.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keylight/audio/midi_session.dart';
import 'package:keylight/looper/loop_audio.dart';
import 'package:keylight/looper/loop_transport.dart';

import 'support/fake_bluetooth_keyboard.dart';

class _Keyboard extends MidiSession {
  _Keyboard() {
    selected = MidiDevice('piano', 'FP-30X', MidiDeviceType.ble, true);
  }
  @override
  bool get canPlayBack => selected?.connected == true;
  final input = StreamController<Uint8List>.broadcast(sync: true);
  final sent = <List<int>>[];
  @override
  Stream<Uint8List> get performance => input.stream;
  void key(List<int> bytes) => input.add(Uint8List.fromList(bytes));
  @override
  void sendPerformance(Uint8List message) => sent.add(message.toList());
  @override
  void dispose() {
    input.close();
    super.dispose();
  }
}

/// Android enumerates both ports but omits them from each note's source descriptor.
class _NativeKeyboard extends Fake implements native.MidiHostApi {
  late final platform = MethodChannelMidiCommand(
    hostApi: this,
    flutterApiSetUp: (_) {},
  );
  final sent = <List<int>>[];
  bool connected = false, plugged = true, hasInputPort = true;
  native.MidiHostDevice get source => native.MidiHostDevice(
    id: 'usb-synth',
    name: 'Synth',
    type: native.MidiDeviceType.serial,
    connected: connected,
  );

  @override
  Future<List<native.MidiHostDevice>> listDevices() async => [
    if (plugged)
      source
        ..inputs = [if (hasInputPort) native.MidiPort(id: 0, isInput: true)]
        ..outputs = [native.MidiPort(id: 0, isInput: false)],
  ];

  @override
  Future<void> connect(
    native.MidiHostDevice device,
    List<native.MidiPort>? ports,
  ) async {
    connected = true;
    platform.onDeviceConnectionStateChanged(device.id!, true);
  }

  void receive(List<int> message) => platform.onDataReceived(
    native.MidiPacket(device: source, data: Uint8List.fromList(message)),
  );

  @override
  Future<void> sendData(native.MidiPacket packet) async {
    expectSync(packet.device?.id, 'usb-synth');
    sent.add(packet.data!.toList());
  }

  @override
  Future<void> disconnect(String id) async => connected = false;
  @override
  Future<void> teardown() async {}
}

class _Source extends Fake implements AudioSource {}

class _Audio extends LoopAudio {
  final metronomeStarts = <(bool, bool)>[];
  final gainChanges = <bool>[];
  int stops = 0;
  final clips = <Uint8List>[];
  final offsets = <int>[];
  void Function(Uint8List)? receive;
  Completer<void>? preparing;
  @override
  Future<void> prepare({required int beatUs, required int beats}) async =>
      preparing?.future;
  @override
  void startMetronome({required bool countIn, required bool audible}) =>
      metronomeStarts.add((countIn, audible));
  @override
  void setMetronomeAudible(bool audible) => gainChanges.add(audible);
  @override
  void stopMetronome() => stops++;
  @override
  Future<void> capture(
    void Function(Uint8List) onData,
    void Function(Object) onError,
  ) async {
    rate = 1000;
    receive = onData;
  }

  @override
  Future<void> endCapture() async => receive = null;
  @override
  Future<AudioSource> load(Uint8List pcm, int rate, int channels) async {
    clips.add(pcm);
    return _Source();
  }

  @override
  SoundHandle play(AudioSource source, int offsetUs) {
    offsets.add(offsetUs);
    return const SoundHandle(1);
  }

  @override
  void stopVoice(SoundHandle? handle) {}
  @override
  Future<void> unload(AudioSource source) async {}
  @override
  Future<void> dispose() async {}
}

void main() {
  late _Keyboard keys;
  late _Audio audio;
  late LoopTransport loop;
  void setup(WidgetTester tester) {
    keys = _Keyboard();
    audio = _Audio();
    loop = LoopTransport(
      keys,
      audio: audio,
      clock: tester.binding.clock.stopwatch(),
    )..configure(tempo: 120, numerator: 3, measures: 1);
  }

  Future<void> finish(WidgetTester tester) async {
    await loop.stop();
    loop.dispose();
    keys.dispose();
    await tester.pump();
  }

  test('click samples stay on the beat grid across the bar seam', () {
    for (final (bpm, beats, unit) in [(40, 3, 4), (137, 7, 8), (240, 12, 8)]) {
      final beatUs = (60000000 * 4 / bpm / unit).round();
      final samples = ByteData.sublistView(metronomeBar(beatUs, beats));
      int frame(int beat) => (beat * beatUs * 44100 / 1000000).round();
      int sample(int offset) => samples.getInt16(offset * 2, Endian.little);
      expect(samples.lengthInBytes, frame(beats) * 2);
      for (var beat = 0; beat < beats; beat++) {
        final start = frame(beat);
        expect(sample((start + frame(beats) - 1) % frame(beats)), 0);
        expect(sample(start), 0);
        expect(
          sample(start + 1),
          beat == 0 ? greaterThan(3000) : inInclusiveRange(1800, 2000),
        );
        expect(sample(start + 1024), 0);
        expect(frame(beat + 1) - start, closeTo(beatUs * 44100 / 1000000, 1));
      }
    }
  });

  testWidgets(
    'count-in, live mute and overdubs share one scheduled metronome',
    (tester) async {
      setup(tester);
      loop.setClick(false);
      await loop.start(record: loop.tracks.first);
      expect(audio.metronomeStarts, [(true, false)]);
      await tester.pump(const Duration(milliseconds: 3001));
      loop.setClick(true);
      await loop.start(record: loop.tracks.first);
      await tester.pump(const Duration(seconds: 4));
      loop.setClick(false);
      expect(audio.metronomeStarts.length, 1);
      expect(audio.gainChanges, [true, false]);
      await loop.stop();
      expect(audio.stops, 1);
      await loop.start();
      expect(audio.metronomeStarts.last, (false, false));
      await finish(tester);
    },
  );

  testWidgets(
    'native note packets preserve the output during record, replay and play-along',
    (tester) async {
      final host = _NativeKeyboard();
      MidiCommand.setPlatformOverride(host.platform);
      final midi = MidiSession(bluetooth: BluetoothKeyboard());
      final transport =
          LoopTransport(
              midi,
              audio: _Audio(),
              clock: tester.binding.clock.stopwatch(),
            )
            ..configure(tempo: 120, numerator: 2, measures: 1)
            ..setCountIn(false);
      addTearDown(() {
        transport.dispose();
        midi.dispose();
        MidiCommand.resetForTest();
      });
      await midi.open();
      await midi.connect(midi.devices.single);
      await tester.pump();
      final track = transport.tracks.single;
      await transport.start(record: track);
      final attack = [0x92, 60, 93], release = [0x82, 60, 17];
      host.receive(attack);
      await tester.pump(const Duration(milliseconds: 150));
      host.receive(release);
      await tester.pump(const Duration(milliseconds: 852));
      expect(track.takes.single.events.length, 2);
      expect(host.sent, [attack]);
      await transport.stop();
      host.sent.clear();
      await transport.start();
      expect(transport.error, isNull);
      host.receive([0x92, 67, 85]);
      await tester.pump(const Duration(milliseconds: 165));
      expect(midi.keys.notes, {67});
      host.receive([0x82, 67, 10]);
      await tester.pump(const Duration(milliseconds: 840));
      expect(host.sent, [attack, release, attack]);
      expect(transport.running, isTrue);
      expect(track.takes.single.events.length, 2);

      host.plugged = false;
      host.platform.onDeviceConnectionStateChanged('usb-synth', false);
      await tester.pump();
      expect(midi.canPlayBack, isFalse);
      expect(transport.running, isFalse);
      expect(transport.error, contains('disconnected'));
      await transport.start();
      expect(transport.error, contains('Connect a MIDI'));
      host.plugged = true;
      await midi.refresh();
      await midi.connect(midi.devices.single);
      await tester.pump();
      expect(transport.error, isNull);
      await transport.start();
      expect(transport.running, isTrue);
      await transport.stop();

      midi.disconnect();
      host.hasInputPort = false;
      await midi.refresh();
      await midi.connect(midi.devices.single);
      expect(midi.canPlayBack, isFalse);
      await transport.start();
      expect(transport.error, contains('MIDI input port'));
    },
  );

  testWidgets(
    'count-in, MIDI dynamics and pedal values survive recording and channel routing',
    (tester) async {
      setup(tester);
      loop.setChannel(4);
      final track = loop.tracks.single;
      await loop.start(record: track);
      keys.key([0x91, 40, 30]);
      await tester.pump(const Duration(milliseconds: 1500));
      expect(audio.metronomeStarts, [(true, true)]);
      keys.key([0x91, 60, 91]);
      keys.key([0xb1, 64, 99]);
      await tester.pump(const Duration(milliseconds: 186));
      keys.key([0x81, 60, 39]);
      await tester.pump(const Duration(milliseconds: 1313));
      keys.key([0xb1, 64, 16]);
      expect(keys.sent, isEmpty);
      await tester.pump(const Duration(milliseconds: 2));
      expect(track.takes.single.events.map((e) => e.us), [
        0,
        0,
        186000,
        1499000,
      ]);
      expect(keys.sent, [
        [0x93, 60, 91],
        [0xb3, 64, 99],
      ]);
      await tester.pump(const Duration(milliseconds: 1499));
      expect(keys.sent, [
        [0x93, 60, 91],
        [0xb3, 64, 99],
        [0x83, 60, 39],
        [0xb3, 64, 16],
        [0x93, 60, 91],
        [0xb3, 64, 99],
      ]);
      await loop.stop();
      expect(keys.sent.sublist(keys.sent.length - 2), [
        [0x83, 60, 0],
        [0xb3, 64, 0],
      ]);
      await finish(tester);
    },
  );

  testWidgets(
    'overdub starts on the next loop and mute releases only owned notes',
    (tester) async {
      setup(tester);
      loop.setCountIn(false);
      final first = loop.tracks.first;
      await loop.start(record: first);
      keys.key([0x92, 60, 78]);
      await tester.pump(const Duration(milliseconds: 1500));
      loop.add(TrackKind.midi);
      final second = loop.tracks.last;
      await loop.start(record: second);
      keys.key([0x92, 45, 1]);
      await tester.pump(const Duration(milliseconds: 1500));
      keys.key([0x92, 60, 91]);
      keys.key([0x92, 67, 76]);
      await tester.pump(const Duration(milliseconds: 1500));
      expect(second.takes.single.events.length, 2);
      keys.sent.clear();
      loop.mute(first);
      expect(keys.sent, isEmpty);
      loop.mute(second);
      expect(keys.sent, [
        [0x82, 60, 0],
        [0x82, 67, 0],
      ]);
      await loop.stop();
      await loop.start(record: first);
      keys.key([0x92, 72, 88]);
      await loop.stop();
      expect(first.takes.length, 2);
      loop.undo(first);
      expect(first.takes.single.events.single.bytes, [0x92, 60, 78]);
      await finish(tester);
    },
  );

  testWidgets(
    'audio takes align to the sample clock, loop and overdub without replacing PCM',
    (tester) async {
      setup(tester);
      loop.configure(numerator: 6, unit: 8);
      expect(loop.beatUs, 250000);
      loop.setCountIn(false);
      loop.add(TrackKind.audio);
      final track = loop.tracks.last;
      await loop.start(record: track);
      await tester.pump(const Duration(milliseconds: 4));
      audio.receive!(Uint8List.fromList([1, 2, 3, 4, 5, 6, 7, 8]));
      await tester.pump(const Duration(milliseconds: 5));
      audio.receive!(Uint8List.fromList([9, 10]));
      await tester.pump(const Duration(milliseconds: 1491));
      expect(track.takes.length, 1);
      expect(audio.clips.single.length, 3000);
      expect(audio.clips.single.take(12), [
        1,
        2,
        3,
        4,
        5,
        6,
        7,
        8,
        9,
        10,
        0,
        0,
      ]);
      expect(audio.offsets, [0]);
      await loop.start(record: track);
      await tester.pump(const Duration(milliseconds: 1504));
      audio.receive!(Uint8List.fromList([22, 23]));
      await loop.stop();
      expect(track.takes.length, 2);
      expect(audio.clips.last.take(8), [0, 0, 0, 0, 0, 0, 22, 23]);
      loop.undo(track);
      expect(track.takes.length, 1);
      final wav = pcmWave(audio.clips.first, 1000, 1);
      expect(String.fromCharCodes(wav.take(4)), 'RIFF');
      expect(ByteData.sublistView(wav).getUint32(40, Endian.little), 3000);
      await finish(tester);
    },
  );

  testWidgets(
    'stop cancels pending preparation and a missing MIDI out is actionable',
    (tester) async {
      setup(tester);
      audio.preparing = Completer<void>();
      final start = loop.start();
      final stop = loop.stop();
      audio.preparing!.complete();
      await Future.wait([start, stop]);
      expect(loop.running, isFalse);
      keys.selected = null;
      await loop.start(record: loop.tracks.first);
      expect(loop.error, contains('MIDI'));
      expect(loop.running, isFalse);
      await finish(tester);
    },
  );
}
