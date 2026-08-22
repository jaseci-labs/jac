#!/usr/bin/env python3
"""T7 na-clean compile gate (local).

Each cliff fixture must nacompile through capability-check + IR-gen + object-emit
with no E5090 and no ICE. The final static-musl link is expected to fail locally
(env, not code) -- reaching "Object code emitted" is the pass condition here.
Runtime-correctness legs (musl link + run, diffed against na_cliffs_ref.jac)
are NOT wired into CI yet; see README.md "Two gates".

Python shim (not Jac): the na compiler is driven as a subprocess, which the Jac
runtime does not host. Run from anywhere:

    JACPY=.venv/bin/python python jac-py/tests/na_cliffs/t7_gate.py
"""
import glob
import os
import re
import subprocess
import sys


def _repo_root() -> str:
    out = subprocess.run(
        ["git", "rev-parse", "--show-toplevel"],
        capture_output=True, text=True, check=True,
    )
    return out.stdout.strip()


def _nacompile(py: str, src: str, obj: str) -> str:
    env = dict(os.environ, PYTHONPATH="jac")
    proc = subprocess.run(
        [py, "-m", "jaclang", "nacompile", src, "-o", obj],
        capture_output=True, text=True, env=env,
    )
    return proc.stdout + proc.stderr


def main() -> int:
    os.chdir(_repo_root())
    py = os.environ.get("JACPY", ".venv/bin/python")
    ice = re.compile(r"Traceback|Assertion|Internal error|panic", re.IGNORECASE)
    fail = 0

    for src in sorted(glob.glob("jac-py/tests/na_cliffs/cliff_*.na.jac")):
        out = _nacompile(py, src, f"/tmp/t7_{os.path.basename(src)}.o")
        if "E5090" in out:
            print(f"FAIL (E5090 native-incompatible): {src}"); fail = 1
        elif ice.search(out):
            print(f"FAIL (compiler ICE): {src}"); fail = 1
        elif "Object code emitted" in out:
            print(f"PASS (object emitted): {src}")
        else:
            print(f"UNKNOWN (no object emit, no E5090 -- inspect): {src}"); fail = 1

    # Leaf check: the whole na-clean object core (objects.jac) must nacompile.
    # Compiled self-contained (its own defs + an entry) so na's multi-module import
    # resolution -- a separate maturity gap -- does not mask the leaf's own status.
    leaf = "jac-py/jacpython/objects.jac"
    if os.path.isfile(leaf):
        tmp = "/tmp/t7_objects_selfcontained.na.jac"
        entry = (
            "\n\nwith entry {\n"
            '    a: PyInt = PyInt(t="int", val=2);\n'
            '    print(expect_int(a.nb_binop(0, PyInt(t="int", val=3))));\n'
            "}\n"
        )
        with open(leaf) as fh:
            body = fh.read()
        with open(tmp, "w") as fh:
            fh.write(body + entry)
        out = _nacompile(py, tmp, "/tmp/t7_objects.o")
        if "E5090" in out:
            print(f"FAIL (leaf not na-clean, E5090): {leaf}"); fail = 1
        elif "Object code emitted" in out:
            print(f"PASS (leaf na-clean, object emitted): {leaf}")
        else:
            print(f"UNKNOWN (leaf -- inspect): {leaf}"); fail = 1

    return fail


if __name__ == "__main__":
    sys.exit(main())
