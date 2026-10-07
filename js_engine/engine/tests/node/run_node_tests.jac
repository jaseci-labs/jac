"""
run_node_tests.jac — Node.js core test runner for js_engine.

Runs tests from the nodejs/node submodule at engine/tests/node/vendor/
(branch v24.x) against either bin/js_engine or system Node.js.

Usage (from js_engine/ repo root):
    jac run engine/tests/node/run_node_tests.jac [options]
    jac run engine/tests/node/run_node_tests.jac -- --help

See README.md for full documentation.
"""
import argparse;
import fnmatch;
import json;
import os;
import re;
import resource;
import shutil;
import signal;
import subprocess;
import sys;
import tempfile;
import time;
import from concurrent.futures { ThreadPoolExecutor, as_completed }
import from datetime { datetime, timezone }
import from pathlib { Path }

# ---------------------------------------------------------------------------
# Paths
# ---------------------------------------------------------------------------

# This script lives at engine/tests/node/run_node_tests.jac inside js_engine/
glob SCRIPT_DIR = Path(__file__).resolve().parent,
     # js_engine/ repo root (three levels up from this file)
     JS_ENGINE_ROOT = SCRIPT_DIR.parent.parent.parent,
     NODE_ROOT = SCRIPT_DIR / "vendor",
     TEST_ROOT = NODE_ROOT / "test",
     LOG_ROOT = JS_ENGINE_ROOT / "regression_logs" / "node",
     DEFAULT_ENGINE = JS_ENGINE_ROOT / "bin" / "js_engine",
     # Default when neither --suite nor a path/--filter is given. Prefer a focused
     # subset for unfiltered runs; path args and --filter search the whole tree.
     DEFAULT_SUITES = ("parallel", ),
     # Directories under test/ that are helpers / build trees, not runnable suites.
     INFRA_DIRS = frozenset(
         {
             "common",
             "fixtures",
             "tools",
             "testpy",
             "cctest",  # C++ gtest binaries, not JS

         }
     ),
     # Suites that use bare *.js names (no test- prefix), paired with *.out expect files.
     BARE_JS_SUITES = frozenset({"message", "pseudo-tty"}),
     # Result constants
     PASS = "PASS",
     FAIL = "FAIL",
     HANG = "HANG",
     SKIP = "SKIP",
     _TIME_BIN = "/usr/bin/time" if os.path.isfile("/usr/bin/time") else None,
     _DEFAULT_MEM_LIMIT_GB = 1,
     _DEFAULT_TIMEOUT_S = 60.0,
     # Node's common.skip() prints TAP skip lines and exits 0.
     _SKIP_RE = re.compile(
         r"^1\.\.0\s+#\s*Skipped:\s*(.*)$", re.IGNORECASE | re.MULTILINE
     ),
     _FLAGS_RE = re.compile(r"^//\s*Flags:\s+(.+)$", re.MULTILINE),
     _ENV_RE = re.compile(r"^//\s*Env:\s+(.+)$", re.MULTILINE);

# ---------------------------------------------------------------------------
# Metadata
# ---------------------------------------------------------------------------

"""
Parse Node.js test directives from the source head.

Matches test/common/index.js parseTestMetadata():
  // Flags: --expose-internals --no-warnings
  // Env: FOO=bar BAZ=qux
"""
def parse_test_metadata(source: str) -> tuple[list[str], dict[str, str]] {
    flags: list[str] = [];
    envs: dict[str, str] = {};

    # Only scan the first ~2 KB (copyright + directives sit near the top).
    head = source[:2048];

    fm = _FLAGS_RE.search(head);
    if fm {
        flags = [
            tok
            for tok in fm.group(1).strip().split()
            if tok
        ];
    }

    em = _ENV_RE.search(head);
    if em {
        for tok in em.group(1).strip().split() {
            if "=" in tok {
                (k, v) = tok.split("=", 1);
                envs[k] = v;
            }
        }
    }

    return (flags, envs);
}

# ---------------------------------------------------------------------------
# Test discovery
# ---------------------------------------------------------------------------

"""All first-level directories under test/ that can hold runnable tests."""
def list_suites(test_root: Path) -> list[str] {
    suites = [];
    for p in sorted(test_root.iterdir()) {
        if not p.is_dir() or p.name.startswith(".") {
            continue;
        }
        if p.name in INFRA_DIRS {
            continue;
        }
        suites.append(p.name);
    }
    return suites;
}

