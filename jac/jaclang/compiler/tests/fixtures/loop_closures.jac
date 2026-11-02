"""Closures created in a loop body keep the loop's own names per pass.

Cross-backend equivalence fixture. A name whose every assignment is inside a
loop belongs to one pass of that loop as far as a closure created in the body
is concerned: the closure shares it with the rest of the function while the
pass lasts and keeps its own copy once the pass ends. A name also assigned
outside the loop stays shared.
"""

def loop_closures_py -> dict[str, any] {
    def calls(fs: list[Callable[[], int]]) -> list[int] {
        out: list[int] = [];
        for f in fs {
            out.append(f());
        }
        return out;
    }

    target_fs: list[Callable[[], int]] = [];
    for x in [1, 2, 3] {
        target_fs.append(lambda -> int { return x; });
    }

    local_fs: list[Callable[[], int]] = [];
    for x in [1, 2, 3] {
        y = x * 10;
        local_fs.append(lambda -> int { return y; });
    }

    typed_fs: list[Callable[[], int]] = [];
    for x in [1, 2, 3] {
        z: int = x * 100;
        typed_fs.append(lambda -> int { return z; });
    }

    counted_fs: list[Callable[[], int]] = [];
    for i = 0 while i < 3 with i += 1 {
        counted_fs.append(lambda -> int { return i; });
    }

    while_fs: list[Callable[[], int]] = [];
    shared_fs: list[Callable[[], int]] = [];
    k = 0;
    while k < 3 {
        v = k * 2;
        while_fs.append(lambda -> int { return v; });
        shared_fs.append(lambda -> int { return k; });
        k += 1;
    }

    late_fs: list[Callable[[], int]] = [];
    for x in [1, 2] {
        w = x;
        late_fs.append(lambda -> int { return w; });
        w = x + 100;
    }

    bump_fs: list[Callable[[], int]] = [];
    for x in [1, 2, 3] {
        c = x;
        def bump -> int {
            c += 10;
            return c;
        }
        bump_fs.append(bump);
    }
    bump_first = bump_fs[0]();
    bump_again = bump_fs[0]();
    bump_third = bump_fs[2]();

    seen_in_pass: list[int] = [];
    for x in [1, 2] {
        d = x;
        def raise_d -> int {
            d += 100;
            return d;
        }
        raise_d();
        seen_in_pass.append(d);
    }

    nested_fs: list[Callable[[], int]] = [];
    for r in [1, 2] {
        for q in [1, 2] {
            nested_fs.append(lambda -> int { return r * 10 + q; });
        }
    }

    outer_fs: list[Callable[[], int]] = [];
    for r in [1, 2] {
        t = r;
        outer_fs.append(lambda -> int { return t; });
        for q in [1, 2, 3] {
            t += q;
        }
    }

    flag_fs: list[Callable[[], bool]] = [];
    done = False;
    for x in [1, 2, 3] {
        flag_fs.append(lambda -> bool { return done; });
        if x == 3 {
            done = True;
        }
    }
    flags: list[bool] = [];
    for f in flag_fs {
        flags.append(f());
    }

    break_fs: list[Callable[[], int]] = [];
    for x in [1, 2, 3] {
        b = x;
        break_fs.append(lambda -> int { return b; });
        if x == 2 {
            break;
        }
    }

    continue_fs: list[Callable[[], int]] = [];
    for x in [1, 2, 3] {
        e = x;
        continue_fs.append(lambda -> int { return e; });
        if x < 3 {
            continue;
        }
    }

    def_fs: list[Callable[[], int]] = [];
    for x in [1, 2] {
        def seven -> int {
            return x * 7;
        }
        def_fs.append(seven);
    }

    pair_fs: list[Callable[[], int]] = [];
    for (m, n) in [(1, 2), (3, 4)] {
        pair_fs.append(lambda -> int { return m * 10 + n; });
    }

    compr_fs: list[Callable[[], int]] = [
        lambda -> int { return n * 2; } for n in [1, 2, 3]
    ];

    after_fs: list[Callable[[], int]] = [];
    for x in [1, 2, 3] {
        a = x * 2;
        after_fs.append(lambda -> int { return a; });
    }

    return {
        "target": calls(target_fs),
        "body_local": calls(local_fs),
        "typed_local": calls(typed_fs),
        "counted": calls(counted_fs),
        "while_local": calls(while_fs),
        "while_shared": calls(shared_fs),
        "same_pass_write": calls(late_fs),
        "closure_write": [bump_first, bump_again, bump_third, c],
        "write_in_pass": seen_in_pass,
        "nested": calls(nested_fs),
        "outer_pass": calls(outer_fs),
        "shared_flag": flags,
        "break": calls(break_fs) + [b],
        "continue": calls(continue_fs),
        "nested_def": calls(def_fs),
        "unpacked": calls(pair_fs),
        "comprehension": calls(compr_fs),
        "after_loop": calls(after_fs) + [a]
    };
}

