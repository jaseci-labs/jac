"""The phase-C timing harness: what the compiler costs, and what it must not.

Epic #8201 phase C moves the code generator off Python bytecode, and every
step of it is a bet that the compiler gets no slower and the programs it emits
get no slower. This file is where those two bets are settled with numbers
instead of impressions.

Three measurements, three shapes:

`warm-compile phase timings` is a REPORT, not a gate. It drives a fixed corpus
of real repo modules through the four schedules `_compile_once` runs for a
Python-lane module, one at a time so each is attributable, and prints the
table. It asserts only what a broken measurement looks like -- a compile error,
or a phase that took no time at all -- because a wall-clock gate on a developer
laptop is a coin flip, and a coin flip that fails the suite teaches people to
ignore it.

`against the pinned baseline` is the same corpus measured on this checkout and
on a snapshot of `BASELINE_REF`, in alternating rounds, so the delta belongs to
the branch rather than to the machine or to the order the two were run in. The
snapshot is a `git archive` of the pinned ref plus symlinks to this checkout's
gitignored build artifacts, cached under the jac cache root and reused across
runs. It is opt-in (`JAC_TIMING_BASELINE=1`) because the first run bootstraps a
second compiler from scratch, which takes minutes and belongs in a deliberate
measurement, never in `jac test`.

`the chess AOT binary` is a real GATE, and the only one here. The AOT lane's
output is the product; if a compiled chess game gets multiples slower, that is
a regression no matter which machine noticed. It is written as a ceiling with
room to spare rather than as the recorded numbers, so it fires on a real
slowdown and stays quiet on a busy box.

The chess binary also carries a correctness floor instead of a time floor. A
lower time bound would only catch a binary that exits early, and the printed
result tally catches that directly and without a threshold to argue about.

Every report is written to `<jac cache root>/timing/*.txt` as well as printed,
because `jac test` captures a test's output at fd level and replays it only on
failure -- and a report that only survives a failure is not much of a report.
The file under the cache root is the copy that always survives.
"""

import json;
import os;
import shutil;
import statistics;
import subprocess;
import sys;
import tempfile;
import time;

import from pathlib { Path }
import from tests.support { JAC_ROOT, TESTS_DIR }
import from jaclang.jac0core.cache_paths { get_jir_cache_dir }

glob PROBE: str = os.path.join(
         TESTS_DIR, "compiler", "fixtures", "compile_timing_probe.jac"
     ),
     CHESS: str = os.path.join(JAC_ROOT, "examples", "chess", "chess.jac"),
     REPO_ROOT: str = os.path.dirname(JAC_ROOT),
     PHASES: list[str] = ["parse", "ir_gen", "boundary", "codegen", "full"];

"""The measured corpus, restated here so the harness pins the probe's list.

The probe owns the list it actually runs; this copy exists so that reading the
harness tells you what was measured, and so a silent edit to either file fails
the suite instead of quietly re-scoping every recorded number. Importing the
probe to read its list is not an option -- importing a `.jac` module runs its
entry block, which is the whole measurement.
"""
glob CORPUS: list[str] = [
         "jaclang/jac0core/srcloc.jac",
         "jaclang/jac0core/parser/tokens.jac",
         "jaclang/jac0core/passes/uni_pass.jac",
         "jaclang/jac0core/constant.jac",
         "examples/chess/chess.jac"
     ];

"""The ref this branch's compile cost is measured against.

Pre-cutover `main`: `f76ca633f`, the type-checker census and the pooled
native seal (#8280), which is the commit this branch forked from. The
baseline tree therefore runs the retired Python-AST emitter and this tree
runs the container, so the delta is exactly the cost of the codegen
change and nothing that landed upstream alongside it. Move it whenever
the branch rebases, and say so in the commit -- a moved baseline silently
reinterprets every number here.
"""
glob BASELINE_REF: str = "f76ca633fa5f82038a0629325d5b8f9df6258e9d";

"""Gitignored build artifacts a fresh checkout of the baseline cannot produce.

Symlinked into the snapshot from this checkout. Without the typeshed stdlib
every compile dies with a scheduling error for the missing `inference`
provider, and without the LLVM shared object the native passes cannot load at
all -- either one would be measured as "the baseline is broken", not as a
timing.
"""
glob SNAPSHOT_LINKS: list[str] = [
         "jaclang/vendor/typeshed/stdlib",
         "jaclang/compiler/passes/native/llvm/libjacllvm.so",
         ".pbs-build",
         ".llvm-build"
     ];

