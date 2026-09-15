"""A one-worker test run still retires workers; jobs=0 stays in-process."""
import os;
import from pathlib { Path }
import from tempfile { TemporaryDirectory }
import from unittest.mock { patch }
import jaclang.testing.test_runner as runner;
import from jaclang.testing.test_runner { TestOutcome, PASSED }
import from jaclang.cli.workpool { pool_available }

def _record_worker(filepath: str, *args: any, **options: any) -> list[TestOutcome] {
    Path(filepath + ".pid").write_text(str(os.getpid()));
    return [TestOutcome(file=filepath, name="worker", status=PASSED)];
}

test "one-worker scheduling preserves recycling and the explicit inline override" {
    if not pool_available() {
        return;
    }
    with TemporaryDirectory() as directory {
        paths = [str(Path(directory) / f"test_worker_{i}.jac") for i in range(2)];
        for path in paths {
            Path(path).write_text('test "worker" { assert True; }');
        }
        with patch.object(runner, "run_file", side_effect=_record_worker), patch.dict(
            os.environ, {"JAC_TEST_RECYCLE": "1", "JAC_TEST_RECYCLE_MB": "0"}
        ) {
            assert runner.run_tests(paths=paths, jobs=1) == 0;
            pids = [int(Path(path + ".pid").read_text()) for path in paths];
            assert len(set(pids)) == 2;
            assert os.getpid() not in pids;
            assert runner.run_tests(paths=paths, jobs=0) == 0;
            assert all(
                int(Path(path + ".pid").read_text()) == os.getpid() for path in paths
            );
        }
    }
}
