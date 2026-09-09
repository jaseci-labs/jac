"""Owned archetype values in a dict: an overwrite drops the old value, `pop`
hands the value to the receiver, `del` drops it, and the dict drop drops the
rest, identically in every memory mode (#8984 rule 3)."""

obj Box {
    has tag: int = 0;

    def drop { print("drop " + str(self.tag)); }
}

def sink(b: own Box) -> None {
    print("sink " + str(b.tag));
}

def run -> int {
    d: dict[str, own Box] = {};
    d["a"] = Box(tag=1);
    d["b"] = Box(tag=2);
    d["a"] = Box(tag=10);
    print("a=" + str(d["a"].tag));
    taken: own Box = d.pop("b");
    print("popped=" + str(taken.tag));
    del d["a"];
    d["c"] = Box(tag=3);
    sink(taken);
    return len(d);
}

with entry { print(run()); print("done"); }