"""What a `-b 1` game of AOT-compiled chess costs, and how far it may drift.

Recorded truth on the machine this landed from: 0.07-0.08s per run, over ten
consecutive runs of a `jac nacompile` binary, with a spread under 0.01s. The
epic's earlier note recorded 0.23-0.26s per run for the same command; that
figure is kept here because the ceiling has to hold under whichever of the two
frames is right, and it is 3x the older number and 9x the measured one. Nothing
in phase C should move this by even one of those multiples; a gate that fires
below them would be reporting the machine, not the compiler.
"""
glob CHESS_RUNS: int = 5,
     CHESS_CEILING_S: float = 0.75,
     CHESS_RECORDED_S: str = "0.07-0.08s measured, 0.23-0.26s previously recorded";

"""How many alternating rounds the baseline comparison measures each tree for."""
glob PAIRED_ROUNDS: int = 2;

glob _PROBE_CACHE: dict[str, list[dict]] = {};

"""This checkout's cache root, which is also where the probe subprocess writes."""
def head_cache -> str {
    return os.environ.get("XDG_CACHE_HOME", "") or str(Path.home() / ".cache");
}

"""Print a report and leave a copy on disk, because `jac test` swallows stdout.

`jac test` exposes no way to turn capture off, so a passing report would
otherwise be invisible -- and a report nobody can read is not a report. The file
under the jac cache root is the copy that survives either way.
"""
def publish(name: str, text: str) {
    print(text);
    out_dir = get_jir_cache_dir().parent / "timing";
    out_dir.mkdir(parents=True, exist_ok=True);
    (out_dir / f"{name}.txt").write_text(text + "\n", encoding="utf-8");
}

"""Environment for a probe subprocess, pinned to `cache` and to nothing else.

`JAC_DEV_SOURCE` is dropped rather than overridden: `_jac_finder` re-derives it
from the nearest `jac.toml` above the subprocess cwd, and an inherited value
would be a second, contradicting answer to the one question this harness needs
the subprocess to answer for itself -- which compiler is running.
"""
def _probe_env(cache: str) -> dict[str, str] {
    env = dict(os.environ);
    env.pop("JAC_DEV_SOURCE", None);
    env["XDG_CACHE_HOME"] = cache;
    return env;
}

"""Run the probe against the tree at `tree_dir`, returning one row per module.

Memoized per `(tree, round)` so the paired comparison can ask for a specific
round and the HEAD-only report can share round zero with it.
"""
def run_probe(tree_dir: str, cache: str, round_no: int = 0) -> list[dict] {
    key = f"{os.path.abspath(tree_dir)}#{round_no}";
    if key in _PROBE_CACHE {
        return _PROBE_CACHE[key];
    }
    proc = subprocess.run(
        [sys.executable, "-m", "jaclang", "run", PROBE],
        cwd=tree_dir,
        env=_probe_env(cache),
        capture_output=True,
        text=True,
        timeout=1800
    );
    rows = [
        json.loads(line[len("TIMING_ROW "):])
        for line in (proc.stdout or "").splitlines()
        if line.startswith("TIMING_ROW ")
    ];
    assert proc.returncode == 0 and rows , (
        f"the timing probe failed in {tree_dir} (exit={proc.returncode})\n"
        f"{((proc.stdout or '') + (proc.stderr or ''))[-2000:]}"
    );
    _PROBE_CACHE[key] = rows;
    return rows;
}

"""Fold several runs of one tree into one row set, keeping each phase's minimum."""
def merge_runs(runs: list[list[dict]]) -> list[dict] {
    merged = [dict(r) for r in runs[0]];
    for later in runs[1:] {
        by_rel = {str(r["rel"]): r for r in later};
        for row in merged {
            other = by_rel.get(str(row["rel"]));
            if other is None {
                continue;
            }
            for phase in PHASES {
                row[phase] = min(row[phase], other[phase]);
            }
            row["errors"] += other["errors"];
        }
    }
    return merged;
}

"""Measure both trees in alternating rounds, so drift cannot favour either one.

Running one tree to completion and then the other hands the second tree a
warmer page cache and a hotter CPU, and the first version of this comparison
duly reported HEAD faster on every phase of every module -- a result shaped
like the ordering, not like the branch. Alternating and keeping each phase's
minimum across rounds removes the monotonic half of that bias.
"""
def paired_rows(base_tree: str, base_cache: str) -> tuple[list[dict], list[dict]] {
    base_runs: list[list[dict]] = [];
    head_runs: list[list[dict]] = [];
    for round_no in range(PAIRED_ROUNDS) {
        base_runs.append(run_probe(base_tree, base_cache, round_no));
        head_runs.append(run_probe(JAC_ROOT, head_cache(), round_no));
    }
    return (merge_runs(base_runs), merge_runs(head_runs));
}

