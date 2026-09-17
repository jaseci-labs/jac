"""Report the pack smoke's performance against main; gate only on what is stable.

The workflow records each foreground command once with GNU time (wall, CPU,
peak RSS, exit status) and each server start with two uptime stamps. Nothing
here repeats a workload, and this helper's own cost is outside every number.

Hard failures are the things a shared runner cannot fake: the command failed,
it hung past its ceiling, its peak RSS crossed the limit, or a measurement is
missing. Wall time is never gated. It is compared with the median of the last
main runs and shown as a delta, with a warning annotation when the delta
crosses the alert ratio. Linux peak RSS is the largest process high-water
mark, including waited-for children, not a sum across a process tree.
"""

import argparse;
import http.client;
import io;
import json;
import math;
import os;
import re;
import statistics;
import sys;
import tempfile;
import urllib.request;
import zipfile;
import from pathlib { Path }
import from jaclang.runtime.object_model { asdict }

glob ARTIFACT_NAME: str = "pack-smoke-performance",
     REDIRECTS: set[int] = {301, 302, 303, 307, 308},
     MIN_BASELINE_SAMPLES: int = 3,
     HANG_STATUS: int = 124;

def finite_positive(value: float | None) -> bool {
    return value is not None and math.isfinite(value) and value > 0;
}

obj Phase {
    has name: str,
        measure: str,
        hang_seconds: float | None = None,
        max_rss_mib: float | None = None;

    def postinit {
        if not re.fullmatch(r"[a-z][a-z0-9-]*", self.name) {
            raise ValueError(
                "phase names must contain lowercase letters, digits or hyphens"
            );
        }
        if self.measure == "command" {
            if not finite_positive(self.hang_seconds)
                or not finite_positive(self.max_rss_mib) {
                raise ValueError(
                    f"{self.name}: a command phase needs a finite positive "
                    "hang_seconds and max_rss_mib"
                );
            }
        } elif self.measure == "readiness" {
            if self.hang_seconds is not None or self.max_rss_mib is not None {
                raise ValueError(
                    f"{self.name}: a readiness phase carries no hang ceiling or "
                    "memory limit; the workflow's wait step is its ceiling"
                );
            }
        } else {
            raise ValueError(f"{self.name}: measure must be command or readiness");
        }
    }
}

obj BaselinePolicy {
    has workflow: str = "ci.yml",
        branch: str = "main",
        runs: int = 10,
        alert_ratio: float = 1.25;

    def postinit {
        if not isinstance(self.runs, int) or self.runs < MIN_BASELINE_SAMPLES {
            raise ValueError(
                f"baseline runs must be an integer of at least {MIN_BASELINE_SAMPLES}"
            );
        }
        if not finite_positive(self.alert_ratio) or self.alert_ratio <= 1 {
            raise ValueError("alert_ratio must be a finite number above 1");
        }
        if not self.workflow or not self.branch {
            raise ValueError("the baseline needs a workflow file and a branch");
        }
    }
}

obj Policy {
    has phases: list[Phase],
        baseline: BaselinePolicy;
}

def load_policy(path: Path) -> Policy {
    raw = json.loads(path.read_text());
    phases = [Phase(name=name, **values) for (name, values) in raw["phases"].items()];
    if not phases {
        raise ValueError("the policy lists no phases");
    }
    return Policy(phases=phases, baseline=BaselinePolicy(**raw.get("baseline", {})));
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

    def completed -> bool {
        return self.exit_code == 0;
    }

    def hung -> bool {
        return self.exit_code == HANG_STATUS;
    }

    def failures(phase: Phase) -> list[str] {
        errors: list[str] = [];
        if self.hung() {
            errors.append(
                f"hung past the {phase.hang_seconds}s ceiling and was stopped"
            );
            return errors;
        }
        if self.exit_code {
            errors.append(f"command exited with status {self.exit_code}");
        }
        if phase.max_rss_mib is not None {
            if self.max_rss_mib is None {
                errors.append("missing peak RSS measurement");
            } elif self.max_rss_mib > phase.max_rss_mib {
                errors.append(
                    f"peak process RSS {self.max_rss_mib:.1f} MiB exceeded "
                    f"{phase.max_rss_mib:g} MiB"
                );
            }
        }
        return errors;
    }
}

