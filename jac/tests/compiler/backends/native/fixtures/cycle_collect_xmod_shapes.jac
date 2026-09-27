"""Objects for test_native_cycle_collect_cross_module.jac: cycles built here
are collected from the other module, and the reverse."""

glob drops: int = 0;

obj Box {
    has tag: int = 0,
        other: Box | None = None;

    def drop {
        drops += 1;
    }
}

def make_pair {
    a = Box(tag=1);
    b = Box(tag=2);
    a.other = b;
    b.other = a;
}

def read_drops -> int {
    return drops;
}

def collect_there -> int {
    __rc_collect_cycles();
    return 0;
}
