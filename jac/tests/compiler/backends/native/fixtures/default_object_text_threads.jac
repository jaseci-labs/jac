"""Threads writing out cyclic objects do not see each other's progress."""

obj Pair {
    has label: int,
        other: Pair | None = None;
}

obj Job {
    has seed: int = 0,
        agree: int = 0,
        size: int = 0;
}

def ring(seed: int) -> Pair {
    a = Pair(label=seed);
    b = Pair(label=seed + 100, other=a);
    a.other = b;
    return a;
}

def work(seed: int) -> int {
    a = ring(seed);
    first = str(a);
    same = 1;
    for i in range(300) {
        if str(a) != first {
            same = 0;
        }
    }
    a.other = None;
    return same * len(first);
}

def build(n: int) -> list[Job] {
    jobs: list[Job] = [];
    for i in range(n) {
        jobs.append(Job(seed=i));
    }
    return jobs;
}

with entry {
    jobs = build(64);
}

with entry {
    flow for j in &mut jobs {
        j.size = work(j.seed);
    }
    wrong = 0;
    for i in range(len(jobs)) {
        if jobs[i].size != len(str(ring(jobs[i].seed))) {
            wrong += 1;
        }
    }
    print(str(ring(7)));
    print("wrong", wrong);
}
