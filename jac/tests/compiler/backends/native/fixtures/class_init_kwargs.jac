"""Keyword construction binds against the initializer's own parameters."""

def tick(v: int) -> int {
    print("tick", v);
    return v;
}

class Point {
    has x: int = 0,
        y: int = 0;

    def __init__(self: Point, x: int, y: int) {
        self.x = x;
        self.y = y;
    }
}

class Pair {
    has x: int = 0,
        y: int = 0;

    def init(self: Pair, x: int, y: int) {
        self.x = x;
        self.y = y;
    }
}

obj Implicit {
    has x: int = 0,
        y: int = 0;

    def init(x: int, y: int) {
        self.x = x;
        self.y = y;
    }
}

class Base {
    has a: int = 0;

    def init(self: Base, a: int) {
        self.a = a;
    }
}

class Derived(Base) {
    has b: int = 0;

    def init(self: Derived, a: int, b: int) {
        super.init(a=a);
        self.b = b;
    }
}

class Acc {
    has x: int = 0,
        total: int = 0;

    def init(self: Acc, x: int) {
        self.total = x * 2;
    }
}

class Heir(Acc) {
    has extra: int = 0;
}

obj Module {
    has name: str = "";
}

class Program {
    has main_mod: Module | None = None,
        label: str = "";

    def init(self: Program, main_mod: Module | None = None, label: str = "dflt") {
        self.main_mod = main_mod;
        self.label = label;
    }
}

obj OBase {
    has a: int = 1;
}

class Mixed(OBase) {
    has b: int = 2;
}

class Plain {
    has b: int = 2;
}

class PlainHeir(Plain) {
    has c: int = 3;
}

with entry {
    p = Point(x=1, y=2);
    print(p.x, p.y);
    q = Point(3, 4);
    print(q.x, q.y);
    r = Point(5, y=6);
    print(r.x, r.y);
    s = Pair(y=8, x=7);
    print(s.x, s.y);
    t = Implicit(x=9, y=10);
    print(t.x, t.y);
    d = Derived(a=11, b=12);
    print(d.a, d.b);
    a = Acc(x=tick(5));
    print(a.x, a.total);
    h = Heir(tick(3));
    print(h.x, h.total, h.extra);
    h2 = Heir(x=tick(4));
    print(h2.x, h2.total);
    prog = Program();
    print(prog.main_mod is None, prog.label);
    prog2 = Program(main_mod=Module(name="m"), label="given");
    print(prog2.main_mod.name if prog2.main_mod else "none", prog2.label);
    m = Mixed(a=3);
    print(m.a, m.b);
    m2 = Mixed(a=3, b=4);
    print(m2.a, m2.b);
    ph = PlainHeir();
    print(ph.b, ph.c);
    pl = Plain();
    pl.b = 9;
    print(pl.b);
}
