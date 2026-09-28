"""`copy.deepcopy` natively, with CPython's memo semantics.

Both backends print and the outputs are diffed. A value reached twice in the
source is copied once (the two references in the copy are the same object), a
cycle between archetypes comes back as a cycle between the copies, nested
lists and dicts are fully independent of the source, tuples and strings of
immutables are returned as they are, and an instance behind a base-typed
variable deep-copies as its runtime subclass.
"""

import copy;
import from copy { deepcopy }

obj Inner {
    has v: int = 0,
        items: list[int] = [];
}

obj Outer {
    has label: str = "o",
        inner: Inner = Inner(),
        maybe: Inner | None = None,
        table: dict[str, list[int]] = {},
        pairs: list[tuple[int, str]] = [],
        crew: list[Inner] = [];
}

obj Cell {
    has v: int = 0,
        nxt: Cell | None = None;
}

obj Animal {
    has name: str = "a",
        marks: list[str] = [];

    def describe -> str {
        return f"Animal({self.name}, {self.marks})";
    }
}

obj Dog(Animal) {
    has tricks: list[str] = [];

    override def describe -> str {
        return f"Dog({self.name}, {self.marks}, {self.tricks})";
    }
}

def shared_and_nested {
    shared = Inner(v=5, items=[9]);
    o = Outer(
        label="L",
        inner=shared,
        maybe=shared,
        table={"k": [1, 2]},
        pairs=[(1, "a")],
        crew=[shared, Inner(v=6)]
    );
    o2 = deepcopy(o);
    print(o2.inner is o.inner, o2.inner is o2.maybe, o2.crew[0] is o2.inner);
    print(o2.inner.v, o2.inner.items, o2.crew[1].v, o2.crew[1] is o.crew[1]);
    o2.inner.items.append(10);
    o2.table["k"].append(3);
    print(o.inner.items, o2.inner.items);
    print(o.table, o2.table, o2.pairs);
}

def containers {
    nested = [[1, 2], [3]];
    n2 = copy.deepcopy(nested);
    n2[0].append(99);
    print(nested, n2);
    row = [1];
    grid = [row, row];
    g2 = copy.deepcopy(grid);
    g2[0].append(2);
    print(grid, g2, g2[0] is g2[1], g2[0] is row);
    dm = {"x": [1], "y": [2]};
    dm2 = copy.deepcopy(dm);
    dm2["x"].append(5);
    print(dm, dm2);
    words = {"p", "q"};
    w2 = copy.deepcopy(words);
    w2.add("r");
    print(len(words), len(w2), w2 is words);
    labels = {"a": "x", "b": "y"};
    print(copy.deepcopy(labels), copy.deepcopy(labels) is labels);
}

def cycles {
    a = Cell(v=1);
    b = Cell(v=2, nxt=a);
    a.nxt = b;
    a2 = copy.deepcopy(a);
    n1 = a2.nxt;
    if n1 is not None {
        print(a2.v, n1.v, n1.nxt is a2, a2 is a, n1 is b);
    }
    a.nxt = None;
    if n1 is not None {
        n1.nxt = None;
    }
}

def atomics_and_dynamic {
    tt = (1, "two", (3, 4));
    print(copy.deepcopy(tt) == tt, copy.deepcopy("s"), copy.deepcopy(3), copy.deepcopy(2.5));
    d = Dog(name="rex", marks=["m"], tricks=["sit"]);
    pet: Animal = d;
    dc = copy.deepcopy(pet);
    dc.marks.append("z");
    print(dc.describe(), type(dc).__name__);
    print(d.describe());
}

with entry {
    shared_and_nested();
    containers();
    cycles();
    atomics_and_dynamic();
}
