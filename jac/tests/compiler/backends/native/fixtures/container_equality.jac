"""Structural `==` / `!=` over dictionaries, nested containers, views and `__eq__`."""

obj Plain {
    has x: int;
}

obj Mod10 {
    has x: int;

    def __eq__(other: Mod10) -> bool {
        return self.x % 10 == other.x % 10;
    }
}

obj Base {
    has x: int;

    def __eq__(other: Base) -> bool {
        return self.x == other.x;
    }
}

obj Child(Base) {
    def __eq__(other: Base) -> bool {
        return self.x % 2 == other.x % 2;
    }
}

obj Picky {
    has x: int;

    def __eq__(other: Picky) -> bool {
        return self.x == other.x;
    }

    def __ne__(other: Picky) -> bool {
        return self.x + 1 != other.x;
    }
}

def dict_scalars {
    a: dict[str, int] = {"x": 1, "y": 2};
    b: dict[str, int] = {"y": 2, "x": 1};
    print("str-int", a == b, a != b, a == {"x": 1}, a == {"x": 1, "z": 2});
    print("str-int values", a == {"x": 1, "y": 3}, a != {"x": 1, "y": 3});
    fa: dict[int, float] = {1: 1.5, 2: 2.5};
    fb: dict[int, float] = {2: 2.5, 1: 1.5};
    print("int-float", fa == fb, fa == {1: 1.5, 2: 2.0});
    ba: dict[str, bool] = {"t": True, "f": False};
    bb: dict[str, bool] = {"f": False, "t": True};
    print("str-bool", ba == bb, ba == {"t": False, "f": False});
    sa: dict[str, str] = {"k": "v" + str(1)};
    sb: dict[str, str] = {"k": "v1"};
    print("str-str", sa == sb, sa == {"k": "v2"});
    ta: dict[tuple[int, int], str] = {(1, 2): "a", (3, 4): "b"};
    tb: dict[tuple[int, int], str] = {(3, 4): "b", (1, 2): "a"};
    print("tuple-key", ta == tb, ta == {(1, 2): "a", (3, 5): "b"});
    ea: dict[str, int] = {};
    eb: dict[str, int] = {};
    print("empty", ea == eb, ea != eb, ea == a);
    print("literal", {"x": 1} == {"x": 1}, {"x": 1} != {"x": 2});
    print("self", a == a, a != a);
}

def dict_mutation {
    a: dict[str, int] = {"a": 1, "b": 2, "c": 3};
    b: dict[str, int] = {"c": 3, "a": 1};
    print("mutation before", a == b);
    del a["b"];
    print("mutation del", a == b);
    a["d"] = 4;
    b["d"] = 4;
    print("mutation add", a == b);
    a.pop("a");
    print("mutation pop", a == b, len(a), len(b));
    b.pop("a");
    print("mutation both", a == b);
    a.clear();
    b.clear();
    print("mutation clear", a == b);
}

def dict_nested {
    la: dict[str, list[int]] = {"l": [1, 2], "m": []};
    lb: dict[str, list[int]] = {"m": [], "l": [1, 2]};
    lc: dict[str, list[int]] = {"l": [1, 3], "m": []};
    print("str-list", la == lb, la == lc);
    na: dict[str, dict[str, int]] = {"n": {"a": 1, "b": 2}};
    nb: dict[str, dict[str, int]] = {"n": {"b": 2, "a": 1}};
    nc: dict[str, dict[str, int]] = {"n": {"a": 2, "b": 2}};
    print("nested", na == nb, na == nc, na != nc);
    sa: dict[str, set[int]] = {"s": {1, 2}};
    sb: dict[str, set[int]] = {"s": {2, 1}};
    print("str-set", sa == sb, sa == {"s": {1}});
    tua: dict[str, tuple[int, str]] = {"t": (1, "a")};
    tub: dict[str, tuple[int, str]] = {"t": (1, "a")};
    print("str-tuple", tua == tub, tua == {"t": (1, "b")});
    oa: dict[str, int | None] = {"a": None, "b": 1};
    ob: dict[str, int | None] = {"b": 1, "a": None};
    print("optional", oa == ob, oa == {"a": 1, "b": 1});
}