def read_phase(output: Path, phase: Phase) -> Measurement {
    if phase.measure == "command" {
        raw = json.loads((output / f"{phase.name}.time.json").read_text());
        return Measurement(
            wall_seconds=raw["wall_seconds"],
            exit_code=raw["exit_code"],
            cpu_seconds=raw["user_seconds"] + raw["system_seconds"],
            max_rss_mib=raw["rss_kib"] / 1024
        );
    }
    started = float((output / f"{phase.name}.start").read_text().split()[0]);
    ready = float((output / f"{phase.name}.ready").read_text().split()[0]);
    return Measurement(wall_seconds=ready - started);
}

obj Baseline {
    has samples: dict[str, list[float]],
        note: str;

    def median(phase: str) -> float | None {
        values = self.samples.get(phase, []);
        if len(values) < MIN_BASELINE_SAMPLES {
            return None;
        }
        return statistics.median(values);
    }
}

def clean_samples(values: object) -> list[float] {
    samples: list[float] = [];
    if not isinstance(values, list) {
        return samples;
    }
    for value in values {
        if isinstance(value, (int, float)) and finite_positive(float(value)) {
            samples.append(float(value));
        }
    }
    return samples;
}

"""GitHub's REST API for one repository; tests inject a transport instead of HTTPS."""
obj GitHub {
    has repository: str,
        token: str = "",
        host: str = "api.github.com",
        transport: Callable[[str], tuple[int, str | None, bytes]] | None = None;

    def request(path: str) -> tuple[int, str | None, bytes] {
        if self.transport is not None {
            return self.transport(path);
        }
        connection = http.client.HTTPSConnection(self.host, timeout=60);
        connection.request(
            "GET",
            path,
            headers={
                "Authorization": f"Bearer {self.token}",
                "Accept": "application/vnd.github+json",
                "User-Agent": "jac-ci-perf",
                "X-GitHub-Api-Version": "2022-11-28"
            }
        );
        response = connection.getresponse();
        result = (response.status, response.getheader("Location"), response.read());
        connection.close();
        return result;
    }

    def get(path: str) -> bytes {
        (status, _, body) = self.request(path);
        if status != 200 {
            raise OSError(f"GET {path} returned HTTP {status}");
        }
        return body;
    }

    def download(path: str) -> bytes {
        (status, location, body) = self.request(path);
        if status == 200 {
            return body;
        }
        # The archive lives on blob storage behind a signed redirect; the API
        # token must not travel there.
        if status in REDIRECTS and location {
            with urllib.request.urlopen(location, timeout=120) as stream {
                return stream.read();
            }
        }
        raise OSError(f"GET {path} returned HTTP {status}");
    }
}

