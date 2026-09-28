"""`copy.copy` natively: a new instance of the runtime class sharing its fields.

Every line is printed by both backends and diffed, so CPython's `copy` is the
oracle. Covers an obj copied through a base-typed parameter (the copy is the
subclass, with its extra fields), a `class` archetype, a method copying
`self`, an optional archetype, scalar mutation staying private while a shared
list shows through both, the container copies, and the atomic values `copy`
hands back unchanged. `import copy`, `import copy as cp` and
`import from copy { copy as shallow }` all reach the same lowering.
"""

import copy;
import copy as cp;
import from copy { copy as shallow }

obj Base {
    has name: str = "b",
        tags: list[str] = [];

    def describe -> str {
        return f"Base({self.name}, {self.tags})";
    }
}

obj Derived(Base) {
    has extra: int = 7,
        note: str | None = None,
        weights: dict[str, float] = {};

    override def describe -> str {
        return f"Derived({self.name}, {self.tags}, {self.extra}, {self.note}, {self.weights})";
    }
}

class Point {
    has x: int = 0,
        y: int = 0;

    def __init__(self: Point, x: int = 0, y: int = 0) {
        self.x = x;
        self.y = y;
    }

    def moved(self: Point, dx: int) -> Point {
        other = copy.copy(self);
        other.x = other.x + dx;
        return other;
    }
}

obj Holder {
    has point: Point = Point(),
        maybe: Point | None = None,
        count: int = 0;
}

def clone_base(b: Base) -> Base {
    return copy.copy(b);
}

def archetypes {
    d = Derived(name="d", tags=["t"], extra=3, note="n", weights={"w": 0.5});
    b: Base = d;
    c = clone_base(b);
    print(c.describe(), type(c).__name__, c is d);
    c.name = "changed";
    c.tags.append("shared");
    print(d.describe());
    print(c.describe());
    plain = Base(name="p");
    pc = clone_base(plain);
    print(pc.describe(), type(pc).__name__, pc is plain);
    p = Point(1, 2);
    q = p.moved(10);
    print(p.x, p.y, q.x, q.y, q is p);
    h = Holder(point=p, maybe=q, count=4);
    h2 = cp.copy(h);
    h2.count = 9;
    print(h.count, h2.count, h2.point is p, h2.maybe is q);
    empty = Holder(point=p);
    e2 = copy.copy(empty);
    print(e2.maybe is None, e2.point is p);
    opt: Point | None = q;
    o2 = copy.copy(opt);
    print(o2 is q, o2 is None);
    none_opt: Point | None = None;
    print(copy.copy(none_opt) is None);
}

def containers {
    lst = [1, 2, 3];
    l2 = copy.copy(lst);
    l2.append(4);
    print(lst, l2, l2 is lst);
    names = ["a", "b"];
    n2 = shallow(names);
    n2[0] = "z";
    print(names, n2);
    rows = [[1], [2]];
    r2 = copy.copy(rows);
    r2[0].append(5);
    print(rows, r2, r2[0] is rows[0]);
    dd = {"a": 1, "b": 2};
    d2 = cp.copy(dd);
    d2["c"] = 3;
    print(dd, d2);
    s = {1, 2};
    s2 = shallow(s);
    s2.add(3);
    print(len(s), len(s2), 3 in s);
}

def atomics {
    st = "hello";
    print(copy.copy(st) is st, copy.copy(st));
    print(copy.copy(5), copy.copy(True), copy.copy(-3));
    t = (1, "x");
    print(copy.copy(t) == t, copy.copy(t));
}

with entry {
    archetypes();
    containers();
    atomics();
}
