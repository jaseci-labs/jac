"""A raise in an enforced frame drops the frame's owned locals exactly once on
the error path, then returns through the error slot to a handling caller."""
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
    try {
        work();
        print("never");
    } except ValueError {
        print("handled");
    }
}
