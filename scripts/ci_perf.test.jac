"""Exercise the pack smoke gates, the comparison with main, and the baseline fetch."""

import contextlib;
import io;
import subprocess;
import from unittest.mock { patch }

obj ProbeResult {
    has code: int,
        output: str;
}

obj PerfProbe {
    has directory: Path;

    def results -> Path {
        return self.directory / "results";
    }

    def policy(hang: float = 5.0, memory: float = 256.0, alert_ratio: float = 1.25) {
        self.results().mkdir(exist_ok=True);
        (self.directory / "policy.json").write_text(
            json.dumps(
                {
                    "baseline": {"alert_ratio": alert_ratio},
                    "phases": {
                        "probe": {
                            "measure": "command",
                            "hang_seconds": hang,
                            "max_rss_mib": memory
                        },
                        "ready": {"measure": "readiness"}
                    }
                }
            )
        );
    }

    def timed(
        wall: float, exit_code: int = 0, rss_mib: float = 64.0, cpu: float = 1.0
    ) {
        (self.results() / "probe.time.json").write_text(
            json.dumps(
                {
                    "wall_seconds": wall,
                    "user_seconds": cpu,
                    "system_seconds": 0.0,
                    "rss_kib": rss_mib * 1024,
                    "exit_code": exit_code
                }
            )
        );
    }

    def ready(started: str = "100.00 400.00", ready: str = "110.00 440.00") {
        (self.results() / "ready.start").write_text(started + "\n");
        (self.results() / "ready.ready").write_text(ready + "\n");
    }

    def baseline(samples: dict[str, list[float]]) -> str {
        path = self.directory / "baseline.json";
        path.write_text(json.dumps(samples));
        return str(path);
    }

    def verdict(*extra: str) -> ProbeResult {
        output = io.StringIO();
        with contextlib.redirect_stdout(output), patch.dict(
            os.environ, {"GITHUB_STEP_SUMMARY": str(self.directory / "summary.md")}
        ) {
            code = main(
                [
                    "--policy",
                    str(self.directory / "policy.json"),
                    "--output",
                    str(self.results()),
                    *extra
                ]
            );
        }
        return ProbeResult(code=code, output=output.getvalue());
    }

    def measurement -> Measurement {
        return read_phase(
            self.results(),
            Phase(name="probe", measure="command", hang_seconds=5.0, max_rss_mib=256.0)
        );
    }
}

def gnu_time_available -> bool {
    try {
        return subprocess.run(
            ["/usr/bin/time", "--version"], capture_output=True
        ).returncode
            == 0;
    } except OSError {
        return False;
    }
}

test "a completed command passes regardless of its wall time" {
    with tempfile.TemporaryDirectory() as directory {
        probe = PerfProbe(directory=Path(directory));
        probe.policy();
        probe.timed(wall=900.0);
        probe.ready();
        result = probe.verdict("--no-baseline");
        assert result.code == 0;
        assert "::error" not in result.output;
        assert "::warning" not in result.output;
        assert "| probe | 900.00 |" in result.output;
        assert "| ready | 10.00 |" in result.output;
        assert "Baseline: disabled" in result.output;
        assert (probe.results() / "probe.json").is_file();
        assert (probe.results() / "baseline.json").is_file();
    }
}

test "a command stopped at the hang ceiling fails without reporting the launcher's accounting" {
    with tempfile.TemporaryDirectory() as directory {
        probe = PerfProbe(directory=Path(directory));
        probe.policy(hang=200.0);
        probe.timed(wall=200.01, exit_code=124, rss_mib=62.0, cpu=0.5);
        probe.ready();
        result = probe.verdict("--no-baseline");
        assert result.code == 1;
        assert "hung past the 200.0s ceiling" in result.output;
        assert "| probe | > 200 |  |  |  |  | hung" in result.output;
        assert "62.0 / 256" not in result.output;
    }
}

test "peak RSS above the limit fails the gate" {
    with tempfile.TemporaryDirectory() as directory {
        probe = PerfProbe(directory=Path(directory));
        probe.policy(memory=128.0);
        probe.timed(wall=1.0, rss_mib=192.0);
        probe.ready();
        result = probe.verdict("--no-baseline");
        assert result.code == 1;
        assert "peak process RSS 192.0 MiB exceeded 128 MiB" in result.output;
    }
}

test "a failed command fails the gate with its status" {
    with tempfile.TemporaryDirectory() as directory {
        probe = PerfProbe(directory=Path(directory));
        probe.policy();
        probe.timed(wall=1.0, exit_code=7);
        probe.ready();
        result = probe.verdict("--no-baseline");
        assert result.code == 1;
        assert "command exited with status 7" in result.output;
    }
}

