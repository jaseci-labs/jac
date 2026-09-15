"""Budget existing CI commands with GNU time and timeout; never repeat the work.

The command's accounting excludes this helper. Linux max RSS is the largest
process high-water mark, including waited-for children, not a process-tree sum.
Startup clocks span the workflow's existing launch and HTTP-readiness steps.
"""

import argparse;
import json;
import math;
import os;
import re;
import sys;
import tempfile;
import from pathlib { Path }
import from jaclang.runtime.object_model { asdict }

obj Budget {
    has wall_seconds: float,
        max_rss_mib: float | None = None;

    def postinit {
        if not math.isfinite(self.wall_seconds) or self.wall_seconds <= 0 {
            raise ValueError("wall budget must be a finite positive number");
        }
        limit = self.max_rss_mib;
        if limit is not None and (not math.isfinite(limit) or limit <= 0) {
            raise ValueError("memory budget must be a finite positive number");
        }
    }
}

obj Measurement {
    has wall_seconds: float,
        exit_code: int = 0,
        cpu_seconds: float | None = None,
        max_rss_mib: float | None = None;

    def postinit {
        for value in [self.wall_seconds, self.cpu_seconds, self.max_rss_mib] {
            if value is not None and (not math.isfinite(value) or value < 0) {
                raise ValueError("measurements must be finite nonnegative numbers");
            }
        }
        if not isinstance(self.exit_code, int) or self.exit_code < 0 {
            raise ValueError("exit status must be a nonnegative integer");
        }
    }

    def failures(budget: Budget) -> list[str] {
        errors: list[str] = [];
        if self.wall_seconds > budget.wall_seconds or self.exit_code == 124 {
            errors.append(
                f"wall time {self.wall_seconds:.2f}s exceeded {budget.wall_seconds:g}s"
            );
        }
        if budget.max_rss_mib is not None {
            if self.max_rss_mib is None {
                errors.append("missing peak RSS measurement");
            } elif self.max_rss_mib > budget.max_rss_mib {
                errors.append(
                    f"peak process RSS {self.max_rss_mib:.1f} MiB exceeded {budget.max_rss_mib:g} MiB"
                );
            }
        }
        if self.exit_code {
            errors.append(f"command exited with status {self.exit_code}");
        }
        return errors;
    }
}

def write_json(path: Path, value: dict[str, object]) {
    path.parent.mkdir(parents=True, exist_ok=True);
    temporary = path.with_suffix(".tmp");
    temporary.write_text(json.dumps(value, indent=2) + "\n");
    temporary.replace(path);
}

def record(
    output: Path, phase: str, measurement: Measurement, budget: Budget
) -> list[str] {
    errors = measurement.failures(budget);
    write_json(
        output / f"{phase}.json",
        {
            ** asdict(measurement),
            "phase": phase,
            "budget": asdict(budget),
            "failures": errors,
            "commit": os.environ.get("GITHUB_SHA"),
            "run_id": os.environ.get("GITHUB_RUN_ID"),
            "runner": os.environ.get("RUNNER_NAME")
        }
    );
    print(f"{phase}: {json.dumps(asdict(measurement))}", flush=True);
    for error in errors {
        print(f"::error title=Performance budget::{phase}: {error}", flush=True);
    }
    return errors;
}

def read_phase(output: Path, phase: str, budget: Budget) -> Measurement {
    if budget.max_rss_mib is not None {
        raw = json.loads((output / f"{phase}.time.json").read_text());
        return Measurement(
            wall_seconds=raw["wall_seconds"],
            exit_code=raw["exit_code"],
            cpu_seconds=raw["user_seconds"] + raw["system_seconds"],
            max_rss_mib=raw["rss_kib"] / 1024
        );
    }
    started = float((output / f"{phase}.start").read_text().split()[0]);
    ready = float((output / f"{phase}.ready").read_text().split()[0]);
    return Measurement(wall_seconds=ready - started);
}

def report_results(output: Path, budgets: dict[str, Budget]) -> int {
    lines = [
        "## Pack smoke performance",
        "",
        "Existing workload, existing cache order. RSS is the largest process peak, not a sum across processes.",
        "",
        "| Phase | Wall / budget (s) | CPU (s) | Peak RSS / budget (MiB) | Result |",
        "| --- | ---: | ---: | ---: | --- |"
    ];
    failed = False;
    for (phase, budget) in budgets.items() {
        try {
            measurement = read_phase(output, phase, budget);
        } except FileNotFoundError {
            lines.append(f"| {phase} | | | | Missing |");
            print(f"::error title=Performance budget::{phase}: missing measurement");
            failed = True;
            continue;
        }
        errors = record(output, phase, measurement, budget);
        failed |= bool(errors);
        cpu = ""
            if measurement.cpu_seconds is None
            else f"{measurement.cpu_seconds:.2f}";
        memory = ""
            if measurement.max_rss_mib is None
            else f"{measurement.max_rss_mib:.1f} / {budget.max_rss_mib:g}";
        lines.append(
            f"| {phase} | {measurement.wall_seconds:.2f} / {budget.wall_seconds:g} | "
            f"{cpu} | {memory} | {'; '.join(errors) if errors else 'Pass'} |"
        );
    }
    markdown = "\n".join(lines) + "\n";
    output.mkdir(parents=True, exist_ok=True);
    (output / "summary.md").write_text(markdown);
    print(markdown);
    summary = os.environ.get("GITHUB_STEP_SUMMARY");
    if summary {
        with open(summary, "a") as stream {
            stream.write(markdown);
        }
    }
    return int(failed);
}

def main(argv: list[str] | None = None) -> int {
    parser = argparse.ArgumentParser(description=__doc__);
    repo = Path(__file__).resolve().parent.parent;
    parser.add_argument(
        "--budgets", type=Path, `default=repo / ".github/pack-smoke-budgets.json"
    );
    parser.add_argument(
        "--output",
        type=Path,
        `default=Path(os.environ.get("RUNNER_TEMP", tempfile.gettempdir()))
            / "pack-smoke-performance"
    );
    args = parser.parse_args(argv);
    try {
        raw = json.loads(args.budgets.read_text());
        budgets = {phase: Budget(**values) for (phase, values) in raw.items()};
        if not budgets
            or any(not re.fullmatch(r"[a-z][a-z0-9-]*", phase) for phase in budgets) {
            raise ValueError(
                "budget phase names must contain lowercase letters, digits or hyphens"
            );
        }
        return report_results(args.output, budgets);
    } except (OSError, ValueError, KeyError, TypeError) as error {
        print(f"::error title=Performance measurement::{error}", flush=True);
        return 1;
    }
}

with entry:__main__ {
    sys.`exit(main());
}
