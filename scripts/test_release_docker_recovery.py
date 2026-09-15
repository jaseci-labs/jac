"""Regression tests for recovering a release without rebuilding its binaries."""

import json
import subprocess
import unittest
from unittest.mock import patch

import release_docker_recovery as recovery


class RecoveryTests(unittest.TestCase):
    def setUp(self):
        self.tag = "v0.37.15"
        self.commit = "a" * 40
        self.platforms = ["linux-x86_64", "linux-aarch64", "macos-aarch64"]
        self.run = {
            "path": ".github/workflows/release.yml",
            "status": "completed",
            "run_attempt": 2,
        }
        names = ["resolve", "approve", "tag-and-release", "build-binaries / plan",
                 "build-binaries / admin-dist"]
        names += [f"build-binaries / {platform}" for platform in self.platforms]
        self.jobs = [{"id": i, "name": name, "conclusion": "success"}
                     for i, name in enumerate(names)]
        self.jobs.append({"id": 99, "name": "build-binaries / docker-image",
                          "conclusion": "failure"})
        self.log = "\n".join(f"2026-09-15T03:05:54.8042564Z {line}" for line in [
            f"  tag: {self.tag}", f"  commit: {self.commit}", "  channel: release",
            "  only: ", "Required to publish: " + " ".join(self.platforms),
        ])
        names = [f"jac-0.37.15-{platform}" for platform in self.platforms]
        names.append("jac-0.37.15-admin-dist.tar.gz")
        self.assets = [{"name": name} for asset in names
                       for name in (asset, asset + ".sha256")]

    def gh(self, *args):
        if args[0] == "release":
            return json.dumps({"assets": self.assets})
        if args[-1].endswith("/logs"):
            return self.log
        if "/commits/" in args[-1]:
            return json.dumps({"sha": self.commit})
        if "/jobs?" in args[-1]:
            # Exercise pagination and the pinned original attempt.
            self.assertIn("/attempts/2/jobs?", args[-1])
            return json.dumps([{"jobs": self.jobs[:4]}, {"jobs": self.jobs[4:]}])
        return json.dumps(self.run)

    def verify(self, tag=None, run_id="123"):
        with patch.dict("os.environ", {"GH_REPO": "jaseci-labs/jac"}), \
                patch.object(recovery, "gh", side_effect=self.gh):
            return recovery.verify(tag or self.tag, run_id)

    def test_complete_release_with_only_docker_failed(self):
        self.assertEqual(self.verify(), self.platforms)

    def test_every_binary_admin_asset_and_checksum_is_required(self):
        original = self.assets[:]
        for asset in original:
            with self.subTest(missing=asset["name"]):
                self.assets = [item for item in original if item != asset]
                with self.assertRaisesRegex(ValueError, "assets are missing"):
                    self.verify()

    def test_approval_and_required_jobs_must_succeed(self):
        for job in self.jobs[:-1]:
            with self.subTest(job=job["name"]):
                job["conclusion"] = "failure"
                with self.assertRaisesRegex(ValueError, "did not succeed"):
                    self.verify()
                job["conclusion"] = "success"

    def test_wrong_or_filtered_plan_and_moved_tag_are_rejected(self):
        original = self.log
        for before, after in [
            (self.tag, "v0.37.14"), (self.commit, "b" * 40),
            ("channel: release", "channel: dev"), ("only: ", "only: linux-x86_64"),
            ("Required to publish:", "Missing output:"),
            (" ".join(self.platforms), "(none)"),
        ]:
            with self.subTest(change=after):
                self.log = original.replace(before, after)
                with self.assertRaises(ValueError):
                    self.verify()

    def test_wrong_or_incomplete_workflow_is_rejected(self):
        for key, value in [("path", ".github/workflows/ci.yml"),
                           ("status", "in_progress")]:
            with self.subTest(field=key), patch.dict(self.run, {key: value}):
                with self.assertRaisesRegex(ValueError, "completed run"):
                    self.verify()

    def test_invalid_inputs(self):
        for tag, run_id in [("dev", "123"), ("v0.37.15", ""),
                            ("v0.37.15", "linux-x86_64")]:
            with self.subTest(tag=tag, run_id=run_id), self.assertRaises(ValueError):
                self.verify(tag, run_id)

    def test_expired_logs_refuse_recovery(self):
        original = self.gh

        def expired(*args):
            if args[-1].endswith("/logs"):
                raise subprocess.CalledProcessError(1, "gh")
            return original(*args)

        self.gh = expired
        with self.assertRaises(subprocess.CalledProcessError):
            self.verify()


if __name__ == "__main__":
    unittest.main()
