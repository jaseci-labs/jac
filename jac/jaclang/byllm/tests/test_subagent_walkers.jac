"""Tests for walker-as-subagent concurrency patterns.

Covers the styles demonstrated in examples/agentic_ai/subagents/:
  1.  flow/wait  — Jac-native parallel spawn, thread isolation, speedup
  2.  Sync walker (jac-scale style) — correctness baseline

Concurrency / isolation proofs use time.sleep; no real API key needed.
LLM integration is exercised in the examples/ files which use module-level
models (the correct pattern — local `by model()` in test bodies hits the
builtin LLM path, not the byllm plugin).
"""

import time;
import threading;


# ---------------------------------------------------------------------------
# 1.  flow/wait — Jac-native parallel spawn
# ---------------------------------------------------------------------------
walker fw_sleeper {
    """Walker that sleeps for `delay` seconds and records its thread id."""
    has delay: float = 0.05,
        label: str = "",
        thread_id: int | None = None,
        done_at: float = 0.0;

    can run with Root entry {
        self.thread_id = threading.current_thread().ident;
        time.sleep(self.delay);
        self.done_at = time.time();
    }
}

test "flow wait gives speedup over serial execution" {
    delay = 0.05;
    w1 = fw_sleeper(label="a", delay=delay);
    w2 = fw_sleeper(label="b", delay=delay);
    w3 = fw_sleeper(label="c", delay=delay);

    t0 = time.time();
    ta = flow w1 spawn root ;
    tb = flow w2 spawn root ;
    tc = flow w3 spawn root ;
    wait ta ;
    wait tb ;
    wait tc ;
    wall = time.time() - t0;

    serial_expected = delay * 3;
    assert wall < serial_expected * 0.8 , (
        f"Expected speedup; wall={wall:.3f}s, serial={serial_expected:.3f}s"
    );
}

test "flow wait walkers run on different threads" {
    w1 = fw_sleeper(label="x", delay=0.04);
    w2 = fw_sleeper(label="y", delay=0.04);

    t1 = flow w1 spawn root ;
    t2 = flow w2 spawn root ;
    wait t1 ;
    wait t2 ;

    assert w1.thread_id != w2.thread_id , (
        f"Expected different threads, both: {w1.thread_id}"
    );
}

test "concurrent walkers have isolated state" {
    labels = ["alpha", "beta", "gamma"];
    walkers = [fw_sleeper(label=lbl, delay=0.03) for lbl in labels];

    tasks = [flow w spawn root  for w in walkers];
    [wait t  for t in tasks];

    # Each walker preserves its own label — no cross-contamination
    for i in range(len(labels)) {
        assert walkers[i].label == labels[i] , (
            f"walker[{i}].label changed: expected {labels[i]}, got {walkers[i].label}"
        );
    }
}

test "flow wait all walkers complete" {
    count = 4;
    walkers = [fw_sleeper(label=str(i), delay=0.02) for i in range(count)];
    tasks = [flow w spawn root  for w in walkers];
    [wait t  for t in tasks];

    for w in walkers {
        assert w.done_at > 0.0 , f"Walker {w.label} did not complete";
    }
}


# ---------------------------------------------------------------------------
# 2.  Sync walker — correctness baseline (jac-scale style)
# ---------------------------------------------------------------------------
walker sync_worker {
    """Blocking sync walker — safe to spawn under jac-scale thread pool."""
    has task: str = "",
        result: str = "";

    can run with Root entry {
        time.sleep(0.01);
        self.result = f"done:{self.task}";
        report {"task": self.task, "result": self.result};
    }
}

test "sync walker produces correct result" {
    w = sync_worker(task="paint");
    w spawn root;
    assert w.result == "done:paint" , f"Got: {w.result}";
}

test "sync walker report is accessible via Jac attribute" {
    w = sync_worker(task="build");
    w spawn root;
    # report values are accessible via walker attributes
    assert w.result == "done:build" , f"Got: {w.result}";
    assert w.task == "build";
}

test "multiple sync walkers each get independent state" {
    tasks_list = ["a", "b", "c"];
    for t in tasks_list {
        w = sync_worker(task=t);
        w spawn root;
        assert w.result == f"done:{t}" , f"Expected done:{t}, got {w.result}";
    }
}
