"""A job that raises a SystemExit marked `stops_command` (a refusal that
must end the command, such as a kernel that cannot be used) stops the whole
pool, inline or in a forked worker, instead of being recorded as one failed
item while the rest go on. Any other SystemExit stays one failed item."""

import from jaclang.cli.workpool { WorkPool, pool_available }

class StopCommand(SystemExit) {
    static has stops_command: bool = True;
}

class OtherExit(SystemExit) {}

glob _seen: list[int] = [];

def _job(request: dict[(str, any)]) -> any {
    raise StopCommand("jac: stop");
}

def _exit_job(request: dict[(str, any)]) -> any {
    raise OtherExit(3);
}

def _on_record(idx: int, record: dict[(str, any)]) {
    _seen.append(idx);
}

def _stopped(pool: WorkPool, inline: bool) -> (str | None) {
    try {
        if inline {
            pool.run_inline();
        } else {
            pool.run();
        }
    } except SystemExit as e {
        return str(e.code);
    }
    return None;
}

test "a command-stopping job error stops an inline pool" {
    _seen.clear();
    pool = WorkPool(items=["a", "b", "c"], job=_job, on_record=_on_record);
    assert _stopped(pool, True) == "jac: stop";
    assert _seen == [] , _seen;
}

test "a command-stopping job error in a worker stops the pool" {
    if not pool_available() {
        return;
    }
    _seen.clear();
    pool = WorkPool(
        items=[f"item-{i}" for i in range(6)],
        job=_job,
        on_record=_on_record,
        jobs=2,
        crash_prefix="jac-workpool-stop-test-"
    );
    assert _stopped(pool, False) == "jac: stop";
    assert _seen == [] , _seen;
}

test "any other SystemExit from a job is one failed item" {
    _seen.clear();
    pool = WorkPool(items=["a", "b"], job=_exit_job, on_record=_on_record);
    assert _stopped(pool, True) is None;
    assert _seen == [0, 1] , _seen;
}