def loop_closures_cl -> dict[str, any] {
    def calls(fs: list[Callable[[], int]]) -> list[int] {
        out: list[int] = [];
        for f in fs {
            out.append(f());
        }
        return out;
    }

    target_fs: list[Callable[[], int]] = [];
    for x in [1, 2, 3] {
        target_fs.append(lambda -> int { return x; });
    }

    local_fs: list[Callable[[], int]] = [];
    for x in [1, 2, 3] {
        y = x * 10;
        local_fs.append(lambda -> int { return y; });
    }

    typed_fs: list[Callable[[], int]] = [];
    for x in [1, 2, 3] {
        z: int = x * 100;
        typed_fs.append(lambda -> int { return z; });
    }

    counted_fs: list[Callable[[], int]] = [];
    for i = 0 while i < 3 with i += 1 {
        counted_fs.append(lambda -> int { return i; });
    }

    while_fs: list[Callable[[], int]] = [];
    shared_fs: list[Callable[[], int]] = [];
    k = 0;
    while k < 3 {
        v = k * 2;
        while_fs.append(lambda -> int { return v; });
        shared_fs.append(lambda -> int { return k; });
        k += 1;
    }

    late_fs: list[Callable[[], int]] = [];
    for x in [1, 2] {
        w = x;
        late_fs.append(lambda -> int { return w; });
        w = x + 100;
    }

    bump_fs: list[Callable[[], int]] = [];
    for x in [1, 2, 3] {
        c = x;
        def bump -> int {
            c += 10;
            return c;
        }
        bump_fs.append(bump);
    }
    bump_first = bump_fs[0]();
    bump_again = bump_fs[0]();
    bump_third = bump_fs[2]();

    seen_in_pass: list[int] = [];
    for x in [1, 2] {
        d = x;
        def raise_d -> int {
            d += 100;
            return d;
        }
        raise_d();
        seen_in_pass.append(d);
    }

    nested_fs: list[Callable[[], int]] = [];
    for r in [1, 2] {
        for q in [1, 2] {
            nested_fs.append(lambda -> int { return r * 10 + q; });
        }
    }

    outer_fs: list[Callable[[], int]] = [];
    for r in [1, 2] {
        t = r;
        outer_fs.append(lambda -> int { return t; });
        for q in [1, 2, 3] {
            t += q;
        }
    }

    flag_fs: list[Callable[[], bool]] = [];
    done = False;
    for x in [1, 2, 3] {
        flag_fs.append(lambda -> bool { return done; });
        if x == 3 {
            done = True;
        }
    }
    flags: list[bool] = [];
    for f in flag_fs {
        flags.append(f());
    }

    break_fs: list[Callable[[], int]] = [];
    for x in [1, 2, 3] {
        b = x;
        break_fs.append(lambda -> int { return b; });
        if x == 2 {
            break;
        }
    }

    continue_fs: list[Callable[[], int]] = [];
    for x in [1, 2, 3] {
        e = x;
        continue_fs.append(lambda -> int { return e; });
        if x < 3 {
            continue;
        }
    }

    def_fs: list[Callable[[], int]] = [];
    for x in [1, 2] {
        def seven -> int {
            return x * 7;
        }
        def_fs.append(seven);
    }

    pair_fs: list[Callable[[], int]] = [];
    for (m, n) in [(1, 2), (3, 4)] {
        pair_fs.append(lambda -> int { return m * 10 + n; });
    }

    compr_fs: list[Callable[[], int]] = [
        lambda -> int { return n * 2; } for n in [1, 2, 3]
    ];

    after_fs: list[Callable[[], int]] = [];
    for x in [1, 2, 3] {
        a = x * 2;
        after_fs.append(lambda -> int { return a; });
    }

    return {
        "target": calls(target_fs),
        "body_local": calls(local_fs),
        "typed_local": calls(typed_fs),
        "counted": calls(counted_fs),
        "while_local": calls(while_fs),
        "while_shared": calls(shared_fs),
        "same_pass_write": calls(late_fs),
        "closure_write": [bump_first, bump_again, bump_third, c],
        "write_in_pass": seen_in_pass,
        "nested": calls(nested_fs),
        "outer_pass": calls(outer_fs),
        "shared_flag": flags,
        "break": calls(break_fs) + [b],
        "continue": calls(continue_fs),
        "nested_def": calls(def_fs),
        "unpacked": calls(pair_fs),
        "comprehension": calls(compr_fs),
        "after_loop": calls(after_fs) + [a]
    };
}

