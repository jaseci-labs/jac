"""A subclass of an imported base, copied both here (where the subclass is
visible, so the copy is a `MainDerived`) and inside the base's module (which
cannot see `MainDerived`, so the native copy raises `TypeError` rather than
building a `LibBase`)."""

import copy;
import from copy_xmod_lib { LibBase, lib_clone }

obj MainDerived(LibBase) {
    has extra: str = "e";

    override def label -> str {
        return f"MainDerived({self.n}, {self.extra})";
    }
}

def run_probe {
    m = MainDerived(n=2, extra="x");
    b: LibBase = m;
    c = copy.copy(b);
    print(c.label());
    d = lib_clone(b);
    print(d.label());
}

with entry {
    run_probe();
}
