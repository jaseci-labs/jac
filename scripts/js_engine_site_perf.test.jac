"""Exercise the site perf measurement, the ratio gate and the baseline it asks for."""

import contextlib;
import io;
import stat;
import tempfile;
import from unittest.mock { patch }

glob FAKE_RUNTIME: str = """#!/bin/sh
if [ "$1" = "--version" ]; then echo v20.0.0-fake; exit 0; fi
mkdir -p web/dist
printf '%s' "BUNDLE" > web/dist/index.html
exit EXIT
""";

obj SiteProbe {
    has directory: Path;

    def client -> Path {
        return self.directory / "client";
    }

    def output -> Path {
        return self.directory / "out";
    }

    def policy_path -> Path {
        return self.directory / "policy.json";
    }

    def site {
        vite = self.client() / "node_modules" / "vite" / "bin" / "vite.js";
        vite.parent.mkdir(parents=True);
        vite.write_text("// vite\n");
        config = self.client() / "configs" / "vite.config.js";
        config.parent.mkdir(parents=True);
        config.write_text("export default {};\n");
    }

    def runtime(name: str, bundle: str = "same", exit_code: int = 0) -> str {
        path = self.directory / name;
        path.write_text(
            FAKE_RUNTIME.replace("BUNDLE", bundle).replace("EXIT", str(exit_code))
        );
        path.chmod(path.stat().st_mode | stat.S_IEXEC);
        return str(path);
    }

    def policy(baseline: dict[str, any] | None = None, runs: int = 2) {
        self.policy_path().write_text(
            json.dumps(
                {
                    "runs": runs,
                    "fail_ratio": 1.05,
                    "update_ratio": 0.95,
                    "baseline": baseline
                }
            )
        );
    }

    def results(engine: float, node_nojit: float, node_jit: float = 1.0) -> Path {
        samples: list[dict[str, any]] = [];
        for (side, seconds) in [
            ("node-nojit", node_nojit), ("engine", engine), ("node", node_jit)
        ] {
            samples.append({"side": side, "run": 1, "seconds": seconds, "rss_mib": 100.0});
            samples.append(
                {"side": side, "run": 2, "seconds": seconds * 1.1, "rss_mib": 120.0}
            );
        }
        path = self.directory / "results.json";
        path.write_text(
            json.dumps({"node": "v20.0.0-fake", "samples": samples, "commit": "abc"})
        );
        return path;
    }

    def call(*argv: str) -> tuple[int, str, str] {
        printed = io.StringIO();
        outputs = self.directory / "github_output";
        outputs.write_text("");
        with contextlib.redirect_stdout(printed), patch.dict(
            os.environ,
            {
                "GITHUB_OUTPUT": str(outputs),
                "GITHUB_STEP_SUMMARY": str(self.directory / "summary.md")
            }
        ) {
            code = main(list(argv));
        }
        return (code, printed.getvalue(), outputs.read_text());
    }

    def gate_with(baseline: dict[str, any] | None, engine: float, node_nojit: float) -> tuple[int, str, str] {
        self.policy(baseline);
        results = self.results(engine, node_nojit);
        return self.call(
            "gate",
            "--policy",
            str(self.policy_path()),
            "--results",
            str(results),
            "--output",
            str(self.output())
        );
    }
}

def baseline_at(ratio: float, node_version: str = "v20.0.0-fake") -> dict[str, any] {
    return {"ratio": ratio, "node": node_version, "commit": "base"};
}

test "measure interleaves the sides and keeps every run" {
    with tempfile.TemporaryDirectory() as directory {
        probe = SiteProbe(directory=Path(directory));
        probe.site();
        probe.policy();
        (code, printed, _out) = probe.call(
            "measure",
            "--client",
            str(probe.client()),
            "--node",
            probe.runtime("node"),
            "--engine",
            probe.runtime("engine"),
            "--policy",
            str(probe.policy_path()),
            "--output",
            str(probe.output())
        );
        assert code == 0 , printed;
        results = json.loads((probe.output() / "results.json").read_text());
        assert [s["side"] for s in results["samples"]] == SIDES + SIDES;
        assert results["node"] == "v20.0.0-fake";
        assert (probe.output() / "logs" / "engine-2.log").is_file();
        summary = summarize(results);
        assert summary["ratio"] > 0 and summary["jit_ratio"] > 0;
    }
}

test "an engine bundle that differs from node's fails the measurement" {
    with tempfile.TemporaryDirectory() as directory {
        probe = SiteProbe(directory=Path(directory));
        probe.site();
        probe.policy(runs=1);
        (code, printed, _out) = probe.call(
            "measure",
            "--client",
            str(probe.client()),
            "--node",
            probe.runtime("node"),
            "--engine",
            probe.runtime("engine", bundle="other"),
            "--policy",
            str(probe.policy_path()),
            "--output",
            str(probe.output())
        );
        assert code == 1;
        assert "differs from node's" in printed;
        assert not (probe.output() / "results.json").exists();
    }
}

