"""List method primitives: append, pop, clear, index, reverse, copy.

Cross-backend equivalence fixture — Python reference + native implementation.
"""

def list_methods_py() -> dict {
    # append + len
    a: list[int] = [10, 20, 30];
    a.append(40);
    append_len = len(a);
    append_last = a[3];

    # get/set
    b: list[int] = [10, 20, 30];
    get_val = b[1];
    b[1] = 99;
    set_val = b[1];

    # multiple appends
    c: list[int] = [];
    c.append(1);
    c.append(2);
    c.append(3);
    c.append(4);
    c.append(5);
    multi_len = len(c);

    # pop
    d: list[int] = [10, 20, 30];
    pop_val = d.pop();
    pop_len = len(d);

    # clear
    e: list[int] = [10, 20, 30];
    e.clear();
    clear_len = len(e);

    # index
    f: list[int] = [10, 20, 30, 20];
    index_found = f.index(20);

    # reverse
    g: list[int] = [10, 20, 30];
    g.reverse();
    rev_first = g[0];
    rev_last = g[2];

    # copy
    h: list[int] = [10, 20, 30];
    h2: list[int] = h.copy();
    copy_len = len(h2);
    copy_first = h2[0];

    return {
        "append_len": append_len,
        "append_last": append_last,
        "get_val": get_val,
        "set_val": set_val,
        "multi_append_len": multi_len,
        "multi_append_first": c[0],
        "multi_append_last": c[4],
        "pop_val": pop_val,
        "pop_len": pop_len,
        "clear_len": clear_len,
        "index_found": index_found,
        "rev_first": rev_first,
        "rev_last": rev_last,
        "copy_len": copy_len,
        "copy_first": copy_first
    };
}

na {
    def list_methods_na() -> dict[str, any] {
        # append + len
        a: list[int] = [10, 20, 30];
        a.append(40);
        append_len: int = len(a);
        append_last: int = a[3];

        # get/set
        b: list[int] = [10, 20, 30];
        get_val: int = b[1];
        b[1] = 99;
        set_val: int = b[1];

        # multiple appends
        c: list[int] = [];
        c.append(1);
        c.append(2);
        c.append(3);
        c.append(4);
        c.append(5);
        multi_len: int = len(c);

        # pop
        d: list[int] = [10, 20, 30];
        pop_val: int = d.pop();
        pop_len: int = len(d);

        # clear
        e: list[int] = [10, 20, 30];
        e.clear();
        clear_len: int = len(e);

        # index
        f: list[int] = [10, 20, 30, 20];
        index_found: int = f.index(20);

        # reverse
        g: list[int] = [10, 20, 30];
        g.reverse();
        rev_first: int = g[0];
        rev_last: int = g[2];

        # copy
        h: list[int] = [10, 20, 30];
        h2: list[int] = h.copy();
        copy_len: int = len(h2);
        copy_first: int = h2[0];

        return {
            "append_len": append_len,
            "append_last": append_last,
            "get_val": get_val,
            "set_val": set_val,
            "multi_append_len": multi_len,
            "multi_append_first": c[0],
            "multi_append_last": c[4],
            "pop_val": pop_val,
            "pop_len": pop_len,
            "clear_len": clear_len,
            "index_found": index_found,
            "rev_first": rev_first,
            "rev_last": rev_last,
            "copy_len": copy_len,
            "copy_first": copy_first
        };
    }
}
