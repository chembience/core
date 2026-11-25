"""Tests for ./release, run against a throwaway Git copy of the release files.

Run directly (`python3 tests/test_release.py`) or through ./test.
"""

import os
import re
import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path

REPO = Path(__file__).resolve().parents[1]
FILES = [
    "release", "VERSION", "CHANGELOG.md", "README.md",
    "prod-tools/k8s/chart-base/Chart.yaml",
    "django/app/k8s/values.yaml", "fastapi/app/k8s/values.yaml",
    "jupyter/app/k8s/values.yaml", "rdkit/app/k8s/values.yaml",
]
NB_HYPHEN = "‑"


class ReleaseTest(unittest.TestCase):
    def setUp(self):
        self.tmp = Path(tempfile.mkdtemp())
        self.addCleanup(shutil.rmtree, self.tmp)
        for rel in FILES:
            (self.tmp / rel).parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(REPO / rel, self.tmp / rel)
        env = {**os.environ, "GIT_CONFIG_NOSYSTEM": "1", "GIT_CONFIG_GLOBAL": os.devnull}
        self.env = env
        self.git("init", "-q", "-b", "develop")
        self.git("config", "user.email", "test@example.org")
        self.git("config", "user.name", "Release test")
        self.git("add", ".")
        self.git("commit", "-qm", "fixture")
        # A synthetic history, independent of the repository's real versions:
        # 1.0.0 is released and 1.0.1-pre1 is in development.
        self.write("CHANGELOG.md", "# Changelog\n\n## [Unreleased]\n\n### Added\n- A feature.\n\n"
                   "## [1.0.0] - 2026-01-02\n\n### Added\n- First release.\n")
        readme = self.read("README.md")
        start = readme.index("## Releases")
        end = readme.index("\n## ", start + 1)
        self.write("README.md", readme[:start] + "## Releases\n\n| Release | Date | Notes |\n"
                   "|-------|------------|---------|\n"
                   f"| 1.0.0 | 2026{NB_HYPHEN}01{NB_HYPHEN}02 | First release |\n" + readme[end:])
        self.set_version("1.0.1-pre1")
        self.git("commit", "-qam", "development state")

    # helpers
    def git(self, *args):
        return subprocess.run(["git", "-C", str(self.tmp), *args], check=True,
                              capture_output=True, text=True, env=self.env).stdout

    def read(self, rel):
        return (self.tmp / rel).read_text(encoding="utf-8")

    def write(self, rel, text):
        (self.tmp / rel).write_text(text, encoding="utf-8")

    def set_version(self, version):
        self.write("VERSION", version + "\n")
        chart = "prod-tools/k8s/chart-base/Chart.yaml"
        self.write(chart, re.sub(r'(?m)^appVersion: ".*"', f'appVersion: "{version}"', self.read(chart)))
        for app in ("django", "fastapi", "jupyter", "rdkit"):
            rel = f"{app}/app/k8s/values.yaml"
            self.write(rel, re.sub(r'(core-rdkit-postgres\s*,?\s*tag:\s*")[^"]+', rf"\g<1>{version}", self.read(rel)))

    def release(self, *args):
        return subprocess.run([str(self.tmp / "release"), *args], capture_output=True,
                              text=True, env=self.env)

    def assert_ok(self, result):
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

    def assert_fails(self, result, message):
        self.assertNotEqual(result.returncode, 0, result.stdout)
        self.assertIn(message, result.stderr)

    # tests
    def test_check_passes_on_development_state(self):
        self.assert_ok(self.release("check"))

    def test_prepare_stable_release_then_start_next_cycle(self):
        result = self.release("prepare", "1.0.1", "--summary", "Shared libraries", "--date", "2026-12-01", "--no-test")
        self.assert_ok(result)
        self.assertIn("cannot be undone", result.stdout)
        self.assertEqual(self.git("rev-parse", "--abbrev-ref", "HEAD").strip(), "release/1.0.1")
        self.assertEqual(self.read("VERSION"), "1.0.1\n")
        self.assertIn('appVersion: "1.0.1"', self.read("prod-tools/k8s/chart-base/Chart.yaml"))
        for app in ("django", "fastapi", "jupyter", "rdkit"):
            self.assertIn('tag: "1.0.1"', self.read(f"{app}/app/k8s/values.yaml"))
        changelog = self.read("CHANGELOG.md")
        self.assertTrue(changelog.split("## [", 1)[1].startswith("1.0.1] - 2026-12-01"))
        self.assertNotIn("[Unreleased]", changelog)
        self.assertIn(f"| 1.0.1 | 2026{NB_HYPHEN}12{NB_HYPHEN}01 | Shared libraries |", self.read("README.md"))
        self.assertEqual(self.git("status", "--porcelain"), "")
        self.assertTrue(self.git("log", "-1", "--format=%s").startswith("Release 1.0.1"))
        self.assert_ok(self.release("check"))

        self.assert_ok(self.release("start", "1.0.2-pre1", "--no-test"))
        self.assertEqual(self.read("VERSION"), "1.0.2-pre1\n")
        self.assertTrue(self.read("CHANGELOG.md").split("## [", 1)[1].startswith("Unreleased]\n"))
        self.assertEqual(self.git("log", "-1", "--format=%s").strip(), "Start 1.0.2-pre1 development")
        self.assert_ok(self.release("check"))

    def test_prepare_prerelease_adds_no_readme_row(self):
        readme = self.read("README.md")
        self.assert_ok(self.release("prepare", "1.0.1-pre1", "--date", "2026-12-01", "--no-test", "--no-branch"))
        self.assertEqual(self.read("README.md"), readme)
        self.assertIn("## [1.0.1-pre1] - 2026-12-01", self.read("CHANGELOG.md"))
        self.assertEqual(self.git("rev-parse", "--abbrev-ref", "HEAD").strip(), "develop")

    def test_prepare_refusals(self):
        self.assert_fails(self.release("prepare", "1.0.1", "--no-test"), "needs --summary")
        self.assert_fails(self.release("prepare", "1.0.0", "--summary", "x", "--no-test"), "not newer than")
        self.assert_fails(self.release("prepare", "banana", "--no-test"), "Not a semantic version")
        self.write("VERSION", "dirty\n")
        self.assert_fails(self.release("prepare", "1.0.1", "--summary", "x", "--no-test"), "not clean")
        self.git("checkout", "--", "VERSION")
        changelog = self.read("CHANGELOG.md").replace("### Added\n- A feature.\n", "")
        self.write("CHANGELOG.md", changelog)
        self.git("commit", "-qam", "empty unreleased")
        self.assert_fails(self.release("prepare", "1.0.1", "--summary", "x", "--no-test"), "no entries")

    def test_check_detects_drift(self):
        (self.tmp / "docs.md").write_text("Pull chembience/core-rdkit:1.0.0-pre1 here.\n", encoding="utf-8")
        self.git("add", "docs.md")
        self.assert_fails(self.release("check"), "docs.md:1: mentions released version 1.0.0")
        self.git("rm", "-q", "--cached", "docs.md")

        self.write("VERSION", "1.0.9\n")
        self.assert_fails(self.release("check"), "appVersion is 1.0.1-pre1, VERSION is 1.0.9")
        self.write("VERSION", "1.0.1-pre1\n")

        readme = self.read("README.md")
        self.write("README.md", readme.replace(f"2026{NB_HYPHEN}01{NB_HYPHEN}02", f"2026{NB_HYPHEN}01{NB_HYPHEN}03"))
        self.assert_fails(self.release("check"), "release 1.0.0 is dated 2026-01-03")


if __name__ == "__main__":
    unittest.main()
