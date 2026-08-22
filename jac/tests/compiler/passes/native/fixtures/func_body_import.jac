"""`import` statements written inside a function body (roadmap N8c).

A body-scoped import is the house idiom for a lazy or conditional import; the
compiler's own source uses it throughout (`seal_native_artifacts`,
`placement_solver.jac`, and the native pass itself), in both the `import x;` and
the `import from x { y }` spelling. Module-level imports already lower, so this
fixture pins the body-scoped ones: a stdlib import, a sibling Jac module import,
one inside a nested block, and one inside a method.
"""

import from func_body_import_lib { bump }

def floor_half(x: int) -> int {
    import math;
    return math.floor(float(x) / 2.0);
}

def ceil_third(x: int) -> int {
    import math;
    return math.ceil(float(x) / 3.0);
}

def conditional_import(x: int) -> int {
    if x > 0 {
        import math;
        return int(math.fabs(float(-x)));
    }
    return 0;
}

def sibling_import(start: int) -> int {
    import from func_body_import_lib { make_counter }
    c = make_counter(start);
    return bump(c);
}

def sibling_type_import(start: int) -> int {
    import from func_body_import_lib { Counter }
    c = Counter(value=start);
    return c.increment();
}

obj Holder {
    has base: int;

    def scaled -> int {
        import math;
        return math.floor(float(self.base) * 1.5);
    }
}

def method_import(base: int) -> int {
    return Holder(base=base).scaled();
}
