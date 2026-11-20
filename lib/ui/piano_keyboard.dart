import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../music/piano_note.dart';
import '../music/tonality.dart';
import '../studio/studio_controller.dart';
import 'studio_theme.dart';
import 'pixel_icon.dart';

class PianoKeyboard extends StatefulWidget {
  const PianoKeyboard({
    super.key,
    required this.controller,
    this.keyHeight = 200,
  });
  final StudioController controller;
  final double keyHeight;

  @override
  State<PianoKeyboard> createState() => _PianoKeyboardState();
}

class _PianoKeyboardState extends State<PianoKeyboard> {
  final _scroll = ScrollController();
  final _whiteNotes = [
    for (var midi = 21; midi <= 108; midi++)
      if (!PianoNote(midi).isBlack) midi,
  ];
  double _keyWidth = 40;
  int? _lastFollowed;
  bool _initialized = false;

  void _center(int midi, {bool animate = true}) {
    if (!mounted || !_scroll.hasClients) return;
    final index = _whiteNotes.indexWhere((n) => n >= midi);
    final target =
        ((index + 0.5) * _keyWidth - _scroll.position.viewportDimension / 2)
            .clamp(0.0, _scroll.position.maxScrollExtent);
    if (animate) {
      _scroll.animateTo(
        target,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
      );
    } else {
      _scroll.jumpTo(target);
    }
  }