"""Materialize the pinned baseline as a compilable tree, or explain why not.

`git archive` rather than `git worktree add`: the snapshot is a read-only
measurement subject that must not register itself in the repo the suite is
running out of. Cached by ref under the jac cache root, so only the first run
pays the extraction and the baseline compiler's bootstrap.
"""
def baseline_tree -> str {
    dest = get_jir_cache_dir().parent / "timing-baseline" / BASELINE_REF[:12];
    tree = dest / "jac";
    if (tree / "jac.toml").is_file() {
        return str(tree);
    }
    if shutil.which("git") is None {
        testskip("git is not on PATH; cannot materialize the baseline ref");
    }
    known = subprocess.run(
        ["git", "-C", REPO_ROOT, "cat-file", "-e", BASELINE_REF + "^{commit}"],
        capture_output=True,
        text=True
    );
    if known.returncode != 0 {
        testskip(
            f"baseline ref {BASELINE_REF[:12]} is not in this clone; fetch it "
            "(a shallow or fork clone may not carry it) to run the comparison"
        );
    }
    shutil.rmtree(dest, ignore_errors=True);
    dest.mkdir(parents=True, exist_ok=True);
    archive = subprocess.run(
        ["git", "-C", REPO_ROOT, "archive", BASELINE_REF, "jac"],
        capture_output=True,
        timeout=600
    );
    assert archive.returncode == 0 , (
        f"git archive of {BASELINE_REF[:12]} failed: "
        f"{(archive.stderr or b'').decode('utf-8', 'replace')[-800:]}"
    );
    extract = subprocess.run(
        ["tar", "-x", "-C", str(dest)],
        input=archive.stdout,
        capture_output=True,
        timeout=600
    );
    assert extract.returncode == 0 , (
        f"unpacking the baseline archive failed: "
        f"{(extract.stderr or b'').decode('utf-8', 'replace')[-800:]}"
    );
    for rel in SNAPSHOT_LINKS {
        live = Path(JAC_ROOT) / rel;
        if not live.exists() {
            continue;
        }
        link = tree / rel;
        link.parent.mkdir(parents=True, exist_ok=True);
        if link.is_symlink() or link.exists() {
            continue;
        }
        os.symlink(str(live.resolve()), str(link));
    }
    return str(tree);
}

"""Format one tree's rows as a fixed-width table, phase columns in pipeline order."""
def phase_table(title: str, rows: list[dict]) -> str {
    width = max([len(str(r["rel"])) for r in rows]);
    head = "  " + "module".ljust(width);
    for phase in PHASES {
        head += "  " + phase.rjust(9);
    }
    out = [title, head];
    for r in rows {
        line = "  " + str(r["rel"]).ljust(width);
        for phase in PHASES {
            line += "  " + f"{r[phase] * 1000:.1f}ms".rjust(9);
        }
        out.append(line);
    }
    totals = "  " + "TOTAL".ljust(width);
    for phase in PHASES {
        totals += "  " + f"{sum([r[phase] for r in rows]) * 1000:.1f}ms".rjust(9);
    }
    out.append(totals);
    return "\n".join(out);
}

"""Format the per-phase delta between two trees as a percentage of baseline."""
def delta_table(baseline: list[dict], current: list[dict]) -> str {
    by_rel = {str(r["rel"]): r for r in baseline};
    width = max([len(str(r["rel"])) for r in current]);
    head = "  " + "module".ljust(width);
    for phase in PHASES {
        head += "  " + phase.rjust(9);
    }
    out = [head];
    for r in current {
        base = by_rel.get(str(r["rel"]));
        if base is None {
            continue;
        }
        line = "  " + str(r["rel"]).ljust(width);
        for phase in PHASES {
            pct = 100.0 * (r[phase] - base[phase]) / base[phase];
            line += "  " + f"{pct:+.1f}%".rjust(9);
        }
        out.append(line);
    }
    totals = "  " + "TOTAL".ljust(width);
    for phase in PHASES {
        cur_sum = sum([r[phase] for r in current]);
        base_sum = sum([by_rel[str(r["rel"])][phase] for r in current]);
        totals += "  " + f"{100.0 * (cur_sum - base_sum) / base_sum:+.1f}%".rjust(9);
    }
    out.append(totals);
    return "\n".join(out);
}

test "the timing corpus names modules that are in this checkout" {
    assert os.path.isfile(PROBE) , f"the timing probe is missing at {PROBE}";
    for rel in CORPUS {
        assert (Path(JAC_ROOT) / rel).is_file() , (
            f"the timing corpus names {rel}, which is not in this checkout; a "
            "corpus that drifts makes every recorded number unreadable"
        );
    }
}

