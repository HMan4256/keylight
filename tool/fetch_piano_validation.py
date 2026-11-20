"""Fetch Magenta's piano demo for the opt-in native inference test.

The recording is not redistributed with this project. Its use is subject to
the source dataset's terms. This script verifies the published fixture bytes.
"""

import argparse
import hashlib
from pathlib import Path
from urllib.request import urlopen

URL = (
    "https://storage.googleapis.com/magentadata/js/checkpoints/"
    "transcription/onsets_frames_uni/"
    "MAPS_MUS-mz_331_3_ENSTDkCl.250frames.wav"
)
SHA256 = "d15bc448a2cd38e4d8f5d86b94c8fb986233dbcfa07f04cc8eac5631bc2fbf52"


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--output", type=Path,
        default=Path(".dart_tool/piano_validation/piano.wav"),
    )
    destination = parser.parse_args().output
    if destination.exists() and hashlib.sha256(destination.read_bytes()).hexdigest() == SHA256:
        print(destination.resolve())
        return
    with urlopen(URL, timeout=60) as response:
        recording = response.read()
    if hashlib.sha256(recording).hexdigest() != SHA256:
        raise ValueError("Piano fixture checksum does not match the recorded reference.")
    destination.parent.mkdir(parents=True, exist_ok=True)
    destination.write_bytes(recording)
    print(destination.resolve())


if __name__ == "__main__":
    main()
