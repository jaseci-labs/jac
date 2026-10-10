"""Void lambdas with statement-call bodies must terminate with `ret void`.

A `-> None` lambda whose single statement is a call got a `ret i64 0`
terminator -- the statement-call's value was coerced into the void return --
and LLVM verification rejected the whole module with E5020. That took down
any module carrying such a lambda, e.g. a callable field assigned
`lambda (x: int) -> None { ... }`.

The field stays `any`: storing the lambda lowers natively, and the module
must still lower even though nothing calls through the `any` value (main
refuses calls through untyped callables instead of dropping them).
"""

glob SEEN: list[int] = [];

def bump(x: int) {
    SEEN.append(x);
}

obj Probe {
    has on_event: any = None;

    def fire(x: int) {
        bump(x);
    }
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
