# MIDI and the looper

Tap **MIDI** to connect a keyboard. Plug in a class-compliant USB MIDI keyboard through a data-capable adapter and choose it in the device list. For a Bluetooth MIDI keyboard, enable pairing on the instrument, tap **Scan Bluetooth**, grant device access, and choose **Connect**. Opening a MIDI connection stops the microphone. Tap **Listen** to switch back.

Green highlights track active keys. MIDI follows physical note-on and note-off messages on all channels. After release, amber highlights keep the last voicing visible until the next attack. The circle connects its pitch classes in fifths order and shows its name and Roman numeral in the center. Brackets mark the selected reference key.

## Record a loop

1. For MIDI, open **MIDI** and connect the instrument. On an FP-30X, use the USB Computer port with a data cable and phone adapter, or select the piano through **Scan Bluetooth**. In **Looper → MIDI out**, choose **FP-30X panel tone · Ch 4** to play the sound selected on the piano. **Recorded channels** keeps the transmitted channel for each event. [Roland’s channel guide](https://support.roland.com/hc/en-us/articles/14535225011611-FP-30X-FP-60X-FP-90X-How-to-play-the-selected-sound-via-MIDI)
2. Set the tempo, time signature, and loop length first. Tempo is in quarter notes per minute. The click marks each time-signature unit and accents the first beat of each bar. **Count-in** gives one bar before recording.
3. Tap **Record** on a MIDI track, or **+ Audio track → Record** to capture the microphone. After one pass the track repeats. **Overdub** layers another take. Recording during playback starts at the next loop boundary.
4. Add more tracks, or open a track’s menu to mute it. Stop playback to undo the last take on a track. Once all takes are removed, the tempo, meter, and length can be changed again.

For other instruments, leave **MIDI out → Recorded channels** selected and enable reception on the channel you played. The looper uses one bidirectional USB MIDI or Bluetooth MIDI device for recording and playback. Instruments with separate five-pin sockets can use a phone-compatible USB MIDI interface. Connect instrument OUT to interface IN, and interface OUT to instrument IN.

MIDI replays channel messages, including key velocity, release velocity, and pedals, with timing measured on arrival at the phone. The instrument generates the sound. Audio tracks play back through the phone’s selected audio output. Headphones keep the metronome and earlier audio takes out of microphone overdubs. All takes stay in memory for the current app session.
