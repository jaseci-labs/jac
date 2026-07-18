"""Golden-render regression test for the native ai_tui_na screen_render.

Self-contained harness: builds (if stale) and runs the dev-only selftest
binary (bin/selftest_render), then diffs every rendered frame against a
byte-exact golden baseline under tests/golden/tui_render/. This is the safety
net for Plan 01 Phase 1 (component extraction): after the refactor,
Screen.render must produce byte-identical output to the pre-refactor
screen_render captured here.

Requires the native toolchain (jac nacompile + the libjacpyembed shim staged
by `zig build`); skipped when the shim is absent so this never fails on
Python-only CI.

To refresh the baseline after an intentional render change, run:
    GOLDEN_UPDATE=1 pytest jac/tests/cli/test_tui_render_golden.jac
"""

import os;
import sys;
import subprocess;
import difflib;
import pytest;
import jaclang.cli.ai_tui.tui_shared as tui_shared;
import from pathlib { Path }


def _repo_root(cli_dir: Path) -> Path {
    # cli_dir = .../jaclang/cli ; repo root is three parents up.
    return cli_dir.parent.parent.parent;
}


def _golden_dir(repo_root: Path) -> Path {
    return repo_root / "jac" / "tests" / "golden" / "tui_render";
}


def _shim_path(repo_root: Path) -> Path {
    shim_dir = (
        repo_root / "jac" / "jaclang" / "runtimelib" / "client" / "targets" / "desktop" / "native"
    );
    name = "libjacpyembed.dylib" if sys.platform == "darwin" else "libjacpyembed.so";
    return shim_dir / name;
}


def _iter_na_sources(na_dir: Path) -> list {
    # Top-level plus Phase 5 nested tui/ and components/ trees.
    out = [];
    for f in os.listdir(na_dir) {
        if f.endswith(".na.jac") {
            out.append(na_dir / f);
        }
    }
    for sub in ("tui", "components") {
        d = na_dir / sub;
        if d.is_dir() {
            for f in os.listdir(d) {
                if f.endswith(".na.jac") {
                    out.append(d / f);
                }
            }
        }
    }
    return out;
}


def _binary_stale(na_dir: Path) -> bool {
    # Rebuild if the binary is missing or any closure source (.na.jac) is newer.
    # Over-rebuilding is safe (the test fails closed on a stale artifact); the
    # nacompile is ~2s.
    binary = na_dir / "bin" / "selftest_render";
    if not binary.is_file() {
        return True;
    }
    bin_mtime = binary.stat().st_mtime;
    for path in _iter_na_sources(na_dir) {
        if path.stat().st_mtime > bin_mtime {
            return True;
        }
    }
    return False;
}


def _ensure_binary(na_dir: Path) {
    if _binary_stale(na_dir) {
        sys.stderr.write("==> selftest binary stale/missing; building ...\n");
        subprocess.run(["bash", str(na_dir / "build_selftest.sh")], check=True);
    }
}


def _run_binary(na_dir: Path) -> bytes {
    proc = subprocess.run(
        [str(na_dir / "bin" / "selftest_render")], capture_output=True, check=True
    );
    return proc.stdout;
}


def _parse_frames(data: bytes) -> dict[str, bytes] {
    # Split the framed stream into {label: frame_bytes}. frame_bytes is the
    # rendered rows joined with b'\n' plus a trailing b'\n' -- exactly the bytes
    # between the header and the END marker, suitable for a golden file.
    frames: dict[str, bytes] = {};
    label: str = "";
    rows: list[bytes] = [];
    in_frame: bool = False;
    for line in data.split(b"\n") {
        if line.startswith(b"===FIXTURE===") and line.endswith(b"===") {
            label = line.split(b"===")[2].decode();
            rows = [];
            in_frame = True;
        } elif line == b"===END===" {
            if in_frame {
                frames[label] = b"\n".join(rows) + b"\n";
            }
            in_frame = False;
        } elif in_frame {
            rows.append(line);
        }
    }
    return frames;
}


def _load_golden(golden_dir: Path) -> dict[str, bytes] {
    if not golden_dir.is_dir() {
        return {};
    }
    return {p.stem: p.read_bytes() for p in golden_dir.glob("*.txt")};
}


def _write_golden(frames: dict[str, bytes], golden_dir: Path) {
    golden_dir.mkdir(parents=True, exist_ok=True);
    keep: set[str] = set(frames);
    for gf in golden_dir.glob("*.txt") {
        if gf.stem not in keep {
            gf.unlink();
            print(f"   - pruned orphaned golden: {gf.name}");
        }
    }
    for label in sorted(frames) {
        (golden_dir / f"{label}.txt").write_bytes(frames[label]);
        print(f"   + {label}.txt ({len(frames[label])} bytes)");
    }
}


def _verify(frames: dict[str, bytes], golden: dict[str, bytes]) -> list[str] {
    failures: list[str] = [];
    out_labels: set[str] = set(frames);
    gold_labels: set[str] = set(golden);
    for label in sorted(out_labels | gold_labels) {
        if label not in golden {
            failures.append(f"{label}: no golden file (run with GOLDEN_UPDATE=1)");
            continue;
        }
        if label not in frames {
            failures.append(
                f"{label}: golden exists but harness emitted no such frame "
                "(fixture removed?)"
            );
            continue;
        }
        if frames[label] != golden[label] {
            got: list[str] = frames[label].decode(
                "utf-8", errors="replace"
            ).splitlines();
            exp: list[str] = golden[label].decode(
                "utf-8", errors="replace"
            ).splitlines();
            diff: str = "\n".join(
                difflib.unified_diff(
                    exp,
                    got,
                    fromfile=f"{label}.golden",
                    tofile=f"{label}.actual",
                    lineterm="",
                )
            );
            failures.append(f"{label}: byte mismatch\n{diff}");
        }
    }
    return failures;
}


test "native screen_render golden frames match the baseline" {
    cli_dir = Path(tui_shared.__file__).resolve().parent.parent;
    na_dir = cli_dir / "ai_tui_na";
    repo_root = _repo_root(cli_dir);
    golden_dir = _golden_dir(repo_root);

    # Skip on Python-only CI: the build needs jac nacompile + the libjacpyembed
    # shim staged by `zig build`. Its absence means the native toolchain isn't
    # built, so this regression net can't run here.
    shim = _shim_path(repo_root);
    if not shim.is_file() {
        pytest.skip(f"native toolchain shim not built ({shim.name}); run `zig build`");
    }

    _ensure_binary(na_dir);
    frames: dict[str, bytes] = _parse_frames(_run_binary(na_dir));
    assert frames , "golden harness emitted no frames";

    if os.environ.get("GOLDEN_UPDATE") == "1" {
        _write_golden(frames, golden_dir);
        pytest.skip(f"captured {len(frames)} frames -> {golden_dir} (GOLDEN_UPDATE=1)");
    }

    golden: dict[str, bytes] = _load_golden(golden_dir);
    assert golden , (
        f"no golden files in {golden_dir} "
        "(run with GOLDEN_UPDATE=1 to capture the baseline)"
    );
    failures: list[str] = _verify(frames, golden);
    assert not failures , (
        f"{len(failures)} of {len(frames)} golden frame(s) differ:\n\n" + "\n\n".join(
            failures
        )
    );
}
