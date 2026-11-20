import 'package:flutter_midi_command/flutter_midi_command.dart';
import 'package:material_ui/material_ui.dart';

import '../studio/studio_controller.dart';

class MidiSheet extends StatefulWidget {
  const MidiSheet({super.key, required this.studio});
  final StudioController studio;
  @override
  State<MidiSheet> createState() => _MidiSheetState();
}

class _MidiSheetState extends State<MidiSheet> {
  @override
  void initState() {
    super.initState();
    widget.studio.midi.open();
  }

  @override
  Widget build(BuildContext context) {
    final midi = widget.studio.midi;
    return SafeArea(
      child: ListenableBuilder(
        listenable: midi,
        builder: (_, _) => SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('MIDI keyboard', style: TextStyle(fontSize: 24)),
              Wrap(
                spacing: 12,
                children: [
                  TextButton(
                    onPressed: midi.busy ? null : midi.refresh,
                    child: const Text('Refresh USB'),
                  ),
                  TextButton(
                    onPressed: midi.busy
                        ? null
                        : midi.scanning
                        ? midi.stopScan
                        : midi.scan,
                    child: Text(midi.scanning ? 'Stop scan' : 'Scan Bluetooth'),
                  ),
                ],
              ),
              if (midi.busy) const LinearProgressIndicator(),
              if (midi.error != null) Text(midi.error!),
              if (midi.devices.isEmpty)
                const Text(
                  'Connect a USB MIDI keyboard or scan for Bluetooth MIDI.',
                ),
              for (final device in midi.devices)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(device.name),
                  subtitle: Text(
                    device.type == MidiDeviceType.ble
                        ? 'Bluetooth MIDI'
                        : 'Wired MIDI',
                  ),
                  trailing: Text(
                    midi.selected?.id == device.id ? 'Disconnect' : 'Connect',
                  ),
                  onTap: midi.busy
                      ? null
                      : () async {
                          if (midi.selected?.id == device.id) {
                            midi.disconnect();
                            return;
                          }
                          if (widget.studio.listening || widget.studio.busy) {
                            await widget.studio.stop();
                          }
                          if (mounted) await midi.connect(device);
                        },
                ),
            ],
          ),
        ),
      ),
    );
  }
}
