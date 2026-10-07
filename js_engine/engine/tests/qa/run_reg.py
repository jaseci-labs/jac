#!/usr/bin/env python3
"""
Regression runner — same behavior as the historical run_reg.sh.

- Discovers tests under regression/ (same rules as find).
- Optional skip manifest for js_engine (--run-fail / --run-hang / --all).
- --fail-only / --hang-only: run only suites listed in the manifest as fail or hang skips
  (intersected with normal discovery / optional path args).
- --node runs all discovered suites under Node (no skip filter).
- --gc / --nogc: run js_engine with the garbage collector explicitly enabled
  (the engine's default) or disabled (engine --nogc flag). Applied via a
  wrapper executable so shell suites and child processes that invoke
  "$JAC_JS_RUNNER" get the same setting. A/B the two to see GC impact.
- --dry-run: print suite paths that would run (after the same filters); no engine, logs, or tests.
- Parallel execution, progress lines, slow-suite monitor, summary + exit codes.
"""
from __future__ import annotations

import atexit
import fcntl
import json
import os
import resource
import shutil
import subprocess
import sys
import tempfile
import threading
import time
from concurrent.futures import ThreadPoolExecutor, as_completed
from pathlib import Path
from typing import List, Optional, Set, Tuple


def script_dir() -> Path:
    return Path(__file__).resolve().parent


SCRIPT_DIR = script_dir()
REPO_ROOT = SCRIPT_DIR.parent.parent.parent
TESTS_DIR = SCRIPT_DIR.resolve()
LOGS_DIR = REPO_ROOT / "regression_logs"
SKIP_MANIFEST = TESTS_DIR / "skip_manifest.json"

# Must match regression/_harness/regression_case.cjs (printed by __jacDone / finalize).
REGRESSION_TESTCASE_FINISHED = "REGRESSION_TESTCASE_FINISHED"

# /usr/bin/time -f '%M' reports the *per-process* peak RSS (KB) of the wrapped
# child. We prefer it over resource.getrusage(RUSAGE_CHILDREN), whose ru_maxrss is
# the cumulative high-water mark across every child a worker has reaped — that makes
# a light test report the peak of a heavy test that ran earlier on the same worker.
_TIME_BIN = "/usr/bin/time" if os.path.isfile("/usr/bin/time") else None

# Per-suite wall-clock limit (override with JAC_REG_TEST_TIMEOUT_SEC). 0 disables.
DEFAULT_TEST_TIMEOUT_SEC = int(os.environ.get("JAC_REG_TEST_TIMEOUT_SEC", "60"))


def _subprocess_captured_output(value: object) -> str:
    """Normalize TimeoutExpired stdout/stderr to str.

    With text=True, subprocess.run normally returns str, but on timeout Python 3.12
    may still expose captured output as bytes — decoding avoids TypeError in handlers.
    """
    if value is None:
        return ""
    if isinstance(value, bytes):
        return value.decode("utf-8", errors="replace")
    return str(value)


def result_safe_for(abs_path: Path) -> str:
    rel = abs_path.resolve().relative_to(REPO_ROOT)
    return str(rel).replace("/", "__")


def canonicalize_path(target: Path) -> Path:
    if not target.exists():
        print(f"ERROR: path does not exist: {target}", file=sys.stderr)
        raise SystemExit(1)
    return target.resolve()


def resolve_user_path(arg: str) -> Path:
    p = Path(arg)
    if p.exists():
        return canonicalize_path(p)
    cand = REPO_ROOT / arg
    if cand.exists():
        return canonicalize_path(cand)
    print(f"ERROR: path does not exist: {arg}", file=sys.stderr)
    raise SystemExit(1)


def path_under_tests_dir(abs_path: Path) -> bool:
    try:
        abs_path.resolve().relative_to(TESTS_DIR)
        return True
    except ValueError:
        return False


