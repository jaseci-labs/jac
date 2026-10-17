#!/usr/bin/env python3
"""Profile a Jac native-backend workload with hardware counters (no perf tool).

Dumps the pre-LLVM IR for a .jac file via the compiler API, builds it with
clang, and runs the bundled `miniperf` counter profiles (core/cache/frontend)
against the result plus any C reference binaries passed with --compare.

Requires: clang, gcc (for miniperf), llvmlite in the running interpreter, and
the repo checkout (uses jac/jaclang sources via sys.path). Linux only:
perf_event_open with paranoid<=2, user-space counting.

Usage:
    python3 scripts/native_profile.py workloads/list.jac \
        [--iters 100000000] [--compare ref1 ref2] [--out bench.json]
"""
from __future__ import annotations

import argparse
import json
import os
import subprocess
import sys
import tempfile
from pathlib import Path

# Dev checkouts may lack the native parser kernel (libjac_compiler.so);
# the store parser is the documented fallback.
os.environ.setdefault("JAC_COMPILER_LIB", "off")

REPO_ROOT = Path(__file__).resolve().parent.parent
JAC_SRC = REPO_ROOT / "jac"
PROFILES = ("core", "cache", "frontend")


def pick_profile_cpu() -> str | None:
    """Pick a CPU for the profiled child. On hybrid x86, perf groups on
    E-cores return zero or partial counts, so pin to the fastest core
    class, preferring the least busy one. None = let miniperf decide."""
    try:
        freqs: dict[int, int] = {}
        for d in Path("/sys/devices/system/cpu").glob("cpu[0-9]*"):
            f = d / "cpufreq" / "cpuinfo_max_freq"
            if f.exists():
                freqs[int(d.name[3:])] = int(f.read_text())
        if not freqs:
            return None
        pcores = [c for c, v in freqs.items() if v == max(freqs.values())]
        idle: dict[int, float] = {}
        with open("/proc/stat") as fh:
            for line in fh:
                parts = line.split()
                if not parts or not parts[0].startswith("cpu"):
                    if idle:
                        break
                    continue
                if len(parts) < 5 or not parts[0][3:].isdigit():
                    continue
                vals = [int(v) for v in parts[1:]]
                total = sum(vals)
                idle[int(parts[0][3:])] = (vals[3] + vals[4]) / total if total else 0.0
        candidates = [c for c in pcores if c in idle]
        if not candidates:
            return str(min(pcores))
        return str(max(candidates, key=lambda c: idle[c]))
    except (OSError, ValueError):
        return None


def ensure_miniperf(cache_dir: Path) -> Path:
    bin_path = cache_dir / "miniperf"
    src_path = REPO_ROOT / "scripts" / "miniperf.c"
    if not bin_path.exists() or src_path.stat().st_mtime > bin_path.stat().st_mtime:
        subprocess.run(
            ["gcc", "-O2", "-o", str(bin_path), str(src_path)], check=True
        )
    return bin_path


def dump_ir(jac_file: Path, out_ll: Path) -> None:
    sys.path.insert(0, str(JAC_SRC))
    from jaclang.compiler.driver.program import JacProgram
    from jaclang.compiler.driver.compile_options import CompileOptions
    from jaclang.compiler.backends.native.na_compile_pass import native_linked_ir_text

    prog = JacProgram()
    mod = prog.compile(
        file_path=str(jac_file),
        options=CompileOptions(
            aot_mode=True, default_codespace="native", force_target_program=True
        ),
    )
    errors = [str(e) for e in prog.errors_had]
    if errors:
        for e in errors:
            print(f"compile error: {e[:300]}", file=sys.stderr)
    ir = native_linked_ir_text(mod)
    out_ll.write_text(ir)
    print(f"IR: {len(ir)} bytes -> {out_ll}")


