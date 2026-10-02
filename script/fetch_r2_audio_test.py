import hashlib
import importlib.util
import os
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch


spec = importlib.util.spec_from_file_location(
    "fetch_r2_audio", Path(__file__).with_name("fetch_r2_audio.py")
)
audio = importlib.util.module_from_spec(spec)
spec.loader.exec_module(audio)


class FetchAudioTest(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.output = Path(self.directory.name) / "audio"
        self.tracks = {
            "first.mp3": hashlib.sha256(b"first audio").hexdigest(),
            "second.mp3": hashlib.sha256(b"second audio").hexdigest(),
        }
        self.environment = patch.dict(os.environ, {
            "R2_AUDIO_ENDPOINT": "https://" + "a" * 32 + ".r2.cloudflarestorage.com",
            "R2_AUDIO_BUCKET": "conquest-build-audio",
            "R2_AUDIO_ACCESS_KEY_ID": "test-key",
            "R2_AUDIO_SECRET_ACCESS_KEY": "test-secret",
        })
        self.environment.start()
        self.addCleanup(self.environment.stop)

    def download(self, command, **kwargs):
        self.assertIn("--endpoint-url", command)
        self.assertEqual(command[command.index("--bucket") + 1], "conquest-build-audio")
        key = command[command.index("--key") + 1]
        content = {"first.mp3": b"first audio", "second.mp3": b"second audio"}[key]
        Path(command[-1]).write_bytes(content)
        return subprocess.CompletedProcess(command, 0)

    def test_downloads_and_publishes_verified_audio(self):
        with patch.object(audio.subprocess, "run", side_effect=self.download):
            audio.fetch_audio(self.output, self.tracks)
        self.assertEqual((self.output / "first.mp3").read_bytes(), b"first audio")
        self.assertEqual((self.output / "second.mp3").read_bytes(), b"second audio")

    def test_corrupt_second_track_does_not_publish_any_download(self):
        self.output.mkdir()
        (self.output / "first.mp3").write_bytes(b"existing audio")
        def corrupt(command, **kwargs):
            self.download(command, **kwargs)
            if command[command.index("--key") + 1] == "second.mp3":
                Path(command[-1]).write_bytes(b"corrupt")
        with patch.object(audio.subprocess, "run", side_effect=corrupt):
            with self.assertRaisesRegex(RuntimeError, "SHA-256"):
                audio.fetch_audio(self.output, self.tracks)
        self.assertEqual((self.output / "first.mp3").read_bytes(), b"existing audio")
        self.assertFalse((self.output / "second.mp3").exists())

    def test_network_failure_leaves_no_partial_audio(self):
        def failed(command, **kwargs):
            self.download(command, **kwargs)
            if command[command.index("--key") + 1] == "second.mp3":
                raise subprocess.CalledProcessError(1, command)
        with patch.object(audio.subprocess, "run", side_effect=failed):
            with self.assertRaisesRegex(RuntimeError, "download"):
                audio.fetch_audio(self.output, self.tracks)
        self.assertFalse((self.output / "first.mp3").exists())
        self.assertFalse((self.output / "second.mp3").exists())

    def test_missing_credentials_stop_before_downloading(self):
        os.environ.pop("R2_AUDIO_SECRET_ACCESS_KEY")
        with patch.object(audio.subprocess, "run", side_effect=AssertionError("network called")):
            with self.assertRaisesRegex(RuntimeError, "R2_AUDIO_SECRET_ACCESS_KEY"):
                audio.fetch_audio(self.output, self.tracks)

    def test_non_r2_endpoint_does_not_receive_credentials(self):
        os.environ["R2_AUDIO_ENDPOINT"] = "https://example.com"
        with patch.object(audio.subprocess, "run", side_effect=AssertionError("network called")):
            with self.assertRaisesRegex(RuntimeError, "endpoint"):
                audio.fetch_audio(self.output, self.tracks)


if __name__ == "__main__":
    unittest.main()