def is_valid_test_file(path: Path) -> bool:
    if not path.is_file():
        return False
    name = path.name
    if name.endswith(".sh"):
        # Library scripts under regression/_harness/ (e.g. regression_case_sh.sh) are sourced, not run.
        return name.startswith("test_")
    if not name.endswith(".js") or name.endswith(".fixture.js"):
        return False
    # Match runnable suites only (exclude module helpers like mod_*.js).
    return name == "test_basic.js" or name.startswith("test_")


def find_tests_under(root: Path) -> List[Path]:
    """Prune _fixtures_node_modules; test_*.js (and test_basic.js), not *.fixture.js; test_*.sh — then sort."""
    root = root.resolve()
    out: List[Path] = []
    for dirpath, dirnames, filenames in os.walk(root):
        if "_fixtures_node_modules" in dirnames:
            dirnames.remove("_fixtures_node_modules")
        for fn in filenames:
            p = Path(dirpath) / fn
            if is_valid_test_file(p):
                out.append(p)
    return sorted(out)


def resolve_ticket_path(ticket: str) -> Path:
    """Map skip_manifest ticket paths to files under engine/tests/qa/issues/."""
    ticket = ticket.strip().replace("\\", "/")
    if ticket.startswith("qa_issues/"):
        return TESTS_DIR / "issues" / ticket[len("qa_issues/") :]
    if ticket.startswith("engine/tests/qa/"):
        return REPO_ROOT / ticket
    return REPO_ROOT / ticket


def read_skip_manifest(manifest: Path) -> Tuple[Set[str], Set[str]]:
    """Return (skip_fail_paths, skip_hang_paths) as manifest path strings (forward slashes)."""
    with manifest.open(encoding="utf-8") as f:
        data = json.load(f)

    skip_fail: Set[str] = set()
    skip_hang: Set[str] = set()
    tests = data.get("tests")
    if not isinstance(tests, list):
        print("ERROR: skip_manifest.json: 'tests' must be an array", file=sys.stderr)
        raise SystemExit(1)

    for i, t in enumerate(tests):
        if not isinstance(t, dict):
            print(f"ERROR: skip_manifest.json: tests[{i}] must be an object", file=sys.stderr)
            raise SystemExit(1)
        p = str(t.get("path", "")).strip()
        typ = str(t.get("skip_type", "")).strip().lower()
        ticket = str(t.get("ticket", "")).strip()
        if typ not in ("fail", "hang"):
            print(
                f"ERROR: skip_manifest.json: tests[{i}].skip_type must be 'fail' or 'hang'",
                file=sys.stderr,
            )
            raise SystemExit(1)
        if not p.startswith("engine/tests/qa/"):
            print(
                f"WARNING: skip_manifest.json: tests[{i}].path should be under engine/tests/qa/: {p!r}",
                file=sys.stderr,
            )
        if typ == "fail":
            skip_fail.add(p)
        else:
            skip_hang.add(p)
        if ticket:
            tp = resolve_ticket_path(ticket)
            if not tp.is_file():
                print(f"WARNING: skip_manifest ticket file missing: {ticket}", file=sys.stderr)

    return skip_fail, skip_hang


def rel_under_script_dir(abs_path: Path) -> str:
    prefix = str(REPO_ROOT.resolve()) + os.sep
    s = str(abs_path.resolve())
    if s.startswith(prefix):
        return s[len(prefix) :].replace(os.sep, "/")
    return s.replace(os.sep, "/")


def apply_skip_manifest(
    paths: List[Path],
    manifest: Path,
    include_fail: bool,
    include_hang: bool,
    stats_out: Path,
) -> List[Path]:
    skip_fail, skip_hang = read_skip_manifest(manifest)
    skipped_fail = 0
    skipped_hang = 0
    kept: List[Path] = []
    paths_in = [p.resolve() for p in paths]

    for abspath in paths_in:
        rel = rel_under_script_dir(abspath)
        if rel in skip_fail and not include_fail:
            skipped_fail += 1
            continue
        if rel in skip_hang and not include_hang:
            skipped_hang += 1
            continue
        kept.append(abspath)

    stats_out.write_text(
        "\n".join(
            [
                f"discovered={len(paths_in)}",
                f"skipped_fail={skipped_fail}",
                f"skipped_hang={skipped_hang}",
                f"kept={len(kept)}",
            ]
        )
        + "\n",
        encoding="utf-8",
    )
    return kept


