"""Wait for packages to appear on PyPI before publishing dependent packages.

Used between publish tiers because dependent packages (e.g., byllm) require
their dependencies (e.g., jaclang>=1.2.4) to be live on PyPI first.
"""

from __future__ import annotations

import argparse
import json
import sys
import time
import urllib.error
import urllib.request

DEFAULT_TIMEOUT = 300  # 5 minutes
DEFAULT_INTERVAL = 10  # seconds


def check_pypi(pypi_name: str, version: str) -> bool:
    url = f"https://pypi.org/pypi/{pypi_name}/{version}/json"
    try:
        urllib.request.urlopen(url, timeout=10)
        return True
    except (urllib.error.HTTPError, urllib.error.URLError):
        return False


def wait_for_packages(packages: list[tuple[str, str]]) -> bool:
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
    parser.add_argument("--matrix", required=True, help="JSON matrix from GitHub Actions")
    parser.add_argument("--tier", type=int, required=True, help="Only wait for this tier")
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