"""Fill each phase with wall times from the newest main runs where that phase completed.

A run where one phase failed still serves the others, and a phase keeps
reading older runs until it has the configured number of samples or the
listing runs out, so a bad week on main cannot silence a comparison.
"""
def fetch_baseline(
    client: GitHub,
    policy: BaselinePolicy,
    phases: list[Phase],
    skip_run: str | None = None
) -> Baseline {
    samples: dict[str, list[float]] = {};
    for phase in phases {
        samples[phase.name] = [];
    }
    used: list[str] = [];
    listing = json.loads(
        client.get(
            f"/repos/{client.repository}/actions/workflows/{policy.workflow}/runs"
            f"?branch={policy.branch}&event=push&per_page={policy.runs * 3}"
        )
    );
    for run in listing["workflow_runs"] {
        short = [
            name
            for (name, values) in samples.items()
            if len(values) < policy.runs
        ];
        if not short {
            break;
        }
        run_id = str(run["id"]);
        if run_id == skip_run {
            continue;
        }
        artifacts = [
            artifact
            for artifact in json.loads(
                client.get(
                    f"/repos/{client.repository}/actions/runs/{run_id}/artifacts"
                    f"?name={ARTIFACT_NAME}"
                )
            )["artifacts"]
            if not artifact.get("expired")
        ];
        if not artifacts {
            continue;
        }
        archive = zipfile.ZipFile(
            io.BytesIO(
                client.download(
                    f"/repos/{client.repository}/actions/artifacts/"
                    f"{artifacts[0]['id']}/zip"
                )
            )
        );
        taken = False;
        for name in short {
            try {
                record = json.loads(archive.read(f"{name}.json"));
            } except KeyError {
                continue;
            }
            if record.get("exit_code", 0) != 0 {
                continue;
            }
            wall = clean_samples([record.get("wall_seconds")]);
            if wall {
                samples[name].extend(wall);
                taken = True;
            }
        }
        if taken {
            used.append(run_id);
        }
    }
    if not used {
        return Baseline(
            samples=samples,
            note=f"unavailable: no {policy.branch} run of {policy.workflow} has a "
            f"{ARTIFACT_NAME} artifact yet"
        );
    }
    counts = ", ".join(f"{name} {len(values)}" for (name, values) in samples.items());
    return Baseline(
        samples=samples,
        note=f"median per phase over the last {len(used)} {policy.branch} pushes of "
        f"{policy.workflow} (runs {used[-1]} to {used[0]}; samples: {counts})"
    );
}

def resolve_baseline(args: argparse.Namespace, policy: Policy) -> Baseline {
    if args.no_baseline {
        return Baseline(samples={}, note="disabled");
    }
    if args.baseline is not None {
        raw = json.loads(args.baseline.read_text());
        return Baseline(
            samples={name: clean_samples(values) for (name, values) in raw.items()},
            note=f"samples from {args.baseline}"
        );
    }
    token = os.environ.get("GITHUB_TOKEN");
    repository = os.environ.get("GITHUB_REPOSITORY");
    if not token or not repository {
        return Baseline(
            samples={}, note="unavailable: GITHUB_TOKEN or GITHUB_REPOSITORY not set"
        );
    }
    try {
        return fetch_baseline(
            GitHub(repository=repository, token=token),
            policy.baseline,
            policy.phases,
            os.environ.get("GITHUB_RUN_ID")
        );
    } except (OSError, ValueError, KeyError, TypeError, zipfile.BadZipFile) as error {
        print(
            "::warning title=Performance baseline::could not read "
            f"{policy.baseline.branch} runs: {error}",
            flush=True
        );
        return Baseline(samples={}, note=f"unavailable: {error}");
    }
}

def percent(ratio: float) -> str {
    delta = round((ratio - 1) * 100);
    return f"+{delta}%" if delta >= 0 else f"{delta}%";
}

def write_json(path: Path, value: dict[str, object]) {
    path.parent.mkdir(parents=True, exist_ok=True);
    temporary = path.with_suffix(".tmp");
    temporary.write_text(json.dumps(value, indent=2) + "\n");
    temporary.replace(path);
}

obj Row {
    has cells: list[str],
        failed: bool;
}

