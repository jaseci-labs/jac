"""Check subprocess accounting before CI relies on the new reporting lanes."""

import json;
import os;
import subprocess;
import tempfile;
import from pathlib { Path }

obj AccountingProbe {
    has directory: Path;

    def run(args: list[str], enabled: bool = True, attempt: str = "1") -> int {
        env = dict(os.environ);
        budgets = self.directory / "budgets.json";
        if not budgets.exists() {
            budgets.write_text('{"jobs": {}}');
        }
        env["JAC_CI_MEASURE_BUDGETS"] = str(budgets);
        env["GITHUB_JOB"] = "jac-check";
        env["GITHUB_RUN_ATTEMPT"] = attempt;
        env["JAC_CI_MEASURE_DIR"] = str(self.directory) if enabled else "";
        env["GITHUB_STEP_SUMMARY"] = str(self.directory / "github-summary.md");
        return subprocess.run(
            ["bash", str(Path(__file__).parent / "ci_measure.sh"), *args],
            env=env,
            capture_output=True,
            text=True
        ).returncode;
    }
}

test "accounting preserves failures and reports CPU memory and cache context" {
    with tempfile.TemporaryDirectory() as directory {
        probe = AccountingProbe(directory=Path(directory));
        context = {"analysis_cache": {"exact": "false", "matched": "prefix-key"}};
        (probe.directory / "context.json").write_text(json.dumps(context));
        assert probe.run(["record", "check", "bash", "-c", "exit 7"]) == 7;
        assert probe.run(["report"]) == 0;
        result = json.loads((probe.directory / "check.json").read_text());
        assert result["exit_code"] == 7;
        assert result["context"] == context;
        assert result["wall_seconds"] >= 0;
        assert result["cpu_seconds"] >= 0;
        assert result["max_rss_mib"] > 0;
        assert result["mode"] == "report";
        assert (probe.directory / "github-summary.md").is_file();
    }
}

test "disabled accounting passes through and invalid phase cannot escape output" {
    with tempfile.TemporaryDirectory() as directory {
        probe = AccountingProbe(directory=Path(directory));
        assert probe.run(["record", "probe", "bash", "-c", "exit 9"], enabled=False)
            == 9;
        assert not (probe.directory / "probe.time.json").exists();
        assert probe.run(["record", "../escape", "true"]) != 0;
        assert not (probe.directory / "../escape.time.json").exists();
    }
}

test "empty reports do not claim a pass and malformed accounting fails" {
    with tempfile.TemporaryDirectory() as directory {
        probe = AccountingProbe(directory=Path(directory));
        (probe.directory / "context.json").write_text("{}");
        assert probe.run(["report"]) == 0;
        assert "No commands were measured"
            in (probe.directory / "summary.md").read_text();
        (probe.directory / "broken.time.json").write_text("not json");
        assert probe.run(["report"]) != 0;
        (probe.directory / "broken.time.json").write_text("{}");
        assert probe.run(["report"]) != 0;
    }
}


test "fixed limits enforce boundaries and reject missing required measurements" {
    with tempfile.TemporaryDirectory() as directory {
        probe = AccountingProbe(directory=Path(directory));
        (probe.directory / "context.json").write_text("{}");
        (probe.directory / "budgets.json").write_text(
            json.dumps(
                {
                    "jobs": {
                        "jac-check": {
                            "check": {"cold": {"wall_seconds": 2, "max_rss_mib": 1}}
                        }
                    }
                }
            )
        );
        assert probe.run(["report"]) != 0;
        raw = {
            "wall_seconds": 2,
            "user_seconds": 1,
            "system_seconds": 0,
            "rss_kib": 1024,
            "exit_code": 0
        };
        (probe.directory / "check.time.json").write_text(json.dumps(raw));
        assert probe.run(["report"]) == 0;
        raw["exit_code"] = 7;
        (probe.directory / "check.time.json").write_text(json.dumps(raw));
        assert probe.run(["report"]) != 0;
        raw["exit_code"] = 0;
        raw["wall_seconds"] = 3;
        raw["rss_kib"] = 2048;
        (probe.directory / "check.time.json").write_text(json.dumps(raw));
        assert probe.run(["report"]) != 0;
        verdict = json.loads((probe.directory / "report.json").read_text());
        assert len(verdict["failures"][0]["failures"]) == 2;
        (probe.directory / "context.json").write_text(
            '{"analysis_cache": {"exact": "false", "matched": "prefix-key"}}'
        );
        assert probe.run(["report"]) == 0;
        verdict = json.loads((probe.directory / "report.json").read_text());
        assert verdict["state"] == "restored";
        assert verdict["results"][0]["mode"] == "report";
        (probe.directory / "context.json").write_text("{}");
        assert probe.run(["report"], attempt="2") == 0;
        verdict = json.loads((probe.directory / "report.json").read_text());
        assert verdict["state"] == "retry-cold";
        assert verdict["results"][0]["mode"] == "report";
    }
}


test "invalid limits cannot disable performance enforcement" {
    with tempfile.TemporaryDirectory() as directory {
        probe = AccountingProbe(directory=Path(directory));
        (probe.directory / "context.json").write_text("{}");
        (probe.directory / "budgets.json").write_text(
            json.dumps(
                {
                    "jobs": {
                        "jac-check": {
                            "check": {"cold": {"wall_seconds": -1, "max_rss_mib": 1}}
                        }
                    }
                }
            )
        );
        assert probe.run(["report"]) != 0;
    }
}