def _fmt_mem(kb: int) -> str:
    if kb >= 1024 * 1024:
        return f"{kb / 1024 / 1024:.1f}GB"
    if kb >= 1024:
        return f"{kb / 1024:.1f}MB"
    return f"{kb}KB"


def _fmt_time(ms: float) -> str:
    if ms >= 60_000:
        return f"{ms / 60_000:.1f}m"
    if ms >= 1_000:
        return f"{ms / 1000:.2f}s"
    return f"{ms:.0f}ms"


def run_test(
    engine: str,
    f: Path,
    tmpdir: Path,
    script_dir: Path,
    tests_dir: Path,
    logs_dir: Path,
    timeout_sec: int = DEFAULT_TEST_TIMEOUT_SEC,
) -> None:
    name = str(f.resolve().relative_to(script_dir))
    result_file = tmpdir / result_safe_for(f)
    rel = str(f.resolve().relative_to(tests_dir))
    log_file = logs_dir / f"{rel}.log"
    log_file.parent.mkdir(parents=True, exist_ok=True)

    popen_kwargs = {
        "stdin": subprocess.DEVNULL,
        "stdout": subprocess.PIPE,
        "stderr": subprocess.STDOUT,
        "text": True,
        "encoding": "utf-8",
        "errors": "replace",
    }

    base_cmd = ["bash", str(f)] if f.suffix == ".sh" else [engine, str(f)]
    # Measure this child's own peak RSS via /usr/bin/time -f '%M' (KB) written to a
    # temp file, instead of the cumulative RUSAGE_CHILDREN high-water mark.
    mem_file = None
    if _TIME_BIN is not None:
        mem_file = tempfile.mktemp()
        cmd = [_TIME_BIN, "-f", "%M", "-o", mem_file] + base_cmd
    else:
        cmd = base_cmd

    def _read_peak_rss_kb() -> int:
        # Returns the per-process peak RSS (KB) from /usr/bin/time, or falls back to
        # the cumulative RUSAGE_CHILDREN value when /usr/bin/time is unavailable.
        if mem_file is not None:
            try:
                lines = [l.strip() for l in open(mem_file).read().splitlines() if l.strip()]
                # /usr/bin/time may prepend "Command exited with non-zero status N"
                # before the %M value — take the last all-digit line.
                for ln in reversed(lines):
                    if ln.isdigit():
                        return int(ln)
            except OSError:
                pass
            return 0
        return resource.getrusage(resource.RUSAGE_CHILDREN).ru_maxrss

    t0 = time.monotonic()
    try:
        proc = subprocess.Popen(cmd, cwd=str(REPO_ROOT), **popen_kwargs)
        try:
            out, _ = proc.communicate(timeout=timeout_sec if timeout_sec > 0 else None)
        except subprocess.TimeoutExpired:
            proc.kill()
            out = _subprocess_captured_output(proc.communicate()[0])
            elapsed_ms = (time.monotonic() - t0) * 1000
            # peak RSS is not meaningful after a kill; report 0
            out += f"\n[run_reg] killed after {timeout_sec}s wall-clock timeout\n"
            log_file.write_text(out, encoding="utf-8")
            result_file.write_text(
                f"FAIL\t{name}\t{elapsed_ms:.0f}\t0\n"
                f"      reason: timeout_after_{timeout_sec}s\n",
                encoding="utf-8",
            )
            return
        elapsed_ms = (time.monotonic() - t0) * 1000
        peak_rss_kb = _read_peak_rss_kb()
    except OSError as exc:
        elapsed_ms = (time.monotonic() - t0) * 1000
        log_file.write_text(str(exc), encoding="utf-8")
        result_file.write_text(
            f"FAIL\t{name}\t{elapsed_ms:.0f}\t0\n"
            f"      reason: launch_error: {exc}\n",
            encoding="utf-8",
        )
        return
    finally:
        if mem_file is not None:
            try:
                os.unlink(mem_file)
            except OSError:
                pass

    log_file.write_text(out or "", encoding="utf-8")
    exit_code = proc.returncode
    if exit_code is None:
        exit_code = -1
    has_marker = REGRESSION_TESTCASE_FINISHED in (out or "")

    if exit_code == 0 and has_marker:
        result_file.write_text(
            f"PASS\t{name}\t{elapsed_ms:.0f}\t{peak_rss_kb}\n",
            encoding="utf-8",
        )
    else:
        reasons: List[str] = []
        if exit_code != 0:
            reasons.append(f"exit_code={exit_code}")
        if not has_marker:
            reasons.append("missing_completion_marker")
        reason_line = "; ".join(reasons) if reasons else "unknown"
        tail_lines = (out or "").splitlines()[-10:]
        body = f"      reason: {reason_line}\n" + "".join(
            f"      {ln}\n" for ln in tail_lines
        )
        result_file.write_text(
            f"FAIL\t{name}\t{elapsed_ms:.0f}\t{peak_rss_kb}\n{body}",
            encoding="utf-8",
        )


