"""Repro fixture: two walkers race on the same Counter node.

SetA writes counter.a (scalar only — exercises put_partial path).
SetB writes counter.b (scalar only — exercises put_partial path, dispatch guard test).
SetBAndAddEdge writes counter.b AND adds an Item child (exercises _put_node_atomic path).
After both pods commit, both .a and .b must be set.
"""

node Item {
    has name: str = "";
}

node Counter {
    has a: int = 0,
        b: int = 0;
}

walker:pub Init {
    can create with Root entry {
        existing = [-->[?:Counter]];
        if not existing {
            here ++> Counter();
        }
        report {"ok": True};
    }
}

walker:pub SetA {
    has value: int = 0;

    can write with Root entry {
        counters = [-->[?:Counter]];
        counters[0].a = self.value;
        report {"ok": True, "a": counters[0].a};
    }
}

walker:pub SetB {
    has value: int = 0;

    can write with Root entry {
        counters = [-->[?:Counter]];
        counters[0].b = self.value;
        report {"ok": True, "b": counters[0].b};
    }
}

walker:pub SetBAndAddEdge {
    has value: int = 0,
        item_name: str = "x";

    can write with Root entry {
        counters = [-->[?:Counter]];
        counters[0].b = self.value;
        here ++> Item(name=self.item_name);
        report {"ok": True, "b": counters[0].b};
    }
}

walker:pub ReadCounter {
    can read with Root entry {
        counters = [-->[?:Counter]];
        c = counters[0];
        report {"a": c.a, "b": c.b};
    }
}