"""
True for Node core tests.

Standard: test-*.js / test-*.mjs / test-*.cjs (also test_*.*).
message/ and pseudo-tty/: bare *.js (excluding *.out expectations).
force=True: any .js/.mjs/.cjs (used when the user names a file explicitly).
"""
def _is_test_file(p: Path, *, force: bool = False) -> bool {
    name = p.name;
    if not name.endswith((".js", ".mjs", ".cjs")) {
        return False;
    }
    if force {
        return True;
    }
    if name.startswith("test-") or name.startswith("test_") {
        return True;
    }
    # node-api / js-native-api often use test.js / testN.js inside subdirs.
    if name == "test.js" or re.`match(r"^test\d*\.js$", name) {
        return True;
    }
    # Top-level suite that owns this file (first component under test/).
    try {
        suite = p.relative_to(TEST_ROOT).parts[0];
    } except ValueError {
        suite = p.parent.name;
    }
    if suite in BARE_JS_SUITES {
        return True;
    }
    return False;
}

"""
Accept filters relative to test/, repo root, or absolute paths.

Examples that all become `module-hooks/foo.mjs`:
  module-hooks/foo.mjs
  engine/tests/node/vendor/test/module-hooks/foo.mjs
  /abs/.../test/module-hooks/foo.mjs
"""
def _normalize_filter(filter_glob: str) -> str {
    s = filter_glob.strip().replace("\\", "/");
    # Absolute / cwd-relative path into TEST_ROOT
    try {
        cand = Path(s).expanduser();
        if not cand.is_absolute() {
            cand = (Path.cwd() / cand).resolve();
        } else {
            cand = cand.resolve();
        }
        try {
            return str(cand.relative_to(TEST_ROOT.resolve())).replace("\\", "/");
        } except ValueError {}
    } except OSError {}

    prefixes = (
        str(TEST_ROOT.resolve()).replace("\\", "/") + "/",
        "engine/tests/node/vendor/test/",
        "js_engine/engine/tests/node/vendor/test/",
        "node/vendor/test/",
        "vendor/test/",
        # Legacy third_party/ locations, still accepted for back-compat.
        "engine/tests/third_party/node/test/",
        "js_engine/engine/tests/third_party/node/test/",
        "third_party/node/test/",
        "test/",

    );
    for pref in prefixes {
        if s.startswith(pref) {
            return s[len(pref):];
        }
    }
    return s;
}

def _match_filter(rel: str, filter_glob: str) -> bool {
    filt = _normalize_filter(filter_glob);
    is_glob = any(c in filt for c in ("*", "?", "["));
    if is_glob {
        return (
            fnmatch.fnmatch(rel, filt)
            or fnmatch.fnmatch(Path(rel).name, filt)
            or fnmatch.fnmatch(rel, "*/" + filt)
        );
    }
    # Exact path, prefix, or substring (e.g. "test-fs-" or "module-hooks/test-")
    if rel == filt or rel.startswith(filt.rstrip("/") + "/") or filt in rel {
        return True;
    }
    return Path(rel).name == filt;
}

"""
Resolve user-supplied paths to concrete test files under test_root.

Accepts absolute paths, paths relative to cwd, or paths relative to test/.
Directories expand to all test files beneath them.
"""
def resolve_path_args(test_root: Path, path_args: list[str]) -> list[Path] {
    found: list[Path] = [];
    seen: set[Path] = set();

    for raw in path_args {
        norm = _normalize_filter(raw);
        candidates = [Path(raw).expanduser(), test_root / norm, Path.cwd() / raw, ];
        target: Path | None = None;
        for c in candidates {
            try {
                c = c.resolve();
            } except OSError {
                continue;
            }
            if c.exists() {
                target = c;
                break;
            }
        }
        if target is None {
            print(f"WARNING: path not found: {raw}", file=sys.stderr);
            continue;
        }

        try {
            target.relative_to(test_root.resolve());
        } except ValueError {
            print(f"WARNING: path is outside {test_root}: {raw}", file=sys.stderr,);
            continue;
        }

        files: list[Path];
        if target.is_dir() {
            files = sorted(
                p
                for p in target.rglob("*")
                if p.is_file()
            );
        } else {
            files = [target];
        }

        for p in files {
            if p.suffix not in {".js", ".mjs", ".cjs"} {
                continue;
            }
            if target.is_file() {
                # User named this file explicitly — run it even without test- prefix.
            } else {
                # Directory expansion: skip fixtures / infra helpers; require test naming.
                if "fixtures" in p.parts {
                    continue;
                }
                if not _is_test_file(p) {
                    continue;
                }
            }
            rp = p.resolve();
            if rp not in seen {
                seen.add(rp);
                found.append(p);
            }
        }
    }

    return found;
}

"""
Find JS/MJS/CJS test files under the selected suites.

If path_args is non-empty, those paths (files or directories) are resolved
directly — suite filtering is ignored for them.
"""
def discover_tests(
    test_root: Path,
    suites: list[str],
    filter_glob: str | None = None,
    path_args: list[str] | None = None,
) -> list[Path] {
    if path_args {
        tests = resolve_path_args(test_root, path_args);
        if filter_glob {
            tests = [
                p
                for p in tests
                if _match_filter(str(p.relative_to(test_root)), filter_glob)
            ];
        }
        return tests;
    }

    tests: list[Path] = [];
    for suite in suites {
        suite_dir = test_root / suite;
        if not suite_dir.is_dir() {
            continue;
        }
        for p in sorted(suite_dir.rglob("*")) {
            if not p.is_file() or not _is_test_file(p) {
                continue;
            }
            # Skip fixtures nested under suite dirs.
            if "fixtures" in p.parts {
                continue;
            }
            rel = str(p.relative_to(test_root));
            if filter_glob and not _match_filter(rel, filter_glob) {
                continue;
            }
            tests.append(p);
        }
    }
    return tests;
}

# ---------------------------------------------------------------------------
# Process helpers
# ---------------------------------------------------------------------------

class _ProcResult {
    static has __slots__: tuple[str, ...] = ("returncode", "stdout", "stderr");

    def init(self: _ProcResult, returncode: int, stdout: str, stderr: str) {
        self.returncode = returncode;
        self.stdout = stdout;
        self.stderr = stderr;
    }
}

"""Force-kill the process group (and process), then reap.

Always attempts ``killpg`` even if the direct child has already exited
(e.g. SIGKILL from RLIMIT_AS): grandchildren that inherited the session
otherwise become orphans. With ``preexec_fn=os.setsid``, ``pgid == pid``.
"""
def _kill_process_group(
    proc: subprocess.Popen | None, pgid: int | None = None,
) -> None {
    if proc is None and pgid is None {
        return;
    }
    if pgid is None and proc is not None {
        # Prefer the session leader pid (setsid in preexec) over getpgid,
        # which fails once the leader is already gone.
        pgid = proc.pid;
        try {
            pgid = os.getpgid(proc.pid);
        } except (ProcessLookupError, OSError) {}
    }
    if pgid is not None {
        try {
            os.killpg(pgid, signal.SIGKILL);  # jac:ignore[E1053]
        } except (ProcessLookupError, OSError) {}
    }
    if proc is not None {
        try {
            proc.kill();
        } except (ProcessLookupError, OSError) {}
        # Drain pipes / reap so the child cannot linger as a zombie.
        try {
            proc.communicate(timeout=5);
        } except (subprocess.TimeoutExpired, OSError, ValueError) {
            try {
                proc.`wait(timeout=5);
            } except (subprocess.TimeoutExpired, OSError) {}
        }
    }
}

