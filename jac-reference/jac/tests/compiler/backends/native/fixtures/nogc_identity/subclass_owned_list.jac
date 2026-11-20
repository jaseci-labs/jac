"""Subclass instances stored in a `list[own Base]` keep their own layout and
dispatch through the base slot (#8984 A3)."""

obj Shape { def area -> int { return 0; } }
obj Sq(Shape) { has s: int = 2; def area -> int { return self.s * self.s; } }
obj Rect(Shape) { has w: int = 2, h: int = 3; def area -> int { return self.w * self.h; } }

def by_index(shapes: &list[own Shape]) -> int {
    t = 0;
    for i in range(len(shapes)) { t += shapes[i].area(); }
    return t;
}

def by_ref_loop(shapes: &list[own Shape]) -> int {
    t = 0;
    for s in &shapes { t += s.area(); }
    return t;
}

def run -> int {
    shapes: list[own Shape] = [];
    shapes.append(Sq());
    shapes.append(Rect());
    return by_index(&shapes) * 100 + by_ref_loop(&shapes);
}

with entry { print(run()); }
