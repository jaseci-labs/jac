"""Native fixture exercising match statements.

Covers the supported pattern kinds: literal value patterns, OR patterns
of literals, capture patterns, wildcard, guards, and string literals.
Structural patterns (sequence/mapping/class) are out of scope and
rejected at compile time.
"""

def classify(x: int) -> int {
    match x {
        case 0: return 100;
        case 1: return 200;
        case _: return 300;
    }
}

def with_or(x: int) -> int {
    match x {
        case 1 | 2 | 3: return 1;
        case _: return 0;
    }
}

def with_capture(x: int) -> int {
    match x {
        case 0: return -1;
        # The capture `n` binds the subject. A cast pins its static type so
        # arithmetic type-checks (match captures infer as Unknown today).
        case n: return (n as int) * 2;
    }
}

def with_guard(x: int) -> int {
    match x {
        case n if n > 10: return 1;
        case n if n > 0: return 2;
        case _: return 3;
    }
}

def match_str(s: str) -> int {
    match s {
        case "hi": return 1;
        case "bye": return 2;
        case _: return 0;
    }
}