def _flock_append_slow_tsv(lock_path: Path, tsv_path: Path, line: str) -> None:
    lock_path.parent.mkdir(parents=True, exist_ok=True)
    tsv_path.parent.mkdir(parents=True, exist_ok=True)
    with open(lock_path, "a", encoding="utf-8") as lockf:
        fcntl.flock(lockf.fileno(), fcntl.LOCK_EX)
        try:
            with open(tsv_path, "a", encoding="utf-8") as tf:
                tf.write(line)
                if not line.endswith("\n"):
                    tf.write("\n")
                tf.flush()
        finally:
            fcntl.flock(lockf.fileno(), fcntl.LOCK_UN)


def _flock_progress_tick(
    lock_path: Path,
    n_path: Path,
    total: int,
    status: str,
    name: str,
    elapsed_ms: float,
    peak_rss_kb: int,
) -> None:
    with open(lock_path, "a", encoding="utf-8") as lockf:
        fcntl.flock(lockf.fileno(), fcntl.LOCK_EX)
        try:
            n = 0
            if n_path.exists():
                try:
                    n = int(n_path.read_text(encoding="utf-8").strip() or "0")
                except ValueError:
                    n = 0
            n += 1
            n_path.write_text(str(n), encoding="utf-8")
            metrics = f"{_fmt_time(elapsed_ms)}  {_fmt_mem(peak_rss_kb)}"
            print(f"[{n}/{total}] {status}\t{name}  ({metrics})", flush=True)
        finally:
            fcntl.flock(lockf.fileno(), fcntl.LOCK_UN)


def run_test_report_progress(
    engine: str,
    f: Path,
    tmpdir: Path,
    script_dir: Path,
    tests_dir: Path,
    logs_dir: Path,
    reg_total_tests: int,
    progress_lock: Path,
    progress_n: Path,
) -> None:
    key = result_safe_for(f)
    name = str(f.resolve().relative_to(script_dir))
    running_dir = tmpdir / "running"
    running_dir.mkdir(parents=True, exist_ok=True)
    running_file = running_dir / key
    start_ts = int(time.time())
    running_file.write_text(f"{start_ts}\n{name}\n", encoding="utf-8")

    run_test(engine, f, tmpdir, script_dir, tests_dir, logs_dir)

    try:
        running_file.unlink()
    except OSError:
        pass

    result_file = tmpdir / key
    first_line = result_file.read_text(encoding="utf-8").splitlines()[0]
    parts = first_line.split("\t")
    status = parts[0].strip()
    try:
        elapsed_ms = float(parts[2]) if len(parts) > 2 else 0.0
    except ValueError:
        elapsed_ms = 0.0
    try:
        peak_rss_kb = int(parts[3]) if len(parts) > 3 else 0
    except ValueError:
        peak_rss_kb = 0

    if elapsed_ms >= 10_000:
        _flock_append_slow_tsv(
            tmpdir / "slow_ge_10s.lock",
            tmpdir / "slow_ge_10s.tsv",
            f"{name}\t{elapsed_ms:.0f}\n",
        )

    _flock_progress_tick(
        progress_lock, progress_n, reg_total_tests, status, name, elapsed_ms, peak_rss_kb
    )


