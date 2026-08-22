"""A `static has` carrying a default must not force instance defaults.

`static has` is class-level, so it takes no part in the instance dataclass
field order; `ir_in` has no default and legitimately follows it.
"""

obj Stage {
    static has PROVIDES: tuple = ('capability', );
    has ir_in: int,
        prog: int = 0;

    def run -> int {
        return self.ir_in + self.prog;
    }
}


def run -> int {
    return Stage(ir_in=2).run();
}
