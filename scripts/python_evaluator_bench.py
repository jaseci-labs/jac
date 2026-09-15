"""Compare execution of identical Python bytecode in two pinned runtimes.

Run with any Python >= 3.11; both subjects must match bootstrap's CPython pin:

    python3 scripts/python_evaluator_bench.py \
        --baseline /path/to/host/python3.14 \
        --candidate /path/to/jacpython/python3.14 --output /tmp/evaluator.json

Compilation, imports, process startup, and warmup are outside measured regions.
Each sample runs in a fresh process; baseline/candidate order alternates. This
is an execution benchmark, not proof that the candidate evaluator is native Jac.
"""

from __future__ import annotations

import argparse
from collections.abc import Callable
from dataclasses import asdict, dataclass
import hashlib
import json
import marshal
import math
from pathlib import Path
import platform
import statistics
import subprocess
import sys
import sysconfig
import tempfile
import time
from types import CodeType
from typing import TypedDict, cast


ROOT = Path(__file__).resolve().parents[1]
FIXTURE = ROOT / "jac/tests/compiler/fixtures/python_evaluator_workloads.py"
PIN = ROOT / "jac/bootstrap/python/sources.json"


class SampleRecord(TypedDict):
    loops: int
    seconds: float
    checksum: int


class PreparedWorkloads(TypedDict):
    cases: list[str]
    source_sha256: str
    bytecode_sha256: str


class Comparison(TypedDict):
    baseline: list[SampleRecord]
    candidate: list[SampleRecord]
    baseline_median_seconds_per_call: float
    candidate_median_seconds_per_call: float
    paired_ratios: list[float]
    median_ratio: float
    min_ratio: float
    max_ratio: float


@dataclass(frozen=True)
class Sample:
    loops: int
    seconds: float
    checksum: int

    @property
    def per_call(self) -> float:
        return self.seconds / self.loops


def runtime_metadata() -> dict[str, object]:
    return {
        "executable": sys.executable,
        "version": list(sys.version_info[:3]),
        "implementation": sys.implementation.name,
        "build": sys.version,
        "platform": sys.platform,
        "machine": platform.machine(),
        "debug": bool(sysconfig.get_config_var("Py_DEBUG")),
        "free_threaded": bool(sysconfig.get_config_var("Py_GIL_DISABLED")),
        "tail_call_interpreter": bool(sysconfig.get_config_var("Py_TAIL_CALL_INTERP")),
        "configure": sysconfig.get_config_var("CONFIG_ARGS"),
        "cflags": sysconfig.get_config_var("PY_CFLAGS"),
        "cflags_nodist": sysconfig.get_config_var("PY_CFLAGS_NODIST"),
        "jit_enabled": bool(getattr(sys, "_jit", None) and sys._jit.is_enabled()),
        "clock_resolution": time.get_clock_info("perf_counter").resolution,
    }


def load_workloads(artifact: Path) -> dict[str, tuple[Callable[[], int], int]]:
    with artifact.open("rb") as stream:
        version, code = marshal.load(stream)
    if tuple(version) != sys.version_info[:3] or not isinstance(code, CodeType):
        raise RuntimeError("bytecode artifact does not match this interpreter")
    namespace: dict[str, object] = {"__name__": "evaluator_workloads"}
    exec(code, namespace)
    return cast(dict[str, tuple[Callable[[], int], int]], namespace["WORKLOADS"])


def measure(function: Callable[[], int], expected: int, loops: int) -> Sample:
    checksum = 0
    start = time.perf_counter()
    for _ in range(loops):
        checksum += function()
    seconds = time.perf_counter() - start
    if checksum != expected * loops:
        raise AssertionError(f"incorrect result: {checksum} != {expected * loops}")
    return Sample(loops, seconds, checksum)


def worker_main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("mode", choices=["_prepare", "_sample", "_metadata"])
    parser.add_argument("--artifact", type=Path)
    parser.add_argument("--case")
    parser.add_argument("--loops", type=int, default=0)
    parser.add_argument("--warmups", type=int, default=128)
    parser.add_argument("--min-time", type=float, default=0.1)
    args = parser.parse_args()
    if args.mode == "_metadata":
        print(json.dumps(runtime_metadata()))
        return
    if args.artifact is None:
        parser.error("--artifact is required")
    if args.mode == "_prepare":
        # Only the reference compiler produces the artifact. Candidate startup
        # may use its own compiler, but the timed functions cannot do so.
        source = FIXTURE.read_bytes()
        code = compile(source, "<python-evaluator-workloads>", "exec", dont_inherit=True)
        with args.artifact.open("wb") as stream:
            marshal.dump((tuple(sys.version_info[:3]), code), stream)
        cases = load_workloads(args.artifact)
        for name, (function, expected) in cases.items():
            result = function()
            if result != expected:
                raise AssertionError(f"{name}: {result} != {expected}")
        print(json.dumps({
            "cases": list(cases),
            "source_sha256": hashlib.sha256(source).hexdigest(),
            "bytecode_sha256": hashlib.sha256(args.artifact.read_bytes()).hexdigest(),
        }))
        return
    if args.case is None:
        parser.error("--case is required")
    function, expected = load_workloads(args.artifact)[args.case]
    for _ in range(args.warmups):
        result = function()
        if result != expected:
            raise AssertionError(f"{args.case}: {result} != {expected}")
    loops = args.loops
    if loops == 0:
        loops = 1
        while True:
            calibration = measure(function, expected, loops)
            if calibration.seconds >= args.min_time:
                break
            loops *= 2
    print(json.dumps(asdict(measure(function, expected, loops))))


