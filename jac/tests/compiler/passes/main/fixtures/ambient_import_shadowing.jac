"""Builtin/typing names used as plain identifiers must not pull an ambient
import; genuine references (annotations) must keep theirs."""

obj Box {
    has schedule: int = 0;
}

# `new` builtin name used only as a def name -> no import
def new(x: int) -> int {
    return x;
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

with entry {
    # attribute member -> no import
    b.schedule = schedule;
    print(new(restspec), Sequence, b.schedule);
}
