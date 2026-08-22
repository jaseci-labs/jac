"""Generic methods on archetypes monomorphize per call site (#7626 A4).

`Box.pick[T]` registers as a method template (keyed Arch.method) instead
of hitting the declaration-time unlowerable-type error; each call site
stamps a specialization with `self` prepended to the specialized
signature and dispatches it directly.
"""

obj Box {
    has val: int = 0;

    def pick[T](a: T, b: T) -> T {
        return a if self.val > 0 else b;
    }
}

def pick_int(v: int) -> int {
    return Box(val=v).pick(7, 9);
}

def pick_str_len(v: int) -> int {
    a: str = "xx";
    b: str = "yyy";
    return len(Box(val=v).pick(a, b));
}