test "wall time far above main's median warns and still passes" {
    with tempfile.TemporaryDirectory() as directory {
        probe = PerfProbe(directory=Path(directory));
        probe.policy();
        probe.timed(wall=90.0);
        probe.ready();
        baseline = probe.baseline(
            {"probe": [60.0, 62.0, 64.0, 66.0, 68.0], "ready": [10.0, 10.5, 11.0]}
        );
        result = probe.verdict("--baseline", baseline);
        assert result.code == 0;
        assert "::warning title=Performance::probe: wall 90.00s is +41%"
            in result.output;
        assert "| probe | 90.00 | 64.00 | +41% |" in result.output;
        assert "Pass, +41% vs main" in result.output;
        assert "| ready | 10.00 | 10.50 | -5% |" in result.output;
        assert "::warning title=Performance::ready" not in result.output;
        recorded = json.loads((probe.results() / "probe.json").read_text());
        assert recorded["baseline_median_seconds"] == 64.0;
        assert abs(recorded["baseline_ratio"] - 90.0 / 64.0) < 1e-9;
    }
}

test "wall time near main's median is a plain pass" {
    with tempfile.TemporaryDirectory() as directory {
        probe = PerfProbe(directory=Path(directory));
        probe.policy();
        probe.timed(wall=66.0);
        probe.ready();
        baseline = probe.baseline({"probe": [60.0, 64.0, 68.0], "ready": []});
        result = probe.verdict("--baseline", baseline);
        assert result.code == 0;
        assert "::warning" not in result.output;
        assert "| probe | 66.00 | 64.00 | +3% |" in result.output;
        assert "| Pass |" in result.output;
    }
}

test "fewer than three baseline samples means no comparison" {
    with tempfile.TemporaryDirectory() as directory {
        probe = PerfProbe(directory=Path(directory));
        probe.policy();
        probe.timed(wall=500.0);
        probe.ready();
        baseline = probe.baseline({"probe": [60.0, 61.0], "ready": [1, "x", -2.0]});
        result = probe.verdict("--baseline", baseline);
        assert result.code == 0;
        assert "::warning" not in result.output;
        assert "| probe | 500.00 |  |  |" in result.output;
    }
}

test "a failed or stopped command is not compared with main" {
    with tempfile.TemporaryDirectory() as directory {
        probe = PerfProbe(directory=Path(directory));
        probe.policy();
        probe.timed(wall=1.0, exit_code=3);
        probe.ready();
        baseline = probe.baseline({"probe": [60.0, 64.0, 68.0]});
        result = probe.verdict("--baseline", baseline);
        assert result.code == 1;
        assert "::warning" not in result.output;
        assert "| probe | 1.00 | 64.00 |  |" in result.output;
    }
}

test "without a token the report runs with no baseline and no failure" {
    with tempfile.TemporaryDirectory() as directory {
        probe = PerfProbe(directory=Path(directory));
        probe.policy();
        probe.timed(wall=1.0);
        probe.ready();
        with patch.dict(os.environ, {"GITHUB_TOKEN": "", "GITHUB_REPOSITORY": ""}) {
            result = probe.verdict();
        }
        assert result.code == 0;
        assert "Baseline: unavailable: GITHUB_TOKEN" in result.output;
    }
}

test "readiness clocks use elapsed uptime across workflow steps" {
    with tempfile.TemporaryDirectory() as directory {
        probe = PerfProbe(directory=Path(directory));
        probe.policy();
        probe.timed(wall=1.0);
        probe.ready(started="123.45 999.00", ready="223.55 1000.00");
        result = probe.verdict("--no-baseline");
        assert result.code == 0;
        assert "| ready | 100.10 |" in result.output;
    }
}

test "missing measurements fail the gate" {
    with tempfile.TemporaryDirectory() as directory {
        probe = PerfProbe(directory=Path(directory));
        probe.policy();
        result = probe.verdict("--no-baseline");
        assert result.code == 1;
        assert "probe: missing measurement" in result.output;
        assert "ready: missing measurement" in result.output;
        probe.timed(wall=1.0);
        (probe.results() / "ready.start").write_text("1 0\n");
        assert probe.verdict("--no-baseline").code == 1;
    }
}

test "nonfinite limits or measurements cannot disable the gate" {
    with tempfile.TemporaryDirectory() as directory {
        probe = PerfProbe(directory=Path(directory));
        probe.policy(hang=float("nan"));
        assert probe.verdict("--no-baseline").code == 1;
        probe.policy();
        probe.timed(wall=1.0);
        (probe.results() / "ready.start").write_text("0 0\n");
        (probe.results() / "ready.ready").write_text("nan 0\n");
        assert probe.verdict("--no-baseline").code == 1;
        probe.policy(alert_ratio=1.0);
        assert probe.verdict("--no-baseline").code == 1;
    }
}

test "a readiness phase cannot carry command limits" {
    with tempfile.TemporaryDirectory() as directory {
        probe = PerfProbe(directory=Path(directory));
        probe.policy();
        (probe.directory / "policy.json").write_text(
            json.dumps(
                {"phases": {"ready": {"measure": "readiness", "max_rss_mib": 1.0}}}
            )
        );
        result = probe.verdict("--no-baseline");
        assert result.code == 1;
        assert "readiness phase carries no hang ceiling" in result.output;
    }
}

