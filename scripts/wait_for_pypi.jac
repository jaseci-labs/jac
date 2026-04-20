"""Wait for packages to appear on PyPI before publishing dependent packages.

PyPI has propagation delay after upload. This script polls until packages
are available, ensuring dependent packages (e.g., byllm requiring jaclang>=1.2.4)
can be installed during their own publish step.

Used between tier publishes in the release workflow.
"""
import from __future__ { annotations }
import argparse;
import json;
import sys;
import time;
import from release_utils { check_pypi }
glob DEFAULT_TIMEOUT: int = 600,
     DEFAULT_INTERVAL: int = 30;
"""Wait for all packages of a given tier to appear on PyPI."""
def wait_for_packages(
    packages: list[dict],
    tier: int,
    timeout: int = DEFAULT_TIMEOUT,
    interval: int = DEFAULT_INTERVAL
) -> bool {
    tier_packages = [
        p
        for p in packages
        if (p["tier"] == tier)
    ];
    if not tier_packages {
        print(f"No tier {tier} packages to wait for");
        return True;
    }
    print(f"Waiting for tier {tier} packages on PyPI:");
    for p in tier_packages {
        print(f"  - {p['pypi']} {p['version']}");
    }
    start = time.time();
    pending = {p["pypi"]: p["version"] for p in tier_packages};
    while (pending and ((time.time() - start) < timeout)) {
        for (pypi_name, version) in list(pending.items()) {
            if check_pypi(pypi_name, version) {
                print(f"  Found: {pypi_name} {version}");
                del pending[pypi_name];
            }
        }
        if pending {
            elapsed = int((time.time() - start));
            print(f"  Waiting... ({elapsed}s elapsed, {len(pending)} remaining)");
            time.sleep(interval);
        }
    }
    if pending {
        print("\nTimeout waiting for packages:");
        for (pypi_name, version) in pending.items() {
            print(f"  - {pypi_name} {version}");
        }
        return False;
    }
    print(f"\nAll tier {tier} packages available on PyPI");
    return True;
}
def main() -> int {
    parser = argparse.ArgumentParser();
    parser.add_argument(
        "--matrix", required=True, help="JSON matrix from parse_release"
    );
    parser.add_argument("--tier", `type=int, required=True, help="Tier to wait for");
    parser.add_argument("--timeout", `type=int, `default=DEFAULT_TIMEOUT);
    parser.add_argument("--interval", `type=int, `default=DEFAULT_INTERVAL);
    args = parser.parse_args();
    matrix = json.loads(args.matrix);
    packages = matrix.get("include", []);
    if not wait_for_packages(packages, args.tier, args.timeout, args.interval) {
        return 1;
    }
    return 0;
}
with entry:__main__ {
    sys.exit(main());
}