def slow_monitor_loop(tmpdir: Path, interval: int, stop: threading.Event) -> None:
    running_dir = tmpdir / "running"
    while True:
        if stop.wait(timeout=interval):
            break
        now = int(time.time())
        ts = time.strftime("%H:%M:%S")
        lines: List[Tuple[int, str]] = []
        if running_dir.is_dir():
            for rf in sorted(running_dir.iterdir()):
                if not rf.is_file():
                    continue
                try:
                    parts = rf.read_text(encoding="utf-8").splitlines()
                    started = int(parts[0])
                    nm = parts[1] if len(parts) > 1 else ""
                except (IndexError, ValueError, OSError):
                    continue
                elapsed = now - started
                if elapsed >= interval:
                    lines.append((elapsed, nm))
        if lines:
            print(
                f"[{ts}] Long-running (≥ {interval}s elapsed, still in progress: {len(lines)} suite(s)):",
                file=sys.stderr,
                flush=True,
            )
            for el, nm in lines:
                print(f"  {el}s\t{nm}", file=sys.stderr, flush=True)


def print_slow_wall_clock_block_if_needed(tmpdir: Path, printed: List[bool]) -> None:
    if printed[0]:
        return
    tsv = tmpdir / "slow_ge_10s.tsv"
    if not tsv.is_file() or tsv.stat().st_size == 0:
        return
    rows: List[Tuple[str, float]] = []
    for ln in tsv.read_text(encoding="utf-8").splitlines():
        if not ln.strip():
            continue
        parts = ln.split("\t", 1)
        if len(parts) == 2:
            try:
                rows.append((parts[0], float(parts[1])))
            except ValueError:
                continue
    rows.sort(key=lambda r: r[1], reverse=True)
    print("Suites that ran ≥10s (wall clock, this run):")
    for s_name, s_ms in rows:
        print(f"  {_fmt_time(s_ms)}\t{s_name}")
    print("")
    printed[0] = True


def parse_argv(
    argv: List[str],
) -> Tuple[bool, bool, bool, bool, bool, bool, bool, bool, List[str]]:
    use_node = False
    use_gc = False
    use_no_gc = False
    run_fail = False
    run_hang = False
    run_all = False
    fail_only = False
    hang_only = False
    dry_run = False
    paths: List[str] = []
    i = 1
    while i < len(argv):
        a = argv[i]
        if a == "--node":
            use_node = True
        elif a == "--gc":
            use_gc = True
        elif a == "--nogc" or a == "--no-gc":
            use_no_gc = True
        elif a == "--run-fail":
            run_fail = True
        elif a == "--run-hang":
            run_hang = True
        elif a == "--all":
            run_all = True
        elif a == "--fail-only":
            fail_only = True
        elif a == "--hang-only":
            hang_only = True
        elif a == "--dry-run":
            dry_run = True
        elif a.startswith("--"):
            print(f"ERROR: unknown option: {a}", file=sys.stderr)
            raise SystemExit(1)
        else:
            paths.append(a)
        i += 1
    if run_all:
        run_fail = True
        run_hang = True
    return use_node, use_gc, use_no_gc, run_fail, run_hang, fail_only, hang_only, dry_run, paths


