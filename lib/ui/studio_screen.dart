import 'dart:async';
import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../audio/microphone_note_input.dart';
import '../looper/loop_transport.dart';
import 'looper_view.dart';
import '../studio/studio_controller.dart';
import 'piano_keyboard.dart';
import 'midi_sheet.dart';
import 'pixel_icon.dart';
import 'studio_theme.dart';
import 'theory_workspace.dart';

class StudioScreen extends StatefulWidget {
  const StudioScreen({super.key, this.controller});
  final StudioController? controller;
  @override
  State<StudioScreen> createState() => _StudioScreenState();
}

class _StudioScreenState extends State<StudioScreen>
    with WidgetsBindingObserver {
  late final controller =
      widget.controller ?? StudioController(MicrophoneNoteInput());
  late final loop = LoopTransport(controller.midi);
  int _tab = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached) {
      unawaited(loop.stop());
      controller.midi.suspend();
      controller.releaseTouches();
      if (controller.listening || controller.busy) unawaited(controller.stop());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    loop.dispose();
    if (widget.controller == null) controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) => Scaffold(
      bottomNavigationBar: NavigationBar(
        height: 60,
        selectedIndex: _tab,
        backgroundColor: StudioColors.background,
        indicatorShape: const RoundedRectangleBorder(),
        indicatorColor: StudioColors.mint.withValues(alpha: .12),
        onDestinationSelected: (index) => setState(() => _tab = index),
        destinations: const [
          NavigationDestination(
            icon: PixelIcon(PixelGlyph.keys),
            selectedIcon: PixelIcon(PixelGlyph.keys, color: StudioColors.mint),
            label: 'Identify',
          ),
          NavigationDestination(
            icon: PixelIcon(PixelGlyph.wheel),
            selectedIcon: PixelIcon(PixelGlyph.wheel, color: StudioColors.mint),
            label: 'Circle',
          ),
          NavigationDestination(
            icon: PixelIcon(PixelGlyph.loop),
            selectedIcon: PixelIcon(PixelGlyph.loop, color: StudioColors.mint),
            label: 'Looper',
          ),
        ],
      ),
      body: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: 1000,
              maxHeight:
                  MediaQuery.sizeOf(context).width >= 800 &&
                      MediaQuery.sizeOf(context).height >= 700
                  ? (_tab == 0 ? 700 : 820)
                  : double.infinity,
            ),
            child: Column(
              children: [
                if (MediaQuery.sizeOf(context).width >= 700 &&
                    MediaQuery.sizeOf(context).height < 500)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 4, 12, 4),
                    child: Row(
                      children: [
                        Expanded(child: _header()),
                        const SizedBox(width: 24),
                        if (_tab != 2)
                          Expanded(
                            child: ReferenceKeyBar(theory: controller.theory),
                          ),
                      ],
                    ),
                  )
                else ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 8, 4),
                    child: _header(),
                  ),
                  if (_tab != 2)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 4,
                      ),
                      child: ReferenceKeyBar(theory: controller.theory),
                    ),
                ],
                if (controller.error != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 4),
                    child: Text(
                      controller.error!,
                      style: const TextStyle(
                        color: StudioColors.amber,
                        fontSize: 12,
                      ),
                    ),
                  ),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, box) {
                      if (_tab == 2) {
                        return LooperView(loop: loop, studio: controller);
                      }
                      final landscape =
                          box.maxWidth >= 700 && box.maxHeight < 500;
                      final short = MediaQuery.sizeOf(context).height < 660;
                      final keyHeight = landscape
                          ? 156.0
                          : _tab == 1 && short
                          ? 60.0
                          : box.maxHeight < 460
                          ? 100.0
                          : 156.0;
                      final keyboard = PianoKeyboard(
                        controller: controller,
                        keyHeight: keyHeight,
                      );
                      Widget workspace(double height) {
                        final content = _tab == 0
                            ? NoteIdentifier(controller: controller)
                            : CircleTheoryView(
                                theory: controller.theory,
                                diameter: math.min(
                                  350,
                                  math.max(145, height - 62),
                                ),
                              );
                        return SingleChildScrollView(
                          key: PageStorageKey('tool-$_tab'),
                          padding: EdgeInsets.fromLTRB(
                            20,
                            _tab == 1 ? 0 : 20,
                            20,
                            _tab == 1 ? 0 : 16,
                          ),
                          child: content,
                        );
                      }

                      if (landscape) {
                        return Row(
                          children: [
                            Expanded(child: workspace(box.maxHeight)),
                            Expanded(child: keyboard),
                          ],
                        );
                      }
                      return Column(
                        children: [
                          Expanded(
                            child: LayoutBuilder(
                              builder: (context, space) =>
                                  workspace(space.maxHeight),
                            ),
                          ),
                          keyboard,
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );

  Widget _header() => Row(
    children: [
      const Expanded(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            'KEYLIGHT',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              letterSpacing: -.5,
            ),
          ),
        ),
      ),
      if (_tab != 2)
        TextButton.icon(
          key: const ValueKey('microphone-toggle'),
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            textStyle: const TextStyle(fontFamily: 'Pixelify', fontSize: 14),
          ),
          onPressed: controller.busy || controller.midi.busy
              ? null
              : () async {
                  if (loop.running || loop.busy) await loop.stop();
                  if (controller.listening) {
                    await controller.stop();
                  } else {
                    await controller.start();
                  }
                },
          icon: controller.busy
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : PixelIcon(
                  controller.listening ? PixelGlyph.stop : PixelGlyph.mic,
                  size: 20,
                ),
          label: Text(
            controller.busy
                ? (controller.state == ListeningState.stopping
                      ? 'Stopping…'
                      : 'Starting…')
                : controller.listening
                ? 'Listening'
                : 'Listen',
          ),
        ),
      TextButton(
        key: const ValueKey('midi-input'),
        onPressed: () => showModalBottomSheet<void>(
          context: context,
          builder: (_) => MidiSheet(studio: controller),
        ),
        style: TextButton.styleFrom(
          minimumSize: const Size(44, 44),
          padding: const EdgeInsets.symmetric(horizontal: 4),
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.sizeOf(context).width * .5,
          ),
          child: Text(
            _tab == 2 && controller.midi.selected != null
                ? 'MIDI · ${controller.midi.selected!.name}'
                : 'MIDI',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: controller.midi.selected == null
                  ? StudioColors.muted
                  : StudioColors.mint,
            ),
          ),
        ),
      ),
      if (_tab != 2)
        IconButton(
          tooltip: 'Settings',
          onPressed: _settings,
          icon: const PixelIcon(PixelGlyph.sliders, size: 20),
        ),
    ],
  );

  void _settings() => showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: ListenableBuilder(
        listenable: controller,
        builder: (context, _) => SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CheckboxListTile(
                title: const Text('Follow played notes'),
                value: controller.followNote,
                onChanged: (v) => controller.setFollow(v ?? true),
              ),
              CheckboxListTile(
                title: const Text('Note labels'),
                value: controller.showLabels,
                onChanged: (v) => controller.setLabels(v ?? true),
              ),
              if (controller.input case final MicrophoneNoteInput microphone)
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Microphone sensitivity'),
                      Slider(
                        value: microphone.onsetThreshold,
                        min: .2,
                        max: .85,
                        onChanged: controller.setOnsetThreshold,
                        label: microphone.onsetThreshold.toStringAsFixed(2),
                      ),
                      const Text(
                        'Lower for softer notes. Raise if extra notes appear.',
                        style: TextStyle(
                          fontSize: 12,
                          color: StudioColors.muted,
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    ),
  );
}
