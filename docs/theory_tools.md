# Piano tools

Identify and Circle share the manually selected reference key and the same input. The Looper tab shares the MIDI connection. Switching tabs keeps the current transport position.

- **Identify:** note names, chord name and inversion, and a Roman numeral / harmonic function in the selected major or minor key. For example, a C-major chord shows I in C major and IV in G major. The key never follows your playing automatically.
- **Circle:** outer major keys and their inner relative minors. Tap a key to select it. **Parallel** keeps the tonic (C major → C minor); **Relative** keeps the signature (C major → A minor). The Major/Minor control also switches to the parallel key.

The keyboard stays visible in both tools. Green indicates active input. Amber recalls the last played voicing after release. Scale highlighting starts **off**. Choose a scale in the keyboard toolbar to shade its notes and label degrees; the overlay never presses notes, creates a chord, or changes the reference key. For example, C harmonic minor can be viewed while the reference key remains C major. The ascending melodic minor is labelled explicitly.

The pin button holds touch notes so a chord can be entered one note at a time. Tap again to release an individual note or use the clear button to release touch input. Swipe to move across all 88 keys; octave arrows and the center button navigate without changing input. Touch entry does not synthesize sound. Microphone listening continues independently.

## Identification

Chord matching uses the complete current pitch-class set, ignoring octave doublings. The lowest sounding note determines inversion and slash bass. Triads, suspended chords, open fifths, sixths, sevenths, and selected extended / altered chords are supported. Ambiguous sets show alternative names; an unmatched collection stays unclassified. Rootless and omitted-tone interpretations are not inferred.

Functions describe a conventional interpretation in your selected major/minor key. They include borrowed minor iv, possible secondary dominants, minor-key V/V7, and raised leading-tone diminished chords. Context can change a chord's role. The scale overlay does not change functional analysis.

Spelling follows the selected scale, then the reference key. Enharmonic octave boundaries are preserved (B♯3 = C4 and C♭4 = B3). Actual note highlights update immediately, without a color-transition delay. The piano follows out-of-view microphone notes when enabled in Settings.

Automatic key estimation, preview notes, chord builders, harmony history, scale/chord palette screens, and lessons/games are absent from this version. USB and Bluetooth MIDI keyboards can be selected in the MIDI input sheet.

## Validation

```sh
flutter analyze
flutter test
flutter build apk --profile
```

Tests cover recognition across all supported chord types and transpositions, inversions/doubling, ambiguous names, minor/chromatic functions, enharmonic spelling, manual key stability, distinct parallel/relative selections, scale overlay isolation, held touch input, background cleanup, and phone/landscape/tablet layouts. All 88 synthetic notes can be displayed together; this does not establish acoustic accuracy on an 88-note recording.

Actual Flutter renders were reviewed at 390×844, 320×568, 844×390, and 1024×1366. Compact and landscape layouts resize the circle to keep its lower key targets and relationship actions visible, while retaining the keyboard. Phone screenshots are available in the [project overview](../README.md). Physical-phone latency and the iOS build have not been measured here.

See [microphone engine and validation](polyphonic_detection.md) for audio timing, accuracy limitations, and the recorded-piano integration test.
