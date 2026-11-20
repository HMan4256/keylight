import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../music/chords.dart';
import '../music/tonality.dart';
import '../studio/studio_controller.dart';
import '../studio/theory_controller.dart';
import 'studio_theme.dart';
import 'pixel_icon.dart';

class ReferenceKeyBar extends StatelessWidget {
  const ReferenceKeyBar({super.key, required this.theory});
  final TheoryController theory;

  @override
  Widget build(BuildContext context) {
    final keys =
        [
          for (var fifths = -7; fifths <= 7; fifths++)
            MusicalKey(fifths, theory.key.mode),
        ]..sort((a, b) {
          final pitch = a.root.pitchClass.compareTo(b.root.pitchClass);
          return pitch != 0 ? pitch : a.fifths.abs().compareTo(b.fifths.abs());
        });
    return Row(
      children: [
        const Text(
          'Key',
          style: TextStyle(color: StudioColors.muted, fontSize: 13),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: DropdownButtonHideUnderline(
            child: DropdownButton<int>(
              key: const ValueKey('key-root'),
              value: theory.key.fifths,
              isExpanded: true,
              icon: const PixelIcon(PixelGlyph.down, size: 16),
              borderRadius: BorderRadius.zero,
              items: [
                for (final key in keys)
                  DropdownMenuItem(
                    value: key.fifths,
                    child: Text(key.root.name),
                  ),
              ],
              onChanged: (value) {
                if (value != null) {
                  theory.selectKey(MusicalKey(value, theory.key.mode));
                }
              },
            ),
          ),
        ),
        const SizedBox(width: 12),
        SegmentedButton<KeyMode>(
          key: const ValueKey('key-mode'),
          showSelectedIcon: false,
          segments: const [
            ButtonSegment(value: KeyMode.major, label: Text('Major')),
            ButtonSegment(value: KeyMode.minor, label: Text('Minor')),
          ],
          selected: {theory.key.mode},
          onSelectionChanged: (modes) {
            if (modes.single != theory.key.mode) {
              theory.selectKey(theory.key.parallel);
            }
          },
          style: SegmentedButton.styleFrom(
            shape: const RoundedRectangleBorder(),
            visualDensity: VisualDensity.compact,
            minimumSize: const Size(0, 40),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            textStyle: const TextStyle(fontFamily: 'Pixelify', fontSize: 13),
            selectedBackgroundColor: StudioColors.raised,
            selectedForegroundColor: StudioColors.ink,
            foregroundColor: StudioColors.muted,
            side: const BorderSide(color: StudioColors.border),
          ),
        ),
      ],
    );
  }
}

class NoteIdentifier extends StatelessWidget {
  const NoteIdentifier({super.key, required this.controller});
  final StudioController controller;

