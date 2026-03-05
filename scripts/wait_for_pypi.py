"""Wait for packages to appear on PyPI before publishing dependent packages.

PyPI has propagation delay after upload. This script polls until packages
are available, ensuring dependent packages (e.g., byllm requiring jaclang>=1.2.4)
can be installed during their own publish step.

Used between tier publishes in the release workflow.
"""

from __future__ import annotations

import argparse
import json
import sys
import time

from release_utils import check_pypi

DEFAULT_TIMEOUT = 300  # 5 minutes
DEFAULT_INTERVAL = 10  # seconds


def wait_for_packages(packages: list[tuple[str, str]]) -> bool:
    """Poll PyPI until all specified packages are available.

    Checks every 10 seconds for up to 5 minutes. Returns True if all packages
    become available, False on timeout.
    """
    if not packages:
        return True

    print(f"Waiting for {len(packages)} package(s) on PyPI...")
    for name, ver in packages:
        print(f"  - {name} {ver}")

    start = time.time()
    pending = set(packages)
    attempt = 0

    while pending and (time.time() - start) < DEFAULT_TIMEOUT:
        attempt += 1
        print(f"\nAttempt {attempt}...")

        still_pending = set()
        for name, ver in pending:
            if check_pypi(name, ver):
                print(f"  {name} {ver} is available!")
            else:
                print(f"  {name} {ver} not yet available")
                still_pending.add((name, ver))

        pending = still_pending
        if pending:
            time.sleep(DEFAULT_INTERVAL)

    if pending:
        print(f"\nTimeout. Still waiting for: {pending}")
        return False

    print("\nAll packages available!")
    return True


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--matrix", required=True, help="JSON matrix from GitHub Actions"
    )
    parser.add_argument(
        "--tier", type=int, required=True, help="Only wait for this tier"
    )
    args = parser.parse_args()

    # Matrix format: {"include": [{"pypi": "jaclang", "version": "1.2.4", "tier": 1}, ...]}
    matrix = json.loads(args.matrix)
    packages = [
        (item["pypi"], item["version"])
        for item in matrix.get("include", [])
        if item.get("tier") == args.tier
    ]

    if not packages:
        print(f"No tier {args.tier} packages to wait for")
        return 0

    return 0 if wait_for_packages(packages) else 1


if __name__ == "__main__":
    sys.exit(main())
