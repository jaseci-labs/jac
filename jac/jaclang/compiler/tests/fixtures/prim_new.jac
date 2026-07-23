"""new() builtin and positional implicit-ctor cross-backend equivalence
fixture (#7593 item 14 M1).

Pins the py (sv) semantics of the `new(Cls, args...)` builtin (positional
`cls(*args)` forwarding) and of positional args to implicit no-init
constructors, including dataclass field ordering across inheritance, against
the native backend. No cl defs: the cl leg auto-skips.

The `collections` import below is a deliberate server signal: it keeps the
module out of whole-module native inference so the py defs stay a genuine
CPython reference instead of coercing to native shims."""

import collections;

obj NewWidget {
    has size: int = 0;

    def area -> int {
        return self.size * self.size;
    }
}

obj NewPair {
    has a: int = 0,
        b: int = 0;

    def init(a: int, b: int) {
        self.a = a;
        self.b = b;
    }
}

obj NewLabel {
    has name: str = "anon",
        count: int = 0;
}

obj NewBase {
    has x: int = 1;
}

obj NewDerived(NewBase) {
    has y: int = 2;
}

def new_py -> dict {
    w = new(NewWidget, 5);
    p = new(NewPair, 3, 4);
    d = NewWidget(6);
    m = new(NewWidget);
    lab = NewLabel("tag", 3);
    dv = NewDerived(10, 20);
    n2 = new(NewDerived, 7, 8);
    mixed = NewDerived(30, y=40);
    return {
        "area": w.area(),
        "pair": p.a * 10 + p.b,
        "direct": d.area(),
        "dflt": m.size,
        "label": lab.name,
        "label_count": lab.count,
        "inherit": dv.x * 100 + dv.y,
        "inherit_new": n2.x * 100 + n2.y,
        "mixed": mixed.x * 100 + mixed.y
    };
}

cl def new_cl -> dict {
    return {};
}

na {
    def new_na -> dict[str, any] {
        w = new(NewWidget, 5);
        p = new(NewPair, 3, 4);
        d = NewWidget(6);
        m = new(NewWidget);
        lab = NewLabel("tag", 3);
        dv = NewDerived(10, 20);
        n2 = new(NewDerived, 7, 8);
        mixed = NewDerived(30, y=40);
        return {
            "area": w.area(),
            "pair": p.a * 10 + p.b,
            "direct": d.area(),
            "dflt": m.size,
            "label": lab.name,
            "label_count": lab.count,
            "inherit": dv.x * 100 + dv.y,
            "inherit_new": n2.x * 100 + n2.y,
            "mixed": mixed.x * 100 + mixed.y
        };
    }
}
