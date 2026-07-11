#!/usr/bin/env python3
"""Golden-render harness runner for ai_tui_na's screen_render.

Builds (if stale) and runs bin/selftest_render, which imports the REAL
screen_render and dumps framed, byte-exact frames to stdout. With --update,
captures each frame into a golden file; by default, diffs every frame against
its golden and exits nonzero on any mismatch.

Frame wire format (emitted by selftest_render.na.jac):
    ===FIXTURE===<label>===
    <rendered row>
    ...
    ===END===

Golden files live in jac/tests/golden/tui_render/<label>.txt and are stored
byte-exact (ANSI escapes, UTF-8 box chars). Plan 01 Phase 1 re-points the
harness at Screen.render and asserts byte-identical output to the baseline
captured here -- that is the safety net for the extraction refactor.

Usage:
    python3 golden_render.py            # build-if-stale, diff every frame
    python3 golden_render.py --update   # (re)capture the baseline
    python3 golden_render.py --no-build # skip the staleness/rebuild check
"""

# ruff: noqa: T201  -- dev-only harness: stdout is the interface, print is intended.

import difflib
import os
import subprocess
import sys
from pathlib import Path

# ai_tui_na/  ->  parents[0]=cli  [1]=jaclang  [2]=jac  [3]=repo root
HERE = Path(__file__).resolve().parent
REPO = HERE.parents[3]
BINARY = HERE / "bin" / "selftest_render"
SHIM = (
    HERE / "bin" / ("libjacpyembed." + ("dylib" if sys.platform == "darwin" else "so"))
)
BUILD_SH = HERE / "build_selftest.sh"
GOLDEN_DIR = REPO / "jac" / "tests" / "golden" / "tui_render"


def binary_stale() -> bool:
    """Rebuild if the binary/shim is missing or any closure source is newer.

    selftest_render's import closure spans nearly every .na.jac in this dir
    (screen -> overlay/runtime/transport -> jacpyembed; terminal -> libc_tty),
    so checking all of them is correct. Over-rebuilding is safe (the test
    fails closed on a stale artifact); the nacompile is ~2s.
    """
    if not BINARY.exists() or not SHIM.exists():
        return True
    bin_mtime = BINARY.stat().st_mtime
    na_files = [HERE / f for f in os.listdir(HERE) if f.endswith(".na.jac")]
    if not na_files:
        return False
    return max(f.stat().st_mtime for f in na_files) > bin_mtime


def ensure_binary(no_build: bool) -> None:
    if no_build:
        return
    if binary_stale():
        print("==> selftest binary stale/missing; building ...", file=sys.stderr)
        subprocess.run(["bash", str(BUILD_SH)], check=True)


def run_binary() -> bytes:
    proc = subprocess.run([str(BINARY)], capture_output=True, check=True)
    return proc.stdout


def parse_frames(data: bytes) -> dict:
    """Split the framed stream into {label: frame_bytes}.

    frame_bytes is the rendered rows joined with b'\\n' plus a trailing
    b'\\n' -- i.e. exactly the bytes between the header and the END marker,
    suitable for writing straight to a golden file.
    """
    frames = {}
    label = None
    rows = []
    for line in data.split(b"\n"):
        if line.startswith(b"===FIXTURE===") and line.endswith(b"==="):
            parts = line.split(b"===")  # [b'', b'FIXTURE', b'<label>', b'']
            label = parts[2].decode()
            rows = []
        elif line == b"===END===":
            if label is not None:
                frames[label] = b"\n".join(rows) + b"\n"
            label = None
        elif label is not None:
            rows.append(line)
    return frames


def load_golden() -> dict:
    if not GOLDEN_DIR.exists():
        return {}
    return {p.stem: p.read_bytes() for p in GOLDEN_DIR.glob("*.txt")}


def write_golden(frames: dict) -> None:
    GOLDEN_DIR.mkdir(parents=True, exist_ok=True)
    # Refresh every current frame; prune golden files whose fixture was removed.
    keep = set(frames)
    for gf in GOLDEN_DIR.glob("*.txt"):
        if gf.stem not in keep:
            gf.unlink()
            print(f"   - pruned orphaned golden: {gf.name}")
    for label, data in sorted(frames.items()):
        (GOLDEN_DIR / f"{label}.txt").write_bytes(data)
        print(f"   + {label}.txt ({len(data)} bytes)")


def verify(frames: dict, golden: dict) -> list:
    """Return a list of failure messages; empty list means all pass."""
    failures = []
    out_labels = set(frames)
    gold_labels = set(golden)

    for label in sorted(out_labels | gold_labels):
        if label not in golden:
            failures.append(
                f"{label}: no golden file (run `golden_render.py --update`)"
            )
            continue
        if label not in frames:
            failures.append(
                f"{label}: golden exists but harness emitted no such frame "
                f"(fixture removed?)"
            )
            continue
        if frames[label] != golden[label]:
            got = frames[label].decode("utf-8", errors="replace").splitlines()
            exp = golden[label].decode("utf-8", errors="replace").splitlines()
            diff = "\n".join(
                difflib.unified_diff(
                    exp,
                    got,
                    fromfile=f"{label}.golden",
                    tofile=f"{label}.actual",
                    lineterm="",
                )
            )
            failures.append(f"{label}: byte mismatch\n{diff}")
    return failures


def main() -> int:
    update = "--update" in sys.argv
    no_build = "--no-build" in sys.argv

    ensure_binary(no_build)
    data = run_binary()
    frames = parse_frames(data)

    if not frames:
        print("ERROR: harness emitted no frames", file=sys.stderr)
        return 2

    if update:
        print(f"==> Capturing {len(frames)} frames -> {GOLDEN_DIR}")
        write_golden(frames)
        print("==> Baseline captured.")
        return 0

    golden = load_golden()
    if not golden:
        print(
            f"ERROR: no golden files in {GOLDEN_DIR} "
            f"(run `golden_render.py --update` to capture the baseline)",
            file=sys.stderr,
        )
        return 2

    failures = verify(frames, golden)
    if failures:
        print(f"FAIL: {len(failures)} frame(s) differ from golden:\n")
        for f in failures:
            print(f)
            print()
        print(f"({len(frames)} frames checked, {len(failures)} failed)")
        return 1

    print(f"PASS: {len(frames)} frames match golden ({GOLDEN_DIR})")
    return 0


if __name__ == "__main__":
    sys.exit(main())
