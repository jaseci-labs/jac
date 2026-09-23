"""The base class and a copying function, in a module that does not import
the module defining the subclass it is handed."""

import copy;

obj LibBase {
    has n: int = 0,
        names: list[str] = [];

    def label -> str {
        return f"LibBase({self.n})";
    }
}

def lib_clone(b: LibBase) -> LibBase {
    return copy.copy(b);
}
