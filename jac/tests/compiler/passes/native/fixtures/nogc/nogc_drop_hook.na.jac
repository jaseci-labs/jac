"""drop hook determinism: def drop fires exactly once per value, in a
defined order, on every exit kind (fall-through, early return)."""

obj Res {
    has tag: int = 0;

    def drop {
        print(self.tag);
    }
}

def use_and_leave_early(flag: int) -> int {
    a: own Res = Res(tag=10);
    if flag > 0 {
        return 1;
    }
    b: own Res = Res(tag=20);
    return 2;
}

def run_all {
    print(use_and_leave_early(1));
    print(use_and_leave_early(0));
    r: own Res = Res(tag=99);
    print("end");
}

with entry {
    run_all();
}