def build_binary(ll_path: Path, out_bin: Path) -> None:
    # jac modules export jac_entry(); link with a tiny main shim.
    with tempfile.TemporaryDirectory() as td:
        shim = Path(td) / "main_shim.c"
        shim.write_text("extern void jac_entry(void);\nint main(void){ jac_entry(); return 0; }\n")
        obj = Path(td) / "payload.o"
        subprocess.run(
            ["clang", "-O2", "-c", str(ll_path), "-o", str(obj)],
            check=True,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )
        subprocess.run(
            ["clang", "-O2", str(shim), str(obj), "-o", str(out_bin)], check=True
        )


def run_profile(
    miniperf: Path, profile: str, cmd: list[str], env: dict[str, str] | None = None
) -> dict:
    parsed: dict = {}
    for attempt in range(2):
        res = subprocess.run(
            [str(miniperf), profile, *cmd],
            check=True,
            capture_output=True,
            text=True,
            env=env,
        )
        parsed = json.loads(res.stdout.strip().splitlines()[-1])
        if parsed["exit"] != 0:
            raise RuntimeError(
                f"profiled workload exited {parsed['exit']} ({parsed['cmd']}); "
                f"{profile} counters are invalid"
            )
        if any(v for k, v in parsed.items() if k not in ("cmd", "exit")):
            break
        if attempt == 0:
            print(
                f"warning: {profile}: all counters zero for {parsed['cmd']}; retrying",
                file=sys.stderr,
            )
    else:
        print(
            f"warning: {profile}: counters still zero for {parsed['cmd']} after "
            "retry; results unreliable",
            file=sys.stderr,
        )
    rejected = [k for k, v in parsed.items() if v is None]
    if rejected:
        print(
            f"warning: {profile}: kernel rejected counter(s) {', '.join(rejected)} "
            f"for {parsed['cmd']}; reported as 0 (raw codes target "
            "Skylake-descendant cores)",
            file=sys.stderr,
        )
    return parsed


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("workload", type=Path, help=".jac workload to profile")
    ap.add_argument("--iters", type=int, default=100_000_000)
    ap.add_argument("--compare", nargs="*", default=[], help="extra binaries to profile for comparison")
    ap.add_argument("--out", type=Path, default=None, help="write raw JSON results here")
    args = ap.parse_args()

    cache = Path(tempfile.gettempdir()) / "jac-native-profile"
    cache.mkdir(exist_ok=True)
    miniperf = ensure_miniperf(cache)

    profile_cpu = pick_profile_cpu()
    if profile_cpu is not None:
        print(f"pinning profiled children to CPU {profile_cpu}")
        profile_env = os.environ | {"MINIPERF_CPU": profile_cpu}
    else:
        profile_env = None

    ll = cache / f"{args.workload.stem}.ll"
    bin_ = cache / args.workload.stem
    dump_ir(args.workload, ll)
    build_binary(ll, bin_)

    results = {}
    for label, cmd in [("jac", [str(bin_)])] + [
        (Path(c).name, [c]) for c in args.compare
    ]:
        for prof in PROFILES:
            results[f"{label}:{prof}"] = run_profile(miniperf, prof, cmd, profile_env)

    if args.out:
        args.out.write_text(json.dumps(results, indent=2))

    iters = args.iters
    print(f"\n{'binary':24s} {'cyc/it':>7s} {'inst/it':>8s} {'br/it':>6s} {'brm/it':>9s} {'sb-stall/it':>12s}")
    for label in ["jac"] + [Path(c).name for c in args.compare]:
        core = results[f"{label}:core"]
        fe = results[f"{label}:frontend"]
        cyc = core["cycles"] / iters
        inst = core["instructions"] / iters
        br = core["branches"] / iters
        brm = core["branch-misses"] / iters
        sb = (fe.get("rs-stalls-sb") or 0) / iters
        print(f"{label:24s} {cyc:7.2f} {inst:8.2f} {br:6.2f} {brm:9.2e} {sb:12.3f}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
