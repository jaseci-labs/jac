"""Void lambdas with statement-call bodies must terminate with `ret void`.

A `-> None` lambda whose single statement is a call got a `ret i64 0`
terminator -- the statement-call's value was coerced into the void return --
and LLVM verification rejected the whole module with E5020. That took down
any module carrying such a lambda, e.g. a callable field assigned
`lambda (x: int) -> None { ... }`.
"""

glob SEEN: list[int] = [];

obj Probe {
    has on_event: any = None;

    def fire(x: int) {
        if self.on_event is not None {
            self.on_event(x);
        }
    }
}

def bump(x: int) {
    SEEN.append(x);
}

def run -> int {
    p = Probe();
    p.on_event = lambda (x: int) { bump(x); };
    p.fire(7);
    return len(SEEN);
}

with entry {
    print(run());
}
