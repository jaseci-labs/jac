"""Verify an otherwise-complete release and print its original required platforms.

Read-only: the caller publishes with release_publish_guard.sh after Docker passes.
Missing/expired plan logs refuse publication rather than guessing a platform list.
"""

import json
import os
import re
import subprocess
import sys


def gh(*args: str):
    """Read GitHub data without printing credentials or downloaded logs."""
    return subprocess.check_output(["gh", *args], text=True)


def verify(tag: str, run_id: str) -> list[str]:
    """Require the original approval, build results, plan, and complete assets."""
    if not re.fullmatch(r"v[0-9]+\.[0-9]+\.[0-9]+", tag):
        raise ValueError("Draft recovery requires a canonical versioned tag.")
    if not re.fullmatch(r"[1-9][0-9]*", run_id):
        raise ValueError("Draft recovery requires the original Release run ID.")
    repo = os.environ["GH_REPO"]
    endpoint = f"repos/{repo}/actions/runs/{run_id}"
    run = json.loads(gh("api", endpoint))
    if run["path"] != ".github/workflows/release.yml" or run["status"] != "completed":
        raise ValueError("Expected a completed run of release.yml.")
    # Pin the attempt: a concurrent rerun must not mix jobs from two attempts.
    pages = json.loads(gh("api", "--paginate", "--slurp", f"{endpoint}/attempts/{run['run_attempt']}/jobs?per_page=100"))
    jobs = [job for page in pages for job in page["jobs"]]

    def successful_job(name: str) -> dict:
        matches = [job for job in jobs if job["name"] == name]
        if len(matches) != 1 or matches[0]["conclusion"] != "success":
            raise ValueError(f"Original release job did not succeed: {name}")
        return matches[0]

    for name in ("resolve", "approve", "tag-and-release", "build-binaries / admin-dist"):
        successful_job(name)
    plan = successful_job("build-binaries / plan")
    log = gh("api", f"repos/{repo}/actions/jobs/{plan['id']}/logs")
    # The raw job log has one timestamp followed by the runner's output.
    lines = [line.partition(" ")[2].strip() for line in log.splitlines()]

    def plan_value(prefix: str) -> str:
        values = [line[len(prefix):].strip() for line in lines if line.startswith(prefix)]
        if len(values) != 1:
            raise ValueError(f"Could not identify the original plan's {prefix}")
        return values[0]

    if plan_value("tag:") != tag or plan_value("channel:") != "release" or plan_value("only:"):
        raise ValueError("Original plan is not an unfiltered release of the selected tag.")
    commit = json.loads(gh("api", f"repos/{repo}/commits/{tag}"))["sha"]
    if plan_value("commit:") != commit:
        raise ValueError("Release tag no longer matches the original approved build commit.")
    required = plan_value("Required to publish:").split()
    if not required or len(set(required)) != len(required) or any(
        not re.fullmatch(r"[a-z0-9]+(?:[-_][a-z0-9]+)*", platform) for platform in required
    ):
        raise ValueError("Original plan has no valid required-platform list.")
    for platform in required:
        successful_job(f"build-binaries / {platform}")
    release = json.loads(gh("release", "view", tag, "--json", "assets"))
    assets = {asset["name"] for asset in release["assets"]}
    expected = [f"jac-{tag[1:]}-{platform}" for platform in required]
    expected.append(f"jac-{tag[1:]}-admin-dist.tar.gz")
    missing = sorted({name for asset in expected for name in (asset, f"{asset}.sha256")} - assets)
    if missing:
        raise ValueError(f"Release assets are missing: {', '.join(missing)}")
    return required


if __name__ == "__main__":
    try:
        if len(sys.argv) != 3:
            raise ValueError("Usage: release_docker_recovery.py <tag> <original-release-run-id>")
        print(" ".join(verify(sys.argv[1], sys.argv[2])))
    except (ValueError, KeyError, subprocess.CalledProcessError) as error:
        sys.exit(f"::error::{error}")
