import from inline_owned_child { Counter }
obj Record {
    has value: int = 0,
        a: float = 1.0,
        b: float = 2.0,
        c: float = 3.0,
        d: float = 4.0,
        e: float = 5.0,
        f: float = 6.0,
        g: float = 7.0;
}

obj Buffer {
    has values: list[own Record] = [];
}
obj State {
    has first: own Buffer = Buffer(),
        second: own Buffer = Buffer(),
        counter: own Counter = Counter();
}

def make_state -> own State {
    s = State();
    s.first.values.append(Record(value=12));
    s.second.values.append(Record(value=34));
    for i in range(20) {
        s.first.values.append(Record(value=i));
    }
    return s;
}