def report_phase(
    output: Path,
    phase: Phase,
    measurement: Measurement,
    baseline: Baseline,
    alert_ratio: float
) -> Row {
    errors = measurement.failures(phase);
    median = baseline.median(phase.name);
    ratio = None;
    if measurement.completed() and median is not None {
        ratio = measurement.wall_seconds / median;
    }
    write_json(
        output / f"{phase.name}.json",
        {
            ** asdict(measurement),
            "phase": phase.name,
            "policy": asdict(phase),
            "failures": errors,
            "baseline_median_seconds": median,
            "baseline_ratio": ratio,
            "commit": os.environ.get("GITHUB_SHA"),
            "run_id": os.environ.get("GITHUB_RUN_ID"),
            "runner": os.environ.get("RUNNER_NAME")
        }
    );
    print(f"{phase.name}: {json.dumps(asdict(measurement))}", flush=True);
    for error in errors {
        print(f"::error title=Performance gate::{phase.name}: {error}", flush=True);
    }
    result = "; ".join(errors) if errors else "Pass";
    delta = "";
    if ratio is not None {
        delta = percent(ratio);
        if ratio > alert_ratio {
            print(
                f"::warning title=Performance::{phase.name}: wall "
                f"{measurement.wall_seconds:.2f}s is {delta} against main's median "
                f"{median:.2f}s",
                flush=True
            );
            if not errors {
                result = f"Pass, {delta} vs main";
            }
        }
    }
    if measurement.hung() {
        # A stopped command leaves only the launcher's accounting behind.
        cells = [phase.name, f"> {phase.hang_seconds:g}", "", "", "", ""];
    } else {
        cells = [
            phase.name,
            f"{measurement.wall_seconds:.2f}",
            "" if median is None else f"{median:.2f}",
            delta,
            "" if measurement.cpu_seconds is None else f"{measurement.cpu_seconds:.2f}",
            ""
                if measurement.max_rss_mib is None
                else f"{measurement.max_rss_mib:.1f} / {phase.max_rss_mib:g}"
        ];
    }
    cells.append(result);
    return Row(cells=cells, failed=bool(errors));
}

def report_results(output: Path, policy: Policy, baseline: Baseline) -> int {
    lines = [
        "## Pack smoke performance",
        "",
        f"Baseline: {baseline.note}. Wall time is compared, not gated; exit status, "
        "hang ceilings and peak RSS are the gates. RSS is the largest process peak, "
        "not a sum across processes.",
        "",
        "| Phase | Wall (s) | Main median (s) | Delta | CPU (s) "
        "| Peak RSS / limit (MiB) | Result |",
        "| --- | ---: | ---: | ---: | ---: | ---: | --- |"
    ];
    failed = False;
    for phase in policy.phases {
        try {
            measurement = read_phase(output, phase);
        } except FileNotFoundError {
            lines.append(f"| {phase.name} | | | | | | Missing |");
            print(f"::error title=Performance gate::{phase.name}: missing measurement");
            failed = True;
            continue;
        }
        row = report_phase(
            output, phase, measurement, baseline, policy.baseline.alert_ratio
        );
        failed |= row.failed;
        lines.append("| " + " | ".join(row.cells) + " |");
    }
    markdown = "\n".join(lines) + "\n";
    output.mkdir(parents=True, exist_ok=True);
    (output / "summary.md").write_text(markdown);
    write_json(
        output / "baseline.json", {"note": baseline.note, "samples": baseline.samples}
    );
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
        "--policy",
        type=Path,
        `default=Path(
            os.environ.get("JAC_CI_PERF_POLICY")
                or repo / ".github/pack-smoke-perf.json"
        )
    );
    parser.add_argument(
        "--output",
        type=Path,
        `default=Path(os.environ.get("RUNNER_TEMP", tempfile.gettempdir()))
            / ARTIFACT_NAME
    );
    parser.add_argument(
        "--baseline",
        type=Path,
        `default=None,
        help="JSON {phase: [wall seconds, ...]} to compare with instead of main's runs"
    );
    parser.add_argument(
        "--no-baseline", action="store_true", help="report without comparing to main"
    );
    args = parser.parse_args(argv);
    try {
        policy = load_policy(args.policy);
        return report_results(args.output, policy, resolve_baseline(args, policy));
    } except (OSError, ValueError, KeyError, TypeError) as error {
        print(f"::error title=Performance measurement::{error}", flush=True);
        return 1;
    }
}

with entry:__main__ {
    sys.`exit(main());
}
