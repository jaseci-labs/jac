"""List emitter: all methods, operators, multiplication, comparison, containers portion.

Cross-backend equivalence fixture.
"""

# --- List methods and operators ---
def list_py() -> dict {
    # methods
    a1: list = [1, 2, 3];
    a1.append(4);

    a2: list = [1, 2];
    a2.extend([3, 4, 5]);

    a3: list = [1, 3, 4];
    a3.insert(1, 2);

    a4: list = [10, 20, 30];
    popped_last: int = a4.pop();

    a5: list = [10, 20, 30];
    popped_first: int = a5.pop(0);

    a6: list = [1, 2, 3];
    a6.clear();

    a7: list = [10, 20, 30, 20];
    idx: int = a7.index(20);

    a8: list = [3, 1, 2];
    a8.reverse();

    a9: list = [1, 2, 3];
    a9_copy: list = a9.copy();

    a: list = [10, 20, 30];
    a.append(40);
    append_len: int = len(a);
    append_last: int = a[3];

    b: list = [10, 20, 30];
    get_val: int = b[1];
    b[1] = 99;
    set_val: int = b[1];

    c: list = [];
    c.append(1);
    c.append(2);
    c.append(3);
    c.append(4);
    c.append(5);
    multi_len: int = len(c);

    d: list = [10, 20, 30];
    pop_val: int = d.pop();
    pop_len: int = len(d);

    e: list = [10, 20, 30];
    e.clear();
    clear_len: int = len(e);

    f: list = [10, 20, 30, 20];
    index_found: int = f.index(20);

    g: list = [10, 20, 30];
    g.reverse();
    rev_first: int = g[0];
    rev_last: int = g[2];

    h: list = [10, 20, 30];
    h2: list = h.copy();
    copy_len: int = len(h2);
    copy_first: int = h2[0];

    # sort
    nums: list[int] = [5, 3, 8, 1, 4, 2, 7, 6];
    nums.sort();

    # remove
    rm_a: list[int] = [1, 2, 3, 2, 1];
    rm_a.remove(2);
    rm_b: list[int] = [10, 20, 30];
    rm_b.remove(10);
    rm_c: list[int] = [5, 10, 15];
    rm_c.remove(15);

    # extend and insert
    ext_a: list[int] = [10, 20];
    ext_b: list[int] = [30, 40, 50];
    ext_a.extend(ext_b);
    ins_c: list[int] = [20, 30];
    ins_c.insert(0, 10);
    ins_d: list[int] = [10, 30];
    ins_d.insert(1, 20);
    ins_e: list[int] = [10, 20];
    ins_e.insert(2, 30);

    # multiplication
    mul_a: list[int] = [1, 2, 3];
    r3: list[int] = mul_a * 3;
    r1: list[int] = mul_a * 1;
    r0: list[int] = mul_a * 0;
    r_rev: list[int] = 2 * mul_a;

    # comparisons
    cmp_a: list[int] = [1, 2, 3];
    cmp_b: list[int] = [1, 2, 3];
    cmp_c: list[int] = [1, 2, 4];
    cmp_d: list[int] = [1, 2];
    cmp_e: list[int] = [1, 2, 3, 4];

    # operators: in, +, +=
    op_nums: list[int] = [10, 20, 30, 40, 50];
    in_found: int = 1 if 30 in op_nums else 0;
    in_missing: int = 1 if 99 in op_nums else 0;
    not_in_found: int = 1 if 30 not in op_nums else 0;
    not_in_missing: int = 1 if 99 not in op_nums else 0;
    in_first: int = 1 if 10 in op_nums else 0;
    in_last: int = 1 if 50 in op_nums else 0;
    op_a: list[int] = [1, 2, 3];
    op_b: list[int] = [4, 5, 6];
    op_c: list[int] = op_a + op_b;

    # containers: += (iadd)
    iadd_c: list = [10, 20];
    iadd_c += [30, 40];

    # list slicing
    sl_src: list[int] = [10, 20, 30, 40, 50];
    sl_mid: list[int] = sl_src[1:4];
    sl_to: list[int] = sl_src[:2];

    return {
        "after_append": a1,
        "after_extend": a2,
        "after_insert": a3,
        "popped_last": popped_last,
        "after_pop_last": a4,
        "popped_first": popped_first,
        "after_pop_first": a5,
        "after_clear": a6,
        "index": idx,
        "after_reverse": a8,
        "copy": a9_copy,
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
        "copy_first": copy_first,
        "s0": nums[0], "s1": nums[1], "s2": nums[2], "s3": nums[3],
        "s4": nums[4], "s5": nums[5], "s6": nums[6], "s7": nums[7],
        "slen": len(nums),
        "remove_mid_len": len(rm_a),
        "remove_mid_first": rm_a[0],
        "remove_mid_second": rm_a[1],
        "remove_mid_third": rm_a[2],
        "remove_mid_fourth": rm_a[3],
        "remove_front_len": len(rm_b),
        "remove_front_first": rm_b[0],
        "remove_front_second": rm_b[1],
        "remove_end_len": len(rm_c),
        "remove_end_first": rm_c[0],
        "remove_end_second": rm_c[1],
        "ext_len": len(ext_a),
        "ext_first": ext_a[0],
        "ext_third": ext_a[2],
        "ext_last": ext_a[4],
        "ins_start_first": ins_c[0],
        "ins_start_second": ins_c[1],
        "ins_start_len": len(ins_c),
        "ins_mid_first": ins_d[0],
        "ins_mid_second": ins_d[1],
        "ins_mid_third": ins_d[2],
        "ins_mid_len": len(ins_d),
        "ins_end_last": ins_e[2],
        "ins_end_len": len(ins_e),
        "r3_len": len(r3),
        "r3_0": r3[0], "r3_1": r3[1], "r3_2": r3[2],
        "r3_3": r3[3], "r3_4": r3[4], "r3_5": r3[5],
        "r3_6": r3[6], "r3_7": r3[7], "r3_8": r3[8],
        "r1_len": len(r1), "r1_0": r1[0],
        "r0_len": len(r0),
        "r_rev_len": len(r_rev),
        "r_rev_0": r_rev[0], "r_rev_3": r_rev[3],
        "orig_len": len(mul_a),
        "eq_same": 1 if cmp_a == cmp_b else 0,
        "eq_diff": 1 if cmp_a == cmp_c else 0,
        "eq_shorter": 1 if cmp_a == cmp_d else 0,
        "ne_same": 1 if cmp_a != cmp_b else 0,
        "ne_diff": 1 if cmp_a != cmp_c else 0,
        "lt_less": 1 if cmp_a < cmp_c else 0,
        "lt_greater": 1 if cmp_c < cmp_a else 0,
        "lt_equal": 1 if cmp_a < cmp_b else 0,
        "lt_shorter": 1 if cmp_d < cmp_a else 0,
        "lt_longer": 1 if cmp_a < cmp_e else 0,
        "gt_less": 1 if cmp_a > cmp_c else 0,
        "gt_greater": 1 if cmp_c > cmp_a else 0,
        "gt_equal": 1 if cmp_a > cmp_b else 0,
        "le_less": 1 if cmp_a <= cmp_c else 0,
        "le_equal": 1 if cmp_a <= cmp_b else 0,
        "le_greater": 1 if cmp_c <= cmp_a else 0,
        "ge_less": 1 if cmp_a >= cmp_c else 0,
        "ge_equal": 1 if cmp_a >= cmp_b else 0,
        "ge_greater": 1 if cmp_c >= cmp_a else 0,
        "in_found": in_found,
        "in_missing": in_missing,
        "not_in_found": not_in_found,
        "not_in_missing": not_in_missing,
        "in_first": in_first,
        "in_last": in_last,
        "concat_len": len(op_c),
        "concat_0": op_c[0],
        "concat_1": op_c[1],
        "concat_2": op_c[2],
        "concat_3": op_c[3],
        "concat_4": op_c[4],
        "concat_5": op_c[5],
        "orig_a_len": len(op_a),
        "orig_b_len": len(op_b),
        "list_iadd": iadd_c,
        "sl_mid_len": len(sl_mid),
        "sl_mid_0": sl_mid[0], "sl_mid_1": sl_mid[1], "sl_mid_2": sl_mid[2],
        "sl_to_len": len(sl_to),
        "sl_to_0": sl_to[0], "sl_to_1": sl_to[1]
    };
}