def run_worker(executable: Path, *arguments: str) -> dict[str, object]:
    result = subprocess.run(
        [str(executable), "-I", "-S", str(Path(__file__).resolve()), *arguments],
        capture_output=True, text=True, timeout=120, check=False,
    )
    if result.returncode:
        raise RuntimeError(
            f"{executable} exited {result.returncode}:\n{result.stdout}\n{result.stderr}"
        )
    return json.loads(result.stdout)


def validate_runtimes(baseline: dict[str, object], candidate: dict[str, object]) -> None:
    pin = json.loads(PIN.read_text())["cpython"]
    version = [int(part) for part in pin["version"].split(".")]
    for name, runtime in (("baseline", baseline), ("candidate", candidate)):
        if runtime["implementation"] != "cpython" or runtime["version"] != version:
            raise ValueError(f"{name} must use the pinned CPython {pin['version']}")
    for field in ("platform", "machine", "debug", "free_threaded", "jit_enabled"):
        if baseline[field] != candidate[field]:
            raise ValueError(f"incomparable runtime setting {field}: {baseline[field]} != {candidate[field]}")


def comparison(baseline: list[Sample], candidate: list[Sample]) -> Comparison:
    if not baseline or len(baseline) != len(candidate):
        raise ValueError("expected equal nonempty sample sets")
    ratios: list[float] = []
    for before, after in zip(baseline, candidate, strict=True):
        if before.loops != after.loops or before.checksum != after.checksum:
            raise ValueError("paired samples must use identical iterations and results")
        if before.loops < 1 or any(
            not math.isfinite(duration) or duration <= 0
            for duration in (before.seconds, after.seconds)
        ):
            raise ValueError("sample iterations and durations must be positive and finite")
        ratios.append(after.per_call / before.per_call)
    return {
        "baseline": [asdict(sample) for sample in baseline],
        "candidate": [asdict(sample) for sample in candidate],
        "baseline_median_seconds_per_call": statistics.median(s.per_call for s in baseline),
        "candidate_median_seconds_per_call": statistics.median(s.per_call for s in candidate),
        "paired_ratios": ratios,
        "median_ratio": statistics.median(ratios),
        "min_ratio": min(ratios),
        "max_ratio": max(ratios),
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--baseline", type=Path, required=True)
    parser.add_argument("--candidate", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--samples", type=int, default=7)
    parser.add_argument("--warmups", type=int, default=128)
    parser.add_argument("--min-time", type=float, default=0.1)
    parser.add_argument("--case", action="append", dest="cases")
    parser.add_argument("--max-slowdown", type=float,
                        help="fail if any case's median candidate/baseline ratio exceeds this value")
    args = parser.parse_args()
    if args.samples < 1 or args.warmups < 1:
        parser.error("samples and warmups must be positive")
    if not math.isfinite(args.min_time) or args.min_time <= 0:
        parser.error("min-time must be positive and finite")
    if args.max_slowdown is not None and (
        not math.isfinite(args.max_slowdown) or args.max_slowdown <= 0
    ):
        parser.error("max-slowdown must be positive and finite")
    baseline_path = args.baseline.resolve(strict=True)
    candidate_path = args.candidate.resolve(strict=True)
    baseline_info = run_worker(baseline_path, "_metadata")
    candidate_info = run_worker(candidate_path, "_metadata")
    validate_runtimes(baseline_info, candidate_info)
    results: dict[str, Comparison] = {}
    regressions: list[str] = []
    with tempfile.TemporaryDirectory(prefix="jac-evaluator-bench-") as directory:
        artifact = Path(directory) / "workloads.marshal"
        prepared = cast(PreparedWorkloads, run_worker(
            baseline_path, "_prepare", "--artifact", str(artifact),
        ))
        cases = args.cases or prepared["cases"]
        if len(set(cases)) != len(cases) or any(case not in prepared["cases"] for case in cases):
            parser.error(f"choose distinct workloads from {prepared['cases']}")
        for case in cases:
            paired: dict[str, list[Sample]] = {"baseline": [], "candidate": []}
            loops = 0
            for index in range(args.samples):
                order = ("baseline", "candidate") if index % 2 == 0 else ("candidate", "baseline")
                for name in order:
                    executable = baseline_path if name == "baseline" else candidate_path
                    raw = run_worker(
                        executable, "_sample", "--artifact", str(artifact), "--case", case,
                        "--loops", str(loops), "--warmups", str(args.warmups),
                        "--min-time", str(args.min_time),
                    )
                    sample = Sample(**cast(SampleRecord, raw))
                    loops = sample.loops
                    paired[name].append(sample)
            result = comparison(paired["baseline"], paired["candidate"])
            results[case] = result
            ratio = result["median_ratio"]
            print(f"{case}: {ratio:.3f}x candidate/baseline", flush=True)
            if args.max_slowdown is not None and ratio > args.max_slowdown:
                regressions.append(case)
    report = {
        "schema_version": 1,
        "baseline": baseline_info,
        "candidate": candidate_info,
        "same_executable": baseline_path.samefile(candidate_path),
        "source_sha256": prepared["source_sha256"],
        "bytecode_sha256": prepared["bytecode_sha256"],
        "warmups": args.warmups,
        "minimum_sample_seconds": args.min_time,
        "max_slowdown": args.max_slowdown,
        "regressions": regressions,
        "cases": results,
    }
    args.output.write_text(json.dumps(report, indent=2) + "\n")
    if regressions:
        print(f"Slowdown threshold exceeded: {', '.join(regressions)}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    if len(sys.argv) > 1 and sys.argv[1].startswith("_"):
        worker_main()
    else:
        raise SystemExit(main())
