"""Check subprocess accounting before CI relies on the new reporting lanes."""

import json;
import os;
import subprocess;
import tempfile;
import from pathlib { Path }

obj AccountingProbe {
    has directory: Path;

    def run(args: list[str], enabled: bool = True) -> int {
        env = dict(os.environ);
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
