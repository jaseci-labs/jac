"""Containers boxed into `any` describe themselves.

Iteration, `str`/`repr`, `==`, ordering and `in` on an `any` read the element
kinds the containers record when they are made, so a list, dict, set, tuple,
str or bytes behind an `any` behaves as it does in Python.
"""
enum Color { RED = 1, BLUE = 2 }

enum Tone { LOW = 1, HIGH = 2 }

obj Point {
    has x: int = 0,
        y: int = 0;
}

obj Named {
    has label: str = "";

    def __str__ -> str {
        return f"<{self.label}>";
    }
}

obj Holder {
    has payload: any = None,
        name: str = "";
}

def as_any(value: any) -> any {
    return value;
}

def walk(value: any) -> str {
    parts: list[str] = [];
    for item in value {
        parts.append(repr(item));
    }
    return ",".join(parts);
}

def order(a: any, b: any) -> str {
    return f"{a < b} {a <= b} {a > b} {a >= b}";
}

with entry {
    print(walk(as_any([1, 2, 3])));
    print(walk(as_any(["a", "b"])));
    print(walk(as_any([1.5, None, True])));
    print(walk(as_any({"k": 1, "j": 2})));
    print(walk(as_any({3, 4})));
    print(walk(as_any((1, "two", 3.0))));
    print(walk(as_any("héllo")));
    print(walk(as_any(b"ab")));
    print(walk(as_any([[1, 2], [3]])));
    print(str(as_any([1, "a", 2.5, None, False])));
    print(repr(as_any({"a": [1, 2], "b": (3, )})));
    empty: set[int] = set();
    print(str(as_any(empty)), str(as_any({7})), str(as_any({})));
    print(str(as_any((1, ))), repr(as_any("q'")), str(as_any("plain")));
    print(str(as_any(Point(x=1, y=2))), str(as_any(Named(label="n"))));
    print(repr(as_any([Point(x=3, y=4), Named(label="m")])));
    print(str(Holder(payload=[1, "x"], name="h")));
    print(str(Holder(payload=Point(x=5, y=6), name="p")));
    print(str(as_any(2.0)), str(as_any(-7)), str(as_any(None)));
    print(as_any([1, 2]) == as_any([1, 2]), as_any([1, 2]) == as_any([1, 3]));
    print(as_any([1, 2]) == as_any([1.0, 2]), as_any((1, "a")) == as_any((1, "a")));
    print(as_any({"a": 1}) == as_any({"a": 1}), as_any({1, 2}) == as_any({2, 1}));
    print(as_any("x") == "x", as_any(3) != 3, as_any(3) == 3.0, as_any(None) == None);
    print(as_any([1]) == as_any((1, )), as_any(b"ab") == as_any(b"ab"));
    print(order(as_any(1), as_any(2.5)));
    print(order(as_any("b"), as_any("a")));
    print(order(as_any([1, 2]), as_any([1, 3])));
    print(order(as_any((1, "a")), as_any((1, "a"))));
    print(order(as_any([1]), as_any([1, 0])));
    print(as_any(3) < 4, as_any(5) >= 4);
    try {
        print(as_any(1) < as_any("a"));
    } except TypeError as err {
        print("TypeError", err);
    }
    print(2 in as_any([1, 2]), "k" in as_any({"k": 1}), "z" in as_any({"k": 1}));
    print("ell" in as_any("hello"), 9 in as_any((1, 9)), 3 in as_any({1, 2}));
    red = as_any(Color.RED);
    print(red == Color.RED, red != Color.BLUE, red == 1, red == Tone.LOW);
    print(isinstance(red, Color), isinstance(red, Tone), isinstance(red, int));
    print(isinstance(as_any(1), Color), red is Color.RED, as_any(Color.RED) == red);
    print(str(red), repr(red), repr(as_any([Color.BLUE, 3, Tone.HIGH])));
    print(Color.BLUE in as_any([Color.RED, Color.BLUE]), 2 in as_any([Color.BLUE]));
    total = 0;
    for _ in range(300) {
        for item in as_any([1, 2, 3]) {
            total += 1 if item == 2 else 0;
        }
    }
    print(total);
}
