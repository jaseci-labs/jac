"""A `while True` loop with no break only exits via return/raise, so a
function whose body ends in such a loop cannot fall through and must not
be flagged E1004 (implicit None return). Regression for the false
positive that hit the bundled na_stdlib `zlib.decompress` retry loop.
"""

def spin(x: int) -> int {
    while True {
        if x > 3 {
            return x;
        }
        x += 1;
    }
}

def spin_or_raise(x: int) -> int {
    while True {
        if x > 3 {
            return x;
        }
        if x < 0 {
            raise ValueError("negative");
        }
        x += 1;
    }
}

def with_break(x: int) -> int {
    while True {
        if x > 3 {
            break;
        }
        x += 1;
    }
    return x;
}

def nested_inner_break(x: int) -> int {
    while True {
        while x < 3 {
            x += 1;
            break;
        }
        if x > 10 {
            return x;
        }
        x += 2;
    }
}

with entry {
    print(spin(1), spin_or_raise(2), with_break(0), nested_inner_break(0));
}
