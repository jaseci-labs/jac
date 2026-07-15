"""Native `T.__new__(T)` adopt-shell lowering.

A type that owns a real constructor (`init(v)`) but is ALSO produced by a
method (`clone`/`alias`) needs a second construction path that does NOT re-run
`init`: a static shell allocates a bare instance via `T.__new__(T)`, then writes
the handle/flag fields on that fresh local.  This is the shape the rust-FFI na
loader synthesizes for ctor-bearing adoptable opaque types (`_synth.jac`
`_adopt`).  Before this fix NaIRGenPass could not lower `__new__` (nor the
external-local field writes on the result), so the whole method demoted to
Python-only.  These functions exercise the primitive in pure Jac.
"""

obj Cell {
    has handle: int = 0;
    has closed: bool = True;

    def init(v: int) {
        self.handle = v;
        self.closed = False;
    }

    static def _adopt(raw: int) -> Cell {
        adopted = Cell.__new__(Cell);
        adopted.handle = raw;
        adopted.closed = False;
        return adopted;
    }

    def alias() -> Cell {
        return Cell._adopt(self.handle + 100);
    }

    def get -> int {
        return self.handle;
    }

    def is_open -> bool {
        return not self.closed;
    }
}

# The real ctor path still runs init (handle = v).
def ctor_handle -> int {
    return Cell(7).get();
}

# The adopt path: __new__ (no init) + field writes; alias mints handle+100.
def adopt_handle -> int {
    c = Cell(7);
    a = c.alias();
    return a.get();
}

# The adopt shell explicitly writes closed=False on the fresh __new__ local.
def adopt_is_open -> int {
    c = Cell(7);
    a = c.alias();
    return 1 if a.is_open() else 0;
}

# Adopting does not disturb the originating instance.
def adopt_leaves_origin -> int {
    c = Cell(7);
    _ = c.alias();
    return c.get();
}
