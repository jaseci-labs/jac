obj Inner {
    has val: int = 0;

    def get_val() -> int {
        return self.val;
    }

    def add(x: int) -> int {
        return self.val + x;
    }
}

obj Outer {
    has inner: Inner;
    has tag: int = 0;
}

obj Grid {
    has items: list[int];
    has size: int = 0;
}

# Test 1: chained field access — outer.inner.val
def test_chained_field() -> int {
    i: Inner = Inner(val=42);
    o: Outer = Outer(inner=i, tag=1);
    return o.inner.val;
}

# Test 2: chained method call — outer.inner.get_val()
def test_chained_method() -> int {
    i: Inner = Inner(val=99);
    o: Outer = Outer(inner=i, tag=2);
    return o.inner.get_val();
}

# Test 3: chained method with args — outer.inner.add(x)
def test_chained_method_args() -> int {
    i: Inner = Inner(val=5);
    o: Outer = Outer(inner=i, tag=3);
    return o.inner.add(10);
}

# Test 4: deep chained expressions in args
def test_deep_chain() -> int {
    i: Inner = Inner(val=7);
    mid: Outer = Outer(inner=i, tag=0);
    return mid.inner.add(mid.inner.get_val());
}

# Test 5: indexed field access — g.items[i]
def test_indexed_field() -> int {
    g: Grid = Grid(items=[10, 20, 30], size=3);
    return g.items[1];
}

# Test 6: indexed field assignment — g.items[i] = val
def test_indexed_field_set() -> int {
    g: Grid = Grid(items=[1, 2, 3], size=3);
    g.items[1] = 99;
    return g.items[1];
}

# Test 7: len on field — len(g.items)
def test_field_len() -> int {
    g: Grid = Grid(items=[10, 20, 30, 40], size=4);
    return len(g.items);
}

# Test 8: append on field — g.items.append(val)
def test_field_append() -> int {
    g: Grid = Grid(items=[1, 2], size=2);
    g.items.append(3);
    return len(g.items);
}
