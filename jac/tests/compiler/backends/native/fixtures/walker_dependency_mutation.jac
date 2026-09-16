node Hub {}
node Cell { has value: int; }
node Gate { has enabled: bool = True; }
obj Choice { has target: Cell; }
node ChangeJob {
    has mode: int, gate: Gate, choice: Choice, replacement: Cell,
        output: int = -1, payload: list[int] = [0];
}
edge FirstHop {}
edge SecondHop {}

def selected(job: ChangeJob) -> list[Cell] {
    return [job->:FirstHop:->[?:Gate, enabled==True]->:SecondHop:->[?:Cell]];
}

walker MutableTargets {
    can start with Hub entry { visit [-->]; }
    can step with ChangeJob entry {
        if here.mode == 0 {
            here.gate.enabled = False;
            here.choice.target = here.replacement;
            here.payload = [11, 22];
        } else {
            candidates = selected(here);
            target = here.choice.target;
            target.value += 1;
            here.output = len(candidates);
            here.payload = [target.value];
        }
        report here.payload;
    }
}

walker PriorWrite {
    can start with Hub entry { visit [-->]; }
    can step with ChangeJob entry {
        here.gate.enabled = False;
        candidates = selected(here);
        here.output = len(candidates);
        report here.output;
    }
}

node TopologyJob { has value: int; }
walker ChangeTopology {
    can start with Hub entry { visit [-->]; }
    can step with TopologyJob entry {
        if here.value == 0 { here ++> TopologyJob(99); }
        report here.value;
        visit [-->];
    }
}

walker ChangeAtStart {
    can start with Hub entry {
        here ++> TopologyJob(7);
        visit [-->];
    }
    can step with TopologyJob entry { report here.value; }
}

with entry {
    hub = Hub();
    old = Cell(10);
    replacement = Cell(20);
    independent = Cell(30);
    gate = Gate();
    other_gate = Gate();
    choice = Choice(old);
    a = ChangeJob(0, gate, choice, replacement);
    b = ChangeJob(1, gate, choice, replacement);
    c = ChangeJob(2, other_gate, Choice(independent), independent);
    for job in [a, b, c] {
        hub ++> job;
        job +>:FirstHop():+> job.gate;
    }
    gate +>:SecondHop():+> old;
    other_gate +>:SecondHop():+> independent;
    visitor = MutableTargets();
    hub spawn visitor;
    assert old.value == 10 and replacement.value == 21 and independent.value == 31;
    assert b.output == 0 and c.output == 1;
    assert len(visitor.reports) == 3;
    first: list[int] = visitor.reports[0];
    second: list[int] = visitor.reports[1];
    third: list[int] = visitor.reports[2];
    assert first is a.payload and second is b.payload and third is c.payload;
    assert first == [11, 22] and second == [21] and third == [31];
    gate.enabled = True;
    other_gate.enabled = True;
    prior = PriorWrite();
    hub spawn prior;
    assert a.output == 0 and b.output == 0 and c.output == 0;
    assert len(prior.reports) == 3;

    topology = Hub();
    for i in range(6) { topology ++> TopologyJob(i); }
    changer = ChangeTopology();
    topology spawn changer;
    assert len(changer.reports) == 7;
    for i in range(6) {
        item: int = changer.reports[i];
        assert item == i;
    }
    last: int = changer.reports[6];
    assert last == 99;
    creator = ChangeAtStart();
    topology spawn creator;
    assert len(creator.reports) == 7;
    print("mutable targets, retained reports and topology fallback passed");
}
