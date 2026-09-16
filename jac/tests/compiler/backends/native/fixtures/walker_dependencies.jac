node Start {}
node Job {
    has mode: int,
        result: int = 0,
        work: int = 0;
}

node Hop {
    has enabled: bool = True;
}
node Data {
    has value: int;
}
edge Link {}
edge Finish {}

def targets(job: Job) -> list[Data] {
    return [job->:Link:->[?:Hop, enabled==True]->:Finish:->[?:Data]];
}

def identity(target: Data) -> Data {
    return target;
}

def body_work(seed: int) -> int {
    result = seed;
    for i in range(20000) {
        result = (result * 31 + i) % 1000003;
    }
    return result;
}

walker Inspector {
    can start with Start entry {
        visit [-->];
    }
    can step with Job entry {
        candidates = targets(here);
        for target in candidates {
            alias = identity(target);
            if here.mode == 0 {
                alias.value = 7;
            } else {
                here.result = alias.value;
            }
        }
        report here.result;
        here.work = body_work(here.mode);
    }
}

with entry {
    start = Start();
    a = Job(0);
    b = Job(1);
    c = Job(2);
    shared = Data(1);
    independent = Data(17);
    start ++> a;
    start ++> b;
    start ++> c;
    for job in [a, b, c] {
        hop = Hop();
        job +>:Link():+> hop;
        if job.mode < 2 {
            hop +>:Finish():+> shared;
        } else {
            hop +>:Finish():+> independent;
        }
    }
    visitor = Inspector();
    start spawn visitor;
    assert shared.value == 7;
    assert b.result == 7;
    assert c.result == 17;
    assert len(visitor.reports) == 3;
    for item in visitor.reports {
        value: int = item;
        print(value);
    }
}