def loop_closures_na -> dict[str, any] {
    def calls(fs: list[Callable[[], int]]) -> list[int] {
        out: list[int] = [];
        for f in fs {
            out.append(f());
        }
        return out;
    }

    target_fs: list[Callable[[], int]] = [];
    for x in [1, 2, 3] {
        target_fs.append(lambda -> int { return x; });
    }

    local_fs: list[Callable[[], int]] = [];
    for x in [1, 2, 3] {
        y = x * 10;
        local_fs.append(lambda -> int { return y; });
    }

    typed_fs: list[Callable[[], int]] = [];
    for x in [1, 2, 3] {
        z: int = x * 100;
        typed_fs.append(lambda -> int { return z; });
    }

    counted_fs: list[Callable[[], int]] = [];
    for i = 0 while i < 3 with i += 1 {
        counted_fs.append(lambda -> int { return i; });
    }

    while_fs: list[Callable[[], int]] = [];
    shared_fs: list[Callable[[], int]] = [];
    k = 0;
    while k < 3 {
        v = k * 2;
        while_fs.append(lambda -> int { return v; });
        shared_fs.append(lambda -> int { return k; });
        k += 1;
    }

    late_fs: list[Callable[[], int]] = [];
    for x in [1, 2] {
        w = x;
        late_fs.append(lambda -> int { return w; });
        w = x + 100;
    }

    bump_fs: list[Callable[[], int]] = [];
    for x in [1, 2, 3] {
        c = x;
        def bump -> int {
            c += 10;
            return c;
        }
        bump_fs.append(bump);
    }
    bump_first = bump_fs[0]();
    bump_again = bump_fs[0]();
    bump_third = bump_fs[2]();

    seen_in_pass: list[int] = [];
    for x in [1, 2] {
        d = x;
        def raise_d -> int {
            d += 100;
            return d;
        }
        raise_d();
        seen_in_pass.append(d);
    }

    nested_fs: list[Callable[[], int]] = [];
    for r in [1, 2] {
        for q in [1, 2] {
            nested_fs.append(lambda -> int { return r * 10 + q; });
        }
    }

    outer_fs: list[Callable[[], int]] = [];
    for r in [1, 2] {
        t = r;
        outer_fs.append(lambda -> int { return t; });
        for q in [1, 2, 3] {
            t += q;
        }
    }

    flag_fs: list[Callable[[], bool]] = [];
    done = False;
    for x in [1, 2, 3] {
        flag_fs.append(lambda -> bool { return done; });
        if x == 3 {
            done = True;
        }
    }
    flags: list[bool] = [];
    for f in flag_fs {
        flags.append(f());
    }

    break_fs: list[Callable[[], int]] = [];
    for x in [1, 2, 3] {
        b = x;
        break_fs.append(lambda -> int { return b; });
        if x == 2 {
            break;
        }
    }

    continue_fs: list[Callable[[], int]] = [];
    for x in [1, 2, 3] {
        e = x;
        continue_fs.append(lambda -> int { return e; });
        if x < 3 {
            continue;
        }
    }

    def_fs: list[Callable[[], int]] = [];
    for x in [1, 2] {
        def seven -> int {
            return x * 7;
        }
        def_fs.append(seven);
    }

    pair_fs: list[Callable[[], int]] = [];
    for (m, n) in [(1, 2), (3, 4)] {
        pair_fs.append(lambda -> int { return m * 10 + n; });
    }

    compr_fs: list[Callable[[], int]] = [
        lambda -> int { return n * 2; } for n in [1, 2, 3]
    ];

    after_fs: list[Callable[[], int]] = [];
    for x in [1, 2, 3] {
        a = x * 2;
        after_fs.append(lambda -> int { return a; });
    }

    return {
        "target": calls(target_fs),
        "body_local": calls(local_fs),
        "typed_local": calls(typed_fs),
        "counted": calls(counted_fs),
        "while_local": calls(while_fs),
        "while_shared": calls(shared_fs),
        "same_pass_write": calls(late_fs),
        "closure_write": [bump_first, bump_again, bump_third, c],
        "write_in_pass": seen_in_pass,
        "nested": calls(nested_fs),
        "outer_pass": calls(outer_fs),
        "shared_flag": flags,
        "break": calls(break_fs) + [b],
        "continue": calls(continue_fs),
        "nested_def": calls(def_fs),
        "unpacked": calls(pair_fs),
        "comprehension": calls(compr_fs),
        "after_loop": calls(after_fs) + [a]
    };
}

def outside_closure_py -> dict[str, any] {
    def peek -> int {
        return cur;
    }
    reported: list[int] = [];
    cur_fs: list[Callable[[], int]] = [];
    for x in [1, 2, 3] {
        cur = x;
        reported.append(peek());
        cur_fs.append(lambda -> int { return cur; });
    }
    seen: list[int] = [];
    for f in cur_fs {
        seen.append(f());
    }
    return {"outside_closure": reported + [peek()], "inside_closure": seen};
}

def outside_closure_cl -> dict[str, any] {
    def peek -> int {
        return cur;
    }
    reported: list[int] = [];
    cur_fs: list[Callable[[], int]] = [];
    for x in [1, 2, 3] {
        cur = x;
        reported.append(peek());
        cur_fs.append(lambda -> int { return cur; });
    }
    seen: list[int] = [];
    for f in cur_fs {
        seen.append(f());
    }
    return {"outside_closure": reported + [peek()], "inside_closure": seen};
}
