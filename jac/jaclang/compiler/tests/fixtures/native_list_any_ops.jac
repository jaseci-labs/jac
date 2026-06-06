"""Native list/`any` codegen gaps surfaced during OSP kernel bring-up (#6435).

Each function isolates one native-backend bug. The cross-backend harness pins
the Python reference and `require=["na"]` makes the native backend a hard
regression guard (a backend that fails to compile/run or mismatches fails the
test instead of being silently skipped).
"""

# --- Issue 1: list.pop(index) must honor the index (kernel FIFO pop(0)) ---
def pop_index_py() -> dict {
    a: list[int] = [];
    a.append(11);
    a.append(22);
    a.append(33);
    first: int = a.pop(0);      # 11; a == [22, 33]
    mid: int = a.pop(1);        # 33; a == [22]
    last: int = a.pop();        # 22; a == []
    b: list[int] = [10, 20, 30, 40];
    neg: int = b.pop(-2);       # 30; b == [10, 20, 40]
    return {
        "first": first, "mid": mid, "last": last, "n": len(a),
        "neg": neg, "b0": b[0], "b1": b[1], "b2": b[2], "bn": len(b)
    };
}

na {
    def pop_index_na() -> dict[str, any] {
        a: list[int] = [];
        a.append(11);
        a.append(22);
        a.append(33);
        first: int = a.pop(0);
        mid: int = a.pop(1);
        last: int = a.pop();
        b: list[int] = [10, 20, 30, 40];
        neg: int = b.pop(-2);
        return {
            "first": first, "mid": mid, "last": last, "n": len(a),
            "neg": neg, "b0": b[0], "b1": b[1], "b2": b[2], "bn": len(b)
        };
    }
}

# --- Issue 2: list[tuple[...]] round-trip (append -> pop -> unpack) ---
def tuple_roundtrip_py() -> dict {
    s: list[tuple[int, int]] = [(10, 0)];
    s.append((20, 1));
    (a, p1) = s.pop();          # (20, 1)
    (b, p0) = s.pop();          # (10, 0)
    return {"a": a, "p1": p1, "b": b, "p0": p0, "n": len(s)};
}

na {
    def tuple_roundtrip_na() -> dict[str, any] {
        s: list[tuple[int, int]] = [(10, 0)];
        s.append((20, 1));
        (a, p1) = s.pop();
        (b, p0) = s.pop();
        return {"a": a, "p1": p1, "b": b, "p0": p0, "n": len(s)};
    }
}

# --- Issue 3: non-empty list literal with a boxed `any` element coerces;
#     a default-`i64` list and an `any` list literal must not collide. ---
# A default-`i64` list and an `any`-element list literal must get distinct
# native helpers (the literal's boxed JacVal must not be stored into an `i64`
# slot). Value round-trip of `any` dict reads is a separate concern, so this
# pins only that both lists coexist with correct lengths.
def any_literal_py() -> dict {
    nums: list[int] = [1, 2, 3];
    d: dict[str, any] = {"v": 7};
    st: list = [d["v"]];
    return {"n": len(nums), "m": len(st)};
}

na {
    def any_literal_na() -> dict[str, any] {
        nums: list[int] = [1, 2, 3];
        d: dict[str, any] = {"v": 7};
        st: list = [d["v"]];
        return {"n": len(nums), "m": len(st)};
    }
}

# --- Issue 4: unpacking pop() of a bare `list` (any element) must type-check
#     in native codespace and round-trip at runtime (kernel DFS tuple-stack). ---
def any_stack_py() -> dict {
    loc: int = 5;
    stack: list = [(loc, 0)];
    stack.append((20, 1));
    (cur, phase) = stack.pop();     # (20, 1)
    (cur0, phase0) = stack.pop();   # (5, 0)
    return {"cur": cur, "phase": phase, "cur0": cur0, "phase0": phase0};
}

na {
    def any_stack_na() -> dict[str, any] {
        loc: int = 5;
        stack: list = [(loc, 0)];
        stack.append((20, 1));
        (cur, phase) = stack.pop();
        (cur0, phase0) = stack.pop();
        return {"cur": cur, "phase": phase, "cur0": cur0, "phase0": phase0};
    }
}
