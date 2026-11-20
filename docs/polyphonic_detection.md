# Polyphonic microphone detection

The default microphone engine is Magenta’s pretrained unidirectional **Onsets and Frames** piano model, executed by `tflite_flutter` in a persistent isolate. Every output frame contains an independent prediction for each key from A0 to C8. Neither inference postprocessing nor rendering selects a fixed number of “best” notes. All 88 activations can pass through together.

That capacity is different from acoustic accuracy: dense clusters, masked quiet notes, detuning, reverberation, sustain, clipping, and competing sounds can cause misses or false detections. A microphone observes sounding pitches; it cannot reliably distinguish a held key from a released key whose strings are still resonating. The result is intended for visual practice, not exact physical key-state measurement.

## Audio and timing

- Capture: mono PCM16 requested at 16 kHz, using `record`. Reported stereo input is downmixed and alternate sample rates are converted with a 63-tap low-pass filter and streaming interpolation.
- Context: 17,920 samples (1.12 seconds), initialized with zeros. Inference can start after the first 512 new samples instead of waiting for a complete context.
- Capture delivery: 512-byte PCM16 chunks requested (16 ms at 16 kHz mono), reduced from 2,048 bytes (64 ms).
- Cadence: a new window every 512 model-rate samples (32 ms), reduced from 2,048 samples (128 ms). The model outputs 32 frames with a 512-sample (32 ms) step and a 2,048-sample frontend window.
- CPU backend: request XNNPACK acceleration when the runtime supports it, with a regular CPU fallback if initialization fails or delegate symbols are unavailable. The delegate stays alive until its interpreter is closed. Older runtimes may leave this dynamic graph undelegated.
- Scheduling: at most one inference and one pending latest window. Slow inference replaces pending windows with the newest audio. The decoder processes unseen frames from overlapping context, recovering attacks after short gaps without replaying old ones. Gaps longer than retained history reset note state.
- Release: onset probability ≥0.5 and frame probability ≥0.3 start a key. Frame probability <0.25 for two frames permits release after a minimum four-frame hold. These are per-key rules, so one note can release while other chord tones remain held.
- Gate: the most recent hop’s RMS is compared to the configured threshold (default −45 dBFS). While notes are sounding, the gate uses a threshold 12 dB lower to follow decaying strings. Gated silence clears live notes and advances the decoder clock so reopening the gate cannot resurrect past attacks.
- Watchdog: a microphone snapshot expires after 600 ms without another snapshot. Explicit empty snapshots release immediately. Stop, interruption, and backgrounding also clear state.

The window’s trailing spectral context, 32 ms cadence, audio buffering, inference, and release smoothing all contribute to visible delay. The 1.12-second context is not a fixed 1.12-second delay. Phone latency and sustained thermal performance have not been measured here.

The noise gate defaults to −45 dBFS. Settings exposes onset sensitivity, which controls admission sensitivity, not a claimed percentage of detection accuracy. The classifier does not estimate precise frequencies, so microphone predictions do not show fabricated Hz/cents values.

## Model and platform setup

The original 75,860,620-byte model is bundled in `assets/models/`, together with attribution and the upstream project license. See [model provenance and checksum](../assets/models/README.md). No model download, server, account, or audio upload is needed at runtime.

Android targets API 26 or later for the native runtime. iOS targets iOS 15 or later and includes a CocoaPods Podfile, optional Pods xcconfig includes, and non-global symbol stripping for TFLite FFI lookup in release builds. Install CocoaPods on the Mac before building. A physical Android/iOS microphone session and native release build still need verification with their platform toolchains.

## Reproduce checks

Pure Dart/controller/widget tests require no host TFLite library:

```sh
flutter analyze
flutter test
```

These cover simultaneous activations up to all 88 keys, per-note releases, onset gating, overlap deduplication, silence/restart behavior, stereo/odd-byte PCM chunks, band-limited resampling at common hardware rates, input lifecycle, and dense-note rendering on phone and tablet sizes. Tests with 88 artificial model activations establish that the software has no count cap; they do not establish that the acoustic model can identify an 88-note recording accurately.

The native integration tests are opt-in because Linux/macOS host test runners do not automatically receive mobile TFLite binaries. Follow the [TFLite Flutter host-library setup](https://pub.dev/packages/tflite_flutter) for your host. On Linux the package loads `blobs/libtensorflowlite_c-linux.so` next to `Platform.resolvedExecutable` (for `flutter test`, the SDK’s `flutter_tester` engine binary).

Fetch the eight-second piano example used by the [official Magenta transcription demo](https://magenta.github.io/magenta-js/music/demos/transcription.html), then run:

```sh
python3 tool/fetch_piano_validation.py
flutter test \
  --dart-define=PIANO_MODEL_INTEGRATION=true \
  --dart-define=PIANO_TEST_WAV="$PWD/.dart_tool/piano_validation/piano.wav" \
  test/piano_model_integration_test.dart
```

The fetch script verifies the fixture checksum. The recording is downloaded for local validation and is not redistributed in this repository. Its source dataset has its own terms.

The test feeds the actual recording through PCM chunking, the audio buffer, the native inference isolate, and note decoding. It checks a known overlapping C4/E4/C5 passage, multiple simultaneous notes, expected pitches, silence, deterministic noise rejection, a new stream epoch, and invalid-model failure/cleanup. It prints inference timings for the host.

Redesign regression run on this Linux host with a TFLite 2.5.0 C runtime: 250 windows at the new 32 ms cadence, up to **6 simultaneous notes**, **19 distinct pitches**, approximately **124 ms median / 160 ms maximum** native inference. Before the scheduling change, the same recording produced 62 windows, 6 simultaneous notes, 20 distinct pitches, and approximately 126 ms median / 162 ms maximum inference. This older runtime rejected delegation of the dynamic graph, so these results do not demonstrate an acceleration speedup. Shorter audio windows and immediate UI highlights reduce avoidable waiting, but the inference cost and model lookahead remain. This is a regression fixture and host benchmark, not a calibrated accuracy score or phone performance guarantee. Further validation needs diverse pianos, chord densities, playing styles, distances, rooms, and physical phones.

For the native platform builds:

```sh
flutter build apk --debug
# On macOS with Xcode and CocoaPods:
flutter build ios --no-codesign
```

## Sources

- [Magenta model and realtime reference](https://github.com/magenta/magenta/tree/main/magenta/models/onsets_frames_transcription/realtime)
- [Onsets and Frames research](https://arxiv.org/abs/1710.11153)
- [TensorFlow XNNPACK backend and delegate lifecycle](https://github.com/tensorflow/tensorflow/blob/master/tensorflow/lite/delegates/xnnpack/README.md)
- [TFLite Flutter package and native setup](https://pub.dev/packages/tflite_flutter)