  void _shift(int direction) {
    if (!_scroll.hasClients) return;
    _scroll.animateTo(
      (_scroll.offset + direction * 7 * _keyWidth).clamp(
        0.0,
        _scroll.position.maxScrollExtent,
      ),
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final midi = controller.followMidi;
    return LayoutBuilder(
      builder: (context, constraints) {
        _keyWidth = math.max(38, constraints.maxWidth / 21);
        if (!_initialized) {
          _initialized = true;
          WidgetsBinding.instance.addPostFrameCallback(
            (_) => _center(60, animate: false),
          );
        } else if (controller.followNote &&
            midi != null &&
            midi != _lastFollowed) {
          _lastFollowed = midi;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!_scroll.hasClients) return;
            final index = _whiteNotes.indexWhere((n) => n >= midi);
            final x = index * _keyWidth;
            if (x < _scroll.offset + _keyWidth ||
                x >
                    _scroll.offset +
                        _scroll.position.viewportDimension -
                        _keyWidth * 2) {
              _center(midi);
            }
          });
        }
        if (!controller.followNote) _lastFollowed = null;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  Expanded(
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        key: const ValueKey('scale-highlight'),
                        icon: const PixelIcon(PixelGlyph.down, size: 14),
                        value: controller.theory.scale?.name ?? 'off',
                        isExpanded: true,
                        style: const TextStyle(
                          fontFamily: 'Pixelify',
                          fontFamilyFallback: ['TheorySymbols'],
                          fontSize: 12,
                          color: StudioColors.muted,
                        ),
                        items: [
                          const DropdownMenuItem(
                            value: 'off',
                            child: Text('Scale: off'),
                          ),
                          for (final scale in ScaleType.values)
                            DropdownMenuItem(
                              value: scale.name,
                              child: Text(scale.label),
                            ),
                        ],
                        onChanged: (name) => controller.theory.setScale(
                          name == 'off' ? null : ScaleType.values.byName(name!),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    tooltip: 'Hold touch notes',
                    isSelected: controller.latchTouches,
                    onPressed: () =>
                        controller.setLatchTouches(!controller.latchTouches),
                    icon: const PixelIcon(PixelGlyph.pin, size: 18),
                    selectedIcon: const PixelIcon(
                      PixelGlyph.pin,
                      size: 18,
                      color: StudioColors.mint,
                    ),
                  ),
                  if (controller.touching)
                    IconButton(
                      tooltip: 'Release touch notes',
                      onPressed: controller.releaseTouches,
                      icon: const PixelIcon(PixelGlyph.close, size: 18),
                    )
                  else
                    IconButton(
                      tooltip: 'Middle C',
                      onPressed: () => _center(60),
                      icon: const PixelIcon(PixelGlyph.center, size: 18),
                    ),
                  IconButton(
                    tooltip: 'Lower octave',
                    onPressed: () => _shift(-1),
                    icon: const PixelIcon(PixelGlyph.left, size: 20),
                  ),
                  IconButton(
                    tooltip: 'Higher octave',
                    onPressed: () => _shift(1),
                    icon: const PixelIcon(PixelGlyph.right, size: 20),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(6, 8, 6, 6),
              decoration: BoxDecoration(
                color: const Color(0xFF080C10),
                borderRadius: BorderRadius.zero,
                border: Border.all(color: StudioColors.border),
              ),
              child: NotificationListener<ScrollStartNotification>(
                onNotification: (notification) {
                  if (notification.dragDetails != null) {
                    controller.cancelTouchPointers();
                  }
                  return false;
                },
                child: SingleChildScrollView(
                  controller: _scroll,
                  scrollDirection: Axis.horizontal,
                  child: SizedBox(
                    width: _whiteNotes.length * _keyWidth,
                    height: widget.keyHeight,
                    child: Stack(
                      children: [
                        for (var index = 0; index < _whiteNotes.length; index++)
                          Positioned(
                            left: index * _keyWidth,
                            top: 0,
                            bottom: 0,
                            width: _keyWidth,
                            child: _key(
                              PianoNote(_whiteNotes[index]),
                              controller,
                            ),
                          ),
                        for (var midi = 22; midi < 108; midi++)
                          if (PianoNote(midi).isBlack)
                            Positioned(
                              left:
                                  _whiteNotes.where((n) => n < midi).length *
                                      _keyWidth -
                                  _keyWidth * 0.31,
                              top: 0,
                              width: _keyWidth * 0.62,
                              height: widget.keyHeight * .62,
                              child: _key(PianoNote(midi), controller),
                            ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _key(PianoNote note, StudioController controller) {
    final active = controller.activeKeys.contains(note.midi);
    final theory = controller.theory;
    final inScale = theory.scalePitchClasses.contains(note.pitchClass);
    final degree = theory.degreeFor(note.pitchClass);
    final spelling = theory.keyboardSpelling(note.pitchClass);
    final dark = note.isBlack;
    final recalled =
        theory.live.isEmpty && theory.inputNotes.contains(note.midi);
    final keyColor = active
        ? StudioColors.mint
        : recalled
        ? StudioColors.amber
        : dark
        ? inScale
              ? const Color(0xFF35463E)
              : const Color(0xFF222831)
        : inScale
        ? const Color(0xFFD9E8DE)
        : const Color(0xFFF0F0E8);
    return Semantics(
      label:
          '${spelling.labelForMidi(note.midi)}${note.midi == 60 ? ', middle C' : ''}',
      button: true,
      selected: active,
      child: GestureDetector(
        // Keep a tap recognizer in the arena even for momentary notes; with
        // only a drag recognizer a scrollable can claim a stationary press.
        onTap: () {
          if (controller.latchTouches) {
            controller.touchDown(-note.midi, note.midi);
          }
        },
        child: Listener(
          onPointerDown: (event) {
            if (!controller.latchTouches) {
              controller.touchDown(event.pointer, note.midi);
            }
          },
          onPointerUp: (event) => controller.touchUp(event.pointer),
          onPointerCancel: (event) => controller.touchUp(event.pointer),
          child: AnimatedContainer(
            key: ValueKey('piano-key-${note.midi}'),
            duration: Duration.zero,
            margin: EdgeInsets.symmetric(horizontal: dark ? 0 : 1),
            decoration: BoxDecoration(
              color: keyColor,
              borderRadius: const BorderRadius.vertical(bottom: Radius.zero),
              border: Border.all(
                color: dark ? const Color(0xFF050709) : const Color(0xFFB2B8B0),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.4),
                  offset: Offset(0, dark ? 4 : 3),
                  blurRadius: 0,
                ),
              ],
            ),
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: EdgeInsets.only(
                  bottom: widget.keyHeight < 90 ? 6 : 12,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (widget.keyHeight >= 90 && inScale && degree == '1')
                      Container(
                        width: 6,
                        height: 6,
                        margin: const EdgeInsets.only(bottom: 10),
                        decoration: BoxDecoration(
                          color: active
                              ? StudioColors.background
                              : StudioColors.mint,
                          shape: BoxShape.rectangle,
                        ),
                      ),
                    if (controller.showLabels)
                      Text(
                        dark ? spelling.name : spelling.labelForMidi(note.midi),
                        style: TextStyle(
                          fontSize: dark ? 10 : 11,
                          fontWeight: FontWeight.w600,
                          color: active || recalled || !dark
                              ? StudioColors.background
                              : StudioColors.muted,
                        ),
                      ),
                    if (inScale && widget.keyHeight >= 90)
                      Text(
                        degree ?? '',
                        style: TextStyle(
                          fontSize: 10,
                          color: active || recalled || !dark
                              ? const Color(0xFF425063)
                              : StudioColors.mint,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
