"""The worker pool budgets each worker at the ceiling it may reach.

`default_jobs` sizes a pool from available memory. It used to divide by a
typical footprint (WORKER_MEM_BYTES) while the pools that recycle workers on
an RSS ceiling let each worker grow to that ceiling first, so a cold `jac
check` sweep on a 16 GB runner ran four workers that were each allowed 4 GB:
17 GB with the parent, and the runner died before any of them retired. A
caller that recycles at a ceiling now passes it, and the pool is sized so
every worker can sit at the ceiling at once and still fit.
"""

import os;
import from jaclang.cli.workpool { MAX_AUTO_JOBS, WORKER_MEM_BYTES, default_jobs }

glob GB: int = 1024 * 1024 * 1024;

test "default_jobs sizes the pool by the per-worker ceiling" {
    cpus = os.cpu_count() or 1;
    # 16 GB box, workers recycled at 4 GB: 16 * 0.6 / 4 = 2, never 4.
    assert default_jobs(worker_bytes=4 * GB, avail_bytes=16 * GB) == min(cpus, 2) , "four 4 GB workers plus the parent do not fit a 16 GB box";
    # Without a ceiling the typical footprint still sizes the pool.
    assert default_jobs(avail_bytes=16 * GB)
        == min(cpus, int((16 * GB * 0.6) // WORKER_MEM_BYTES), MAX_AUTO_JOBS);
    # A ceiling below the typical footprint does not grow the pool.
    assert default_jobs(worker_bytes=1 * GB, avail_bytes=16 * GB)
        == default_jobs(avail_bytes=16 * GB);
    # A ceiling the box cannot hold even once still yields one worker.
    assert default_jobs(worker_bytes=64 * GB, avail_bytes=16 * GB) == 1;
}

test "test runner auto jobs use a budget independent of the hard ceiling" {
    import from unittest.mock { patch }
    import jaclang.cli.workpool as pool;
    import from jaclang.testing.test_runner { resolve_jobs }

    def on_runner(worker_bytes: int = 0, avail_bytes: int = 0) -> int {
        return default_jobs(worker_bytes=worker_bytes, avail_bytes=16 * GB);
    }
    with patch.object(pool, "default_jobs", on_runner), patch.dict(
        os.environ, {"JAC_TEST_RECYCLE_MB": "8192", "JAC_TEST_WORKER_MB": "2048"}
    ) {
        assert resolve_jobs("auto") == min(os.cpu_count() or 1, 4);
        import from jaclang.testing.test_runner { _test_retire }
        assert _test_retire(1, 2048, budget_mb=2048);
        assert not _test_retire(1, 2048);
        assert not _test_retire(1, 1024, budget_mb=2048);
        assert resolve_jobs(2) == 2 , "an explicit worker count must remain explicit";
    }
}

test "one test worker recycles while jobs zero stays inline" {
    import json;
    import subprocess;
    import sys;
    import from pathlib { Path }
    import from tempfile { TemporaryDirectory }
    import from jaclang.cli.workpool { pool_available }

    if not pool_available() {
        testskip("worker recycling requires fork");
    }
    with TemporaryDirectory() as tmp {
        fixture_dir = Path(tmp);
        files: list[str] = [];
        outputs: list[Path] = [];
        for index in range(2) {
            output = fixture_dir / f"pid_{index}.txt";
            fixture = fixture_dir / f"test_worker_{index}.jac";
            fixture.write_text(
                'import os;\nimport from pathlib { Path }\n'
                    + 'test "worker" { Path('
                    + repr(str(output))
                    + ').write_text(str(os.getpid())); }\n'
            );
            files.append(str(fixture));
            outputs.append(output);
        }
        probe = '''import json, os, sys
from jaclang.testing.test_runner import run_tests
result = run_tests(paths=sys.argv[2:], jobs=sys.argv[1])
print("DRIVER=" + json.dumps(os.getpid()))
sys.exit(result)
''';
        env = dict(os.environ);
        env["JAC_TEST_RECYCLE"] = "1";
        for jobs in ["1", "0"] {
            result = subprocess.run(
                [sys.executable, "-c", probe, jobs] + files,
                cwd=tmp,
                env=env,
                capture_output=True,
                text=True,
                timeout=180
            );
            assert result.returncode == 0 , result.stdout + result.stderr;
            driver = int(json.loads(result.stdout.split("DRIVER=")[-1].strip()));
            pids = [int(output.read_text()) for output in outputs];
            if jobs == "1" {
                assert driver not in pids , "one worker must not run in the driver";
                assert len(set(pids)) == 2 , "the worker must retire after each file";
            } else {
                assert pids == [driver, driver] , "jobs zero must remain inline";
            }
        }
    }
}
