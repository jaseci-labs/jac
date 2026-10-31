"""Fixture for E1006: a local must be assigned on every path before it is read.

Every read marked `E1006` must be reported, and nothing else.
"""

import from typing { Never }

obj Box {
    has n: int = 0;
}

def count(boxes: list[Box]) -> int {
    return len(boxes);
}

def read_before_assign -> int {
    first = [Box(n=1)];
    total = count(first + later);  # E1006
    later = [Box(n=2)];
    return total + len(later);
}

def assigned_in_one_branch(c: bool) -> int {
    if c {
        x = 5;
    }
    return x;  # E1006
}

def loop_carried(n: int) -> int {
    seen = 0;
    for i in range(n) {
        if i > 0 {
            seen += last;  # E1006
        }
        last = i;
    }
    return seen;
}

def for_target_after_empty_loop -> int {
    for i in range(0) {
        i;
    }
    return i;  # E1006
}

def assigned_only_in_try(text: str) -> int {
    try {
        v = int(text);
    } except ValueError {
        text;
    }
    return v;  # E1006
}

def read_in_finally(text: str) -> int {
    try {
        v = int(text);
    } finally {
        v;  # E1006
    }
    return v;
}

def except_alias_after_handler -> str {
    try {
        raise ValueError("x");
    } except ValueError as e {
        e;
    }
    return str(e);  # E1006
}

def walrus_on_short_circuit(a: bool, f: int) -> int {
    if a or (m := f) > 0 {
        return m;  # E1006
    }
    return 0;
}

def read_after_del -> int {
    z = 1;
    del z;
    return z;  # E1006
}

def augmented_unassigned(c: bool) -> int {
    if c {
        k = 1;
    }
    k += 1;  # E1006
    return k;
}

def every_branch_assigns(c: bool, d: bool) -> int {
    if c {
        x = 1;
    } elif d {
        x = 2;
    } else {
        x = 3;
    }
    return x;
}

def handler_assigns(text: str) -> int {
    try {
        v = int(text);
    } except ValueError {
        v = 0;
    }
    return v;
}

def finally_after_assignment(text: str) -> int {
    try {
        v = int(text);
    } finally {
        text;
    }
    return v;
}

def handler_returns(text: str) -> int {
    try {
        v = int(text);
    } except ValueError {
        return 0;
    }
    return v;
}

def while_true_break -> int {
    while True {
        got = 5;
        if got > 1 {
            break;
        }
    }
    return got;
}

def walrus_on_true_branch(a: bool, f: int) -> int {
    if a and (m := f) > 0 {
        return m;
    }
    if (w := f) > 2 {
        return w;
    }
    return w;
}

def exhaustive_match(v: int) -> str {
    match v {
        case 1:
            s = "one";

        case _:
            s = "other";

    }
    return s;
}

def with_body_assigns(path: str) -> str {
    with open(path) as h {
        data = h.read();
    }
    return data;
}

def for_else_break(xs: list[int]) -> int {
    for x in xs {
        if x > 2 {
            found = x;
            break;
        }
    } else {
        found = -1;
    }
    return found;
}

def break_out_of_loop_ending_if(xs: list[int], c: bool) -> int {
    if c {
        for x in xs {
            last = x;
            break;
        } else {
            last = 0;
        }
    } else {
        last = 1;
    }
    return last;
}

def raising_branch(c: bool) -> int {
    if c {
        y = 1;
    } else {
        raise ValueError("no");
    }
    return y;
}

def lambda_reads_later_local -> int {
    f = lambda (a: int) -> int { return a + later; };
    later = 3;
    return f(1);
}

def stop -> Never {
    raise SystemExit(1);
}

def never_returning_branch(c: bool) -> int {
    if c {
        y = 1;
    } else {
        stop();
    }
    return y;
}

def unpacking -> int {
    (a, b) = (1, 2);
    [c, *rest] = [3, 4, 5];
    return a + b + c + len(rest);
}

def rebind_loop_target_in_nested_block(pairs: list[tuple[str, str]]) -> list[str] {
    out: list[str] = [];
    for (cond, other) in pairs {
        if other {
            cond += other;
        }
        out.append(cond);
    }
    return out;
}
