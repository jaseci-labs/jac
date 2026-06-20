"""Builtin/typing names used as plain identifiers must not pull an ambient
import; genuine references (annotations) must keep theirs."""

obj Box {
    has schedule: int = 0;
}

# `new` builtin name used only as a def name -> no import
def new(x: int) -> int {
    return x;
}

# `printgraph` builtin name used as a keyword-argument key below -> no import
def takes_kw(printgraph: int) -> int {
    return printgraph;
}

# genuine references
def uses_callable(cb: Callable) -> int {
    return 1;
}

def uses_proto(p: APIProtocol) -> int {
    return 1;
}

# builtin/typing names as plain variables -> no import
glob schedule = 1,
     restspec = 2,
     Sequence = 3,
     b = Box();

# attribute member -> no import
with entry {
    b.schedule = schedule;
    # keyword-argument key (`printgraph`) -> no import
    print(new(restspec), takes_kw(printgraph=1), Sequence, b.schedule);
    # match-pattern keyword key (`schedule`) -> no import
    match b {
        case Box(schedule=1): print("one");
        case _: print("other");
    }
}
