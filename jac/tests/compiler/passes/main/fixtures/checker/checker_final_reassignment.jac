"""Fixture: Final immutability enforcement (issue #7354)."""
import from typing { Final }

obj Config {
    has name: Final[str] = "a";
}

obj Point {
    has x: Final[int];

    def init(x: int) {
        self.x = x;                    # OK: no-default Final set in init
    }
}

obj Tagged {
    has tag: Final[str] = "t";

    def init {
        self.tag = "u";                # <-- Error (Final with default reassigned in init)
    }
}

# Assigning a no-default Final in init is a scope rule, not a count (Pyright
# does no definite-assignment analysis here). Repeated writes -- sequential,
# branched, or in a loop -- are all legal inside init/postinit.
obj Pair {
    has a: Final[int];

    def init {
        self.a = 1;                    # OK: init write
        self.a = 2;                    # OK: init is not write-counted
    }
}

obj Cond {
    has v: Final[int];

    def init(flag: bool) {
        if flag {
            self.v = 1;                # OK
        } else {
            self.v = 2;                # OK
        }
    }
}

obj LoopInit {
    has w: Final[int];

    def init {
        for i in [1, 2, 3] {
            self.w = i;                # OK: still just an init write
        }
    }
}

# A `for` target binds a fresh symbol in the loop's scope, so re-using a Final
# name as a loop variable shadows it rather than writing it -- no E1121. Pinned
# deliberately: if scoping ever changes so the target resolves to the outer
# symbol, this becomes an error and the count in the driver test must be
# revisited on purpose rather than silently.
def for_target_shadows_final(items: list[int]) -> int {
    t: Final[int] = 1;
    total = t;
    for t in items {
        total += t;
    }
    return total;
}

glob RATE: Final[float] = 1.5;

with entry {
    c = Config(name="custom");         # OK: constructor initialization
    print(c.name);                     # OK: reading a Final attribute
    p = Point(3);
    print(p.x);

    y: Final[int] = 10;                # OK: declaring assignment
    b: Final = 99;                     # OK: bare Final infers from value
    print(y + b);

    c.name = "b";                      # <-- Error (Final attribute reassigned)
    y = 2;                             # <-- Error (Final local reassigned)
    y += 1;                            # <-- Error (augmented assignment)
    (y, w) = (1, 2);                   # <-- Error (unpacking into Final)
    del y;                             # <-- Error (deleting a Final)
    RATE = 2.0;                        # <-- Error (Final glob reassigned)
    print(w);
}
