"""Method-kind keywords (`abst`, `class def`, `static def`) on native.

The compiler's own sources reached for `@abstractmethod` / `@classmethod`
where Jac already has first-class syntax. The keyword forms set flags on
`uni.Ability` (`is_abstract` / `is_classmethod` / `is_static`) instead of
populating `decorators`, so they carry the same semantics without the
capability gate having a decorator expression to reject.
"""

obj Shape {
    def area(n: int) -> int abst;
}

obj Square(Shape) {
    def area(n: int) -> int {
        return n * n;
    }
}

obj Counter {
    static def bump(n: int) -> int {
        return n + 1;
    }
}

obj Factory {
    class def base -> int {
        return 7;
    }

    class def scale(v: int) -> int {
        return v * 2;
    }
}

def call_abstract_impl(n: int) -> int {
    sq = Square();
    return sq.area(n);
}

def call_abstract_through_base(n: int) -> int {
    base: Shape = Square();
    return base.area(n);
}

def call_staticmethod(n: int) -> int {
    return Counter.bump(n);
}

def call_classmethod(n: int) -> int {
    return Factory.base() + Factory.scale(n);
}
