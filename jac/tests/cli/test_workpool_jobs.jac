"""Scheduling budgets and post-file retirement are independent policies."""

import os;
import from unittest.mock { mock_open, patch }
import from jaclang.cli.workpool { MAX_AUTO_JOBS, WORKER_MEM_BYTES, default_jobs }
import from jaclang.testing.test_runner { resolve_jobs as resolve_test_jobs }

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

test "test retirement thresholds do not serialize automatic scheduling" {
    with patch("os.cpu_count", return_value=4), patch(
        "builtins.open", mock_open(read_data="MemAvailable: 16777216 kB\n")
    ), patch.dict(os.environ, {"JAC_TEST_JOBS": "auto", "JAC_TEST_RECYCLE_MB": ""}) {
        assert resolve_test_jobs() == 4;
        with patch.dict(os.environ, {"JAC_TEST_RECYCLE_MB": "4096"}) {
            assert resolve_test_jobs() == 4;
        }
        with patch.dict(os.environ, {"JAC_TEST_RECYCLE_MB": "0"}) {
            assert resolve_test_jobs() == 4;
        }
        # An explicit count remains an operator override.
        assert resolve_test_jobs("3") == 3;
    }
}
