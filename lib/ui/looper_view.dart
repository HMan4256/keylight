import 'package:material_ui/material_ui.dart';

import '../looper/loop_transport.dart';
import '../studio/studio_controller.dart';
import 'studio_theme.dart';

class LooperView extends StatelessWidget {
  const LooperView({super.key, required this.loop, required this.studio});
  final LoopTransport loop;
  final StudioController studio;

  Future<void> _record(LoopTrack track) async {
    if (track.kind == TrackKind.audio && (studio.busy || studio.listening)) {
      await studio.stop();
    }
    await loop.start(record: track);
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: loop,
    builder: (context, _) => LayoutBuilder(
      builder: (context, bounds) {
        final controls = _controls(context), tracks = _tracks();
        Widget panel(List<Widget> items) => ListView(
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 24),
          children: items,
        );
        if (bounds.maxWidth >= 700) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  children: [
                    _transport(),
                    Expanded(child: panel(controls)),
                  ],
                ),
              ),
              const VerticalDivider(width: 1),
              Expanded(child: panel(tracks)),
            ],
          );
        }
        return Column(
          children: [
            _transport(),
            Expanded(child: panel([...controls, ...tracks])),
          ],
        );
      },
    ),
  );

  Widget _transport() => Padding(
    padding: const EdgeInsets.fromLTRB(18, 6, 18, 8),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            FilledButton(
              style: FilledButton.styleFrom(
                shape: const RoundedRectangleBorder(),
              ),
              onPressed: loop.running
                  ? loop.stop
                  : loop.busy
                  ? null
                  : () => loop.start(),
              child: Text(loop.running ? 'Stop' : 'Play'),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                !loop.running
                    ? 'Stopped'
                    : loop.bar == 0
                    ? 'Count-in · ${loop.beat}'
                    : 'Bar ${loop.bar} / ${loop.bars}   Beat ${loop.beat}',
                style: const TextStyle(color: StudioColors.mint),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ExcludeSemantics(
          child: Row(
            children: [
              for (var i = 1; i <= loop.beats; i++)
                Expanded(
                  child: Container(
                    height: 5,
                    margin: EdgeInsets.only(right: i == loop.beats ? 0 : 3),
                    color: loop.running && loop.beat == i
                        ? (loop.recording
                              ? StudioColors.amber
                              : StudioColors.mint)
                        : StudioColors.border,
                  ),
                ),
            ],
          ),
        ),
        if (loop.error != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              loop.error!,
              style: const TextStyle(color: StudioColors.amber),
            ),
          ),
      ],
    ),
  );

  List<Widget> _controls(BuildContext context) => [
    Wrap(
      spacing: 18,
      runSpacing: 2,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        TextButton(
          onPressed: loop.locked
              ? null
              : () async {
                  final value = await showDialog<int>(
                    context: context,
                    builder: (_) => _TempoDialog(initial: loop.bpm),
                  );
                  if (value != null) loop.configure(tempo: value);
                },
          child: Text('${loop.bpm} BPM'),
        ),
        DropdownButton<(int, int)>(
          value: (loop.beats, loop.denominator),
          items: [
            for (final meter in const [
              (2, 4),
              (3, 4),
              (4, 4),
              (5, 4),
              (6, 8),
              (7, 8),
              (9, 8),
              (12, 8),
            ])
              DropdownMenuItem(
                value: meter,
                child: Text('${meter.$1}/${meter.$2}'),
              ),
          ],
          onChanged: loop.locked
              ? null
              : (m) => loop.configure(numerator: m!.$1, unit: m.$2),
        ),
        DropdownButton<int>(
          value: loop.bars,
          items: [
            for (final n in [1, 2, 4, 8])
              DropdownMenuItem(
                value: n,
                child: Text('$n ${n == 1 ? 'bar' : 'bars'}'),
              ),
          ],
          onChanged: loop.locked ? null : (v) => loop.configure(measures: v),
        ),
      ],
    ),
    Wrap(
      spacing: 8,
      children: [
        FilterChip(
          shape: const RoundedRectangleBorder(),
          selectedColor: StudioColors.raised,
          checkmarkColor: StudioColors.mint,
          labelStyle: const TextStyle(color: StudioColors.ink),
          label: const Text('Metronome'),
          selected: loop.metronome,
          onSelected: loop.setClick,
        ),
        FilterChip(
          shape: const RoundedRectangleBorder(),
          selectedColor: StudioColors.raised,
          checkmarkColor: StudioColors.mint,
          labelStyle: const TextStyle(color: StudioColors.ink),
          label: const Text('Count-in'),
          selected: loop.countIn,
          onSelected: loop.running ? null : loop.setCountIn,
        ),
      ],
    ),
    const SizedBox(height: 12),
    Row(
      children: [
        const Text('MIDI out'),
        const SizedBox(width: 12),
        Expanded(
          child: DropdownButton<int>(
            isExpanded: true,
            value: loop.outputChannel,
            items: const [
              DropdownMenuItem(value: 0, child: Text('Recorded channels')),
              DropdownMenuItem(
                value: 4,
                child: Text('FP-30X panel tone · Ch 4'),
              ),
            ],
            onChanged: loop.running || loop.busy
                ? null
                : (v) => loop.setChannel(v!),
          ),
        ),
      ],
    ),
  ];

  List<Widget> _tracks() => [
    for (final track in loop.tracks) ...[
      const Divider(),
      Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(track.name, style: const TextStyle(fontSize: 18)),
                Text(
                  identical(track, loop.target)
                      ? (loop.recording
                            ? 'Recording'
                            : 'Armed for next downbeat')
                      : track.takes.isEmpty
                      ? 'Empty'
                      : '${track.takes.length} ${track.takes.length == 1 ? 'take' : 'takes'}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: StudioColors.muted,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: loop.busy || loop.target != null
                ? null
                : () => _record(track),
            child: Text(track.takes.isEmpty ? 'Record' : 'Overdub'),
          ),
          PopupMenuButton<String>(
            tooltip: 'Options for ${track.name}',
            onSelected: (action) {
              if (action == 'mute') {
                loop.mute(track);
              } else if (action == 'undo') {
                loop.undo(track);
              } else {
                loop.remove(track);
              }
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                value: 'mute',
                child: Text(track.muted ? 'Unmute' : 'Mute'),
              ),
              PopupMenuItem(
                value: 'undo',
                enabled: !loop.running && !loop.busy && track.takes.isNotEmpty,
                child: const Text('Undo last take'),
              ),
              PopupMenuItem(
                value: 'remove',
                enabled: !loop.running && !loop.busy && track.takes.isEmpty,
                child: const Text('Remove empty track'),
              ),
            ],
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
              child: Text(track.muted ? 'Muted ▾' : '···'),
            ),
          ),
        ],
      ),
    ],
    const Divider(),
    Wrap(
      spacing: 12,
      children: [
        OutlinedButton(
          style: OutlinedButton.styleFrom(
            shape: const RoundedRectangleBorder(),
          ),
          onPressed: () => loop.add(TrackKind.midi),
          child: const Text('+ MIDI track'),
        ),
        OutlinedButton(
          style: OutlinedButton.styleFrom(
            shape: const RoundedRectangleBorder(),
          ),
          onPressed: () => loop.add(TrackKind.audio),
          child: const Text('+ Audio track'),
        ),
      ],
    ),
  ];
}

class _TempoDialog extends StatefulWidget {
  const _TempoDialog({required this.initial});
  final int initial;

  @override
  State<_TempoDialog> createState() => _TempoDialogState();
}

class _TempoDialogState extends State<_TempoDialog> {
  final form = GlobalKey<FormState>();
  late int value = widget.initial;

  void submit() {
    if (form.currentState!.validate()) Navigator.pop(context, value);
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Tempo'),
    content: Form(
      key: form,
      child: TextFormField(
        autofocus: true,
        selectAllOnFocus: true,
        initialValue: widget.initial.toString(),
        keyboardType: TextInputType.number,
        decoration: const InputDecoration(
          labelText: 'Quarter notes per minute',
        ),
        validator: (text) {
          final bpm = int.tryParse(text?.trim() ?? '');
          if (bpm == null || bpm < 40 || bpm > 240) return 'Enter 40–240 BPM';
          value = bpm;
          return null;
        },
        onFieldSubmitted: (_) => submit(),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      TextButton(onPressed: submit, child: const Text('Set tempo')),
    ],
  );
}
