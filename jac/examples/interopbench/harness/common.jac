"""Shared result protocol for interopbench harnesses."""

import hashlib;
import json;
import statistics;
import subprocess;
import from pathlib { Path }


glob DEFAULT_INVOCATIONS: int = 30,
     WARMUP_CALLS: int = 5,
     SIZE_SMALL_CHURN: list[str] = ["200", "20"],
     SIZE_DEFAULT_CHURN: list[str] = ["5000", "500"],
     SIZE_VIEW_DEFAULT: list[str] = ["5000"],
     DEFAULT_WORK: int = 5000,
     DEFAULT_CALLS: int = 500,
     DEFAULT_VIEW_COUNT: int = 5000;


"""Parse one kernel invocation and enforce the canonical output contract."""
def parse_output(stdout: str) -> dict {
    timing: int | None = None;
    metrics: dict[str, int] = {};
    digest_lines: list[str] = [];
    timing_count = 0;
    for line in stdout.splitlines() {
        if not line.strip() {
            continue;
        }
        if line.startswith("ns=") {
            timing_count += 1;
            try {
                timing = int(line[3:]);
            } except ValueError {
                raise ValueError(f"invalid timing line: {line}");
            }
            if timing < 0 {
                raise ValueError(f"negative timing line: {line}");
            }
        } elif line.startswith("m:") {
            metric = line[2:];
            (key, separator, value) = metric.partition("=");
            if not separator or not key or not value {
                raise ValueError(f"invalid metric line: {line}");
            }
            if key in metrics {
                raise ValueError(f"duplicate metric key: {key}");
            }
            try {
                metrics[key] = int(value);
            } except ValueError {
                raise ValueError(f"invalid metric value: {line}");
            }
        } else {
            digest_lines.append(line);
        }
    }
    if timing_count != 1 or timing is None {
        raise ValueError(f"expected exactly one ns= line, found {timing_count}");
    }
    if len(digest_lines) != 1 {
        raise ValueError(
            f"expected exactly one non-empty digest line, found {len(digest_lines)}"
        );
    }
    canonical = digest_lines[0];
    digest = hashlib.sha256(canonical.encode()).hexdigest()[:16];
    return {
        "canonical_digest": canonical,
        "digest": digest,
        "ns": timing,
        "metrics": metrics,

    };
}


"""Run one adapter command and parse its output."""
def run_command(
    command: list[str],
    timeout_s: int,
    cwd: str | None = None,
    env: dict[str, str] | None = None,
) -> dict {
    run_env = None;
    if env is not None {
        import os;
        run_env = os.environ.copy();
        run_env.update(env);
    }
    try {
        result = subprocess.run(
            command,
            capture_output=True,
            text=True,
            timeout=timeout_s,
            cwd=cwd,
            env=run_env,
        );
    } except subprocess.TimeoutExpired {
        raise RuntimeError(
            f"command timed out after {timeout_s}s: {' '.join(command)}"
        );
    }
    if result.returncode != 0 {
        raise RuntimeError(
            f"command failed rc={result.returncode}: {' '.join(command)}\n"
            f"stdout:\n{result.stdout}\nstderr:\n{result.stderr}"
        );
    }
    return parse_output(result.stdout);
}


"""Aggregate repeated invocations and reject unstable output."""
def aggregate_runs(runs: list[dict]) -> dict {
    if not runs {
        raise ValueError("cannot aggregate zero invocations");
    }
    canonical = runs[0]["canonical_digest"];
    metric_keys = set(runs[0]["metrics"].keys());
    for run in runs[1:] {
        if run["canonical_digest"] != canonical {
            raise ValueError("nondeterministic canonical digest across invocations");
        }
        if set(run["metrics"].keys()) != metric_keys {
            raise ValueError("metric-key set changed across invocations");
        }
    }
    times = [run["ns"] for run in runs];
    metric_medians: dict[str, int] = {};
    for key in metric_keys {
        metric_medians[key] = int(
            statistics.median([run["metrics"][key] for run in runs])
        );
    }
    return {
        "median_ns": int(statistics.median(times)),
        "min_ns": min(times),
        "max_ns": max(times),
        "stdev_ns": int(statistics.stdev(times)) if len(times) > 1 else 0,
        "canonical_digest": canonical,
        "digest": runs[0]["digest"],
        "metrics": metric_medians,

    };
}


"""Assert that every named variant has the same canonical digest."""
def compare_oracle(scenario: str, variants: dict[str, dict]) -> str {
    if len(variants) < 2 {
        raise ValueError(f"{scenario}: oracle requires at least two variants");
    }
    digests: set[str] = {cell["canonical_digest"] as str for cell in variants.values()};
    if len(digests) != 1 {
        rendered_parts: list[str] = [];
        for (name, cell) in variants.items() {
            rendered_parts.append(f"{name}={cell['canonical_digest']}");
        }
        rendered = ", ".join(rendered_parts);
        raise ValueError(f"{scenario}: differential identity failed: {rendered}");
    }
    return digests.pop() as str;
}


"""Write schema-versioned family results."""
def write_results(out: Path, family: str, cells: dict) {
    document = {
        "schema_version": 1,
        "suite": "interopbench",
        "family": family,
        "cells": cells,

    };
    out.parent.mkdir(parents=True, exist_ok=True);
    out.write_text(json.dumps(document, indent=2) + "\n");
}