test "a failing build fails the measurement and names its log" {
    with tempfile.TemporaryDirectory() as directory {
        probe = SiteProbe(directory=Path(directory));
        probe.site();
        probe.policy(runs=1);
        (code, printed, _out) = probe.call(
            "measure",
            "--client",
            str(probe.client()),
            "--node",
            probe.runtime("node"),
            "--engine",
            probe.runtime("engine", exit_code=3),
            "--policy",
            str(probe.policy_path()),
            "--output",
            str(probe.output())
        );
        assert code == 1;
        assert "engine run 1 exited 3; see logs/engine-1.log" in printed;
    }
}

test "a build that outlives the timeout is killed and fails" {
    with tempfile.TemporaryDirectory() as directory {
        probe = SiteProbe(directory=Path(directory));
        probe.site();
        probe.policy(runs=1);
        slow = Path(directory) / "slow";
        slow.write_text("#!/bin/sh\nexec sleep 30\n");
        slow.chmod(slow.stat().st_mode | stat.S_IEXEC);
        (code, printed, _out) = probe.call(
            "measure",
            "--client",
            str(probe.client()),
            "--node",
            str(slow),
            "--engine",
            probe.runtime("engine"),
            "--timeout",
            "0.5",
            "--policy",
            str(probe.policy_path()),
            "--output",
            str(probe.output())
        );
        assert code == 1;
        assert "node-nojit run 1 exited -9" in printed;
    }
}

test "the fastest run of each side sets the ratios" {
    with tempfile.TemporaryDirectory() as directory {
        probe = SiteProbe(directory=Path(directory));
        summary = summarize(json.loads(probe.results(120.0, 30.0, 10.0).read_text()));
        assert summary["ratio"] == 4.0;
        assert summary["jit_ratio"] == 12.0;
        assert summary["engine_seconds"] == 120.0;
        assert summary["engine_rss_mib"] == 120.0;
        assert summary["runs"] == 2;
    }
}

test "with no baseline the run fails and gives the ratio to commit" {
    with tempfile.TemporaryDirectory() as directory {
        probe = SiteProbe(directory=Path(directory));
        (code, printed, outputs) = probe.gate_with(None, 120.0, 30.0);
        assert code == 1;
        assert "status=no-baseline" in outputs;
        assert "::error title=js_engine site perf::there is no baseline yet; set the baseline in .github/js-engine-site-perf.json to ratio 4.0000" in printed;
        recorded = json.loads((probe.output() / "baseline.json").read_text());
        assert recorded["ratio"] == 4.0 and recorded["node"] == "v20.0.0-fake";
        summary = (probe.output() / "summary.md").read_text();
        assert "| engine / node no-JIT (gated) | 4.000 |  |" in summary;
        assert "### Update the baseline" in summary;
        assert '"ratio": 4.0,' in summary;
    }
}

test "a ratio inside the band passes and asks for nothing" {
    with tempfile.TemporaryDirectory() as directory {
        probe = SiteProbe(directory=Path(directory));
        (code, printed, outputs) = probe.gate_with(baseline_at(4.0), 123.0, 30.0);
        assert code == 0 , printed;
        assert "status=pass" in outputs;
        assert "::error" not in printed;
        assert "### Update the baseline" not in printed;
        assert not (probe.output() / "baseline.json").exists();
        assert "+2.5%" in printed;
    }
}

test "a ratio past fail_ratio fails the gate" {
    with tempfile.TemporaryDirectory() as directory {
        probe = SiteProbe(directory=Path(directory));
        (code, printed, outputs) = probe.gate_with(baseline_at(4.0), 132.0, 30.0);
        assert code == 1;
        assert "status=regressed" in outputs;
        assert "::error title=js_engine site perf::the engine got slower" in printed;
        assert "+10.0%" in printed;
        assert "### Update the baseline" not in printed;
        assert not (probe.output() / "baseline.json").exists();
    }
}

test "a ratio below update_ratio fails and gives the new baseline to commit" {
    with tempfile.TemporaryDirectory() as directory {
        probe = SiteProbe(directory=Path(directory));
        (code, printed, outputs) = probe.gate_with(baseline_at(4.0), 108.0, 30.0);
        assert code == 1;
        assert "status=improved" in outputs;
        assert "::error title=js_engine site perf::the engine got faster relative to node: 3.600 against the baseline's 4.000 (-10.0%); set the baseline in .github/js-engine-site-perf.json to ratio 3.6000" in printed;
        assert "### Update the baseline" in printed;
        recorded = json.loads((probe.output() / "baseline.json").read_text());
        assert recorded["ratio"] == 3.6;
        assert recorded["commit"] == "abc";
    }
}

test "a different node version fails and asks for a new baseline, not a comparison" {
    with tempfile.TemporaryDirectory() as directory {
        probe = SiteProbe(directory=Path(directory));
        (code, printed, outputs) = probe.gate_with(
            baseline_at(2.0, node_version="v18.0.0"), 132.0, 30.0
        );
        assert code == 1;
        assert "status=node-changed" in outputs;
        assert "node changed from v18.0.0 to v20.0.0-fake" in printed;
        assert "to ratio 4.4000" in printed;
        assert (probe.output() / "baseline.json").exists();
    }
}

test "a policy outside its bounds is refused" {
    for raw in [
        {"fail_ratio": 1.0},
        {"update_ratio": 1.0},
        {"runs": 0},
        {"baseline": {"ratio": 0}}
    ] {
        raised = False;
        try {
            Policy(**raw);
        } except ValueError {
            raised = True;
        }
        assert raised , raw;
    }
}
