import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_midi_command/flutter_midi_command_messages.dart';
import 'package:keylight/audio/midi_session.dart';
import 'package:keylight/studio/theory_controller.dart';

void main() {
  test(
    'MIDI running status, split packets, release tails and the next attack',
    () {
      final keys = MidiKeys();
      final theory = TheoryController();
      addTearDown(theory.dispose);
      final parser = MidiMessageParser();
      void packet(List<int> bytes) {
        for (final event in parser.parse(Uint8List.fromList(bytes))) {
          if (keys.apply(event)) theory.observe(keys.notes);
        }
      }

      packet([0x90, 60]);
      packet([100, 64, 80, 67, 80]);
      expect(theory.chord!.name(theory.key), 'C');
      packet([64, 0, 0x80, 67, 40]);
      expect(theory.live, {60});
      expect(theory.inputNotes, {60, 64, 67});
      packet([60, 0]);
      expect(theory.live, isEmpty);
      expect(theory.recalling, isTrue);
      packet([0x90, 62, 100]);
      expect(theory.inputNotes, {62});
      expect(theory.chord, isNull);
      expect(theory.recalling, isFalse);
      packet([0x91, 62, 100, 0xb0, 123, 0]);
      expect(keys.notes, {62});
      packet([0x81, 62, 32]);
      expect(keys.notes, isEmpty);
    },
  );
}
