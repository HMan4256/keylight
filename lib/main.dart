import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import 'studio/studio_controller.dart';
import 'ui/studio_screen.dart';
import 'ui/studio_theme.dart';

void main() {
  LicenseRegistry.addLicense(() async* {
    final license = await rootBundle.loadString(
      'assets/models/MAGENTA_LICENSE',
    );
    yield LicenseEntryWithLineBreaks([
      'Magenta piano transcription model',
    ], license);
    yield LicenseEntryWithLineBreaks([
      'Pixelify Sans',
    ], await rootBundle.loadString('assets/fonts/Pixelify-OFL.txt'));
    yield LicenseEntryWithLineBreaks([
      'Noto Music',
    ], await rootBundle.loadString('assets/fonts/OFL.txt'));
  });
  runApp(const KeylightApp());
}

class KeylightApp extends StatelessWidget {
  const KeylightApp({super.key, this.controller});
  final StudioController? controller;

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Keylight · Piano studio',
    debugShowCheckedModeBanner: false,
    theme: studioTheme(),
    home: StudioScreen(controller: controller),
  );
}
