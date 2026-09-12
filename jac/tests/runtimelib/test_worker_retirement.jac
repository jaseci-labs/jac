"""A pool worker retires on how much it is holding, not just how many files.

`JAC_TEST_RECYCLE` bounds files served per worker, which bounds a slow drip
but not a single heavy compile: one native fixture can take a worker from
under 500 MB to several GB, and the count-based cap then keeps that worker
alive for the two dozen files it has left to serve. On a runner with no
headroom the agent itself is killed, which produces no step log and no test
output at all.

Retirement therefore takes whichever bound trips first. `JAC_TEST_RECYCLE_MB`
carries the memory bound; either can be disabled with 0.
"""

import from jaclang.testing.test_runner { _should_retire, _worker_rss_mb }
import mmap;
import sys;

test "a worker under both bounds keeps serving" {
    assert not _should_retire(served=3, recycle=25, rss_mb=400, rss_cap=2048);
}

test "the file count still retires a worker" {
    assert _should_retire(served=25, recycle=25, rss_mb=400, rss_cap=2048);
    assert _should_retire(served=26, recycle=25, rss_mb=400, rss_cap=2048);
}

test "a single heavy file retires a worker the count would have kept" {
    assert _should_retire(served=1, recycle=25, rss_mb=4608, rss_cap=2048) , (
        "a worker holding 4.5 GB after one file kept serving because the "
        "count-based cap had 24 files left to go"
    );
}

test "either bound can be disabled with 0" {
    assert not _should_retire(served=99, recycle=0, rss_mb=400, rss_cap=2048);
    assert not _should_retire(served=3, recycle=25, rss_mb=99999, rss_cap=0);
    assert not _should_retire(served=99, recycle=0, rss_mb=99999, rss_cap=0);
}

test "the worker can read its own footprint" {
    mb = _worker_rss_mb();
    assert mb > 0 , "a live worker reports no resident memory";
    assert mb < 1024 * 1024 , f"implausible footprint {mb} MB: check the unit";
}

test "released Linux memory no longer counts toward worker retirement" {
    if sys.platform != "linux" {
        return;
    }
    before = _worker_rss_mb();
    with mmap.mmap(-1, 64 * 1024 * 1024) as allocation {
        for offset in range(0, len(allocation), 4096) {
            allocation[offset] = 1;
        }
        during = _worker_rss_mb();
        assert during >= before + 48 , (before, during);
    }
    after = _worker_rss_mb();
    assert after <= during - 48 , (before, during, after);
}
