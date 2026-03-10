"""Error and edge-case tests for Self type.

These tests verify that Self is properly handled in edge cases
and that various archetype features work correctly with Self.
"""

# ═══════════════════════════════════════════════════════════════════════════════
# ERROR 3: class def without Self — should still work as plain classmethod
# ═══════════════════════════════════════════════════════════════════════════════

"""class def that doesn't use Self should still compile fine."""
obj NoSelfUsage {
    class def greeting() -> str {
        return "hello";
    }
}

with entry:__main__ {
    print(f"E3: {NoSelfUsage.greeting()}");  # hello
}

# ═══════════════════════════════════════════════════════════════════════════════
# ERROR 4: class def called on instance (should still work like Python)
# ═══════════════════════════════════════════════════════════════════════════════

"""Calling a classmethod on an instance should still dispatch to the class."""
obj Dispatchy {
    has x: int = 0;

    class def make(x: int) -> Self {
        return Self(x=x);
    }
}

with entry:__main__ {
    d = Dispatchy(x=1);
    # Calling classmethod on instance — Self should still be Dispatchy
    d2 = d.make(99);
    print(f"E4.1: {d2.x}");  # 99
    print(f"E4.2: {type(d2).__name__}");  # Dispatchy
}

# ═══════════════════════════════════════════════════════════════════════════════
# ERROR 5: Self in nested class
# ═══════════════════════════════════════════════════════════════════════════════

"""Self in a nested obj should refer to the inner obj, not the outer."""
obj Outer {
    has a: int = 1;

    obj Inner {
        has b: int = 2;

        class def make() -> Self {
            return Self(b=10);
        }

        def get_b() -> int {
            return self.b;
        }
    }

    class def make() -> Self {
        return Self(a=20);
    }
}

with entry:__main__ {
    inner = Outer.Inner.make();
    outer = Outer.make();
    print(f"E5.1: {inner.get_b()}");  # 10 (Inner.Self = Inner)
    print(f"E5.2: {outer.a}");  # 20 (Outer.Self = Outer)
    print(f"E5.3: {type(inner).__name__}");  # Inner
    print(f"E5.4: {type(outer).__name__}");  # Outer
}

# ═══════════════════════════════════════════════════════════════════════════════
# ERROR 6: Self in list comprehension inside method
# ═══════════════════════════════════════════════════════════════════════════════

"""Self inside a comprehension within a method should still resolve to enclosing type."""
obj WithLambda {
    has val: int = 0;

    class def make_list(values: list[int]) -> list[Self] {
        return [Self(val=v) for v in values];
    }
}

with entry:__main__ {
    items = WithLambda.make_list([1, 2, 3]);
    print(f"E6.1: {len(items)}");  # 3
    print(f"E6.2: {items[0].val} {items[1].val} {items[2].val}");  # 1 2 3
    print(f"E6.3: {type(items[0]).__name__}");  # WithLambda
}

# ═══════════════════════════════════════════════════════════════════════════════
# ERROR 7: Self as type in has field (within the same obj)
# ═══════════════════════════════════════════════════════════════════════════════

"""Self as a type annotation in has fields — useful for linked-list patterns."""
obj ListNode {
    has value: int = 0,
        next_node: Self | None = None;

    class def from_list(values: list[int]) -> Self | None {
        if not values {
            return None;
        }
        head = Self(value=values[0]);
        current = head;
        for v in values[1:] {
            current.next_node = Self(value=v);
            current = current.next_node;
        }
        return head;
    }

    def to_list() -> list[int] {
        result: list[int] = [self.value];
        cur = self.next_node;
        while cur is not None {
            result.append(cur.value);
            cur = cur.next_node;
        }
        return result;
    }
}

with entry:__main__ {
    head = ListNode.from_list([1, 2, 3, 4, 5]);
    print(f"E7.1: {head.to_list()}");  # [1, 2, 3, 4, 5]
    print(f"E7.2: {head.next_node.value}");  # 2
}

# ═══════════════════════════════════════════════════════════════════════════════
# ERROR 8: Self in type check / isinstance
# ═══════════════════════════════════════════════════════════════════════════════

"""Using Self with isinstance checks."""
obj TypeChecker {
    has data: any = None;

    def is_same_type(other: any) -> bool {
        return isinstance(other, Self);
    }

    class def check(value: any) -> bool {
        return isinstance(value, Self);
    }
}

with entry:__main__ {
    tc = TypeChecker(data=42);
    tc2 = TypeChecker(data="hello");
    print(f"E8.1: {tc.is_same_type(tc2)}");   # True
    print(f"E8.2: {tc.is_same_type('nope')}"); # False
    print(f"E8.3: {TypeChecker.check(tc)}");   # True
    print(f"E8.4: {TypeChecker.check(123)}");  # False
}

# ═══════════════════════════════════════════════════════════════════════════════
# ERROR 9: Mixing static def and class def in same obj
# ═══════════════════════════════════════════════════════════════════════════════

"""static def and class def should coexist without conflict."""
obj MixedMethods {
    has x: int = 0;

    static def utility(a: int, b: int) -> int {
        # No self, no Self — pure static
        return a + b;
    }

    class def create(x: int) -> Self {
        # Self available
        return Self(x=x);
    }

    def get_x() -> int {
        return self.x;
    }
}

with entry:__main__ {
    print(f"E9.1: {MixedMethods.utility(3, 4)}");  # 7
    m = MixedMethods.create(10);
    print(f"E9.2: {m.get_x()}");  # 10
}

# ═══════════════════════════════════════════════════════════════════════════════
# ERROR 10: class def with inheritance override
# ═══════════════════════════════════════════════════════════════════════════════

"""Overriding a classmethod in a subclass — Self should update."""
obj BaseFactory {
    has label: str = "base";

    class def create() -> Self {
        return Self();
    }
}

obj ChildFactory(BaseFactory) {
    has label: str = "child";

    override class def create() -> Self {
        inst = Self();
        inst.label = "custom_child";
        return inst;
    }
}

with entry:__main__ {
    b = BaseFactory.create();
    c = ChildFactory.create();
    print(f"E10.1: {b.label}");  # base
    print(f"E10.2: {c.label}");  # custom_child
    print(f"E10.3: {type(b).__name__}");  # BaseFactory
    print(f"E10.4: {type(c).__name__}");  # ChildFactory
}
