"""Hash-table set mutation semantics: add/remove/discard/pop/clear/order/rehash.

Each function returns a sentinel on failure so the JIT tests can pinpoint the
broken operation; the entry block re-runs everything under assert so the same
fixture doubles as an AOT smoke binary for the GC-mode matrix (rc / cycles /
none). Prints "OK set_hash_ops" on success.
"""

def add_remove_contains_int -> int {
    s: set[int] = {3, 1, 2};
    s.add(4);
    s.add(3);
    if len(s) != 4 {
        return -1;
    }
    if 3 not in s or 9 in s {
        return -2;
    }
    s.remove(3);
    if 3 in s or len(s) != 3 {
        return -3;
    }
    s.discard(99);
    s.discard(4);
    if len(s) != 2 or 4 in s {
        return -4;
    }
    return len(s);
}

def add_remove_contains_str -> int {
    s: set[str] = {"one"};
    s.add("two");
    s.add("three");
    s.add("two");
    if len(s) != 3 {
        return -1;
    }
    if "two" not in s or "zz" in s {
        return -2;
    }
    s.remove("one");
    if "one" in s or len(s) != 2 {
        return -3;
    }
    s.discard("nope");
    if len(s) != 2 {
        return -4;
    }
    return len(s);
}

def tombstone_reuse -> int {
    s: set[str] = set();
    s.add("k1");
    s.add("k2");
    s.add("k3");
    s.remove("k2");
    s.add("k2");
    if "k2" not in s {
        return -1;
    }
    if len(s) != 3 {
        return -2;
    }
    s.remove("k2");
    if "k2" in s {
        return -3;
    }
    return len(s);
}

def rehash_with_deletes -> int {
    s: set[str] = set();
    i: int = 0;
    while i < 8 {
        s.add("a" + str(i));
        i += 1;
    }
    s.remove("a1");
    s.remove("a3");
    s.remove("a5");
    j: int = 0;
    while j < 40 {
        s.add("b" + str(j));
        j += 1;
    }
    if len(s) != 45 {
        return -1;
    }
    if "a0" not in s or "a2" not in s or "a4" not in s {
        return -2;
    }
    if "a6" not in s or "a7" not in s {
        return -3;
    }
    if "a1" in s or "a3" in s or "a5" in s {
        return -4;
    }
    k: int = 0;
    while k < 40 {
        if ("b" + str(k)) not in s {
            return -5;
        }
        k += 1;
    }
    return 1;
}

def clear_then_reuse -> int {
    s: set[str] = {"x", "y", "z"};
    s.clear();
    if len(s) != 0 {
        return -1;
    }
    if "x" in s or "y" in s or "z" in s {
        return -2;
    }
    s.add("x");
    s.add("w");
    if "x" not in s or "w" not in s {
        return -3;
    }
    if len(s) != 2 {
        return -4;
    }
    return 1;
}

def order_after_deletes -> str {
    s: set[str] = set();
    s.add("one");
    s.add("two");
    s.add("three");
    s.add("four");
    s.remove("two");
    s.add("five");
    out: str = "";
    for v in iter(s) {
        out += v + ";";
    }
    return out;
}

def pop_lifo -> int {
    s: set[str] = set();
    s.add("p");
    s.add("q");
    s.add("r");
    v1: str = s.pop();
    if v1 != "r" {
        return -1;
    }
    v2: str = s.pop();
    if v2 != "q" {
        return -2;
    }
    v3: str = s.pop();
    if v3 != "p" {
        return -3;
    }
    return len(s);
}

def algebra -> int {
    a: set[int] = {1, 2, 3, 4};
    b: set[int] = {3, 4, 5};
    u: set[int] = a.union(b);
    if len(u) != 5 or 5 not in u or 1 not in u {
        return -1;
    }
    inter: set[int] = a.intersection(b);
    if len(inter) != 2 or 3 not in inter or 1 in inter {
        return -2;
    }
    d: set[int] = a.difference(b);
    if len(d) != 2 or 1 not in d or 3 in d {
        return -3;
    }
    sd: set[int] = a.symmetric_difference(b);
    if len(sd) != 3 or 5 not in sd or 3 in sd {
        return -4;
    }
    if not {1, 2}.issubset(a) {
        return -5;
    }
    if {1, 9}.issubset(a) {
        return -6;
    }
    if not a.issuperset({1, 2}) {
        return -7;
    }
    if not a.isdisjoint({9, 10}) {
        return -8;
    }
    if a.isdisjoint(b) {
        return -9;
    }
    c: set[int] = a.copy();
    c.add(99);
    if len(a) != 4 or len(c) != 5 {
        return -10;
    }
    return 1;
}

def inplace_ops -> int {
    a: set[int] = {1, 2, 3};
    a |= {3, 4};
    if len(a) != 4 or 4 not in a {
        return -1;
    }
    b: set[int] = {1, 2, 3, 4};
    b.update({5, 6});
    if len(b) != 6 or 6 not in b {
        return -2;
    }
    b.intersection_update({1, 2, 5, 9});
    if len(b) != 3 or 1 not in b or 4 in b {
        return -3;
    }
    b.difference_update({2});
    if len(b) != 2 or 2 in b or 1 not in b {
        return -4;
    }
    b.symmetric_difference_update({5, 7});
    if len(b) != 2 or 5 in b or 7 not in b or 1 not in b {
        return -5;
    }
    return 1;
}

def f64_elems -> int {
    s: set[float] = set();
    s.add(1.5);
    s.add(2.25);
    s.add(1.5);
    if len(s) != 2 {
        return -1;
    }
    if 1.5 not in s or 3.5 in s {
        return -2;
    }
    s.remove(1.5);
    if 1.5 in s {
        return -3;
    }
    return len(s);
}

with entry {
    assert add_remove_contains_int() == 2 , "int add/remove/contains failed";
    assert add_remove_contains_str() == 2 , "str add/remove/contains failed";
    assert tombstone_reuse() == 2 , "tombstone reuse (remove then re-add) failed";
    assert rehash_with_deletes() == 1 , "rehash cycle with mixed deletes failed";
    assert clear_then_reuse() == 1 , "clear-then-contains / re-add-after-clear failed";
    assert order_after_deletes() == "one;three;four;five;" , "insertion-order iteration after deletes failed";
    assert pop_lifo() == 0 , "pop drain failed";
    assert algebra() == 1 , "set algebra failed";
    assert inplace_ops() == 1 , "in-place set ops failed";
    assert f64_elems() == 1 , "f64-elem set ops failed";
    print("OK set_hash_ops");
}
