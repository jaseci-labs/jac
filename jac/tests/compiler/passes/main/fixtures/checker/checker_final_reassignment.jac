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
