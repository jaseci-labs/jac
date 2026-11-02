"""Dictionary and view equality under the headerless (nogc) profile."""

obj Mod10 {
    has x: int;

    def __eq__(other: &Mod10) -> bool {
        return self.x % 10 == other.x % 10;
    }
}

def compare_all {
    a: dict[str, int] = {"x": 1, "y": 2};
    b: dict[str, int] = {"y": 2, "x": 1};
    c: dict[str, int] = {"x": 1, "y": 3};
    print("str-int", a == b, a != b, a == c, a == {"x": 1});
    f: dict[int, float] = {1: 1.5, 2: 2.5};
    g: dict[int, float] = {2: 2.5, 1: 1.5};
    print("int-float", f == g, f == {1: 1.5, 2: 2.0});
    del a["y"];
    print("mutated", a == b, a == {"x": 1});
    rows: list[list[int]] = [[1], [2, 3]];
    same: list[list[int]] = [[1], [2, 3]];
    print("list-list", rows == same, rows == [[1], [2, 4]]);
    print(
        "keys", b.keys() == c.keys(), b.items() == c.items(), b.values() == c.values()
    );
    print("dunder", Mod10(1) == Mod10(11), Mod10(1) != Mod10(2));
}

with entry {
    compare_all();
}
