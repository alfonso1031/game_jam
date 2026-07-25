from __future__ import annotations

import math
import struct
import tempfile
import unittest
import wave
from pathlib import Path

import generate_slime_audio as generator


class SlimeAudioGenerationTests(unittest.TestCase):
    def test_generates_expected_pcm_pack(self) -> None:
        with tempfile.TemporaryDirectory() as temp:
            output = Path(temp)
            generator.generate_assets([output])

            self.assertEqual(
                sorted(path.name for path in output.glob("*.wav")),
                sorted(generator.ASSET_DURATIONS),
            )

            for name, duration in generator.ASSET_DURATIONS.items():
                path = output / name
                with wave.open(str(path), "rb") as source:
                    self.assertEqual(source.getnchannels(), 1, name)
                    self.assertEqual(source.getsampwidth(), 2, name)
                    self.assertEqual(source.getframerate(), generator.SAMPLE_RATE, name)
                    expected_frames = round(duration * generator.SAMPLE_RATE)
                    self.assertLessEqual(abs(source.getnframes() - expected_frames), 1, name)
                    frames = source.readframes(source.getnframes())

                samples = struct.unpack(f"<{len(frames) // 2}h", frames)
                peak = max(abs(sample) for sample in samples)
                self.assertLessEqual(peak, generator.MAX_PCM_PEAK, name)
                self.assertGreater(peak, 2048, name)

    def test_charge_loop_has_matching_boundaries(self) -> None:
        with tempfile.TemporaryDirectory() as temp:
            output = Path(temp)
            generator.generate_assets([output])
            with wave.open(str(output / "slime_charge_loop.wav"), "rb") as source:
                frames = source.readframes(source.getnframes())
            samples = struct.unpack(f"<{len(frames) // 2}h", frames)
            self.assertLessEqual(abs(samples[0] - samples[-1]), 256)


if __name__ == "__main__":
    unittest.main()
