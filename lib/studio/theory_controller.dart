import 'package:flutter/foundation.dart';

import '../music/chords.dart';
import '../music/tonality.dart';

/// Identifies the current notes against a key chosen by the player.
class TheoryController extends ChangeNotifier {
  MusicalKey key = const MusicalKey(0);
  ScaleType? scale;
  Set<int> live = {};
  bool get recalling => _input.isNotEmpty && !setEquals(_input, live);
  Set<int> _input = {};
  List<IdentifiedChord> matches = [];

  Set<int> get inputNotes => Set.unmodifiable(_input);
  IdentifiedChord? get chord => matches.firstOrNull;
  List<SpelledPitch> get scaleTones => scale?.tones(key.root) ?? [];
  Set<int> get scalePitchClasses => scaleTones.map((n) => n.pitchClass).toSet();

  String nameFor(int pc) => keyboardSpelling(pc).name;

  String? degreeFor(int pc) {
    final index = scaleTones.indexWhere((tone) => tone.pitchClass == pc % 12);
    return index < 0 ? null : scale!.degreeLabel(index);
  }

  SpelledPitch keyboardSpelling(int pc) {
    for (final tone in [...scaleTones, ...key.tones]) {
      if (tone.pitchClass == pc % 12) return tone;
    }
    return SpelledPitch.parse(key.nameFor(pc));
  }

  void observe(Set<int> notes) {
    if (setEquals(notes, live)) return;
    final attack = notes.difference(live).isNotEmpty;
    live = Set.of(notes);
    // Releasing the notes of a chord one at a time preserves its identity.
    if (!attack) return;
    _input = Set.of(notes);
    matches = const ChordRecognizer().identify(_input, key);
  }

  void selectKey(MusicalKey next) {
    key = next;
    matches = const ChordRecognizer().identify(_input, key);
    notifyListeners();
  }

  // A scale is only an overlay: it never changes the reference key or input.
  void setScale(ScaleType? next) {
    scale = next;
    notifyListeners();
  }
}
