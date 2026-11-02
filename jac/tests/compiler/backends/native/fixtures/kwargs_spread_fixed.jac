"""`**` spreads into callees with fixed, statically known parameters."""

def area(width: int, height: int = 1) -> int {
    return width * height;
}

def label(name: str, suffix: str = "!", *, upper: bool = False) -> str {
    text = name + suffix;
    return text.upper() if upper else text;
}

def tail(first: int, *rest: int, scale: int = 1) -> int {
    total = first;
    for r in rest {
        total += r;
    }
    return total * scale;
}

obj Shape {
    has sides: int = 0;

    def scaled(factor: int, offset: int = 0) -> int {
        return self.sides * factor + offset;
    }
}

def try_call(dims: dict[str, int]) -> str {
    try {
        return str(area(**dims));
    } except TypeError {
        return "TypeError";
    }
}

def run {
    dims: dict[str, int] = {"width": 3, "height": 4};
    print(area(**dims));
    only_width: dict[str, int] = {"width": 5};
    print(area(**only_width));
    print(area(2, **{"height": 6}));
    names: dict[str, str] = {"suffix": "?"};
    print(label("hi", **names), label(name="yo", **{"suffix": "."}));
    flags: dict[str, bool] = {"upper": True};
    print(label("up", **flags));
    print(tail(1, 2, 3, **{"scale": 2}));
    s = Shape(sides=4);
    print(s.scaled(**{"factor": 3, "offset": 1}));
    first: dict[str, int] = {"width": 2};
    second: dict[str, int] = {"height": 7};
    print(area(**first, **second));
    print(try_call({"width": 1, "depth": 2}));
    print(try_call({"height": 2}));
    try {
        area(1, **first);
    } except TypeError {
        print("duplicate TypeError");
    }
    again: dict[str, int] = {"width": 9};
    try {
        area(**first, **again);
    } except TypeError {
        print("repeated TypeError");
    }
}

with entry {
    run();
}
