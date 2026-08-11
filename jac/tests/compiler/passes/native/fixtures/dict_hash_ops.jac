"""Hash-table dict mutation semantics: del/pop/popitem/clear/order/rehash.

Each function returns a sentinel on failure so the JIT tests can pinpoint the
broken operation; the entry block re-runs everything under assert so the same
fixture doubles as an AOT smoke binary for the GC-mode matrix (rc / cycles /
none / headerless none). Prints "OK dict_hash_ops" on success.
"""

def del_pop_str_keys -> int {
    d: dict[str, int] = {"a": 1, "b": 2, "c": 3};
    del d["b"];
    if "b" in d {
        return -1;
    }
    v: int = d.pop("c");
    if v != 3 {
        return -2;
    }
    if "c" in d {
        return -3;
    }
    m: int = d.pop("zz", 42);
    if m != 42 {
        return -4;
    }
    return len(d);
}

def tombstone_reuse -> int {
    d: dict[str, int] = {};
    d["k1"] = 10;
    d["k2"] = 20;
    d["k3"] = 30;
    del d["k2"];
    # Reinsert must land on the tombstone without desyncing order/len.
    d["k2"] = 25;
    if d["k2"] != 25 {
        return -1;
    }
    if len(d) != 3 {
        return -2;
    }
    del d["k2"];
    if "k2" in d {
        return -3;
    }
    return len(d);
}

def rehash_with_deletes -> int {
    d: dict[str, int] = {};
    i: int = 0;
    while i < 8 {
        d["a" + str(i)] = i;
        i += 1;
    }
    # Tombstones present...
    del d["a1"];
    del d["a3"];
    del d["a5"];
    # ...then grow far past the 75% load factor (several rehash cycles).
    j: int = 0;
    while j < 40 {
        d["b" + str(j)] = 100 + j;
        j += 1;
    }
    if len(d) != 45 {
        return -1;
    }
    if d["a0"] != 0 or d["a2"] != 2 or d["a4"] != 4 {
        return -2;
    }
    if d["a6"] != 6 or d["a7"] != 7 {
        return -3;
    }
    if "a1" in d or "a3" in d or "a5" in d {
        return -4;
    }
    k: int = 0;
    tot: int = 0;
    while k < 40 {
        tot += d["b" + str(k)];
        k += 1;
    }
    # sum(100..139) == 100*40 + 780
    if tot != 4780 {
        return -5;
    }
    return 1;
}

def clear_then_reuse -> int {
    d: dict[str, int] = {"x": 1, "y": 2, "z": 3};
    d.clear();
    if len(d) != 0 {
        return -1;
    }
    # A cleared key must be gone from the hash probe, not just from len.
    if "x" in d or "y" in d or "z" in d {
        return -2;
    }
    d["x"] = 9;
    d["w"] = 8;
    if d["x"] != 9 or d["w"] != 8 {
        return -3;
    }
    if len(d) != 2 {
        return -4;
    }
    return 1;
}

def order_after_deletes -> str {
    d: dict[str, int] = {};
    d["one"] = 1;
    d["two"] = 2;
    d["three"] = 3;
    d["four"] = 4;
    del d["two"];
    d["five"] = 5;
    out: str = "";
    for k in d {
        out += k + ";";
    }
    return out;
}

def popitem_last_str -> str {
    d: dict[str, str] = {};
    d["alpha"] = "A";
    d["beta"] = "B";
    d["gamma"] = "C";
    item = d.popitem();
    k: str = item[0];
    v: str = item[1];
    if len(d) != 2 {
        return "badlen";
    }
    if "gamma" in d {
        return "stillthere";
    }
    return k + "=" + v;
}

def popitem_drain -> int {
    d: dict[str, int] = {"p": 1, "q": 2, "r": 3};
    it1 = d.popitem();
    it2 = d.popitem();
    it3 = d.popitem();
    if it1[0] != "r" or it1[1] != 3 {
        return -1;
    }
    if it2[0] != "q" or it2[1] != 2 {
        return -2;
    }
    if it3[0] != "p" or it3[1] != 1 {
        return -3;
    }
    return len(d);
}

def f64_keys -> int {
    d: dict[float, int] = {};
    d[1.5] = 10;
    d[2.25] = 20;
    if d[1.5] != 10 or d[2.25] != 20 {
        return -1;
    }
    if not (1.5 in d) {
        return -2;
    }
    del d[1.5];
    if 1.5 in d {
        return -3;
    }
    return len(d);
}

with entry {
    assert del_pop_str_keys() == 1 , "del/pop with str keys failed";
    assert tombstone_reuse() == 2 , "tombstone reuse (delete then reinsert) failed";
    assert rehash_with_deletes() == 1 , "rehash cycle with mixed deletes failed";
    assert clear_then_reuse() == 1 , "clear-then-contains / reinsert-after-clear failed";
    assert order_after_deletes() == "one;three;four;five;" , "iteration order after deletes failed";
    assert popitem_last_str() == "gamma=C" , "popitem last str pair failed";
    assert popitem_drain() == 0 , "popitem drain failed";
    assert f64_keys() == 1 , "f64-key dict ops failed";
    print("OK dict_hash_ops");
}
