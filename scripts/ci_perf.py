#!/usr/bin/env python3
"""Apply budgets to existing CI commands without rerunning their workloads.

GNU time supplies kernel accounting; GNU timeout bounds the command's process
group. Linux max RSS is the largest individual process high-water mark, including
waited-for descendants, not simultaneous process-tree memory. Startup clocks
span the workflow's existing launch and HTTP-readiness steps.

Use the runner's Python so observing Jac does not compile or warm Jac itself.
"""

from __future__ import annotations

import argparse
from dataclasses import asdict, dataclass
import json
import math
import os
from pathlib import Path
import re
import subprocess
import tempfile
import time


ROOT = Path(__file__).resolve().parent.parent


@dataclass(frozen=True)
class Budget:
    wall_seconds: float
    max_rss_mib: float | None = None

    def __post_init__(self) -> None:
        for value in (self.wall_seconds, self.max_rss_mib):
            if value is not None and (not math.isfinite(value) or value <= 0):
                raise ValueError("budgets must be finite positive numbers")


@dataclass(frozen=True)
class Measurement:
    wall_seconds: float
    exit_code: int = 0
    cpu_seconds: float | None = None
    max_rss_mib: float | None = None

    def failures(self, budget: Budget) -> list[str]:
        failures: list[str] = []
        if self.wall_seconds > budget.wall_seconds or self.exit_code == 124:
            failures.append(
                f"wall time {self.wall_seconds:.2f}s exceeded {budget.wall_seconds:g}s"
            )
        if budget.max_rss_mib is not None:
            if self.max_rss_mib is None:
                failures.append("missing peak RSS measurement")
            elif self.max_rss_mib > budget.max_rss_mib:
                failures.append(
                    f"peak process RSS {self.max_rss_mib:.1f} MiB exceeded "
                    f"{budget.max_rss_mib:g} MiB"
                )
        if self.exit_code:
            failures.append(f"command exited with status {self.exit_code}")
        return failures


def write_json(path: Path, value: object) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_suffix(".tmp")
    temporary.write_text(json.dumps(value, indent=2) + "\n")
    temporary.replace(path)


def record(
    output: Path, phase: str, measurement: Measurement, budget: Budget,
    command: list[str] | None = None,
) -> int:
    failures = measurement.failures(budget)
    write_json(output / f"{phase}.json", {
        **asdict(measurement), "phase": phase, "budget": asdict(budget),
        "command": command, "failures": failures,
        "commit": os.environ.get("GITHUB_SHA"),
        "run_id": os.environ.get("GITHUB_RUN_ID"),
        "runner": os.environ.get("RUNNER_NAME"),
    })
    print(f"{phase}: {json.dumps(asdict(measurement))}", flush=True)
    for failure in failures:
        print(f"::error title=Performance budget::{phase}: {failure}", flush=True)
    return measurement.exit_code or int(bool(failures))


def run_command(output: Path, phase: str, budget: Budget, command: list[str]) -> int:
    if not command:
        raise ValueError("run requires a command after --")
    if budget.max_rss_mib is None:
        raise ValueError("command budgets must specify max_rss_mib")
    output.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix="accounting-", dir=output) as directory:
        accounting = Path(directory) / "time.json"
        result = subprocess.run([
            "/usr/bin/time", "--quiet", "--output", str(accounting), "--format",
            '{"wall_seconds":%e,"user_seconds":%U,"system_seconds":%S,"rss_kib":%M}',
            "timeout", "--kill-after=5s", f"{budget.wall_seconds:g}s", *command,
        ], env={**os.environ, "LC_ALL": "C"})
        raw = json.loads(accounting.read_text())
    measurement = Measurement(
        wall_seconds=raw["wall_seconds"],
        exit_code=result.returncode if result.returncode >= 0 else 128 - result.returncode,
        cpu_seconds=raw["user_seconds"] + raw["system_seconds"],
        max_rss_mib=raw["rss_kib"] / 1024,
    )
    return record(output, phase, measurement, budget, command)