  @override
  Widget build(BuildContext context) {
    final theory = controller.theory;
    final notes = theory.inputNotes.toList()..sort();
    final chord = theory.chord;
    final function = chord == null
        ? null
        : ChordFunction.analyze(chord, theory.key);
    final one = notes.length == 1;
    final title = notes.isEmpty
        ? 'Play a note'
        : one
        ? theory.keyboardSpelling(notes.single % 12).labelForMidi(notes.single)
        : chord?.name(theory.key) ?? '${notes.length} notes';
    final role = function == null
        ? null
        : switch (function.role) {
            HarmonicRole.tonic => 'Tonic',
            HarmonicRole.prolongation => 'Tonic prolongation',
            HarmonicRole.predominant => 'Predominant',
            HarmonicRole.dominant => 'Dominant',
            HarmonicRole.color => 'Context dependent',
          };
    final degree = one
        ? theory.key.tones.indexWhere((t) => t.pitchClass == notes.single % 12)
        : -1;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 16),
        if (notes.isNotEmpty)
          Text(
            theory.recalling ? 'LAST PLAYED' : 'PLAYING',
            textAlign: TextAlign.center,
            style: TextStyle(
              letterSpacing: 2,
              fontSize: 12,
              color: theory.recalling ? StudioColors.amber : StudioColors.mint,
            ),
          ),
        const SizedBox(height: 8),
        Text(
          title,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: notes.isEmpty ? 30 : 64,
            height: 1.15,
            letterSpacing: -1.5,
            fontWeight: FontWeight.w500,
            color: notes.isEmpty ? StudioColors.muted : StudioColors.ink,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          notes.isEmpty
              ? 'Use the microphone or touch the keyboard.'
              : one
              ? (degree < 0
                    ? 'Outside ${theory.key.label}'
                    : 'Degree ${degree + 1} in ${theory.key.label}')
              : chord == null
              ? 'No chord match'
              : '${chord.type.label} · ${chord.inversionLabel.toLowerCase()}',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 13, color: StudioColors.muted),
        ),
        if (function != null) ...[
          const SizedBox(height: 20),
          Text(
            '${function.roman} · $role in ${theory.key.label}',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              color: theory.recalling ? StudioColors.amber : StudioColors.mint,
            ),
          ),
          if (theory.matches.length > 1)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Also ${theory.matches.skip(1).take(2).map((c) => c.name(theory.key)).join(' / ')}',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12, color: StudioColors.muted),
              ),
            ),
        ],
        if (notes.length > 1) ...[
          const SizedBox(height: 32),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 20,
            runSpacing: 12,
            children: [
              for (final midi in notes)
                Text(
                  theory.keyboardSpelling(midi % 12).labelForMidi(midi),
                  key: ValueKey('detected-note-$midi'),
                  style: const TextStyle(
                    fontSize: 18,
                    color: StudioColors.muted,
                  ),
                ),
            ],
          ),
        ],
        const SizedBox(height: 24),
      ],
    );
  }
}

class CircleTheoryView extends StatelessWidget {
  const CircleTheoryView({
    super.key,
    required this.theory,
    this.diameter = 350,
  });
  final TheoryController theory;
  final double diameter;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: diameter),
          child: CircleOfFifths(theory: theory),
        ),
      ),
      const SizedBox(height: 8),
      Row(
        children: [
          Expanded(
            child: TextButton(
              key: const ValueKey('parallel-key'),
              onPressed: () => theory.selectKey(theory.key.parallel),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  'Parallel · ${theory.key.parallel.label}',
                  style: const TextStyle(fontSize: 13),
                ),
              ),
            ),
          ),
          Expanded(
            child: TextButton(
              key: const ValueKey('relative-key'),
              onPressed: () => theory.selectKey(theory.key.relative),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  'Relative · ${theory.key.relative.label}',
                  style: const TextStyle(fontSize: 13),
                ),
              ),
            ),
          ),
        ],
      ),
    ],
  );
}

class CircleOfFifths extends StatelessWidget {
  const CircleOfFifths({super.key, required this.theory});
  final TheoryController theory;

