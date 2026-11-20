import 'package:flutter_test/flutter_test.dart';
import 'package:keylight/main.dart';
import 'package:keylight/studio/studio_controller.dart';
import 'package:material_ui/material_ui.dart';

import 'support/fake_note_input.dart';

void main() {
  testWidgets('looper edits tempo, routes a track, and explains missing MIDI', (
    tester,
  ) async {
    final studio = StudioController(FakeNoteInput());
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(KeylightApp(controller: studio));
    await tester.tap(find.text('Looper'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('100 BPM'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), '0');
    await tester.tap(find.text('Set tempo'));
    await tester.pumpAndSettle();
    expect(find.text('Enter 40–240 BPM'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField), '117');
    await tester.tap(find.text('Set tempo'));
    await tester.pumpAndSettle();
    expect(find.text('117 BPM'), findsOneWidget);
    await tester.tap(find.text('Recorded channels'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('FP-30X panel tone · Ch 4').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Record'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Connect a MIDI keyboard'), findsOneWidget);
    await tester.ensureVisible(find.text('+ Audio track'));
    await tester.tap(find.text('+ Audio track'));
    await tester.pumpAndSettle();
    expect(find.text('Audio 2'), findsOneWidget);
    await tester.tap(find.text('Identify'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Looper'));
    await tester.pumpAndSettle();
    expect(find.text('Audio 2'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    studio.dispose();
  });
}
