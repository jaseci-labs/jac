"""Exercise the actual GNU accounting format and Jac's CI budget verdicts."""

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

    def budget(wall: float = 5.0, memory: float | None = 256.0) {
        (self.directory / "results").mkdir(exist_ok=True);
        (self.directory / "budgets.json").write_text(
            json.dumps({"probe": {"wall_seconds": wall, "max_rss_mib": memory}})
        );
    }

    def verdict -> ProbeResult {
        output = io.StringIO();
        with contextlib.redirect_stdout(output), patch.dict(
            os.environ, {"GITHUB_STEP_SUMMARY": str(self.directory / "summary.md")}
        ) {
            code = main(
                [
                    "--budgets",
                    str(self.directory / "budgets.json"),
                    "--output",
                    str(self.directory / "results")
                ]
            );
        }
        return ProbeResult(code=code, output=output.getvalue());
    }

    def run(source: str) -> int {
        budget = json.loads((self.directory / "budgets.json").read_text())["probe"];
        result = subprocess.run(
            [
                "/usr/bin/time",
                "--quiet",
                "--output",
                str(self.directory / "results/probe.time.json"),
                "--format",
                '{"wall_seconds":%e,"user_seconds":%U,"system_seconds":%S,"rss_kib":%M,"exit_code":%x}',
                "timeout",
                "--kill-after=5s",
                f"{budget['wall_seconds']}s",
                sys.executable,
                "-c",
                source
            ],
            env={** os.environ, "LC_ALL": "C"}
        );
        return result.returncode;
    }

    def measurement -> Measurement {
        return read_phase(
            self.directory / "results",
            "probe",
            Budget(wall_seconds=5.0, max_rss_mib=256.0)
        );
    }
}

test "accounted command runs once and records kernel metrics" {
    with tempfile.TemporaryDirectory() as directory {
        probe = PerfProbe(directory=Path(directory));
        probe.budget();
        counter = probe.directory / "counter";
        code = probe.run(
            f"from pathlib import Path; p=Path({str(counter)!r}); "
            "p.write_text(p.read_text()+'x' if p.exists() else 'x')"
        );
        assert code == 0;
        assert counter.read_text() == "x";
        measured = probe.measurement();
        assert measured.max_rss_mib is not None and measured.max_rss_mib > 0;
        assert measured.cpu_seconds is not None and measured.cpu_seconds >= 0;
        assert probe.verdict().code == 0;
        assert (probe.directory / "results/probe.json").is_file();
    }
}

test "slow command stops and its saved measurement fails the gate" {
    with tempfile.TemporaryDirectory() as directory {
        probe = PerfProbe(directory=Path(directory));
        probe.budget(wall=0.05);
        assert probe.run("import time; time.sleep(2)") == 124;
        assert probe.measurement().exit_code == 124;
        result = probe.verdict();
        assert result.code == 1;
        assert "wall" in result.output;
    }
}

test "memory growth in a command or its child fails the gate" {
    for child in [False, True] {
        with tempfile.TemporaryDirectory() as directory {
            probe = PerfProbe(directory=Path(directory));
            probe.budget(memory=128.0);
            source = "data=bytearray(192*1024*1024)";
            if child {
                source = f"import subprocess,sys; subprocess.run([sys.executable,'-c',{source!r}], check=True)";
            }
            assert probe.run(source) == 0;
            result = probe.verdict();
            assert result.code == 1;
            assert "RSS" in result.output;
            measured = probe.measurement();
            assert measured.exit_code == 0;
            assert measured.max_rss_mib is not None and measured.max_rss_mib > 128.0;
        }
    }
}

test "accounting preserves command failures" {
    with tempfile.TemporaryDirectory() as directory {
        probe = PerfProbe(directory=Path(directory));
        probe.budget();
        assert probe.run("raise SystemExit(7)") == 7;
        assert probe.measurement().exit_code == 7;
        assert probe.verdict().code == 1;
    }
}

test "readiness gate uses elapsed uptime across workflow steps" {
    with tempfile.TemporaryDirectory() as directory {
        probe = PerfProbe(directory=Path(directory));
        probe.budget(wall=2.0, memory=None);
        (probe.directory / "results/probe.start").write_text("123.45 999.00\n");
        (probe.directory / "results/probe.ready").write_text("124.55 1000.00\n");
        assert probe.verdict().code == 0;
        (probe.directory / "results/probe.ready").write_text("126.00 1001.00\n");
        result = probe.verdict();
        assert result.code == 1;
        assert "wall" in result.output;
    }
}

test "nonfinite limits or measurements cannot disable the gate" {
    with tempfile.TemporaryDirectory() as directory {
        probe = PerfProbe(directory=Path(directory));
        probe.budget(wall=float("nan"));
        assert probe.verdict().code == 1;
        probe.budget(memory=None);
        (probe.directory / "results/probe.start").write_text("0 0\n");
        (probe.directory / "results/probe.ready").write_text("nan 0\n");
        assert probe.verdict().code == 1;
    }
}

test "missing measurements fail the gate" {
    with tempfile.TemporaryDirectory() as directory {
        probe = PerfProbe(directory=Path(directory));
        probe.budget(memory=None);
        assert probe.verdict().code == 1;
        (probe.directory / "results/probe.start").write_text("1 0\n");
        assert probe.verdict().code == 1;
    }
}