test "GNU time accounting records the command's own peak RSS, including a child" {
    if not gnu_time_available() {
        return;
    }
    with tempfile.TemporaryDirectory() as directory {
        probe = PerfProbe(directory=Path(directory));
        probe.policy(memory=128.0);
        probe.ready();
        for child in [False, True] {
            source = "data=bytearray(192*1024*1024)";
            if child {
                source = (
                    "import subprocess,sys; "
                    f"subprocess.run([sys.executable,'-c',{source!r}], check=True)"
                );
            }
            code = subprocess.run(
                [
                    "/usr/bin/time",
                    "--quiet",
                    "--output",
                    str(probe.results() / "probe.time.json"),
                    "--format",
                    '{"wall_seconds":%e,"user_seconds":%U,"system_seconds":%S,'
                    '"rss_kib":%M,"exit_code":%x}',
                    "timeout",
                    "--kill-after=5s",
                    "60s",
                    sys.executable,
                    "-c",
                    source
                ],
                env={** os.environ, "LC_ALL": "C"}
            ).returncode;
            assert code == 0;
            measured = probe.measurement();
            assert measured.exit_code == 0;
            assert measured.max_rss_mib is not None and measured.max_rss_mib > 128.0;
            assert measured.cpu_seconds is not None and measured.cpu_seconds >= 0;
            result = probe.verdict("--no-baseline");
            assert result.code == 1;
            assert "RSS" in result.output;
        }
    }
}

obj FakeTransport {
    has runs: list[int] = [],
        artifacts: dict[int, list[dict[str, object]]] = {},
        archives: dict[int, bytes] = {},
        downloads: list[int] = [];

    def respond(path: str) -> tuple[int, str | None, bytes] {
        if "/workflows/ci.yml/runs?branch=main&event=push&per_page=9" in path {
            return (
                200,
                None,
                json.dumps(
                    {"workflow_runs": [{"id": run} for run in self.runs]}
                ).encode()
            );
        }
        zipped = re.fullmatch(r"/repos/o/r/actions/artifacts/(\d+)/zip", path);
        if zipped is not None {
            self.downloads.append(int(zipped.group(1)));
            return (200, None, self.archives[int(zipped.group(1))]);
        }
        listed = re.search(
            r"/runs/(\d+)/artifacts\?name=pack-smoke-performance$", path
        );
        assert listed is not None , path;
        return (
            200,
            None,
            json.dumps(
                {"artifacts": self.artifacts.get(int(listed.group(1)), [])}
            ).encode()
        );
    }
}

def archive(records: dict[str, dict[str, object]]) -> bytes {
    buffer = io.BytesIO();
    with zipfile.ZipFile(buffer, "w") as zipped {
        for (name, record) in records.items() {
            zipped.writestr(f"{name}.json", json.dumps(record));
        }
    }
    return buffer.getvalue();
}

test "each phase fills from completed main runs until it has enough samples" {
    phases = [
        Phase(name="probe", measure="command", hang_seconds=5.0, max_rss_mib=1.0),
        Phase(name="ready", measure="readiness")
    ];
    fake = FakeTransport();
    fake.runs = [1, 2, 3, 4, 5, 6, 7, 8];
    fake.artifacts = {
        2: [{"id": 20, "expired": False}],
        3: [{"id": 30, "expired": True}],
        4: [{"id": 40, "expired": False}],
        6: [{"id": 60, "expired": False}],
        7: [{"id": 70, "expired": False}],
        8: [{"id": 80, "expired": False}]
    };
    fake.archives = {
        20: archive(
            {
                "probe": {"wall_seconds": 60.0, "exit_code": 0},
                "ready": {"wall_seconds": 10.0, "exit_code": 0}
            }
        ),
        40: archive(
            {
                "probe": {"wall_seconds": 200.0, "exit_code": 124},
                "ready": {"wall_seconds": 12.0, "exit_code": 0}
            }
        ),
        60: archive(
            {
                "probe": {"wall_seconds": 62.0, "exit_code": 0},
                "ready": {"wall_seconds": float("nan"), "exit_code": 0}
            }
        ),
        70: archive({"probe": {"wall_seconds": 64.0, "exit_code": 0}}),
        80: archive({"probe": {"wall_seconds": 66.0, "exit_code": 0}})
    };
    client = GitHub(repository="o/r", transport=fake.respond);
    baseline = fetch_baseline(client, BaselinePolicy(runs=3), phases, skip_run="1");
    assert fake.downloads == [20, 40, 60, 70, 80];
    assert baseline.samples == {"probe": [60.0, 62.0, 64.0], "ready": [10.0, 12.0]};
    assert baseline.median("probe") == 62.0;
    assert baseline.median("ready") is None;
    assert "4 main pushes of ci.yml (runs 7 to 2; samples: probe 3, ready 2)"
        in baseline.note;
    fake.downloads = [];
    full = fetch_baseline(client, BaselinePolicy(runs=3), phases, skip_run="1");
    assert full.samples["probe"] == [60.0, 62.0, 64.0];
    empty = fetch_baseline(
        GitHub(repository="o/r", transport=FakeTransport().respond),
        BaselinePolicy(runs=3),
        phases
    );
    assert empty.samples == {"probe": [], "ready": []};
    assert empty.note.startswith("unavailable");
}
