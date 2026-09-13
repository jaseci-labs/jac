"""Dependency barriers survive worker retirement, failure and idle workers."""

import os;
import from pathlib { Path }
import from tempfile { TemporaryDirectory }
import from jaclang.cli.workpool { WorkPool, pool_available }

test "a diamond waits for its prerequisite and runs each item once" {
    for parallel in [False, True] {
        if parallel and not pool_available() {
            continue;
        }
        with TemporaryDirectory() as directory {
            dependencies = {0: {1, 2}, 1: {3}, 2: {3}};
            records: dict[int, dict[str, any]] = {};
            def job(request: dict[str, any]) -> int {
                idx = int(request["idx"]);
                for dependency in dependencies.get(idx, set()) {
                    assert (Path(directory) / str(dependency)).is_file();
                }
                (Path(directory) / str(idx)).write_text("done");
                return idx;
            }
            def recorded(idx: int, record: dict[str, any]) {
                assert idx not in records;
                records[idx] = record;
            }
            pool = WorkPool(
                items=["root", "left", "right", "shared"],
                job=job,
                on_record=recorded,
                jobs=4,
                prerequisites=dependencies,
                retire=lambda (served: int, rss: int) -> bool { return True; }
            );
            if parallel {
                pool.run();
            } else {
                pool.run_inline();
            }
            assert len(records) == 4;
            for (idx, record) in records.items() {
                assert record.get("result") == idx , record;
                assert record["wall_seconds"] >= 0;
                assert record["setup_seconds"] >= 0;
                assert record["worker_pid"] > 0;
            }
        }
    }
}

test "a dead dependency worker releases pending consumers without losing results" {
    if not pool_available() {
        return;
    }
    records: dict[int, dict[str, any]] = {};
    def job(request: dict[str, any]) -> int {
        if request["idx"] == 1 {
            os._exit(9);
        }
        return int(request["idx"]);
    }
    def recorded(idx: int, record: dict[str, any]) {
        records[idx] = record;
    }
    WorkPool(
        items=["consumer", "dependency"],
        job=job,
        on_record=recorded,
        jobs=2,
        prerequisites={0: {1}}
    ).run();
    assert len(records) == 2;
    assert "crash" in records[1];
    assert records[0]["result"] == 0;
}

test "cyclic prerequisites are rejected before starting workers" {
    caught = False;
    try {
        WorkPool(
            items=["one", "two"],
            job=lambda (request: dict[str, any]) { return None; },
            on_record=lambda (idx: int, record: dict[str, any]) { return None; },
            prerequisites={0: {1}, 1: {0}}
        );
    } except ValueError {
        caught = True;
    }
    assert caught;
}