  @override
  Widget build(BuildContext context) => AspectRatio(
    aspectRatio: 1,
    child: LayoutBuilder(
      builder: (context, box) {
        final side = box.maxWidth;
        return Stack(
          alignment: Alignment.center,
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: _CirclePainter({
                  for (final note
                      in theory.live.isEmpty ? theory.inputNotes : theory.live)
                    note % 12,
                }, theory.live.isEmpty),
              ),
            ),
            for (var index = 0; index < 12; index++)
              for (final mode in KeyMode.values) _node(side, index, mode),
            IgnorePointer(
              child: SizedBox(
                width: side * .32,
                height: side * .34,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (theory.inputNotes.isNotEmpty) const Spacer(),
                    Flexible(
                      flex: 1,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          theory.chord?.name(theory.key) ??
                              (theory.inputNotes.isEmpty
                                  ? theory.key.root.name
                                  : (theory.inputNotes.toList()..sort())
                                        .map((n) => theory.nameFor(n % 12))
                                        .toSet()
                                        .join(' ')),
                          style: TextStyle(
                            fontSize: side * .072,
                            color: theory.recalling
                                ? StudioColors.amber
                                : StudioColors.mint,
                          ),
                        ),
                      ),
                    ),
                    Text(
                      theory.chord != null
                          ? ChordFunction.analyze(
                              theory.chord!,
                              theory.key,
                            ).roman
                          : theory.key.mode.name,
                      style: TextStyle(
                        fontSize: (side * .04).clamp(8, 13),
                        color: StudioColors.muted,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    ),
  );

  Widget _node(double side, int index, KeyMode mode) {
    final key = MusicalKey(MusicalKey.circleFifths[index], mode);
    final radius = side * (mode == KeyMode.major ? .43 : .275);
    final angle = -math.pi / 2 + index * math.pi / 6;
    final size = mode == KeyMode.major
        ? math.min(44.0, side * .17)
        : math.min(36.0, side * .13);
    final selected = theory.key.sameSound(key);
    final playing =
        mode == KeyMode.major &&
        (theory.live.isEmpty ? theory.inputNotes : theory.live).any(
          (n) => n % 12 == key.root.pitchClass,
        );
    final label = '${key.root.name}${mode == KeyMode.minor ? 'm' : ''}';
    final playedColor = theory.live.isEmpty
        ? StudioColors.amber
        : StudioColors.mint;
    return Positioned(
      left: side / 2 + math.cos(angle) * radius - size / 2,
      top: side / 2 + math.sin(angle) * radius - size / 2,
      width: size,
      height: size,
      child: Semantics(
        selected: selected,
        button: true,
        label: key.label,
        child: Tooltip(
          message: key.label,
          child: TextButton(
            key: ValueKey('circle-${key.fifths}-${mode.name}'),
            style: TextButton.styleFrom(
              padding: EdgeInsets.zero,
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              foregroundColor: selected || mode == KeyMode.major
                  ? StudioColors.ink
                  : StudioColors.muted,
              shape: const RoundedRectangleBorder(),
            ),
            onPressed: () => theory.selectKey(key),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                selected ? '[$label]' : label,
                maxLines: 1,
                style: TextStyle(
                  fontSize: mode == KeyMode.major
                      ? (side * .05).clamp(9, 16)
                      : (side * .039).clamp(8, 12),
                  color: playing ? playedColor : null,
                  decoration: playing ? TextDecoration.underline : null,
                  decorationColor: playedColor,
                  decorationThickness: 2,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CirclePainter extends CustomPainter {
  const _CirclePainter(this.notes, this.recalled);
  final Set<int> notes;
  final bool recalled;
  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = StudioColors.border.withValues(alpha: .6);
    final points = <Offset>[];
    for (var i = 0; i < 12; i++) {
      if (!notes.contains(
        MusicalKey(MusicalKey.circleFifths[i]).root.pitchClass,
      )) {
        continue;
      }
      final angle = -math.pi / 2 + i * math.pi / 6;
      points.add(
        center +
            Offset(0, -size.width * .077) +
            Offset(math.cos(angle), math.sin(angle)) * size.width * .075,
      );
    }
    final trace = Paint()
      ..color = recalled ? StudioColors.amber : StudioColors.mint
      ..strokeWidth = 2
      ..isAntiAlias = false;
    for (var i = 0; i < points.length; i++) {
      canvas.drawLine(points[i], points[(i + 1) % points.length], trace);
      canvas.drawRect(
        Rect.fromCenter(
          center: points[i],
          width: size.width * .014,
          height: size.width * .014,
        ),
        trace,
      );
    }
    canvas.drawCircle(center, size.width * .35, paint);
    canvas.drawCircle(center, size.width * .20, paint);
    for (var index = 0; index < 12; index++) {
      final angle = -math.pi / 2 + (index + .5) * math.pi / 6;
      final direction = Offset(math.cos(angle), math.sin(angle));
      canvas.drawLine(
        center + direction * size.width * .20,
        center + direction * size.width * .49,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_CirclePainter old) =>
      old.recalled != recalled ||
      notes.length != old.notes.length ||
      !notes.containsAll(old.notes);
}
