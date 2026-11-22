"""stdjac on jac's runtime: what neojac programs import, behaving as they expect.

`codec.encode` writes an enum member by name whatever its base, and an object's
fields down its whole class hierarchy; `stdjac.x` and `jaclang.stdjac.x` are one
module.
"""

import from stdjac.codec { encode }

enum Shade: str { LIGHT = "light", DARK = "dark", }

enum Rank: int { LOW = 1, HIGH = 2, }

obj Base {
    has id: str = "b";
}

obj Child(Base) {
    has extra: int = 1;
}


test "stdjac's short name and jaclang.stdjac are one module" {
    import importlib;
    short = importlib.import_module("stdjac.codec");
    long = importlib.import_module("jaclang.stdjac.codec");
    assert short is long , (short, long);
    assert importlib.import_module("stdjac.codec") is short;
}

test "codec encodes enum members by name and fields across the hierarchy" {
    assert encode(Shade.DARK) == "DARK" , encode(Shade.DARK);
    assert encode(Rank.HIGH) == "HIGH" , encode(Rank.HIGH);
    assert encode({"k": Rank.LOW}) == {"k": "LOW"};
    assert encode(Child()) == {"id": "b", "extra": 1} , encode(Child());
}
