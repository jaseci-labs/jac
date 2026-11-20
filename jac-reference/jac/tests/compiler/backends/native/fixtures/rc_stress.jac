"""Reference counting stress tests.

Allocates heavily to verify no memory corruption or OOM
under pressure with the RC memory management scheme.
"""

# Stress test 1: Many objects in a loop
def test_many_objects(n: int) -> int {
    count: int = 0;
    i: int = 0;
    while i < n {
        b: Box = Box(val=i);
        count = count + 1;
        i = i + 1;
    }
    return count;
}

obj Box {
    has val: int = 0;

    def get_val() -> int {
        return self.val;
    }
}

# Stress test 2: Rapid reassignment of same variable
def test_rapid_reassign(n: int) -> int {
    b: Box = Box(val=0);
    i: int = 0;
    while i < n {
        b = Box(val=i);
        i = i + 1;
    }
    return b.get_val();
}

# Stress test 3: Large list that grows many times
def test_large_list(n: int) -> int {
    items: list[int] = [];
    i: int = 0;
    while i < n {
        items.append(i);
        i = i + 1;
    }
    return len(items);
}

# Stress test 4: Many string concatenations
def test_string_concat_stress(n: int) -> int {
    s: str = "";
    i: int = 0;
    while i < n {
        s = s + "x";
        i = i + 1;
    }
    return len(s);
}

# Stress test 5: Dict with many entries
def test_large_dict(n: int) -> int {
    d: dict[int, int] = {};
    i: int = 0;
    while i < n {
        d[i] = i * 2;
        i = i + 1;
    }
    return len(d);
}