cl def list_cl() -> dict {
    a1: list = [1, 2, 3];
    a1.append(4);

    a2: list = [1, 2];
    a2.extend([3, 4, 5]);

    a3: list = [1, 3, 4];
    a3.insert(1, 2);

    a4: list = [10, 20, 30];
    popped_last: int = a4.pop();

    a5: list = [10, 20, 30];
    popped_first: int = a5.pop(0);

    a6: list = [1, 2, 3];
    a6.clear();

    a7: list = [10, 20, 30, 20];
    idx: int = a7.index(20);

    a8: list = [3, 1, 2];
    a8.reverse();

    a9: list = [1, 2, 3];
    a9_copy: list = a9.copy();

    nums: list[int] = [5, 3, 8, 1, 4, 2, 7, 6];
    nums.sort();

    rm_a: list[int] = [1, 2, 3, 2, 1];
    rm_a.remove(2);
    rm_b: list[int] = [10, 20, 30];
    rm_b.remove(10);
    rm_c: list[int] = [5, 10, 15];
    rm_c.remove(15);

    ext_a: list[int] = [10, 20];
    ext_b: list[int] = [30, 40, 50];
    ext_a.extend(ext_b);
    ins_c: list[int] = [20, 30];
    ins_c.insert(0, 10);
    ins_d: list[int] = [10, 30];
    ins_d.insert(1, 20);
    ins_e: list[int] = [10, 20];
    ins_e.insert(2, 30);

    mul_a: list[int] = [1, 2, 3];
    r3: list[int] = mul_a * 3;
    r1: list[int] = mul_a * 1;
    r0: list[int] = mul_a * 0;
    r_rev: list[int] = 2 * mul_a;

    cmp_a: list[int] = [1, 2, 3];
    cmp_b: list[int] = [1, 2, 3];
    cmp_c: list[int] = [1, 2, 4];
    cmp_d: list[int] = [1, 2];
    cmp_e: list[int] = [1, 2, 3, 4];

    op_nums: list[int] = [10, 20, 30, 40, 50];
    in_found: int = 1 if 30 in op_nums else 0;
    in_missing: int = 1 if 99 in op_nums else 0;
    not_in_found: int = 1 if 30 not in op_nums else 0;
    not_in_missing: int = 1 if 99 not in op_nums else 0;
    in_first: int = 1 if 10 in op_nums else 0;
    in_last: int = 1 if 50 in op_nums else 0;
    op_a: list[int] = [1, 2, 3];
    op_b: list[int] = [4, 5, 6];
    op_c: list[int] = op_a + op_b;

    iadd_c: list = [10, 20];
    iadd_c += [30, 40];

    return {
        "after_append": a1,
        "after_extend": a2,
        "after_insert": a3,
        "popped_last": popped_last,
        "after_pop_last": a4,
        "popped_first": popped_first,
        "after_pop_first": a5,
        "after_clear": a6,
        "index": idx,
        "after_reverse": a8,
        "copy": a9_copy,
        "s0": nums[0], "s1": nums[1], "s2": nums[2], "s3": nums[3],
        "s4": nums[4], "s5": nums[5], "s6": nums[6], "s7": nums[7],
        "slen": len(nums),
        "remove_mid_len": len(rm_a),
        "remove_mid_first": rm_a[0],
        "remove_mid_second": rm_a[1],
        "remove_mid_third": rm_a[2],
        "remove_mid_fourth": rm_a[3],
        "remove_front_len": len(rm_b),
        "remove_front_first": rm_b[0],
        "remove_front_second": rm_b[1],
        "remove_end_len": len(rm_c),
        "remove_end_first": rm_c[0],
        "remove_end_second": rm_c[1],
        "ext_len": len(ext_a),
        "ext_first": ext_a[0],
        "ext_third": ext_a[2],
        "ext_last": ext_a[4],
        "ins_start_first": ins_c[0],
        "ins_start_second": ins_c[1],
        "ins_start_len": len(ins_c),
        "ins_mid_first": ins_d[0],
        "ins_mid_second": ins_d[1],
        "ins_mid_third": ins_d[2],
        "ins_mid_len": len(ins_d),
        "ins_end_last": ins_e[2],
        "ins_end_len": len(ins_e),
        "r3_len": len(r3),
        "r3_0": r3[0], "r3_1": r3[1], "r3_2": r3[2],
        "r3_3": r3[3], "r3_4": r3[4], "r3_5": r3[5],
        "r3_6": r3[6], "r3_7": r3[7], "r3_8": r3[8],
        "r1_len": len(r1), "r1_0": r1[0],
        "r0_len": len(r0),
        "r_rev_len": len(r_rev),
        "r_rev_0": r_rev[0], "r_rev_3": r_rev[3],
        "orig_len": len(mul_a),
        "eq_same": 1 if cmp_a == cmp_b else 0,
        "eq_diff": 1 if cmp_a == cmp_c else 0,
        "eq_shorter": 1 if cmp_a == cmp_d else 0,
        "ne_same": 1 if cmp_a != cmp_b else 0,
        "ne_diff": 1 if cmp_a != cmp_c else 0,
        "lt_less": 1 if cmp_a < cmp_c else 0,
        "lt_greater": 1 if cmp_c < cmp_a else 0,
        "lt_equal": 1 if cmp_a < cmp_b else 0,
        "lt_shorter": 1 if cmp_d < cmp_a else 0,
        "lt_longer": 1 if cmp_a < cmp_e else 0,
        "gt_less": 1 if cmp_a > cmp_c else 0,
        "gt_greater": 1 if cmp_c > cmp_a else 0,
        "gt_equal": 1 if cmp_a > cmp_b else 0,
        "le_less": 1 if cmp_a <= cmp_c else 0,
        "le_equal": 1 if cmp_a <= cmp_b else 0,
        "le_greater": 1 if cmp_c <= cmp_a else 0,
        "ge_less": 1 if cmp_a >= cmp_c else 0,
        "ge_equal": 1 if cmp_a >= cmp_b else 0,
        "ge_greater": 1 if cmp_c >= cmp_a else 0,
        "in_found": in_found,
        "in_missing": in_missing,
        "not_in_found": not_in_found,
        "not_in_missing": not_in_missing,
        "in_first": in_first,
        "in_last": in_last,
        "concat_len": len(op_c),
        "concat_0": op_c[0],
        "concat_1": op_c[1],
        "concat_2": op_c[2],
        "concat_3": op_c[3],
        "concat_4": op_c[4],
        "concat_5": op_c[5],
        "orig_a_len": len(op_a),
        "orig_b_len": len(op_b),
        "list_iadd": iadd_c
    };
}