test "warm-compile phase timings for the corpus" {
    rows = run_probe(JAC_ROOT, head_cache());
    publish(
        "phase-timings-head",
        phase_table(f"warm-compile phases at HEAD ({len(rows)} modules):", rows)
    );
    assert [str(r["rel"]) for r in rows] == CORPUS , (
        f"the probe measured {[str(r['rel']) for r in rows]}, but the harness "
        f"declares {CORPUS}; the two lists must stay in lockstep"
    );
    for r in rows {
        assert r["errors"] == 0 , (
            f"{r['rel']} did not compile clean during the measurement "
            f"({r['errors']} alert(s)); the numbers above are timing a failure"
        );
        for phase in PHASES {
            assert r[phase] > 0.0 , (
                f"{r['rel']} reported {phase} as {r[phase]}s, so the phase was "
                "skipped rather than measured"
            );
        }
    }
}

test "warm-compile phase timings against the pinned baseline" {
    if os.environ.get("JAC_TIMING_BASELINE", "") != "1" {
        testskip(
            "set JAC_TIMING_BASELINE=1 to measure against "
            f"{BASELINE_REF[:12]}; the first run extracts that ref and "
            "bootstraps its compiler, which takes minutes"
        );
    }
    tree = baseline_tree();
    cache = str(Path(tree).parent / "cache");
    (base_rows, head_rows) = paired_rows(tree, cache);
    publish(
        "phase-timings-baseline",
        "\n".join(
            [
                f"{PAIRED_ROUNDS} alternating round(s) per tree, per-phase minimum",
                phase_table(f"baseline {BASELINE_REF[:12]}:", base_rows),
                phase_table("HEAD:", head_rows),
                f"delta (HEAD vs {BASELINE_REF[:12]}, + is slower):",
                delta_table(base_rows, head_rows)
            ]
        )
    );
    base_rels = {str(r["rel"]) for r in base_rows};
    head_rels = {str(r["rel"]) for r in head_rows};
    assert base_rels == head_rels , (
        f"the two trees measured different corpora: baseline {sorted(base_rels)} "
        f"vs HEAD {sorted(head_rels)}"
    );
    for r in base_rows {
        assert r["errors"] == 0 , (
            f"{r['rel']} did not compile clean at {BASELINE_REF[:12]}; the "
            "delta above compares against a failure"
        );
    }
}

test "the chess AOT binary stays inside its recorded run envelope" {
    with tempfile.TemporaryDirectory() as tmp {
        out_bin = os.path.join(tmp, "chess");
        comp = subprocess.run(
            [sys.executable, "-m", "jaclang", "nacompile", CHESS, "-o", out_bin],
            capture_output=True,
            text=True,
            timeout=1800
        );
        assert comp.returncode == 0 and os.path.exists(out_bin) , (
            f"nacompile of the chess example failed: exit={comp.returncode}\n"
            f"{((comp.stdout or '') + (comp.stderr or ''))[-1200:]}"
        );
        runs: list[float] = [];
        for i in range(CHESS_RUNS) {
            started = time.perf_counter();
            proc = subprocess.run(
                [out_bin, "-b", "1"], capture_output=True, text=True, timeout=300
            );
            runs.append(time.perf_counter() - started);
            assert proc.returncode == 0 , (
                f"chess run {i + 1} exited {proc.returncode}: "
                f"{(proc.stderr or '')[-800:]}"
            );
            assert "--- Results (1 games) ---" in proc.stdout , (
                f"chess run {i + 1} printed no result tally, so its time is "
                f"the cost of exiting early: {proc.stdout[-400:]}"
            );
        }
        median = statistics.median(runs);
        publish(
            "chess-aot",
            f"chess AOT x{CHESS_RUNS}: median {median:.3f}s, "
            f"min {min(runs):.3f}s, max {max(runs):.3f}s "
            f"(recorded {CHESS_RECORDED_S}, ceiling {CHESS_CEILING_S:.2f}s)"
        );
        assert median <= CHESS_CEILING_S , (
            f"AOT-compiled chess now takes {median:.3f}s per `-b 1` game "
            f"(runs: {[round(s, 3) for s in runs]}). Recorded truth is "
            f"{CHESS_RECORDED_S} and the ceiling is {CHESS_CEILING_S:.2f}s, "
            "which is 3x the slower recorded figure -- this is a real "
            "execution regression in the AOT lane, not measurement noise."
        );
    }
}