def main() -> int:
    (
        use_node,
        use_gc,
        use_no_gc,
        reg_run_fail,
        reg_run_hang,
        fail_only,
        hang_only,
        dry_run,
        pos_args,
    ) = parse_argv(sys.argv)

    if (use_gc or use_no_gc) and use_node:
        print(
            "ERROR: --gc/--nogc only apply to the js_engine runner (drop --node)",
            file=sys.stderr,
        )
        return 1

    if fail_only and hang_only:
        print(
            "ERROR: --fail-only and --hang-only are mutually exclusive",
            file=sys.stderr,
        )
        return 1
    if (fail_only or hang_only) and (reg_run_fail or reg_run_hang):
        print(
            "ERROR: --fail-only / --hang-only cannot be combined with "
            "--run-fail, --run-hang, or --all",
            file=sys.stderr,
        )
        return 1

    if not pos_args:
        test_files = find_tests_under(TESTS_DIR)
    else:
        collected: List[Path] = []
        for arg in pos_args:
            abs_p = resolve_user_path(arg)
            if not path_under_tests_dir(abs_p):
                print(
                    f"ERROR: path must be under engine/tests/qa ({TESTS_DIR}): {arg}",
                    file=sys.stderr,
                )
                return 1
            if abs_p.is_dir():
                collected.extend(find_tests_under(abs_p))
            elif abs_p.is_file():
                if not is_valid_test_file(abs_p):
                    print(
                        "ERROR: not a runnable regression test "
                        "(test_*.js, test_basic.js, or test_*.sh): "
                        f"{arg}",
                        file=sys.stderr,
                    )
                    return 1
                collected.append(abs_p)
            else:
                print(f"ERROR: not a file or directory: {arg}", file=sys.stderr)
                return 1
        test_files = sorted(set(collected))

    reg_discovered = len(test_files)

    if fail_only or hang_only:
        if not SKIP_MANIFEST.is_file():
            print(f"ERROR: skip manifest not found: {SKIP_MANIFEST}", file=sys.stderr)
            return 1
        skip_fail, skip_hang = read_skip_manifest(SKIP_MANIFEST)
        want = skip_fail if fail_only else skip_hang
        mode = "--fail-only" if fail_only else "--hang-only"
        kind = "fail" if fail_only else "hang"
        matched = [p for p in test_files if rel_under_script_dir(p) in want]
        test_files = sorted(set(matched))
        print(f"Skip manifest: {SKIP_MANIFEST}", flush=True)
        print(
            f"  {mode}: running suites with skip_type={kind!r} that appear in "
            "the current discovery/path filter.",
            flush=True,
        )
        print(f"  Discovered suites:     {reg_discovered}", flush=True)
        print(f"  Manifest ({kind}) paths: {len(want)}", flush=True)
        print(f"  Intersection (to run): {len(test_files)}", flush=True)
        print("", flush=True)
    elif use_node:
        print("Skip manifest: not applied (--node runs all discovered suites under Node).")
        print("")
    else:
        if not SKIP_MANIFEST.is_file():
            print(f"ERROR: skip manifest not found: {SKIP_MANIFEST}", file=sys.stderr)
            return 1
        stats: dict[str, str] = {}
        fd, stats_path = tempfile.mkstemp(prefix="run_reg_skip_", suffix=".txt", text=True)
        os.close(fd)
        statsf = Path(stats_path)
        try:
            test_files = apply_skip_manifest(
                test_files,
                SKIP_MANIFEST,
                reg_run_fail,
                reg_run_hang,
                statsf,
            )
            for ln in statsf.read_text(encoding="utf-8").splitlines():
                if "=" in ln:
                    k, v = ln.split("=", 1)
                    stats[k] = v
        finally:
            statsf.unlink(missing_ok=True)
        print(f"Skip manifest: {SKIP_MANIFEST}", flush=True)
        print(f"  Discovered suites: {stats.get('discovered', '?')}", flush=True)
        print(
            f"  Skipped (fail):    {stats.get('skipped_fail', '0')}  "
            "(include with --run-fail or --all)",
            flush=True,
        )
        print(
            f"  Skipped (hang):    {stats.get('skipped_hang', '0')}  "
            "(include with --run-hang or --all)",
            flush=True,
        )
        print(f"  Running now:       {stats.get('kept', '?')}", flush=True)
        print("", flush=True)

    if not test_files:
        if fail_only or hang_only:
            print(
                "No suites to run: discovery/path filter did not match any manifest "
                f"{'fail' if fail_only else 'hang'} skips.",
                file=sys.stderr,
            )
            return 0
        if not use_node and reg_discovered > 0:
            print(
                f"All {reg_discovered} discovered suite(s) were skipped by the manifest.",
                file=sys.stderr,
            )
            print(
                "Use --run-fail, --run-hang, or --all to include skipped suites, "
                "or narrow path arguments.",
                file=sys.stderr,
            )
            return 0
        if not pos_args:
            print(f"No test files found in {TESTS_DIR}")
        else:
            print("No test files matched the given path(s)", file=sys.stderr)
        return 0

    if dry_run:
        runner_label = "node" if use_node else ("js_engine --gc" if use_gc else ("js_engine --nogc" if use_no_gc else "js_engine"))
        print(
            f"Dry-run (--dry-run): {len(test_files)} suite(s) would run "
            f"(runner: {runner_label}). No tests executed."
        )
        print("")
        for f in test_files:
            name = str(f.resolve().relative_to(REPO_ROOT)).replace(os.sep, "/")
            print(name)
        return 0

    if use_node:
        engine = shutil.which("node")
        if not engine:
            print("ERROR: node not found in PATH (install Node.js or drop --node)", file=sys.stderr)
            return 1
    else:
        engine = str(REPO_ROOT / "bin" / "js_engine")
        if not os.access(engine, os.X_OK):
            print(
                f"ERROR: engine not found at {engine}  (run 'make all' first)",
                file=sys.stderr,
            )
            return 1

    if use_gc or use_no_gc:
        # Shell suites exec "$JAC_JS_RUNNER" as a single quoted path (no
        # word-splitting), so the flag must be baked into a wrapper
        # executable. Keep the basename "js_engine" — harness scripts branch
        # on `basename "$JAC_JS_RUNNER"` to detect node vs engine.
        gc_flag = "--gc" if use_gc else "--nogc"
        gc_wrap_dir = Path(tempfile.mkdtemp(prefix="run_reg_gc_"))
        atexit.register(shutil.rmtree, gc_wrap_dir, ignore_errors=True)
        gc_wrapper = gc_wrap_dir / "js_engine"
        gc_wrapper.write_text(
            f'#!/bin/sh\nexec "{engine}" {gc_flag} "$@"\n', encoding="utf-8"
        )
        gc_wrapper.chmod(0o755)
        engine = str(gc_wrapper)

    os.environ["JAC_JS_RUNNER"] = engine
    os.environ["JAC_ENGINE_ROOT"] = str(REPO_ROOT)
    lib_dir = str(REPO_ROOT / "lib")
    llhttp_lib = str(REPO_ROOT / "lib" / "llhttp" / "lib")
    ld_path = os.environ.get("LD_LIBRARY_PATH", "")
    os.environ["LD_LIBRARY_PATH"] = f"{lib_dir}:{llhttp_lib}:{ld_path}" if ld_path else f"{lib_dir}:{llhttp_lib}"

    if LOGS_DIR.exists():
        shutil.rmtree(LOGS_DIR)

    jobs = os.cpu_count() or 1

    tmpdir = Path(tempfile.mkdtemp())
    stop_monitor = threading.Event()
    monitor_thread: Optional[threading.Thread] = None

    def cleanup() -> None:
        stop_monitor.set()
        if monitor_thread is not None and monitor_thread.is_alive():
            monitor_thread.join(timeout=2)
        shutil.rmtree(tmpdir, ignore_errors=True)

    atexit.register(cleanup)

    runner_label = "node" if use_node else ("js_engine --gc" if use_gc else "js_engine")
    print(f"Running {len(test_files)} test(s) in parallel (jobs: {jobs}, runner: {runner_label}) ...")
    print("")

    progress_lock = tmpdir / ".reg_progress.lock"
    progress_n = tmpdir / ".reg_progress_n"
    progress_lock.write_text("", encoding="utf-8")
    progress_n.write_text("0", encoding="utf-8")
    (tmpdir / "slow_ge_10s.tsv").write_text("", encoding="utf-8")
    (tmpdir / "slow_ge_10s.lock").write_text("", encoding="utf-8")

    reg_total_tests = len(test_files)

    print("Progress (one line per suite as it finishes; order reflects parallelism):")
    print("")

    (tmpdir / "running").mkdir(parents=True, exist_ok=True)
    stop_monitor.clear()
    monitor_thread = threading.Thread(
        target=slow_monitor_loop,
        args=(tmpdir, 10, stop_monitor),
        daemon=True,
    )
    monitor_thread.start()

    def one_task(fpath: Path) -> None:
        run_test_report_progress(
            engine,
            fpath,
            tmpdir,
            REPO_ROOT,
            TESTS_DIR,
            LOGS_DIR,
            reg_total_tests,
            progress_lock,
            progress_n,
        )

    with ThreadPoolExecutor(max_workers=jobs) as ex:
        futs = [ex.submit(one_task, f) for f in test_files]
        for fut in as_completed(futs):
            fut.result()

    stop_monitor.set()
    if monitor_thread is not None:
        monitor_thread.join(timeout=2)

    print("")
    print("Summary (pass/fail listing and totals follow):")
    print("")

    total = 0
    total_passed = 0
    total_failed = 0
    suite_failures: List[str] = []
    need_failure_section_close = False
    slow_printed = [False]

    for f in test_files:
        name = str(f.resolve().relative_to(REPO_ROOT))
        result_file = tmpdir / result_safe_for(f)
        if not result_file.is_file():
            continue
        total += 1
        lines = result_file.read_text(encoding="utf-8").splitlines()
        parts = lines[0].split("\t") if lines else [""]
        status = parts[0].strip()
        try:
            elapsed_ms = float(parts[2]) if len(parts) > 2 else 0.0
        except ValueError:
            elapsed_ms = 0.0
        try:
            peak_rss_kb = int(parts[3]) if len(parts) > 3 else 0
        except ValueError:
            peak_rss_kb = 0
        metrics = f"  [{_fmt_time(elapsed_ms)}  {_fmt_mem(peak_rss_kb)}]"

        if status == "PASS":
            if need_failure_section_close:
                print("──────────────────────────────────────────────────")
                need_failure_section_close = False
            total_passed += 1
            print(f"ok    {name}{metrics}")
        else:
            print_slow_wall_clock_block_if_needed(tmpdir, slow_printed)
            print("──────────────────────────────────────────────────")
            total_failed += 1
            suite_failures.append(name)
            print(f"FAIL  {name}{metrics}")
            for ln in lines[1:]:
                print(ln)
            need_failure_section_close = True

    print_slow_wall_clock_block_if_needed(tmpdir, slow_printed)

    if need_failure_section_close:
        print("──────────────────────────────────────────────────")

    print("")
    print("══════════════════════════════════════════════════")
    print(f"  Suites: {total} total  |  {total_passed} passed  |  {total_failed} failed")
    print(f"  (parallelism: {jobs}, runner: {runner_label})")
    print("══════════════════════════════════════════════════")

    if suite_failures:
        print("")
        print("Failed suites:")
        for s in suite_failures:
            print(f"  • {s}")
        return 1
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except KeyboardInterrupt:
        print("\nInterrupted.", file=sys.stderr)
        raise SystemExit(130)