"""Return online CPU count via nproc, falling back to os.cpu_count()."""
def _nproc -> int {
    try {
        return max(1, int(subprocess.check_output(["nproc"], text=True).strip()));
    } except (OSError, subprocess.CalledProcessError, ValueError) {
        return max(1, os.cpu_count() or 1);
    }
}

def _make_mem_limiter(limit_bytes: int) -> any {
    def _limit {
        resource.setrlimit(resource.RLIMIT_AS, (limit_bytes, limit_bytes));
    }

    return _limit;
}

def _ulimit_wrap(engine_cmd: list[str], limit_bytes: int) -> list[str] {
    limit_kb = max(1, limit_bytes // 1024);
    inner = " ".join(f'"{a}"' for a in engine_cmd);
    return ["bash", "-c", f"ulimit -v {limit_kb}; exec {inner}"];
}

def _fmt_mem(kb: int | None) -> str {
    if kb is None or kb <= 0 {
        return "-";
    }
    if kb >= 1_048_576 {
        return f"{kb / 1_048_576:.1f}GB";
    }
    if kb >= 1024 {
        return f"{kb / 1024:.1f}MB";
    }
    return f"{kb}KB";
}

def _fmt_time(seconds: float) -> str {
    if seconds >= 1.0 {
        return f"{seconds:.2f}s";
    }
    return f"{seconds * 1000:.0f}ms";
}

def _git_revision(path: Path) -> str {
    try {
        return subprocess.check_output(
            ["git", "rev-parse", "HEAD"],
            cwd=path,
            stderr=subprocess.DEVNULL,
            text=True,
        ).strip()[:12];
    } except (OSError, subprocess.CalledProcessError) {
        return "unknown";
    }
}

# ---------------------------------------------------------------------------
# Single test execution
# ---------------------------------------------------------------------------

"""
Returns (result, reason, detail, elapsed_s, peak_kb).
result is PASS/FAIL/HANG/SKIP.

timeout and mem_limit_bytes are always enforced (must be > 0).
On timeout/termination the child process group is force-killed.
"""
def run_single_test(
    test_path: Path,
    engine: str,
    timeout: float,
    use_node: bool,
    dry_run: bool,
    mem_limit_bytes: int,
) -> tuple[str, str, str, float, int | None] {
    if dry_run {
        return (PASS, "dry-run", "", 0.0, None);
    }

    try {
        source = test_path.read_text(encoding="utf-8", errors="replace");
    } except OSError as e {
        return (FAIL, "read-error", str(e), 0.0, None);
    }

    (flags, test_envs) = parse_test_metadata(source);
    test_path_str = str(test_path);

    # Run the test file in place so require('../common') and fixtures resolve.
    if use_node {
        base_cmd = ["node", *flags, test_path_str];
    } else {
        # Forward // Flags: when present; unsupported flags may cause FAIL —
        # that is intentional signal for engine gaps.
        base_cmd = [engine, *flags, test_path_str];
    }

    mem_file: str | None = None;
    peak_kb: int | None = None;
    mem_limiter = None;

    if _TIME_BIN and not use_node {
        mem_file = tempfile.mktemp(prefix="node_test_mem_");
        # When mem limit is active, wrap only the engine with bash+ulimit so
        # /usr/bin/time itself runs unrestricted but the engine is constrained.
        inner_cmd = _ulimit_wrap(base_cmd, mem_limit_bytes)
            if mem_limit_bytes > 0
            else base_cmd;
        cmd = [_TIME_BIN, "-f", "%M", "-o", mem_file] + inner_cmd;
    } else {
        cmd = base_cmd;
        if mem_limit_bytes > 0 and not use_node {
            mem_limiter = _make_mem_limiter(mem_limit_bytes);
        }
    }

    proc_env = os.environ.copy();
    # Match tools/test.py: avoid common's auto-respawn when flags are already set.
    proc_env["NODE_SKIP_FLAG_CHECK"] = "true";
    # Isolate temp files under a per-run root when provided by the parent.
    if "NODE_TEST_DIR" not in proc_env {
        proc_env["NODE_TEST_DIR"] = str(TEST_ROOT);
    }
    # Relative libnapi_shim.so resolution expects cwd = js_engine root.
    proc_env.setdefault(
        "LD_LIBRARY_PATH",
        str(JS_ENGINE_ROOT / "lib")
            + (
                os.pathsep + proc_env["LD_LIBRARY_PATH"]
                    if proc_env.get("LD_LIBRARY_PATH")
                    else ""
            ),
    );
    proc_env.update(test_envs);

    def _child_preexec {
        os.setsid();
        # Never let a segfaulting engine dump core: on WSL, core_pattern pipes
        # to a crash-capture helper, and dozens of concurrent segfaults can
        # overwhelm/destabilize the VM. RLIMIT_CORE=0 suppresses this cleanly.
        try {
            resource.setrlimit(resource.RLIMIT_CORE, (0, 0));
        } except (ValueError, OSError) {}
        if mem_limiter is not None {
            mem_limiter();
        }
    }

    t0 = time.monotonic();
    proc_h: subprocess.Popen | None = None;
    # With setsid() in preexec, the child's pid is its process-group id.
    # Capture it so we can killpg even after the leader is already dead
    # (RLIMIT_AS SIGKILL), which would otherwise leave grandchildren orphaned.
    child_pgid: int | None = None;
    try {
        try {
            proc_h = subprocess.Popen(
                cmd,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                encoding="utf-8",
                errors="replace",
                cwd=str(JS_ENGINE_ROOT),
                preexec_fn=_child_preexec,
                env=proc_env,
            );
            child_pgid = proc_h.pid;
        } except FileNotFoundError as e {
            return (FAIL, "engine-not-found", str(e), 0.0, None);
        }

        try {
            (proc_out, proc_err) = proc_h.communicate(timeout=timeout);  # jac:ignore[E1099]
            returncode = proc_h.returncode;  # jac:ignore[E1099]
        } except subprocess.TimeoutExpired {
            elapsed = time.monotonic() - t0;
            _kill_process_group(proc_h, child_pgid);
            return (HANG, "timeout", f"exceeded {timeout}s", elapsed, None);
        }

        elapsed = time.monotonic() - t0;
        proc = _ProcResult(returncode, proc_out or "", proc_err or "");

        if mem_file {
            try {
                lines = [
                    ln.strip()
                    for ln in open(mem_file).read().splitlines()
                    if ln.strip()
                ];
                last = lines[-1] if lines else "";
                peak_kb = int(last) if last.isdigit() else None;
            } except OSError {}
        }

        # RLIMIT_AS exceeded: process may be killed with SIGKILL (rc=-9/137),
        # crash with SIGSEGV when the allocator hits a bad ptr (rc=-11/139),
        # or exit non-zero with ENOMEM from libc (rc=1 with empty output).
        oom_rc = proc.returncode in (-9, -11, 137, 139);
        oom_silent = (
            mem_limit_bytes > 0
            and proc.returncode != 0
            and not (proc.stderr or proc.stdout).strip()
        );
        if not use_node and mem_limit_bytes > 0 and (oom_rc or oom_silent) {
            # Parent may already be dead from SIGKILL; still reap the group.
            _kill_process_group(proc_h, child_pgid);
            limit_gb = mem_limit_bytes / (1024 ** 3);
            return (
                HANG,
                "oom",
                f"exceeded {limit_gb:g}GB memory limit",
                elapsed,
                peak_kb,

            );
        }

        combined = (proc.stdout or "") + "\n" + (proc.stderr or "");
        skip_m = _SKIP_RE.search(combined);
        if skip_m and proc.returncode == 0 {
            return (SKIP, "skipped", skip_m.group(1).strip()[:300], elapsed, peak_kb);
        }

        if proc.returncode == 0 {
            return (PASS, "", "", elapsed, peak_kb);
        }

        detail = (proc.stderr or proc.stdout or "").strip()[:300];
        return (FAIL, "non-zero-exit", detail, elapsed, peak_kb);
    } finally {
        # Always kill the process group — even if the leader already exited —
        # so child_process descendants (e.g. stay-alive fixtures) cannot leak.
        if proc_h is not None or child_pgid is not None {
            _kill_process_group(proc_h, child_pgid);
        }
        if mem_file {
            try {
                os.unlink(mem_file);
            } except OSError {}
        }
    }
}

# ---------------------------------------------------------------------------
# Logging / baseline
# ---------------------------------------------------------------------------

def write_log(
    test_path: Path, result: str, reason: str, detail: str, run_meta: dict[str, any],
) {
    try {
        rel = test_path.relative_to(TEST_ROOT);
    } except ValueError {
        rel = Path(test_path.name);
    }

    log_path = LOG_ROOT / rel.with_suffix(rel.suffix + ".log");
    log_path.parent.mkdir(parents=True, exist_ok=True);
    with open(log_path, "w", encoding="utf-8") as f {
        f.write(f"result: {result}\n");
        f.write(f"reason: {reason}\n");
        f.write(f"run_id: {run_meta['run_id']}\n");
        f.write(f"engine_revision: {run_meta['engine_revision']}\n");
        f.write(f"node_revision: {run_meta['node_revision']}\n");
        if detail {
            f.write(f"detail: {detail}\n");
        }
    }
}

def _write_baseline(path: str, records: dict[str, dict[str, any]], run_meta: dict[str, any],) {
    payload = {
        "version": 3,
        "meta": run_meta,
        "tests": {rel: records[rel] for rel in sorted(records)},

    };
    with open(path, "w", encoding="utf-8") as f {
        json.dump(payload, f, indent=2, sort_keys=True);
        f.write("\n");
    }
}

def _load_baseline(path: str) -> dict[str, dict[str, any]] {
    try {
        with open(path, encoding="utf-8") as f {
            content = f.read();
        }
    } except FileNotFoundError {
        print(f"ERROR: baseline file not found: {path}", file=sys.stderr);
        sys.`exit(1);
    }

    stripped = content.lstrip();
    if stripped.startswith("{") {
        data = json.loads(content);
        return dict(data.get("tests", {}));
    }

    records: dict[str, dict[str, any]] = {};
    for line in content.splitlines() {
        line = line.strip();
        if line.startswith("ok  ") {
            records[line[4:]] = {"result": "PASS", "time_s": None, "peak_kb": None};
        }
    }
    return records;
}

def _check_perf(
    baseline: dict[str, dict[str, any]],
    current: dict[str, dict[str, any]],
    ran_paths: set[str],
    pct: float,
    time_floor_ms: float,
    mem_floor_mb: float,
) -> list[tuple[str, str, float, float]] {
    time_floor_s = time_floor_ms / 1000.0;
    mem_floor_kb = mem_floor_mb * 1024.0;
    factor = 1.0 + pct / 100.0;
    regressions: list[tuple[str, str, float, float]] = [];

    for rel in sorted(ran_paths) {
        base = baseline.get(rel);
        cur = current.get(rel);
        if not base or not cur {
            continue;
        }
        if base.get("result") != "PASS" or cur.get("result") != "PASS" {
            continue;
        }

        (ot, nt) = (base.get("time_s"), cur.get("time_s"));
        if ot is not None and nt is not None and ot > 0 {
            if nt > ot * factor and (nt - ot) > time_floor_s {
                regressions.append((rel, "time", ot, nt));
            }
        }

        (om, nm) = (base.get("peak_kb"), cur.get("peak_kb"));
        if om is not None and nm is not None and om > 0 {
            if nm > om * factor and (nm - om) > mem_floor_kb {
                regressions.append((rel, "mem", float(om), float(nm)));
            }
        }
    }

    return regressions;
}

def _check_baseline(
    baseline_path: str,
    current: dict[str, dict[str, any]],
    ran_paths: set[str],
    perf_check: bool = False,
    perf_pct: float = 50.0,
    perf_time_floor_ms: float = 20.0,
    perf_mem_floor_mb: float = 5.0,
) -> int {
    baseline = _load_baseline(baseline_path);

    # SKIP does not count as a functional regression against a prior PASS.
    passed_now = {
        rel
        for (rel, r) in current.items()
        if r.get("result") == "PASS"
    };
    baseline_passing = {
        rel
        for (rel, r) in baseline.items()
        if r.get("result") == "PASS"
    };
    baseline_in_scope = baseline_passing & ran_paths;

    func_regressions = sorted(baseline_in_scope - passed_now);
    improvements = sorted(passed_now - baseline_in_scope);

    if improvements {
        print(f"\nImprovements ({len(improvements)} tests newly passing):");
        for p in improvements[:30] {
            print(f"  + {p}");
        }
        if len(improvements) > 30 {
            print(f"  ... and {len(improvements) - 30} more");
        }
    }

    if func_regressions {
        print(
            f"\nFUNCTIONAL REGRESSIONS ({len(func_regressions)} tests that were "
            f"passing are now failing):"
        );
        for p in func_regressions {
            print(f"  - {p}");
        }
    } else {
        print(
            f"\n✓ No functional regressions — all {len(baseline_in_scope)} "
            f"in-scope baseline tests still pass"
        );
        if improvements {
            print(
                f"  ({len(
                    improvements
                )} newly passing — consider updating the baseline)"
            );
        }
    }

    perf_regressions: list[tuple[str, str, float, float]] = [];
    baseline_has_perf = any(
        r.get("time_s") is not None or r.get("peak_kb") is not None
        for r in baseline.values()
    );
    if perf_check and not baseline_has_perf {
        print(
            "\n(perf check skipped — baseline has no performance metrics; "
            "re-run --save-baseline with this version to record them)"
        );
    } elif perf_check {
        perf_regressions = _check_perf(
            baseline,
            current,
            ran_paths,
            perf_pct,
            perf_time_floor_ms,
            perf_mem_floor_mb,
        );
        if perf_regressions {
            print(
                f"\nPERFORMANCE REGRESSIONS ({len(
                    perf_regressions
                )} metric(s) exceeded "
                f"+{perf_pct:g}% threshold):"
            );
            for (rel, metric, old, new) in perf_regressions {
                delta = (new / old - 1.0) * 100.0;
                if metric == "time" {
                    print(
                        f"  ~ {rel}  time {_fmt_time(old)} → {_fmt_time(new)}  (+{delta:.0f}%)"
                    );
                } else {
                    print(
                        f"  ~ {rel}  mem {_fmt_mem(int(old))} → {_fmt_mem(int(new))}  (+{delta:.0f}%)"
                    );
                }
            }
        } else {
            print(
                f"\n✓ No performance regressions "
                f"(threshold +{perf_pct:g}%, floors {perf_time_floor_ms:g}ms / {perf_mem_floor_mb:g}MB)"
            );
        }
    }

    return len(func_regressions) + len(perf_regressions);
}

# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------

def parse_args(argv: list[str] | None = None) -> argparse.Namespace {
    p = argparse.ArgumentParser(
        description="Run nodejs/node core tests against js_engine.",
        epilog=(
            "Examples:\n"
            "  %(prog)s --filter 'module-hooks/test-*.mjs'\n"
            "  %(prog)s engine/tests/node/vendor/test/module-hooks/test-foo.mjs\n"
            "  %(prog)s --suite all --filter 'test-fs-*'\n"
        ),
        formatter_class=argparse.RawDescriptionHelpFormatter,
    );
    p.add_argument(
        "paths",
        nargs="*",
        metavar="PATH",
        help=(
            "Specific test file(s) or directories under test/ to run. "
            "Accepts paths relative to test/, the repo root, or absolute paths. "
            "When given, --suite is ignored for discovery."
        ),
    );
    p.add_argument(
        "--engine",
        `default=str(DEFAULT_ENGINE),
        help="Path to the JS engine binary (default: bin/js_engine)",
    );
    p.add_argument(
        "--node",
        action="store_true",
        help="Run under system Node.js instead of the engine (baseline)",
    );
    p.add_argument(
        "--timeout",
        type=float,
        `default=_DEFAULT_TIMEOUT_S,
        help=(
            f"Per-test timeout in seconds (default: {_DEFAULT_TIMEOUT_S:g}). "
            "Always enforced; timed-out tests are force-killed."
        ),
    );
    p.add_argument(
        "--mem-limit",
        type=float,
        `default=float(_DEFAULT_MEM_LIMIT_GB),
        metavar="GB",
        help=(
            f"Per-test virtual memory limit in GB (default: {_DEFAULT_MEM_LIMIT_GB}). "
            "Set to 0 to disable."
        ),
    );
    p.add_argument(
        "--jobs",
        "-j",
        type=int,
        `default=None,
        metavar="N",
        help=(
            "Max parallel test workers (default: nproc). "
            "Use -j1 on low-RAM hosts (e.g. WSL) to avoid thrashing."
        ),
    );
    p.add_argument(
        "--dry-run",
        action="store_true",
        help="List tests that would run without executing them",
    );
    p.add_argument(
        "--filter",
        `default=None,
        metavar="GLOB",
        help=(
            "Only run tests whose path (relative to test/) matches this glob/substring. "
            "Searches all suites under test/ unless --suite is set."
        ),
    );
    p.add_argument(
        "--suite",
        `default=None,
        metavar="LIST",
        help=(
            "Comma-separated suites under test/ to run "
            f"(default: {','.join(DEFAULT_SUITES)} when no PATH/--filter; "
            "'all' when --filter is set). "
            "Use 'all' for every suite under test/, or e.g. 'parallel,module-hooks'."
        ),
    );
    p.add_argument(
        "--verbose",
        "-v",
        action="store_true",
        help="Print each test result as it completes (always on for small runs)",
    );
    p.add_argument(
        "--save-baseline",
        metavar="FILE",
        `default=None,
        help="After the run, write a JSON baseline of per-test results",
    );
    p.add_argument(
        "--check-baseline",
        metavar="FILE",
        `default=None,
        help="Compare this run against a previously saved baseline; exit non-zero on regressions",
    );
    p.add_argument(
        "--perf-check",
        action="store_true",
        help="With --check-baseline, also compare time/memory against the baseline",
    );
    p.add_argument(
        "--perf-pct",
        type=float,
        `default=50.0,
        metavar="PCT",
        help="Perf regression threshold percent (default: 50)",
    );
    p.add_argument(
        "--perf-time-floor",
        type=float,
        `default=20.0,
        metavar="MS",
        help="Ignore time regressions below this absolute increase (default: 20)",
    );
    p.add_argument(
        "--perf-mem-floor",
        type=float,
        `default=5.0,
        metavar="MB",
        help="Ignore memory regressions below this absolute increase (default: 5)",
    );
    return p.parse_args(argv);
}

"""
Decide which suites to scan.

- Explicit --suite wins.
- PATH args: ignored (discover via resolve_path_args).
- --filter without --suite: search all suites so any test/ path matches.
- Otherwise: DEFAULT_SUITES (parallel).
"""
def _resolve_suites(
    suite_arg: str | None, *, has_filter: bool, has_paths: bool, available: list[str],
) -> list[str] {
    if has_paths {
        return available;  # unused when path_args set; keep for logging
    }
    if suite_arg is None {
        if has_filter {
            return available;
        }
        return [
            s
            for s in DEFAULT_SUITES
            if s in available
        ]
            or available[:1];
    }

    raw = [
        s.strip()
        for s in suite_arg.split(",")
        if s.strip()
    ];
    if not raw {
        return [
            s
            for s in DEFAULT_SUITES
            if s in available
        ]
            or available[:1];
    }
    if len(raw) == 1 and raw[0].lower() == "all" {
        return available;
    }
    unknown = [
        s
        for s in raw
        if s not in available
    ];
    if unknown {
        print(
            f"WARNING: unknown suite(s) {unknown}; available: {', '.join(available)}",
            file=sys.stderr,
        );
    }
    return raw;
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def main(argv: list[str] | None = None) -> int {
    args = parse_args(argv);

    if args.timeout <= 0 {
        print(
            "ERROR: --timeout must be > 0 (time limit is always enforced)",
            file=sys.stderr,
        );
        return 1;
    }

    if not TEST_ROOT.is_dir() {
        print("ERROR: Node.js test suite not found.", file=sys.stderr);
        print(f"  Expected: {TEST_ROOT}", file=sys.stderr);
        print("  Fetch it (pinned commit):", file=sys.stderr);
        print("    tools/fetch_test_deps.sh node", file=sys.stderr);
        return 1;
    }

    if not (TEST_ROOT / "common").is_dir() {
        print(f"ERROR: test/common helpers missing under {TEST_ROOT}", file=sys.stderr);
        return 1;
    }

    available = list_suites(TEST_ROOT);
    path_args = list(args.paths or []);
    suites = _resolve_suites(
        args.suite,
        has_filter=bool(args.filter),
        has_paths=bool(path_args),
        available=available,
    );
    tests = discover_tests(
        TEST_ROOT, suites, filter_glob=args.filter, path_args=path_args or None,
    );

    if not tests {
        print("No test files found.", file=sys.stderr);
        if path_args {
            print(
                "  Check that PATH points under test/ and is a .js/.mjs/.cjs file.",
                file=sys.stderr,
            );
        } elif args.filter {
            print(
                f"  Filter: {args.filter!r}  (searched suites: {', '.join(suites)})",
                file=sys.stderr,
            );
        } else {
            print(f"  Suites: {', '.join(suites)}", file=sys.stderr);
            print(
                "  Tip: pass a path, or --filter 'module-hooks/*', or --suite all",
                file=sys.stderr,
            );
        }
        return 1;
    }

    if path_args {
        suite_label = "paths";
    } elif args.suite and args.suite.lower() == "all" {
        suite_label = "all";
    } elif args.suite is None and args.filter {
        suite_label = "all";
    } else {
        suite_label = ",".join(suites);
    }

    if args.dry_run {
        print(
            f"Dry run: {len(tests)} test files under {TEST_ROOT}  scope={suite_label}"
        );
        for tp in tests {
            rel = tp.relative_to(TEST_ROOT);
            if args.verbose or len(tests) <= 50 {
                print(f"  WOULD RUN: {rel}");
            }
        }
        print(f"\nWould run:  {len(tests)}");
        return 0;
    }

    if args.`node {
        engine = shutil.which("node");
        if not engine {
            print("ERROR: node not found on PATH", file=sys.stderr);
            return 1;
        }
    } else {
        engine = args.engine;
        if not os.access(engine, os.X_OK) {
            print(
                f"ERROR: engine not found at {engine}  (run 'make all' first)",
                file=sys.stderr,
            );
            return 1;
        }
    }

    results = {PASS: 0, FAIL: 0, HANG: 0, SKIP: 0};
    failures: list[tuple[Path, str, str, float, int | None]] = [];
    skipped: list[tuple[Path, str]] = [];
    passed_paths: set[str] = set();
    records: dict[str, dict[str, any]] = {};

    mem_limit_bytes = int(args.mem_limit * (1024 ** 3)) if args.mem_limit > 0 else 0;
    run_started = datetime.now(timezone.utc);
    run_meta: dict[str, any] = {
        "run_id": run_started.strftime("%Y%m%dT%H%M%S.%fZ"),
        "timestamp": run_started.isoformat(),
        "engine_revision": _git_revision(JS_ENGINE_ROOT),
        "node_revision": _git_revision(NODE_ROOT),
        "command": " ".join([Path(sys.executable).name, *sys.argv]),
        "engine": "node" if args.`node else str(Path(engine).resolve()),
        "filter": args.filter,
        "suite": ",".join(suites),
        "timeout_s": args.timeout,
        "mem_limit_gb": args.mem_limit,

    };

    jobs = _nproc();
    if args.jobs is not None {
        if args.jobs < 1 {
            print("ERROR: --jobs must be >= 1", file=sys.stderr);
            return 2;
        }
        jobs = args.jobs;
    }
    # sequential suite must not race on shared state — force 1 worker when only that suite.
    if not path_args and suites == ["sequential"] {
        jobs = 1;
    }

    def _run(tp: Path) -> tuple[Path, tuple[str, str, str, float, int | None]] {
        return (
            tp,
            run_single_test(
                test_path=tp,
                engine=engine,
                timeout=args.timeout,
                use_node=args.`node,
                dry_run=False,
                mem_limit_bytes=mem_limit_bytes,
            ),

        );
    }

    total = len(tests);
    done = 0;
    peak_kb: int | None = None;
    peak_name = "";
    suite_start = time.monotonic();

    print(
        f"Running {total} Node.js tests  engine={'node' if args.`node else engine}  "
        f"scope={suite_label}  jobs={jobs}  "
        f"timeout={args.timeout:g}s  mem-limit={args.mem_limit:g}GB",
        flush=True,
    );

    with ThreadPoolExecutor(max_workers=jobs) as pool {
        futures = {pool.submit(_run, tp): tp for tp in tests};
        for fut in as_completed(futures) {
            fut_res: tuple[Path, tuple[str, str, str, float, int | None]] = fut.result();
            (tp, (result, reason, detail, elapsed, test_kb)) = fut_res;
            results[result] += 1;
            done += 1;

            try {
                rel_key = str(tp.relative_to(TEST_ROOT));
            } except ValueError {
                rel_key = str(tp);
            }

            records[rel_key] = {
                "result": result,
                "reason": reason,
                "time_s": round(elapsed, 4),
                "peak_kb": test_kb,

            };

            if result == PASS {
                passed_paths.add(rel_key);
            } elif result == SKIP {
                skipped.append((tp, detail or reason));
            } elif result == FAIL {
                failures.append((tp, reason, detail, elapsed, test_kb));
            } elif result == HANG {
                failures.append((tp, reason, detail, elapsed, test_kb));
            }

            if test_kb is not None and (peak_kb is None or test_kb > peak_kb) {
                peak_kb = test_kb;
                peak_name = rel_key;
            }

            elapsed_fmt = _fmt_time(elapsed);
            mem_fmt = _fmt_mem(test_kb);
            label = {PASS: "ok  ", SKIP: "SKIP", FAIL: "FAIL", HANG: "TO  ",}[result];

            hang_note = "";
            if result == HANG {
                hang_note = f"  (OOM >{args.mem_limit:g}GB)"
                    if reason == "oom"
                    else f"  (killed after {args.timeout}s)";
            }

            print(
                f"[{done:6d}/{total}] {label}  {rel_key:<70}  "
                f"{elapsed_fmt:>8}  {mem_fmt:>8}{hang_note}",
                flush=True,
            );
            if result == FAIL and detail {
                for line in detail.splitlines()[:3] {
                    print(f"             {line}");
                }
            }
            if result == SKIP and detail and args.verbose {
                print(f"             skipped: {detail}");
            }

            if result in (FAIL, HANG) {
                write_log(tp, result, reason, detail, run_meta);
            }
        }
    }

    suite_elapsed = time.monotonic() - suite_start;
    n_pass = results[PASS];
    n_fail = results[FAIL];
    n_hang = results[HANG];
    n_skip = results[SKIP];
    n_ran = n_pass + n_fail + n_hang;  # excludes skips from pass-rate denominator
    pass_rate = (100.0 * n_pass / n_ran) if n_ran > 0 else 0.0;

    if args.save_baseline {
        _write_baseline(args.save_baseline, records, run_meta);
        n_with_perf = sum(
            1
            for r in records.values()
            if r.get("time_s") is not None
        );
        print(
            f"\nBaseline saved → {args.save_baseline}  "
            f"({len(passed_paths)} passing, {n_skip} skipped, {n_with_perf} with perf metrics)"
        );
        if jobs > 1 {
            print(
                f"  NOTE: parallel timing is contended "
                f"(this run used {jobs} workers); perf baselines are less stable under load."
            );
        }
    }

    regression_count = 0;
    if args.check_baseline {
        ran_paths = set(records.keys());
        regression_count = _check_baseline(
            args.check_baseline,
            records,
            ran_paths,
            perf_check=args.perf_check,
            perf_pct=args.perf_pct,
            perf_time_floor_ms=args.perf_time_floor,
            perf_mem_floor_mb=args.perf_mem_floor,
        );
    }

    print();
    print("══════════════════════════════════════════════════");
    print(
        f"  Tests: {total} total  |  {n_pass} passed  |  {n_fail + n_hang} failed  "
        f"|  {n_skip} skipped  |  {_fmt_time(suite_elapsed)} total"
    );
    if n_hang {
        print(f"  (of failures: {n_fail} FAIL, {n_hang} HANG/timeout)");
    }
    print(f"  Pass rate: {pass_rate:.1f}%  (of {n_ran} executed, skips excluded)");
    if peak_kb is not None {
        print(f"  Peak memory: {_fmt_mem(peak_kb)}  ({peak_name})");
    }
    print("══════════════════════════════════════════════════");

    if failures {
        print(f"\nFailed tests ({min(20, len(failures))} of {len(failures)} shown):");
        for (tp, reason, detail, elapsed, test_kb) in failures[:20] {
            try {
                rel = tp.relative_to(TEST_ROOT);
            } except ValueError {
                rel = tp;
            }
            print(f"  FAIL  {rel}  [{reason}]  {_fmt_time(elapsed)}");
            if detail {
                print(f"        {detail[:120]}");
            }
        }
    }

    if regression_count > 0 {
        return 1;
    }
    return 0 if n_fail == 0 and n_hang == 0 else 1;
}

with entry:__main__ {
    raise SystemExit(main());
}
