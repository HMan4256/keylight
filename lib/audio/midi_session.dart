import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_midi_command/flutter_midi_command.dart';
import 'package:flutter_midi_command/flutter_midi_command_messages.dart';
import 'package:flutter_midi_command_ble/flutter_midi_command_ble.dart';

/// Physical keys are independent per MIDI channel. Pedal resonance does not
/// keep a released key marked as physically down.
class MidiKeys {
  final _down = <(int, int)>{};
  Set<int> get notes => {for (final entry in _down) entry.$2};

  bool apply(MidiMessage message) {
    if (message is CCMessage &&
        (message.controller == 120 || message.controller >= 123)) {
      final count = _down.length;
      _down.removeWhere((entry) => entry.$1 == message.channel);
      return count != _down.length;
    }
    if (message is NoteOffMessage) {
      return _down.remove((message.channel, message.note));
    }
    if (message is! NoteOnMessage || message.note < 21 || message.note > 108) {
      return false;
    }
    final key = (message.channel, message.note);
    return message.velocity == 0 ? _down.remove(key) : _down.add(key);
  }

  void clear() => _down.clear();
}

/// One connection survives sheet/tab changes. Bluetooth starts only on demand.
class MidiSession extends ChangeNotifier {
  MidiSession({this.bluetooth});
  final MidiBleTransport? bluetooth;
  final keys = MidiKeys();
  MidiCommand? _api;
  StreamSubscription<MidiDataReceivedEvent>? _data;
  StreamSubscription<MidiSetupChange>? _setup;
  StreamSubscription<MidiPacket>? _raw;
  final _performance = StreamController<Uint8List>.broadcast(sync: true);
  Stream<Uint8List> get performance => _performance.stream;
  // Native note packets can replace the plugin's cached port lists with empty
  // lists. Discovery provides port capabilities, and a successful connection
  // owns the playback destination until it disconnects.
  Set<String> _discoveredOutputs = {};
  String? _playbackId;
  bool get canPlayBack => _playbackId != null;

  void sendPerformance(Uint8List message) {
    final destination = _playbackId;
    if (destination != null) _api!.sendData(message, deviceId: destination);
  }

  VoidCallback? beforeDisconnect;
  List<MidiDevice> devices = [];
  MidiDevice? selected;
  bool busy = false, scanning = false, _closed = false;
  String? error;
  int _generation = 0, _refresh = 0;
  Timer? _scanTimer;

  void _changed() {
    if (!_closed) notifyListeners();
  }

  Future<void> open() async {
    try {
      if (_api == null) {
        final api = _api = MidiCommand()
          ..configureBleTransport(bluetooth ?? UniversalBleMidiTransport());
        _raw = api.onMidiPacketReceived?.listen((packet) {
          final bytes = packet.data;
          if (packet.device.id == selected?.id &&
              bytes.isNotEmpty &&
              bytes.first >= 0x80 &&
              bytes.first < 0xf0) {
            _performance.add(bytes);
          }
        }, onError: _fail);
        _data = api.onMidiDataReceived?.listen(
          (event) {
            if (event.device.id == selected?.id && keys.apply(event.message)) {
              _changed();
            }
          },
          onError: (Object e) {
            disconnect();
            _fail(e);
          },
        );
        _setup = api.onMidiSetupChanged?.listen(
          (_) => refresh(),
          onError: _fail,
        );
      }
      await refresh();
    } catch (e) {
      _fail(e);
    }
  }

  void _fail(Object e) {
    error = e.toString();
    _changed();
  }

  Future<void> refresh() async {
    final request = ++_refresh;
    try {
      final found = await _api?.devices ?? <MidiDevice>[];
      if (_closed || request != _refresh) return;
      _discoveredOutputs = {
        for (final device in found)
          if (device.type == MidiDeviceType.ble ||
              device.inputPorts.isNotEmpty ||
              (device.id == _playbackId &&
                  device.connected &&
                  device.outputPorts.isEmpty))
            device.id,
      };
      devices = found
          .where(
            (d) =>
                d.type == MidiDeviceType.ble ||
                d.outputPorts.isNotEmpty ||
                d.id == selected?.id,
          )
          .toList();
      if (!busy &&
          selected != null &&
          !found.any((d) => d.id == selected!.id && d.connected)) {
        _playbackId = null;
        selected = null;
        keys.clear();
        error = 'MIDI keyboard disconnected.';
      }
      _changed();
    } catch (e) {
      _fail(e);
    }
  }

  Future<void> scan() async {
    if (busy || scanning || _api == null) return;
    final generation = _generation;
    busy = true;
    error = null;
    _changed();
    try {
      final api = _api!;
      await api.startBluetooth();
      await api.waitUntilBluetoothIsInitialized().timeout(
        const Duration(seconds: 10),
      );
      if (_closed || generation != _generation) return;
      if (api.bluetoothState != BluetoothState.poweredOn) {
        throw StateError(
          'Enable Bluetooth and allow nearby device access in system settings.',
        );
      }
      await api.startScanningForBluetoothDevices();
      scanning = true;
      if (_closed || generation != _generation) {
        stopScan();
        return;
      }
      _scanTimer = Timer(const Duration(seconds: 15), stopScan);
      await refresh();
    } catch (e) {
      _fail(e);
    } finally {
      busy = false;
      _changed();
    }
  }

  void stopScan() {
    _scanTimer?.cancel();
    if (!scanning) return;
    scanning = false;
    _api?.stopScanningForBluetoothDevices();
    _changed();
  }

  Future<void> connect(MidiDevice device) async {
    if (busy || _api == null) return;
    final supportsPlayback =
        _discoveredOutputs.contains(device.id) ||
        device.type == MidiDeviceType.ble ||
        device.inputPorts.isNotEmpty;
    disconnect();
    final generation = _generation;
    final api = _api!;
    busy = true;
    selected = device;
    error = null;
    _changed();
    try {
      await api.connectToDevice(device);
      if (_closed || generation != _generation) {
        api.disconnectDevice(device);
      } else if (supportsPlayback) {
        _playbackId = device.id;
      }
    } catch (e) {
      selected = null;
      keys.clear();
      _fail(e);
    } finally {
      busy = false;
      _changed();
    }
  }

  void disconnect() {
    _generation++;
    _refresh++;
    final device = selected;
    if (device != null) beforeDisconnect?.call();
    _playbackId = null;
    selected = null;
    keys.clear();
    if (device != null) _api?.disconnectDevice(device);
    _changed();
  }

  void suspend() {
    disconnect();
    stopScan();
  }

  @override
  void dispose() {
    _closed = true;
    suspend();
    _raw?.cancel();
    _performance.close();
    _data?.cancel();
    _setup?.cancel();
    _api?.dispose();
    super.dispose();
  }
}
