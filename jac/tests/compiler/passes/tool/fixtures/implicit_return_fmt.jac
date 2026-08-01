"""Formatter round-trip for implicit returns: a tail expression without ';'
must keep neither a synthesized `return` nor a trailing ';'."""

def add(a: int, b: int) -> int {
    a + b
}

def classify(n: int) -> str {
    if n > 0 {
        return "pos";
    }
    "non-pos"
}

def shout(msg: str) -> str {
    loud = msg.upper();
    loud + "!"
}

def styled -> dict {
    {"color": "red", "size": 4}
}

glob single = lambda (x: int) -> int { x * 2 };

with entry {
    print(add(1, 2));
    print(single(21));
}
