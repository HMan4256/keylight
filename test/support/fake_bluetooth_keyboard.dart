import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_midi_command/flutter_midi_command.dart';
import 'package:flutter_test/flutter_test.dart';

class BluetoothKeyboard extends Fake implements MidiBleTransport {
  final device = MidiDevice(
    'ble-keyboard',
    'BLE piano',
    MidiDeviceType.ble,
    false,
  );
  final sends = <(String?, List<int>)>[];
  @override
  void sendData(Uint8List data, {int? timestamp, String? deviceId}) =>
      sends.add((deviceId, data.toList()));
  final packets = StreamController<MidiPacket>.broadcast();
  final topology = StreamController<MidiSetupChange>.broadcast();
  final radio = StreamController<String>.broadcast();
  bool visible = false;
  @override
  Stream<String> get onBluetoothStateChanged => radio.stream;
  @override
  Future<String> bluetoothState() async => 'poweredOn';
  @override
  Future<void> startBluetooth() async {
    radio.add('poweredOn');
  }

  @override
  Future<void> startScanningForBluetoothDevices() async {
    visible = true;
    topology.add(MidiSetupChange.deviceAppeared);
  }

  @override
  void stopScanningForBluetoothDevices() {}
  @override
  Future<List<MidiDevice>> get devices async => visible ? [device] : [];
  @override
  Stream<MidiSetupChange> get onMidiSetupChanged => topology.stream;
  @override
  Stream<MidiPacket> get onMidiDataReceived => packets.stream;
  @override
  Future<void> connectToDevice(
    MidiDevice device, {
    List<MidiPort>? ports,
    Duration? timeout,
  }) async {
    device.connected = true;
  }

  @override
  void disconnectDevice(MidiDevice device) {
    device.connected = false;
  }

  @override
  void teardown() {
    radio.close();
    packets.close();
    topology.close();
  }
}
