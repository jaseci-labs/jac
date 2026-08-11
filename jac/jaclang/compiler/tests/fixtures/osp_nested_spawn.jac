"""Cross-backend OSP equivalence fixture: an ability spawns a second walker.

The `Outer` walker's entry ability spawns an `Inner` walker on a derived node,
then folds the inner walker's result back into its own state
(`Outer.sum = Inner.got = here.val * 2`). This pins that a nested spawn runs to
completion with its own isolated scope and the outer walk resumes correctly.

The nested `inner spawn` lowers to a nested `osp_spawn` with its own kernel
scope on every backend. The report-aggregation half of nested spawning is
pinned cross-backend by `osp_nested_report`.
"""

node Item {
    has val: int;
}

walker Inner {
    has got: int = 0;

    can grab with Item entry {
        self.got = here.val;
    }
}

walker Outer {
    has sum: int = 0;

    can run with Item entry {
        inner = Inner();
        inner spawn Item(val=here.val * 2);
        self.sum = self.sum + inner.got;
    }
}

def nested_spawn_py() -> dict[str, any] {
    o = Outer();
    o spawn Item(val=4);
    return {"sum": o.sum};
}


def nested_spawn_na() -> dict[str, any] {
    o = Outer();
    o spawn Item(val=4);
    return {"sum": o.sum};
}


def nested_spawn_cl() -> dict[str, any] {
    o = Outer();
    o spawn Item(val=4);
    return {"sum": o.sum};
}