def dict_objects {
    shared = Plain(1);
    pa: dict[str, Plain] = {"p": shared};
    pb: dict[str, Plain] = {"p": shared};
    pc: dict[str, Plain] = {"p": Plain(1)};
    print("identity", pa == pb, pa == pc, Plain(1) == Plain(1));
    qa: dict[str, Mod10] = {"q": Mod10(1)};
    qb: dict[str, Mod10] = {"q": Mod10(11)};
    qc: dict[str, Mod10] = {"q": Mod10(2)};
    print("dunder", qa == qb, qa == qc, qa != qb, Mod10(1) == Mod10(21));
    ca: dict[str, Base] = {"c": Child(1)};
    cb: dict[str, Base] = {"c": Base(3)};
    print("virtual", ca == cb, Child(1) == Base(3), Base(3) == Child(1));
    print("ne", Picky(1) != Picky(2), Picky(1) != Picky(3), Picky(1) == Picky(1));
}

def lists_and_tuples {
    lla: list[list[int]] = [[1], [2, 3]];
    llb: list[list[int]] = [[1], [2, 3]];
    llc: list[list[int]] = [[1], [2, 4]];
    print("list-list", lla == llb, lla == llc, lla != llc);
    lda: list[dict[str, int]] = [{"a": 1, "b": 2}];
    ldb: list[dict[str, int]] = [{"b": 2, "a": 1}];
    ldc: list[dict[str, int]] = [{"a": 2, "b": 2}];
    print("list-dict", lda == ldb, lda == ldc);
    lsa: list[set[int]] = [{1, 2}];
    lsb: list[set[int]] = [{2, 1}];
    print("list-set", lsa == lsb, lsa == [{3}]);
    lqa: list[Mod10] = [Mod10(3)];
    lqb: list[Mod10] = [Mod10(13)];
    print("list-dunder", lqa == lqb, lqa == [Mod10(4)]);
    lta: list[tuple[int, str]] = [(1, "a")];
    ltb: list[tuple[int, str]] = [(1, "a")];
    print("list-tuple", lta == ltb, lta == [(1, "b")]);
    tda: tuple[dict[str, int], int] = ({"a": 1}, 1);
    tdb: tuple[dict[str, int], int] = ({"a": 1}, 1);
    tdc: tuple[dict[str, int], int] = ({"a": 2}, 1);
    print("tuple-dict", tda == tdb, tda == tdc);
    tla: tuple[list[int], str] = ([1, 2], "x");
    tlb: tuple[list[int], str] = ([1, 2], "x");
    print("tuple-list", tla == tlb, tla == ([1], "x"));
    print("list-lt", [[1], [2]] < [[1], [3]], [[1], [3]] < [[1], [2]]);
    print("index", lda.index({"b": 2, "a": 1}), lda.count({"a": 1, "b": 2}));
    print(
        "in-list", {"b": 2, "a": 1} in lda, {"a": 2} in lda, [2, 3] in llb, [2] in llb
    );
    print("in-list-dunder", Mod10(23) in lqa, Mod10(4) not in lqa);
    tdd: tuple[dict[str, int], dict[str, int]] = ({"a": 1}, {"b": 2});
    print("in-tuple", {"b": 2} in tdd, {"b": 3} in tdd, "y" in ("x", "y"), 3 in (1, 2));
}

def sets_and_views {
    s1: set[int] = {1, 2, 3};
    s2: set[int] = {3, 2, 1};
    print("set", s1 == s2, s1 != s2, s1 == {1, 2});
    ss1: set[str] = {"a", "b"};
    ss2: set[str] = {"b", "a"};
    print("set-str", ss1 == ss2, ss1 == {"a"});
    st1: set[tuple[int, int]] = set();
    st1.add((1, 2));
    st2: set[tuple[int, int]] = set();
    st2.add((1, 2));
    print("set-tuple", st1 == st2);
    a: dict[str, int] = {"x": 1, "y": 2};
    b: dict[str, int] = {"y": 2, "x": 1};
    c: dict[str, int] = {"x": 1, "y": 3};
    print("keys", a.keys() == b.keys(), a.keys() != b.keys(), a.keys() == c.keys());
    print("items", a.items() == b.items(), a.items() == c.items());
    print("values", a.values() == b.values(), a.values() != b.values());
    v = a.values();
    print("values-same", v == v);
    ks: set[str] = {"x", "y"};
    print("keys-set", a.keys() == ks, ks == a.keys(), a.keys() == {"x"});
    print("keys-list", a.keys() == ["x", "y"]);
}

with entry {
    dict_scalars();
    dict_mutation();
    dict_nested();
    dict_objects();
    lists_and_tuples();
    sets_and_views();
}
