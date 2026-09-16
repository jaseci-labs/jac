"""Dependency scheduling retains results and refreshes mutable query inputs."""

import from jaclang.runtime.osp_kernel {
    OspAccess,
    OspEngine,
    OspRuntime,
    OspTask,
    Slot,
    WalkerDesc,
    NodeDesc,
    WalkScope
}

glob events: list[str] = [],
     attempts: list[list[int]] = [],
     accesses: dict[int, OspAccess] = {},
     values: dict[int, int] = {100: 0, 200: 0},
     controls: dict[str, int] = {"reject": -1, "change": 0};

def step(w: any, n: any) {
    node_id: int = n;
    events.append("commit" + str(node_id));
    if node_id == 2 {
        values[100] += 1;
        controls["epoch"] += controls["mutate"];
        if controls["change"] {
            accesses[3] = OspAccess(reads=[200], unknown=False);
        }
    }
}

def inspect(task: OspTask) {
    node_id: int = task.b;
    events.append("inspect" + str(node_id));
    task.access = accesses.get(node_id, OspAccess(unknown=True));
}

def run(tasks: list[OspTask]) {
    batch: list[int] = [];
    for task in tasks {
        node_id: int = task.b;
        batch.append(node_id);
        events.append("run" + str(node_id));
        task.state = values[100] + 1;
    }
    attempts.append(batch);
}

def commit(task: OspTask) -> bool {
    node_id: int = task.b;
    if controls["reject"] == node_id {
        return False;
    }
    if node_id == 3 {
        assert task.state == 2;
    }
    step(task.a, task.b);
    return True;
}

def drop(task: OspTask) {
    node_id: int = task.b;
    events.append("drop" + str(node_id));
    task.state = 0;
}

def tag(n: any) -> int {
    return 1;
}

def isa(a: int, b: int) -> bool {
    return a == b;
}

def desc(t: int) -> NodeDesc {
    return NodeDesc(t, [], []);
}

def finish(scope: WalkScope, ok: bool) {}
def topology_epoch -> int {
    return controls["epoch"];
}

def runtime -> OspRuntime {
    return OspRuntime(
        tag,
        isa,
        desc,
        finish,
        task_width=2,
        run_tasks=run,
        commit_task=commit,
        drop_task=drop,
        dependency_inspection=True,
        inspect_task=inspect,
        topology_epoch=topology_epoch
    );
}

def reset {
    events.clear();
    attempts.clear();
    values[100] = 0;
    controls["reject"] = -1;
    controls["change"] = 0;
    controls["mutate"] = 0;
    controls["epoch"] = 0;
    accesses.clear();
    accesses[2] = OspAccess(writes=[100], unknown=False);
    accesses[3] = OspAccess(reads=[100], unknown=False);
    accesses[4] = OspAccess(writes=[200], unknown=False);
}

def event_index(name: str) -> int {
    for i in range(len(events)) {
        if events[i] == name {
            return i;
        }
    }
    assert False;
    return -1;
}

def event_count(name: str) -> int {
    count = 0;
    for event in events {
        if event == name {
            count += 1;
        }
    }
    return count;
}

test "A and C run first and C survives until B commits" {
    reset();
    engine = OspEngine([]);
    engine.spawn(runtime(), 99, WalkerDesc(10, [Slot(1, step)], []), [2, 3, 4]);
    assert str(attempts) == "[[2, 4], [3]]";
    assert [
        s
        for s in events
        if s.startswith("commit")
    ]
        == ["commit2", "commit3", "commit4"];
    assert event_count("inspect4") == 1;
    assert event_count("inspect3") == 2;
    assert event_index("run3") < event_index("drop4");
}

test "preview has no worker sized horizon and shared reads remain runnable" {
    reset();
    engine = OspEngine([]);
    starts = [2, 3, 4, 5, 6, 7, 8];
    engine.spawn(runtime(), 99, WalkerDesc(10, [Slot(1, step)], []), starts);
    assert event_index("inspect8") < event_index("run2");
    assert all(len(batch) <= 2 for batch in attempts);
    assert sum(len(batch) for batch in attempts) == len(starts);
    reset();
    accesses[2] = OspAccess(reads=[100], unknown=False);
    tasks = [OspTask(Slot(1, step), 99, n, []) for n in [2, 3, 4]];
    ready = engine.runnable(runtime(), tasks, 0);
    assert len(ready) == 2 and ready[0] is tasks[0] and ready[1] is tasks[1];
}

test "read after write write after read and multiple writers block bodies" {
    reset();
    engine = OspEngine([]);
    tasks = [OspTask(Slot(1, step), 99, n, []) for n in [2, 3, 4]];
    for first in [OspAccess(reads=[100]), OspAccess(writes=[100])] {
        accesses[2] = first;
        accesses[3] = OspAccess(writes=[100]);
        accesses[4] = OspAccess(writes=[100]);
        ready = engine.runnable(runtime(), tasks, 0);
        assert len(ready) == 1 and ready[0] is tasks[0];
        assert tasks[1].dependency == 0;
        assert tasks[2].dependency == 1;
    }
}

test "unstarted targets are inspected again after a commit" {
    reset();
    controls["change"] = 1;
    engine = OspEngine([]);
    engine.spawn(runtime(), 99, WalkerDesc(10, [Slot(1, step)], []), [2, 3, 4]);
    assert str(attempts) == "[[2, 4], [3]]";
    assert event_count("inspect3") == 2;
}

test "a failed validation discards retained later results before serial execution" {
    reset();
    controls["reject"] = 3;
    engine = OspEngine([]);
    engine.spawn(runtime(), 99, WalkerDesc(10, [Slot(1, step)], []), [2, 3, 4]);
    assert event_index("drop4") < event_index("commit3");
    assert [
        s
        for s in events
        if s.startswith("commit")
    ]
        == ["commit2", "commit3", "commit4"];
}

test "topology boundary disables inspection for the rest of this walker" {
    reset();
    accesses[3] = OspAccess(serial=True);
    engine = OspEngine([]);
    engine.spawn(runtime(), 99, WalkerDesc(10, [Slot(1, step)], []), [2, 3, 4]);
    assert str(attempts) == "[[2]]";
    assert event_count("inspect4") == 0;
    assert [
        s
        for s in events
        if s.startswith("commit")
    ]
        == ["commit2", "commit3", "commit4"];
}

test "a topology change during commit discards retained predictions" {
    reset();
    controls["mutate"] = 1;
    engine = OspEngine([]);
    engine.spawn(runtime(), 99, WalkerDesc(10, [Slot(1, step)], []), [2, 3, 4]);
    assert str(attempts) == "[[2, 4], [3, 4]]";
    assert event_count("inspect3") == 1;
    assert event_index("drop4") < event_index("run3");
}
