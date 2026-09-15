"""CPU-heavy walker microbenchmark: 16 independent jobs, ordered reports.

Each job performs 6.4 million floating-point recurrence steps. The 64 steps
per loop are deliberately unrolled to amortize speculative block bookkeeping.
This measures favorable, conflict-free CPU work, not general walker speed.
"""

def calculate(seed: float) -> float {
    value = seed;
    for i = 0 while i < 100000 with i += 1 {
        value = (value + seed) / (value + seed + 1.0);
        value = (value + seed) / (value + seed + 1.0);
        value = (value + seed) / (value + seed + 1.0);
        value = (value + seed) / (value + seed + 1.0);
        value = (value + seed) / (value + seed + 1.0);
        value = (value + seed) / (value + seed + 1.0);
        value = (value + seed) / (value + seed + 1.0);
        value = (value + seed) / (value + seed + 1.0);
        value = (value + seed) / (value + seed + 1.0);
        value = (value + seed) / (value + seed + 1.0);
        value = (value + seed) / (value + seed + 1.0);
        value = (value + seed) / (value + seed + 1.0);
        value = (value + seed) / (value + seed + 1.0);
        value = (value + seed) / (value + seed + 1.0);
        value = (value + seed) / (value + seed + 1.0);
        value = (value + seed) / (value + seed + 1.0);
        value = (value + seed) / (value + seed + 1.0);
        value = (value + seed) / (value + seed + 1.0);
        value = (value + seed) / (value + seed + 1.0);
        value = (value + seed) / (value + seed + 1.0);
        value = (value + seed) / (value + seed + 1.0);
        value = (value + seed) / (value + seed + 1.0);
        value = (value + seed) / (value + seed + 1.0);
        value = (value + seed) / (value + seed + 1.0);
        value = (value + seed) / (value + seed + 1.0);
        value = (value + seed) / (value + seed + 1.0);
        value = (value + seed) / (value + seed + 1.0);
        value = (value + seed) / (value + seed + 1.0);
        value = (value + seed) / (value + seed + 1.0);
        value = (value + seed) / (value + seed + 1.0);
        value = (value + seed) / (value + seed + 1.0);
        value = (value + seed) / (value + seed + 1.0);
        value = (value + seed) / (value + seed + 1.0);
        value = (value + seed) / (value + seed + 1.0);
        value = (value + seed) / (value + seed + 1.0);
        value = (value + seed) / (value + seed + 1.0);
        value = (value + seed) / (value + seed + 1.0);
        value = (value + seed) / (value + seed + 1.0);
        value = (value + seed) / (value + seed + 1.0);
        value = (value + seed) / (value + seed + 1.0);
        value = (value + seed) / (value + seed + 1.0);
        value = (value + seed) / (value + seed + 1.0);
        value = (value + seed) / (value + seed + 1.0);
        value = (value + seed) / (value + seed + 1.0);
        value = (value + seed) / (value + seed + 1.0);
        value = (value + seed) / (value + seed + 1.0);
        value = (value + seed) / (value + seed + 1.0);
        value = (value + seed) / (value + seed + 1.0);
        value = (value + seed) / (value + seed + 1.0);
        value = (value + seed) / (value + seed + 1.0);
        value = (value + seed) / (value + seed + 1.0);
        value = (value + seed) / (value + seed + 1.0);
        value = (value + seed) / (value + seed + 1.0);
        value = (value + seed) / (value + seed + 1.0);
        value = (value + seed) / (value + seed + 1.0);
        value = (value + seed) / (value + seed + 1.0);
        value = (value + seed) / (value + seed + 1.0);
        value = (value + seed) / (value + seed + 1.0);
        value = (value + seed) / (value + seed + 1.0);
        value = (value + seed) / (value + seed + 1.0);
        value = (value + seed) / (value + seed + 1.0);
        value = (value + seed) / (value + seed + 1.0);
        value = (value + seed) / (value + seed + 1.0);
        value = (value + seed) / (value + seed + 1.0);
    }
    return value;
}

node Batch {}

node Job {
    has index: int,
        result: float = 0.0;
}

walker Calculate {
    can queue with Batch entry {
        visit [-->];
    }

    can step with Job entry {
        here.result = calculate(float(here.index));
        report here.index;
        report here.result;
        visit [-->];
    }
}

with entry {
    batch = Batch();
    jobs: list[Job] = [];
    for i = 1 while i <= 16 with i += 1 {
        job = Job(i);
        jobs.append(job);
        batch ++> job;
    }
    worker = Calculate();
    batch spawn worker;
    assert len(worker.reports) == 32;
    for job in jobs {
        offset = (job.index - 1) * 2;
        reported_index: int = worker.reports[offset];
        reported_result: float = worker.reports[offset + 1];
        assert reported_index == job.index;
        assert reported_result == job.result;
        print(reported_index, reported_result);
    }
}
