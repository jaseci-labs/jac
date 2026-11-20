"""Generic archetype owned by another module, for the cross-module read.

The consumer never sees this file's layout registry; it reaches `Cell`'s
erased slot through the type argument it writes at its own call sites, and
`build` hands back cells this module allocated so the read also covers a slot
some other module's code wrote.
"""

obj Leaf {
    has num: int = 0,
        name: str = "";
}

obj Cell[T] {
    has slot: T,
        kind: int = 0;
}

def build(n: int) -> Cell[Leaf] {
    return Cell[Leaf](slot=Leaf(num=n, name="lib"), kind=n * 2);
}
