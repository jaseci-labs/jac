"""Execution benchmark controls must not mistake compiler work for VM speed."""
import copy;
import json;
import from pathlib { Path }
import runpy;
import subprocess;
import sys;
import tempfile;
import from tests.support { JAC_ROOT }

glob benchmark = Path(JAC_ROOT).parent / "scripts/python_evaluator_bench.py";

test "evaluator workloads execute identical marshalled bytecode in paired processes" {
    if not benchmark.is_file() {
        testskip("repository benchmark script is not installed");
    }
    with tempfile.TemporaryDirectory(prefix="jac-evaluator-test-") as directory {
        report_path = Path(directory) / "report.json";
        result = subprocess.run(
            [
                sys.executable,
                "-I",
                "-S",
                str(benchmark),
                "--baseline",
                sys.executable,
                "--candidate",
                sys.executable,
                "--samples",
                "2",
                "--warmups",
                "2",
                "--min-time",
                "0.001",
                "--output",
                str(report_path)
            ],
            capture_output=True,
            text=True,
            timeout=120
        );
        assert result.returncode == 0 , result.stdout + result.stderr;
        data = json.loads(report_path.read_text());
        assert data["same_executable"];
        assert len(data["source_sha256"]) == 64;
        assert len(data["bytecode_sha256"]) == 64;
        assert len(data["cases"]) == 12;
        assert data["regressions"] == [];
        for result in data["cases"].values() {
            assert len(result["baseline"]) == len(result["candidate"]) == 2;
            for (baseline, candidate) in zip(result["baseline"], result["candidate"]) {
                assert baseline["loops"] == candidate["loops"] > 0;
                assert baseline["checksum"] == candidate["checksum"];
            }
        }
    }
}

test "evaluator comparison rejects mismatched samples and runtime configurations" {
    if not benchmark.is_file() {
        testskip("repository benchmark script is not installed");
    }
    api = runpy.run_path(str(benchmark));
    sample = api["Sample"];
    comparison = api["comparison"];
    result = comparison([sample(2, 4.0, 84)], [sample(2, 6.0, 84)]);
    assert result["median_ratio"] == 1.5;
    for candidate in [
        sample(3, 6.0, 84),
        sample(2, 6.0, 83),
        sample(2, 0.0, 84),
        sample(2, float("nan"), 84),
        sample(2, float("inf"), 84)
    ] {
        failed = False;
        try {
            comparison([sample(2, 4.0, 84)], [candidate]);
        } except ValueError {
            failed = True;
        }
        assert failed;
    }
    metadata = api["runtime_metadata"]();
    api["validate_runtimes"](metadata, metadata);
    for (field, value) in [
        ("version", [3, 13, 0]),
        ("implementation", "pypy"),
        ("debug", not metadata["debug"]),
        ("free_threaded", not metadata["free_threaded"]),
        ("jit_enabled", not metadata["jit_enabled"])
    ] {
        candidate = copy.deepcopy(metadata);
        candidate[field] = value;
        failed = False;
        try {
            api["validate_runtimes"](metadata, candidate);
        } except ValueError {
            failed = True;
        }
        assert failed;
    }
}

test "evaluator slowdown threshold fails and preserves measurements" {
    if not benchmark.is_file() {
        testskip("repository benchmark script is not installed");
    }
    with tempfile.TemporaryDirectory(prefix="jac-evaluator-threshold-") as directory {
        report_path = Path(directory) / "report.json";
        result = subprocess.run(
            [
                sys.executable,
                "-I",
                "-S",
                str(benchmark),
                "--baseline",
                sys.executable,
                "--candidate",
                sys.executable,
                "--samples",
                "1",
                "--warmups",
                "1",
                "--min-time",
                "0.001",
                "--case",
                "arithmetic",
                "--max-slowdown",
                "0.000001",
                "--output",
                str(report_path)
            ],
            capture_output=True,
            text=True,
            timeout=120
        );
        assert result.returncode == 1 , result.stdout + result.stderr;
        assert "Slowdown threshold exceeded: arithmetic" in result.stderr;
        data = json.loads(report_path.read_text());
        assert data["regressions"] == ["arithmetic"];
        assert data["cases"]["arithmetic"]["median_ratio"] > data["max_slowdown"];
    }
}
