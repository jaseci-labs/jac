import sys;

node BenchStart {}
node BenchJob { has steps: int; }
node BenchHop { has enabled: bool = True; }
node BenchData { has value: int; }
edge BenchLink {}
edge BenchFinish {}

def bench_targets(job: BenchJob) -> list[BenchData] {
    return [job->:BenchLink:->[?:BenchHop, enabled==True]->:BenchFinish:->[?:BenchData]];
}

def bench_compute(seed: int, steps: int) -> int {
    value = seed;
    for i in range(steps) { value = (value * 31 + i) % 1000003; }
    return value;
}

walker DependencyBench {
    can begin with BenchStart entry { visit [-->]; }
    can step with BenchJob entry {
        for target in bench_targets(here) {
            target.value = bench_compute(target.value, here.steps);
            report target.value;
        }
    }
}

with entry {
    groups = int(sys.argv[1]);
    query_size = int(sys.argv[2]);
    steps = int(sys.argv[3]);
    hub = BenchStart();
    pool: list[BenchData] = [];
    for i in range(groups * query_size) { pool.append(BenchData(i + 1)); }
    for i in range(16) {
        job = BenchJob(steps);
        hub ++> job;
        hop = BenchHop();
        job +>:BenchLink():+> hop;
        for j in range(query_size) {
            hop +>:BenchFinish():+> pool[(i % groups) * query_size + j];
        }
    }
    visitor = DependencyBench();
    hub spawn visitor;
    assert len(visitor.reports) == 16 * query_size;
    checksum = 0;
    for item in visitor.reports {
        value: int = item;
        checksum = (checksum * 31 + value) % 1000003;
    }
    for item in pool { checksum = (checksum * 31 + item.value) % 1000003; }
    print(checksum);
}
