"""`?.` on an Any-typed base must stay Any, not collapse to NoneType.

The attribute may well exist at runtime; collapsing to NoneType poisoned
every downstream use (`mod_path = self._module?.__file__` became
NoneType and `Path(mod_path)` errored). Regression from runtimelib/server.
"""
obj Holder {
    has _module: any = None;

    def module_path() -> str | None {
        mod_path: str | None = self._module?.__file__;
        if mod_path {
            return mod_path;
        }
        return None;
    }
}

obj Pt {
    has x: int = 0;
}

def concrete_miss(p: Pt | None) -> None {
    # On a concrete class, ?. of a *missing* attribute is still NoneType.
    missing = p?.nope;
    bad: int = missing;   # Error: NoneType not assignable to int
    print(bad);
}
