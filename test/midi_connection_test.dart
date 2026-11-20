import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_midi_command/flutter_midi_command.dart';
import 'package:flutter_midi_command_platform_interface/flutter_midi_command_platform_interface.dart';
import 'package:keylight/studio/studio_controller.dart';
import 'package:keylight/audio/midi_session.dart';

import 'support/fake_note_input.dart';
import 'support/fake_bluetooth_keyboard.dart';

class WiredKeyboard extends MidiCommandPlatform {
  final keyboard =
      MidiDevice('usb1', 'Test piano', MidiDeviceType.serial, false)
        ..outputPorts.add(MidiPort(0, MidiPortType.OUT))
        ..inputPorts.add(MidiPort(0, MidiPortType.IN));
  final sends = <(String?, List<int>)>[];
  @override
  void sendData(Uint8List data, {int? timestamp, String? deviceId}) =>
      sends.add((deviceId, data.toList()));
  final packets = StreamController<MidiPacket>.broadcast();
  final changes = StreamController<MidiSetupChange>.broadcast();
  bool plugged = true;
  @override
  Future<List<MidiDevice>> get devices async => plugged ? [keyboard] : [];
  @override
  Future<void> connectToDevice(
    MidiDevice device, {
    List<MidiPort>? ports,
  }) async {
    device.connected = true;
  }

  @override
  void disconnectDevice(MidiDevice device) {
    device.connected = false;
  }

  @override
  Stream<MidiPacket> get onMidiDataReceived => packets.stream;
  @override
  Stream<MidiSetupChange> get onMidiSetupChanged => changes.stream;
  @override
  void teardown() {
    packets.close();
    changes.close();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'Bluetooth discovery routes notes from only the selected device',
    () async {
      final host = WiredKeyboard();
      final ble = BluetoothKeyboard();
      MidiCommand.setPlatformOverride(host);
      final midi = MidiSession(bluetooth: ble);
      addTearDown(() {
        midi.dispose();
        MidiCommand.resetForTest();
      });
      await midi.open();
      expect(midi.devices, [host.keyboard]);
      await midi.scan();
      expect(midi.devices, contains(ble.device));
      await midi.connect(ble.device);
      ble.packets.add(
        MidiPacket(Uint8List.fromList([0x90, 72, 99]), 0, ble.device),
      );
      host.packets.add(
        MidiPacket(Uint8List.fromList([0x90, 65, 99]), 0, host.keyboard),
      );
      await Future<void>.delayed(Duration.zero);
      expect(midi.keys.notes, {72});
      midi.sendPerformance(Uint8List.fromList([0xb3, 64, 99]));
      expect(ble.sends.single.$1, ble.device.id);
      expect(ble.sends.single.$2, [0xb3, 64, 99]);
      expect(host.sends, isEmpty);
      midi.suspend();
      expect(midi.keys.notes, isEmpty);
      expect(midi.selected, isNull);
      expect(midi.scanning, isFalse);
    },
  );
  test(
    'discovered keyboard drives identification and unplug releases live keys',
    () async {
      final host = WiredKeyboard();
      MidiCommand.setPlatformOverride(host);
      final studio = StudioController(FakeNoteInput());
      addTearDown(() {
        studio.dispose();
        MidiCommand.resetForTest();
      });
      await studio.midi.open();
      expect(studio.midi.devices.single.name, 'Test piano');
      await studio.midi.connect(studio.midi.devices.single);
      host.packets.add(
        MidiPacket(
          Uint8List.fromList([0x90, 60, 90, 64, 90, 67, 90]),
          0,
          host.keyboard,
        ),
      );
      await Future<void>.delayed(Duration.zero);
      expect(studio.activeKeys, {60, 64, 67});
      studio.midi.sendPerformance(Uint8List.fromList([0x93, 67, 80]));
      expect(host.sends.single.$1, host.keyboard.id);
      expect(host.sends.single.$2, [0x93, 67, 80]);
      expect(studio.theory.chord!.name(studio.theory.key), 'C');
      host.plugged = false;
      host.changes.add(MidiSetupChange.deviceDisconnected);
      await Future<void>.delayed(Duration.zero);
      expect(studio.midi.selected, isNull);
      expect(studio.activeKeys, isEmpty);
      expect(studio.theory.inputNotes, {60, 64, 67});
    },
  );
}
