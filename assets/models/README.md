# Piano transcription model

Bundled file: `piano_onsets_frames.tflite` (75,860,620 bytes).

Source: Magenta’s published `onsets_frames_wavinput_no_offset_uni.tflite`, downloaded without conversion or modification.

- [Official model and realtime example](https://github.com/magenta/magenta/tree/main/magenta/models/onsets_frames_transcription/realtime)
- [Original model download](https://storage.googleapis.com/magentadata/models/onsets_frames_transcription/tflite/onsets_frames_wavinput_no_offset_uni.tflite)
- [Magenta repository license](https://github.com/magenta/magenta/blob/main/LICENSE) (copy included as `MAGENTA_LICENSE`)

SHA-256:

```text
69ac3567d8ee5fda620225a49c62839c3e82165e89d54d1af63caac877605dfc
```

The Magenta Authors supply the pretrained model. The inference and postprocessing integration in this app is separate. The model expects 17,920 mono float32 samples at 16 kHz and returns 32 frames of 88-key onset/frame logits. The unused `offset_logits` output is a scalar in this particular no-offset model; it is deliberately not read or interpreted as an 88-key array.

This asset is included in the app, so first use does not download a model or require an internet connection. Keep the model and attribution files when distributing the application. The model occupies about 72 MiB before application packaging, and requires additional runtime memory for tensors and activations.
