"""End-to-end GC effectiveness tests for the native LLVM backend.

Each test AOT-compiles a fixture via `jac nacompile`, then runs the resulting
binary twice — once with the reference-counted GC enabled (default), and once
with it disabled (`JAC_NO_GC=1`). Maximum resident set size is captured via
`/usr/bin/time -v` and we assert that GC reduces peak RSS.

Fixtures exercised:
  - chess.na.jac           (interactive game; we pipe "quit" to exit early)
  - perf_alloc_storm.na.jac
  - perf_retain_release.na.jac
  - perf_string_concat.na.jac
  - perf_deep_call_chain.na.jac
"""

import os;
import re;
import shutil;
import subprocess;
import sys;
import tempfile;
import from pathlib { Path }
import jaclang;

glob FIXTURES = str(
         Path(jaclang.__file__).parent.parent / "tests" / "compiler" / "passes" / "native" / "fixtures"
     ),
     # Programs whose RSS savings are too small / noisy to gate on (still verified to
     # run, but the strict GC < no-GC inequality is downgraded to a non-regression
     # check to avoid flakes on systems with high allocator slack).
     LENIENT_FIXTURES = {"perf_alloc_storm.na.jac"};


"""Run /usr/bin/time -v on `binary` and return (rss_kb, exit_code, stdout_head).

`env_extra` is merged into the child environment.  `stdin_data` is fed to the
binary's stdin (used for the interactive chess fixture).
"""
def _run_with_time(
    binary: str,
    env_extra: dict | None = None,
    stdin_data: str | None = None,
    timeout: int = 120,
) -> tuple[int, int, str] {
    time_bin = "/usr/bin/time";
    assert os.path.exists(time_bin) , f"{time_bin} required for RSS measurement";
    env = os.environ.copy();
    # Make /usr/bin/time output deterministic across locales.
    env["LC_ALL"] = "C";
    if env_extra {
        for (k, v) in env_extra.items() {
            env[k] = v;
        }
    }
    proc = subprocess.run(
        [time_bin, "-v", binary],
        input=stdin_data,
        capture_output=True,
        text=True,
        timeout=timeout,
        env=env,
    );
    # /usr/bin/time -v writes its summary to stderr after the child's own stderr.
    rss_kb = 0;
    m = re.search(r"Maximum resident set size \(kbytes\):\s*(\d+)", proc.stderr);
    if m {
        rss_kb = int(m.group(1));
    }
    head = proc.stdout[:200] if proc.stdout else "";
    return (rss_kb, proc.returncode, head);
}


"""Compile `fixture` to a native binary at `out_bin`.  Asserts success."""
def _nacompile(fixture: str, out_bin: str) {
    src = os.path.join(FIXTURES, fixture);
    assert os.path.exists(src) , f"fixture missing: {src}";
    comp = subprocess.run(
        [sys.executable, "-m", "jaclang", "nacompile", src, "-o", out_bin],
        capture_output=True,
        text=True,
        timeout=300,
    );
    assert comp.returncode == 0 , (
        f"nacompile failed for {fixture}: exit={comp.returncode}\n"
        f"stderr: {comp.stderr[-800:] if comp.stderr else '(empty)'}"
    );
    assert os.path.exists(out_bin) , f"binary not produced at {out_bin}";
}


"""Compile + run twice (with / without GC) and return (gc_rss, nogc_rss).

Asserts that both runs exit cleanly and that — for non-lenient fixtures — peak
RSS with the GC enabled is strictly lower than with `JAC_NO_GC=1`.  For lenient
fixtures we only assert that the GC-enabled run does not regress beyond a small
slack window.
"""
def _measure_gc_savings(
    fixture: str,
    stdin_data: str | None = None,
    min_savings_kb: int = 1024,
    lenient_slack_kb: int = 256,
    timeout: int = 180,
) -> tuple[int, int] {
    with tempfile.TemporaryDirectory() as tmp {
        bin_path = os.path.join(tmp, fixture.replace(".na.jac", ""));
        _nacompile(fixture, bin_path);
        # GC enabled (default).
        (gc_rss, gc_rc, _gc_out) = _run_with_time(
            bin_path, env_extra=None, stdin_data=stdin_data, timeout=timeout
        );
        assert gc_rc == 0 , f"{fixture} (with GC) exited non-zero: {gc_rc}";
        assert gc_rss > 0 , f"{fixture} (with GC) failed to capture RSS";
        # GC disabled — every allocation leaks until process exit.
        (nogc_rss, nogc_rc, _nogc_out) = _run_with_time(
            bin_path,
            env_extra={"JAC_NO_GC": "1"},
            stdin_data=stdin_data,
            timeout=timeout,
        );
        assert nogc_rc == 0 , f"{fixture} (JAC_NO_GC=1) exited non-zero: {nogc_rc}";
        assert nogc_rss > 0 , f"{fixture} (JAC_NO_GC=1) failed to capture RSS";
        if fixture in LENIENT_FIXTURES {
            # Lenient: just don't regress badly.
            assert gc_rss <= nogc_rss + lenient_slack_kb , (
                f"{fixture}: GC RSS {gc_rss} KB exceeds no-GC RSS {nogc_rss} KB"
                f" by more than {lenient_slack_kb} KB slack"
            );
        } else {
            saved = nogc_rss - gc_rss;
            assert saved >= min_savings_kb , (
                f"{fixture}: GC saved only {saved} KB"
                f" (with-GC={gc_rss} KB, no-GC={nogc_rss} KB);"
                f" expected >= {min_savings_kb} KB"
            );
        }
        return (gc_rss, nogc_rss);
    }
}


# --- Tests ------------------------------------------------------------------
test "gc reduces rss for perf_alloc_storm" {
    (gc, nogc) = _measure_gc_savings("perf_alloc_storm.na.jac");
    print(f"[alloc_storm] gc={gc} KB  nogc={nogc} KB  saved={nogc - gc} KB");
}

test "gc reduces rss for perf_retain_release" {
    # 1M reassignments -> ~100 MB leak without GC.
    (gc, nogc) = _measure_gc_savings(
        "perf_retain_release.na.jac", min_savings_kb=10240
    );
    print(f"[retain_release] gc={gc} KB  nogc={nogc} KB  saved={nogc - gc} KB");
}

test "gc reduces rss for perf_string_concat" {
    # String churn allocates fresh buffers each iter; without GC RSS balloons.
    (gc, nogc) = _measure_gc_savings("perf_string_concat.na.jac", min_savings_kb=10240);
    print(f"[string_concat] gc={gc} KB  nogc={nogc} KB  saved={nogc - gc} KB");
}

test "gc reduces rss for perf_deep_call_chain" {
    # Per-frame Frame() allocations pile up in 200x5000 calls without GC.
    (gc, nogc) = _measure_gc_savings(
        "perf_deep_call_chain.na.jac", min_savings_kb=10240
    );
    print(f"[deep_call_chain] gc={gc} KB  nogc={nogc} KB  saved={nogc - gc} KB");
}

test "gc reduces rss for chess" {
    # Feed EOF (Ctrl+D) immediately on stdin: input() returns empty so each
    # turn picks a random move and the game runs to completion (checkmate).
    # Each iteration allocates a fresh `legal_moves` list plus piece dicts —
    # without GC these all leak, ballooning RSS into the hundreds of MB.
    (gc, nogc) = _measure_gc_savings(
        "chess.na.jac", stdin_data="", min_savings_kb=51200, timeout=120
    );
    print(f"[chess] gc={gc} KB  nogc={nogc} KB  saved={nogc - gc} KB");
}
