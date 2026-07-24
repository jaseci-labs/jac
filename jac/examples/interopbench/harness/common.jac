"""Shared result protocol for interopbench harnesses."""

import hashlib;
import json;
import os;
import platform;
import statistics;
import subprocess;
import sys;
import from datetime { datetime, timezone }
import from pathlib { Path }


glob DEFAULT_INVOCATIONS: int = 30,
     WARMUP_CALLS: int = 5,
     SIZE_SMALL_CHURN: list[str] = ["200", "20"],
     SIZE_DEFAULT_CHURN: list[str] = ["5000", "500"],
     DEFAULT_WORK: int = 5000,
     DEFAULT_CALLS: int = 500;


"""Parse one kernel invocation and enforce the canonical output contract."""
def parse_output(stdout: str) -> dict[str, object] {
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
) -> dict[str, object] {
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
def aggregate_runs(runs: list[dict[str, object]]) -> dict[str, object] {
    if not runs {
        raise ValueError("cannot aggregate zero invocations");
    }
    canonical = runs[0]["canonical_digest"] as str;
    metric_keys = set((runs[0]["metrics"] as dict[str, int]).keys());
    for run in runs[1:] {
        if (run["canonical_digest"] as str) != canonical {
            raise ValueError("nondeterministic canonical digest across invocations");
        }
        if set((run["metrics"] as dict[str, int]).keys()) != metric_keys {
            raise ValueError("metric-key set changed across invocations");
        }
    }
    times: list[int] = [run["ns"] as int for run in runs];
    metric_medians: dict[str, int] = {};
    metric_samples: dict[str, list[int]] = {};
    for key in metric_keys {
        raw: list[int] = [(run["metrics"] as dict[str, int])[key] for run in runs];
        metric_samples[key] = raw;
        metric_medians[key] = int(statistics.median(raw));
    }
    return {
        "samples": len(times),
        "median_ns": int(statistics.median(times)),
        "min_ns": min(times),
        "max_ns": max(times),
        "stdev_ns": int(statistics.stdev(times)) if len(times) > 1 else 0,
        "iqr_ns": _iqr(times),
        "canonical_digest": canonical,
        "digest": runs[0]["digest"] as str,
        "metrics": metric_medians,
        "samples_ns": times,
        "metric_samples": metric_samples,

    };
}


"""Interquartile range in ns; a robust spread that ignores tail outliers."""
def _iqr(values: list[int]) -> int {
    if len(values) < 4 {
        return max(values) - min(values);
    }
    (q1, _median, q3) = statistics.quantiles(values, n=4);
    return int(q3 - q1);
}


"""Machine and environment provenance for a results document.

Timings are only comparable within one such block: they carry no
machine-independent threshold and must never be quoted across hosts or
compiler revisions without re-running here."""
def provenance -> dict[str, object] {
    return {
        "captured_utc": datetime.now(timezone.utc).isoformat(),
        "host": platform.node(),
        "platform": platform.platform(),
        "machine": platform.machine(),
        "processor": platform.processor(),
        "cpu_count": os.cpu_count(),
        "python": f"{platform.python_implementation()} {platform.python_version()}",
        "executable": sys.executable,

    };
}


"""Assert that every named variant has the same canonical digest."""
def compare_oracle(scenario: str, variants: dict[str, dict[str, object]]) -> str {
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
def write_results(out: Path, family: str, cells: dict[str, object]) {
    document = {
        "schema_version": 2,
        "suite": "interopbench",
        "family": family,
        "provenance": provenance(),
        "cells": cells,

    };
    out.parent.mkdir(parents=True, exist_ok=True);
    out.write_text(json.dumps(document, indent=2) + "\n");
}