def startup(output: Path, phase: str, budget: Budget, action: str) -> int:
    if budget.max_rss_mib is not None:
        raise ValueError("startup clocks only measure wall time")
    state = output / f"{phase}.clock.json"
    if action == "start":
        # A second start must not silently reset a deadline.
        if state.exists():
            raise ValueError(f"{phase}: startup clock already exists")
        write_json(state, {"started": time.monotonic()})
        return 0
    elapsed = time.monotonic() - json.loads(state.read_text())["started"]
    measurement = Measurement(wall_seconds=elapsed)
    if action == "ready" or measurement.failures(budget):
        return record(output, phase, measurement, budget)
    return 0


def report(output: Path, budgets: dict[str, Budget]) -> int:
    lines = [
        "## Pack smoke performance", "",
        "Existing workload, existing cache order. RSS is the largest process peak, "
        "not a sum across processes.", "",
        "| Phase | Wall / budget (s) | CPU (s) | Peak RSS / budget (MiB) | Result |",
        "| --- | ---: | ---: | ---: | --- |",
    ]
    failed = False
    for phase, budget in budgets.items():
        path = output / f"{phase}.json"
        if not path.exists():
            lines.append(f"| {phase} | | | | Missing |")
            print(f"::error title=Performance budget::{phase}: missing measurement")
            failed = True
            continue
        raw = json.loads(path.read_text())
        measurement = Measurement(**{key: raw[key] for key in Measurement.__dataclass_fields__})
        failures = measurement.failures(budget)
        failed |= bool(failures)
        cpu = "" if measurement.cpu_seconds is None else f"{measurement.cpu_seconds:.2f}"
        memory = "" if measurement.max_rss_mib is None else (
            f"{measurement.max_rss_mib:.1f} / {budget.max_rss_mib:g}"
        )
        lines.append(
            f"| {phase} | {measurement.wall_seconds:.2f} / {budget.wall_seconds:g} | "
            f"{cpu} | {memory} | {'; '.join(failures) if failures else 'Pass'} |"
        )
    markdown = "\n".join(lines) + "\n"
    output.mkdir(parents=True, exist_ok=True)
    (output / "summary.md").write_text(markdown)
    print(markdown)
    summary = os.environ.get("GITHUB_STEP_SUMMARY")
    if summary:
        with open(summary, "a") as stream:
            stream.write(markdown)
    return int(failed)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--budgets", type=Path, default=ROOT / ".github/pack-smoke-budgets.json")
    parser.add_argument("--output", type=Path, default=Path(
        os.environ.get("RUNNER_TEMP", tempfile.gettempdir())
    ) / "pack-smoke-performance")
    subparsers = parser.add_subparsers(dest="action", required=True)
    run = subparsers.add_parser("run")
    run.add_argument("phase")
    run.add_argument("command", nargs=argparse.REMAINDER)
    for action in ("start", "deadline", "ready"):
        subparsers.add_parser(action).add_argument("phase")
    subparsers.add_parser("report")
    args = parser.parse_args()
    try:
        raw = json.loads(args.budgets.read_text())
        budgets = {phase: Budget(**values) for phase, values in raw.items()}
        if not budgets or any(not re.fullmatch(r"[a-z][a-z0-9-]*", phase) for phase in budgets):
            raise ValueError("budget phase names must contain lowercase letters, digits or hyphens")
        if args.action == "report":
            return report(args.output, budgets)
        budget = budgets[args.phase]
        if args.action == "run":
            command = args.command[1:] if args.command[:1] == ["--"] else args.command
            return run_command(args.output, args.phase, budget, command)
        return startup(args.output, args.phase, budget, args.action)
    except (OSError, ValueError, KeyError, TypeError) as error:
        print(f"::error title=Performance measurement::{error}", flush=True)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
