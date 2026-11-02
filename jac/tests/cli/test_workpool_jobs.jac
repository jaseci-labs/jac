"""Scheduling budgets and post-file retirement are independent policies."""

import os;
import from unittest.mock { mock_open, patch }
import from pathlib { Path }
import from tempfile { TemporaryDirectory }
import from jaclang.cli.workpool {
    MAX_AUTO_JOBS,
    RAMP_START_JOBS,
    WORKER_MEM_BYTES,
    WorkPool,
    default_jobs,
    memory_headroom_bytes
}
import from jaclang.testing.test_runner { resolve_jobs as resolve_test_jobs }

glob GB: int = 1024 * 1024 * 1024;

test "default_jobs sizes the pool by the per-worker ceiling" {
    import from jaclang.cli.workpool { cpu_quota }
    cpus = cpu_quota();
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
        "jaclang.cli.workpool.cpu_quota", return_value=4
    ), patch("builtins.open", mock_open(read_data="MemAvailable: 16777216 kB\n")), patch.dict(
        os.environ, {"JAC_TEST_JOBS": "auto", "JAC_TEST_RECYCLE_MB": ""}
    ) {
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


test "memory headroom is the tightest cgroup limit on the way to the top" {
    with TemporaryDirectory() as td {
        top = Path(td);
        leaf = top / "build.slice" / "seal.scope";
        leaf.mkdir(parents=True);
        (top / "build.slice" / "memory.max").write_text(str(4 * GB));
        (top / "build.slice" / "memory.current").write_text(str(1 * GB));
        (leaf / "memory.max").write_text("max");
        (leaf / "memory.current").write_text(str(1 * GB));
        mine = top / "self_cgroup";
        mine.write_text("0::/build.slice/seal.scope\n");
        roomy = memory_headroom_bytes(cgroup_root=td, self_cgroup=str(mine));
        assert 0 < roomy <= 3 * GB , (
            f"a 4 GB limit on the parent slice with 1 GB used leaves at most 3 GB, got {roomy}"
        );
        (leaf / "memory.max").write_text(str(2 * GB));
        (leaf / "memory.current").write_text(str(GB + GB // 2));
        tight = memory_headroom_bytes(cgroup_root=td, self_cgroup=str(mine));
        assert 0 < tight <= GB // 2 , (
            f"the scope's mine 2 GB limit with 1.5 GB used is the tightest, got {tight}"
        );
    }
}


test "memory headroom reads a cgroup v1 memory limit too" {
    with TemporaryDirectory() as td {
        top = Path(td);
        scope = top / "memory" / "docker" / "app";
        scope.mkdir(parents=True);
        (scope / "memory.limit_in_bytes").write_text(str(1 * GB));
        (scope / "memory.usage_in_bytes").write_text(str(GB // 4));
        (top / "memory" / "memory.limit_in_bytes").write_text(str(1 << 62));
        (top / "memory" / "memory.usage_in_bytes").write_text(str(GB));
        mine = top / "self_cgroup";
        mine.write_text("4:cpu,cpuacct:/docker/app\n3:memory:/docker/app\n");
        room = memory_headroom_bytes(cgroup_root=td, self_cgroup=str(mine));
        assert 0 < room <= GB - GB // 4 , (
            f"a 1 GB v1 limit with 256 MB used leaves at most 768 MB, got {room}"
        );
    }
}


def _worker_pids(headroom: int) -> set[int] {
    pids: set[int] = set();
    def job(request: dict[str, any]) -> int {
        return os.getpid();
    }
    def collect(idx: int, record: dict[str, any]) {
        if "result" in record {
            pids.add(int(record["result"]));
        }
    }
    def room -> int {
        return headroom;
    }
    WorkPool(
        items=[f"item{n}" for n in range(40)],
        job=job,
        on_record=collect,
        jobs=8,
        headroom=room
    ).run();
    return pids;
}


test "a pool adds workers only while the memory they use fits" {
    held = _worker_pids(0);
    assert len(held) == RAMP_START_JOBS , (
        f"with no memory to spare, 8 requested workers must stay at {RAMP_START_JOBS}; "
        f"{len(held)} ran"
    );
    roomy = _worker_pids(64 * GB);
    assert len(roomy) == 8 , (
        f"with room for all of them, the pool widens to the 8 requested; {len(
            roomy
        )} ran"
    );
}
