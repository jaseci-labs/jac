"""Tests for the scheduler leader lock (cross-replica run-once)."""

import from jac_scale.state.state_backend { InProcessStateBackend }
import from jac_scale.runtime.lifecycle.leader_lock { run_once, fire_lock_key }


test "fire_lock_key namespaces by job and fire token" {
    assert fire_lock_key("nightly", "2026-06-24T00:00") == "sched:lock:nightly:2026-06-24T00:00";
}


test "run_once runs the task on the first acquire" {
    backend = InProcessStateBackend();
    ran: list[int] = [];
    did_run = run_once(backend, "sched:lock:j:t", 60, lambda : ran.append(1));
    assert did_run;
    assert len(ran) == 1;
}


test "run_once skips a fire whose lock is already held (no double-fire)" {
    backend = InProcessStateBackend();
    ran: list[int] = [];
    first = run_once(backend, "sched:lock:j:t", 60, lambda : ran.append(1));
    second = run_once(backend, "sched:lock:j:t", 60, lambda : ran.append(1));
    assert first;
    assert not second;
    assert len(ran) == 1;
}


test "different fire tokens each run once" {
    backend = InProcessStateBackend();
    ran: list[str] = [];
    run_once(backend, fire_lock_key("j", "t1"), 60, lambda : ran.append("a"));
    run_once(backend, fire_lock_key("j", "t2"), 60, lambda : ran.append("b"));
    assert len(ran) == 2;
}
