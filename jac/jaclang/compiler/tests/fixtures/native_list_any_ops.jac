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

# --- Issue 5: container truthiness drives loop termination (osp_kernel DFS).
#     `while <list>` must test emptiness, not the (always non-null) pointer; the
#     kernel's `while stack` / `while scope.next` otherwise loop forever and
#     pop() runs past empty into garbage (the `tag_of` segfault). Mirrors the
#     kernel's FIFO `scope.next.pop(0)` + `(loc, phase)` tuple-stack DFS. ---
def dfs_stack_py() -> dict {
    queue: list[int] = [100, 200, 300];
    first_out: int = queue.pop(0);
    second_out: int = queue.pop(0);
    stack: list = [(first_out, 0)];
    stack.append((second_out, 1));
    n0: int = 0;
    n1: int = 0;
    visited: int = 0;
    while stack {
        (cur, phase) = stack.pop();
        if phase == 0 { n0 = n0 + 1; } else { n1 = n1 + 1; }
        visited = visited + 1;
    }
    return {"first_out": first_out, "second_out": second_out,
            "n0": n0, "n1": n1, "visited": visited, "qn": len(queue),
            "stack_empty": 0 if stack else 1};
}

na {
    def dfs_stack_na() -> dict[str, any] {
        queue: list[int] = [100, 200, 300];
        first_out: int = queue.pop(0);
        second_out: int = queue.pop(0);
        stack: list = [(first_out, 0)];
        stack.append((second_out, 1));
        n0: int = 0;
        n1: int = 0;
        visited: int = 0;
        while stack {
            (cur, phase) = stack.pop();
            if phase == 0 { n0 = n0 + 1; } else { n1 = n1 + 1; }
            visited = visited + 1;
        }
        return {"first_out": first_out, "second_out": second_out,
                "n0": n0, "n1": n1, "visited": visited, "qn": len(queue),
                "stack_empty": 0 if stack else 1};
    }
}

# --- #6449: scalar / boxed `any` values must round-trip through the native
#     JacVal representation. Faithful gradual typing: anything sv does with
#     `any`, na must do too. Covers (a) a scalar boxed into an `any` local,
#     (b) reading scalar/str values out of a `dict[str, any]` *local*, and
#     (c) a tuple whose element is `any` stored in a list, popped, unpacked
#     (the titled bug; also exercises i64 -> `any` boxing at the call site). ---
def any_scalar_box_py() -> dict {
    x: any = 555;
    y: any = 3.5;
    z: any = "hi";
    return {"x": x, "y": y, "z": z};
}

na {
    def any_scalar_box_na() -> dict[str, any] {
        x: any = 555;
        y: any = 3.5;
        z: any = "hi";
        return {"x": x, "y": y, "z": z};
    }
}

def any_dict_local_py() -> dict {
    d: dict = {"l": 555, "s": "hi"};
    li: int = d["l"];
    return {"l": li, "s": d["s"]};
}

na {
    def any_dict_local_na() -> dict[str, any] {
        d: dict[str, any] = {"l": 555, "s": "hi"};
        li: int = d["l"];
        return {"l": li, "s": d["s"]};
    }
}

def any_tuple_helper_py(loc: any) -> dict {
    s: list = [(loc, 0)];
    (cur, phase) = s.pop();
    return {"cur": cur, "phase": phase};
}

def any_tuple_roundtrip_py() -> dict {
    return any_tuple_helper_py(555);
}

na {
    def any_tuple_helper_na(loc: any) -> dict[str, any] {
        s: list = [(loc, 0)];
        (cur, phase) = s.pop();
        return {"cur": cur, "phase": phase};
    }

    def any_tuple_roundtrip_na() -> dict[str, any] {
        return any_tuple_helper_na(555);
    }
}