na {
    def list_na() -> dict[str, any] {
        # basic methods
        a: list[int] = [10, 20, 30];
        a.append(40);
        append_len: int = len(a);
        append_last: int = a[3];

        b: list[int] = [10, 20, 30];
        get_val: int = b[1];
        b[1] = 99;
        set_val: int = b[1];

        c: list[int] = [];
        c.append(1);
        c.append(2);
        c.append(3);
        c.append(4);
        c.append(5);
        multi_len: int = len(c);

        d: list[int] = [10, 20, 30];
        pop_val: int = d.pop();
        pop_len: int = len(d);

        e: list[int] = [10, 20, 30];
        e.clear();
        clear_len: int = len(e);

        f: list[int] = [10, 20, 30, 20];
        index_found: int = f.index(20);

        g: list[int] = [10, 20, 30];
        g.reverse();
        rev_first: int = g[0];
        rev_last: int = g[2];

        h: list[int] = [10, 20, 30];
        h2: list[int] = h.copy();
        copy_len: int = len(h2);
        copy_first: int = h2[0];

        # sort
        nums: list[int] = [5, 3, 8, 1, 4, 2, 7, 6];
        nums.sort();

        # remove
        rm_a: list[int] = [1, 2, 3, 2, 1];
        rm_a.remove(2);
        rm_b: list[int] = [10, 20, 30];
        rm_b.remove(10);
        rm_c: list[int] = [5, 10, 15];
        rm_c.remove(15);

        # extend and insert
        ext_a: list[int] = [10, 20];
        ext_b: list[int] = [30, 40, 50];
        ext_a.extend(ext_b);
        ext_len: int = len(ext_a);
        ext_last: int = ext_a[4];
        ins_c: list[int] = [20, 30];
        ins_c.insert(0, 10);
        ins_start_first: int = ins_c[0];
        ins_start_second: int = ins_c[1];
        ins_start_len: int = len(ins_c);
        ins_d: list[int] = [10, 30];
        ins_d.insert(1, 20);
        ins_mid_first: int = ins_d[0];
        ins_mid_second: int = ins_d[1];
        ins_mid_third: int = ins_d[2];
        ins_mid_len: int = len(ins_d);
        ins_e: list[int] = [10, 20];
        ins_e.insert(2, 30);
        ins_end_last: int = ins_e[2];
        ins_end_len: int = len(ins_e);

        # multiplication
        mul_a: list[int] = [1, 2, 3];
        r3: list[int] = mul_a * 3;
        r1: list[int] = mul_a * 1;
        r0: list[int] = mul_a * 0;
        r_rev: list[int] = 2 * mul_a;

        # comparisons
        cmp_a: list[int] = [1, 2, 3];
        cmp_b: list[int] = [1, 2, 3];
        cmp_c: list[int] = [1, 2, 4];
        cmp_d: list[int] = [1, 2];
        cmp_e: list[int] = [1, 2, 3, 4];

        # operators
        op_nums: list[int] = [10, 20, 30, 40, 50];
        in_found: int = 1 if 30 in op_nums else 0;
        in_missing: int = 1 if 99 in op_nums else 0;
        not_in_found: int = 1 if 30 not in op_nums else 0;
        not_in_missing: int = 1 if 99 not in op_nums else 0;
        in_first: int = 1 if 10 in op_nums else 0;
        in_last: int = 1 if 50 in op_nums else 0;
        op_a: list[int] = [1, 2, 3];
        op_b: list[int] = [4, 5, 6];
        op_c: list[int] = op_a + op_b;

        # iadd
        grow: list[int] = [1, 2];
        grow += [3, 4];
        grow_len: int = len(grow);
        grow_last: int = grow[len(grow) - 1];

        # list slicing
        sl_src: list[int] = [10, 20, 30, 40, 50];
        sl_mid: list[int] = sl_src[1:4];
        sl_to: list[int] = sl_src[:2];

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
            "copy_first": copy_first,
            "s0": nums[0], "s1": nums[1], "s2": nums[2], "s3": nums[3],
            "s4": nums[4], "s5": nums[5], "s6": nums[6], "s7": nums[7],
            "slen": len(nums),
            "remove_mid_len": len(rm_a),
            "remove_mid_first": rm_a[0],
            "remove_mid_second": rm_a[1],
            "remove_mid_third": rm_a[2],
            "remove_mid_fourth": rm_a[3],
            "remove_front_len": len(rm_b),
            "remove_front_first": rm_b[0],
            "remove_front_second": rm_b[1],
            "remove_end_len": len(rm_c),
            "remove_end_first": rm_c[0],
            "remove_end_second": rm_c[1],
            "ext_len": ext_len,
            "ext_first": ext_a[0],
            "ext_third": ext_a[2],
            "ext_last": ext_last,
            "ins_start_first": ins_start_first,
            "ins_start_second": ins_start_second,
            "ins_start_len": ins_start_len,
            "ins_mid_first": ins_mid_first,
            "ins_mid_second": ins_mid_second,
            "ins_mid_third": ins_mid_third,
            "ins_mid_len": ins_mid_len,
            "ins_end_last": ins_end_last,
            "ins_end_len": ins_end_len,
            "r3_len": len(r3),
            "r3_0": r3[0], "r3_1": r3[1], "r3_2": r3[2],
            "r3_3": r3[3], "r3_4": r3[4], "r3_5": r3[5],
            "r3_6": r3[6], "r3_7": r3[7], "r3_8": r3[8],
            "r1_len": len(r1), "r1_0": r1[0],
            "r0_len": len(r0),
            "r_rev_len": len(r_rev),
            "r_rev_0": r_rev[0], "r_rev_3": r_rev[3],
            "orig_len": len(mul_a),
            "eq_same": 1 if cmp_a == cmp_b else 0,
            "eq_diff": 1 if cmp_a == cmp_c else 0,
            "eq_shorter": 1 if cmp_a == cmp_d else 0,
            "ne_same": 1 if cmp_a != cmp_b else 0,
            "ne_diff": 1 if cmp_a != cmp_c else 0,
            "lt_less": 1 if cmp_a < cmp_c else 0,
            "lt_greater": 1 if cmp_c < cmp_a else 0,
            "lt_equal": 1 if cmp_a < cmp_b else 0,
            "lt_shorter": 1 if cmp_d < cmp_a else 0,
            "lt_longer": 1 if cmp_a < cmp_e else 0,
            "gt_less": 1 if cmp_a > cmp_c else 0,
            "gt_greater": 1 if cmp_c > cmp_a else 0,
            "gt_equal": 1 if cmp_a > cmp_b else 0,
            "le_less": 1 if cmp_a <= cmp_c else 0,
            "le_equal": 1 if cmp_a <= cmp_b else 0,
            "le_greater": 1 if cmp_c <= cmp_a else 0,
            "ge_less": 1 if cmp_a >= cmp_c else 0,
            "ge_equal": 1 if cmp_a >= cmp_b else 0,
            "ge_greater": 1 if cmp_c >= cmp_a else 0,
            "in_found": in_found,
            "in_missing": in_missing,
            "not_in_found": not_in_found,
            "not_in_missing": not_in_missing,
            "in_first": in_first,
            "in_last": in_last,
            "concat_len": len(op_c),
            "concat_0": op_c[0],
            "concat_1": op_c[1],
            "concat_2": op_c[2],
            "concat_3": op_c[3],
            "concat_4": op_c[4],
            "concat_5": op_c[5],
            "orig_a_len": len(op_a),
            "orig_b_len": len(op_b),
            "iadd_len": grow_len,
            "iadd_last": grow_last,
            "sl_mid_len": len(sl_mid),
            "sl_mid_0": sl_mid[0], "sl_mid_1": sl_mid[1], "sl_mid_2": sl_mid[2],
            "sl_to_len": len(sl_to),
            "sl_to_0": sl_to[0], "sl_to_1": sl_to[1]
        };
    }
}
