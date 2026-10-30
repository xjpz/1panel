"""Exercise post-clone startup with an isolated SDK and no network or signing."""

import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest


SCRIPT = Path(__file__).resolve().parents[2] / "ios/ci_scripts/ci_post_clone.sh"
VERSION = json.loads((SCRIPT.parents[2] / ".fvmrc").read_text())["flutter"]

FAKE_FLUTTER = r'''#!/usr/bin/env python3
import json
import os
from pathlib import Path
import sys

args = sys.argv[1:]
with open(os.environ["FAKE_FLUTTER_TRACE"], "a") as trace:
    trace.write(json.dumps(args) + "\n")
if args == ["--version", "--machine"]:
    mode = os.environ["FAKE_FLUTTER_MODE"]
    if mode == "fail":
        print("SDK bootstrap failed", file=sys.stderr)
        sys.exit(42)
    if mode == "cold":
        print("  Downloading Flutter bootstrap artifacts...")
    cache = Path(os.environ["FLUTTER_ROOT"]) / "bin/cache/flutter.version.json"
    cache.parent.mkdir(parents=True, exist_ok=True)
    version = {"frameworkVersion": os.environ["FAKE_FLUTTER_VERSION"]}
    cache.write_text("not JSON" if mode == "invalid-cache" else json.dumps(version))
    print(json.dumps(version))
'''


class PostCloneStartupTest(unittest.TestCase):
    def run_script(self, mode="cold", version=VERSION):
        temporary = tempfile.TemporaryDirectory(prefix="1panel-ci-startup-")
        self.addCleanup(temporary.cleanup)
        root = Path(temporary.name)
        repository = root / "repository with spaces"
        repository.mkdir()
        (repository / ".fvmrc").write_text(json.dumps({"flutter": VERSION}))
        subprocess.run(["git", "init", "--quiet", str(repository)], check=True)
        sdk = root / "SDK with spaces"
        binary = sdk / "bin"
        binary.mkdir(parents=True)
        flutter = binary / "flutter"
        flutter.write_text(FAKE_FLUTTER)
        flutter.chmod(0o755)
        pod = binary / "pod"
        pod.write_text("#!/bin/sh\nexit 0\n")
        pod.chmod(0o755)
        cache = binary / "cache/flutter.version.json"
        if mode in ("warm", "fail"):
            cache.parent.mkdir()
            cache.write_text(json.dumps({"frameworkVersion": VERSION}))
        trace = root / "commands.jsonl"
        environment = dict(os.environ, CI_BUILD_NUMBER="19",
                           CI_PRIMARY_REPOSITORY_PATH=str(repository),
                           FLUTTER_ROOT=str(sdk), FAKE_FLUTTER_MODE=mode,
                           FAKE_FLUTTER_VERSION=version,
                           FAKE_FLUTTER_TRACE=str(trace))
        result = subprocess.run(["bash", str(SCRIPT)], env=environment,
                                text=True, capture_output=True, timeout=20)
        commands = [json.loads(line) for line in trace.read_text().splitlines()]
        return result, commands

    def test_cold_sdk_progress_does_not_break_version_parsing(self):
        result, commands = self.run_script()
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn("Downloading Flutter bootstrap artifacts", result.stdout)
        self.assertIn("ready for Xcode Cloud (build 19)", result.stdout)
        self.assertEqual(commands, [
            ["--version", "--machine"],
            ["precache", "--ios"],
            ["pub", "get", "--enforce-lockfile"],
            ["build", "ios", "--release", "--config-only", "--no-codesign",
             "--no-pub", "--build-number=19"],
        ])

    def test_warm_sdk_still_succeeds(self):
        result, _ = self.run_script("warm")
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

    def test_version_mismatch_stops_before_dependencies(self):
        result, commands = self.run_script(version="0.0.0")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("found 0.0.0", result.stderr)
        self.assertEqual(commands, [["--version", "--machine"]])

    def test_failed_bootstrap_cannot_use_stale_version_cache(self):
        result, commands = self.run_script("fail")
        self.assertEqual(result.returncode, 42)
        self.assertIn("SDK bootstrap failed", result.stderr)
        self.assertEqual(commands, [["--version", "--machine"]])

    def test_invalid_version_cache_stops_before_dependencies(self):
        result, commands = self.run_script("invalid-cache")
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(commands, [["--version", "--machine"]])


if __name__ == "__main__":
    unittest.main()
