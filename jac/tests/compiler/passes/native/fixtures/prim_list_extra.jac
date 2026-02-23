"""List extra method primitives: extend, insert.

Cross-backend equivalence fixture — Python reference + native implementation.
"""

def list_extra_py() -> dict {
    # extend
    a: list[int] = [10, 20];
    b: list[int] = [30, 40, 50];
    a.extend(b);
    ext_len = len(a);
    ext_last = a[4];

    # insert at start
    c: list[int] = [20, 30];
    c.insert(0, 10);
    ins_start_first = c[0];
    ins_start_second = c[1];
    ins_start_len = len(c);

    # insert in middle
    d: list[int] = [10, 30];
    d.insert(1, 20);
    ins_mid_first = d[0];
    ins_mid_second = d[1];
    ins_mid_third = d[2];
    ins_mid_len = len(d);

    # insert at end
    e: list[int] = [10, 20];
    e.insert(2, 30);
    ins_end_last = e[2];
    ins_end_len = len(e);

    return {
        "ext_len": ext_len,
        "ext_first": a[0],
        "ext_third": a[2],
        "ext_last": ext_last,
        "ins_start_first": ins_start_first,
        "ins_start_second": ins_start_second,
        "ins_start_len": ins_start_len,
        "ins_mid_first": ins_mid_first,
        "ins_mid_second": ins_mid_second,
        "ins_mid_third": ins_mid_third,
        "ins_mid_len": ins_mid_len,
        "ins_end_last": ins_end_last,
        "ins_end_len": ins_end_len
    };
}

na {
    def list_extra_na() -> dict[str, any] {
        # extend
        a: list[int] = [10, 20];
        b: list[int] = [30, 40, 50];
        a.extend(b);
        ext_len: int = len(a);
        ext_last: int = a[4];

        # insert at start
        c: list[int] = [20, 30];
        c.insert(0, 10);
        ins_start_first: int = c[0];
        ins_start_second: int = c[1];
        ins_start_len: int = len(c);

        # insert in middle
        d: list[int] = [10, 30];
        d.insert(1, 20);
        ins_mid_first: int = d[0];
        ins_mid_second: int = d[1];
        ins_mid_third: int = d[2];
        ins_mid_len: int = len(d);

        # insert at end
        e: list[int] = [10, 20];
        e.insert(2, 30);
        ins_end_last: int = e[2];
        ins_end_len: int = len(e);

        return {
            "ext_len": ext_len,
            "ext_first": a[0],
            "ext_third": a[2],
            "ext_last": ext_last,
            "ins_start_first": ins_start_first,
            "ins_start_second": ins_start_second,
            "ins_start_len": ins_start_len,
            "ins_mid_first": ins_mid_first,
            "ins_mid_second": ins_mid_second,
            "ins_mid_third": ins_mid_third,
            "ins_mid_len": ins_mid_len,
            "ins_end_last": ins_end_last,
            "ins_end_len": ins_end_len
        };
    }
}
