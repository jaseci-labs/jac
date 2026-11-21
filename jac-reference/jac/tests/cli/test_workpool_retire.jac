"""Worker-pool retirement regression guard.

`WorkPool` replaces a worker whenever the retire hook fires (the precompile and
check lanes retire on an RSS ceiling). Two defects made frequent retirement
unsafe, and both only appear once enough retirements have accumulated, so a
short pool run never caught them:

1. A retired kid was left in `self.kids` forever. `_spawn` runs in the forked
   child and closes every sibling's pipe fds by number, so once a reaped kid's
   fd numbers were recycled by a later `os.pipe()`, a new child could close a
   live pipe (including its own dispatch end) and exit immediately at EOF. The
   parent then reported "worker exited while running this item" for the item it
   had just handed over.
2. The same accumulation leaked the retired kid's two fds until shutdown,
   which `select()` cannot survive past fd 1024.

Retiring after every item exercises both in seconds: before the fix this
completed 8 of 1200 items.
"""

import os;
import from jaclang.cli.workpool { WorkPool, pool_available }

glob ITEMS: int = 400,
     _done: list[int] = [],
     _failed: list[str] = [];

def _job(request: dict[(str, any)]) -> any {
    return {"idx": int(request["idx"])};
}

def _on_record(idx: int, record: dict[(str, any)]) {
    if isinstance(record.get("result"), dict) {
        _done.append(idx);
    } else {
        _failed.append(str(record.get("crash") or record.get("error"))[:200]);
    }
}

def _retire_always(served: int, rss_mb: int) -> bool {
    return True;
}

def _open_fds -> int {
    try {
        return len(os.listdir("/proc/self/fd"));
    } except OSError {
        return -1;
    }
}

test "every item completes when a worker retires after each one" {
    if not pool_available() {
        return;
    }
    _done.clear();
    _failed.clear();
    before = _open_fds();
    pool = WorkPool(
        items=[f"item-{i}" for i in range(ITEMS)],
        job=_job,
        on_record=_on_record,
        jobs=4,
        retire=_retire_always,
        crash_prefix="jac-workpool-retire-test-"
    );
    pool.run();
    assert not _failed , f"{len(_failed)} item(s) failed, first: {_failed[:2]}";
    assert len(_done) == ITEMS , f"completed {len(_done)} of {ITEMS}";
    assert sorted(_done) == list(range(ITEMS)) , "item indices were not all served";
    after = _open_fds();
    if before >= 0 and after >= 0 {
        assert after <= before + 4 , f"file descriptors leaked: {before} -> {after}";
    }
}
