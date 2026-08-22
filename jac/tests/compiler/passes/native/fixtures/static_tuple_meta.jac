"""Class-level tuple metadata, the shape every pass in the compiler carries.

`PROVIDES`/`REQUIRES` are read-only class constants: the annotation is the
widened `tuple`, so the layout can only come from the literal. The base
class declares the empty tuple, which has to lower as well.
"""

obj Stage {
    has ir_in: int = 0;
    static has PROVIDES: tuple = (),
        REQUIRES: tuple = ();

    def run -> int {
        return self.ir_in + 1;
    }
}


obj Access(Stage) {
    static has PROVIDES: tuple = ('access-checks', );
}


def first_provided -> str {
    return Access.PROVIDES[0];
}


def run -> int {
    return Stage(ir_in=1).run() + len(first_provided());
}
