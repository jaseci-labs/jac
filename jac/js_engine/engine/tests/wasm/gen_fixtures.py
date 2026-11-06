#!/usr/bin/env python3
"""Compile the pinned WebAssembly spec testsuite into wast2json fixture dirs.

    python3 gen_fixtures.py <spec checkout> <out dir> <wast2json binary>

Produces <out>/<suite>/<suite>.json (plus the module binaries wast2json
writes beside it) for every top-level .wast in the testsuite, minus the
exclusions below, mirroring the corpus the reference fixtures were pinned
against. spec_cmds.py flattens the result into the line format the native
spec driver reads; CI regenerates the corpus on every wasm-spec run so no
binary fixture is vendored in this repo.
"""
import os
import subprocess
import sys

# Informational: the testsuite snapshot the corpus is pinned to.
SPEC_COMMIT = "6aacfd8929504d8e02a5144a14d184196ede6790"

# skip-stack-guard-page is a stack-depth stress for the host, not an
# interpreter signal; the pinned corpus excludes it too.
EXCLUDE = {"skip-stack-guard-page"}


def main():
    src, out, wast2json = sys.argv[1], sys.argv[2], sys.argv[3]
    os.makedirs(out, exist_ok=True)
    wasts = sorted(f for f in os.listdir(src) if f.endswith(".wast"))
    suites = [f[:-5] for f in wasts if f[:-5] not in EXCLUDE]
    failed = []
    for suite in suites:
        dest = os.path.join(out, suite)
        os.makedirs(dest, exist_ok=True)
        r = subprocess.run(
            [wast2json, os.path.join(src, suite + ".wast"), "-o", os.path.join(dest, suite + ".json")],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )
        if r.returncode != 0:
            failed.append(suite)
    if failed:
        print("wast2json failed for: " + " ".join(sorted(failed)), file=sys.stderr)
        sys.exit(1)
    print("generated %d suites into %s" % (len(suites), out))


if __name__ == "__main__":
    main()
