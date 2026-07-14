import from jaclang.scale.state.state_backend { InProcessStateBackend }
import from jaclang.scale.runtime.lifecycle.leader_lock { run_once }


test "the same fire runs once and is skipped while the lock is held" {
    backend = InProcessStateBackend();
    runs: list[int] = [];
    first = run_once(backend, "sched:lock:job:tick", 60, lambda { runs.append(1); });
    second = run_once(backend, "sched:lock:job:tick", 60, lambda { runs.append(1); });
    assert first;
    assert not second;
    assert len(runs) == 1;
}
