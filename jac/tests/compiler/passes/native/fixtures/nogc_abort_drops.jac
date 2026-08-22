"""A raise in an enforced frame runs the frame's drops, then aborts."""

obj Res {
    has tag: int = 0;

    def drop {
        print(f"drop {self.tag}");
    }
}

def work {
    a: own Res = Res(tag=1);
    b: own Res = Res(tag=2);
    print(a.tag);
    print("before");
    raise ValueError("boom");
    print(b.tag);
}

with entry {
    work();
    print("never");
}
