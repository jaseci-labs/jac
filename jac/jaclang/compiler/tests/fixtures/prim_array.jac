"""Bundled native ``array`` cross-backend equivalence fixture.

The SAME ``import array`` binds CPython's ``array`` module on the sv (Python)
backend and the bundled ``na_stdlib/array.jac`` Mechanism-B module on the na
(native LLVM) backend. This fixture pins the two congruent.

Byte-level results are compared via ``_digest`` of ``tobytes()`` output plus
``__len__`` -- raw ``bytes`` cannot be marshalled across the sv/na boundary.
Element results go through ``tolist()``/``__getitem__`` which produce plain
ints/floats on both lanes.

Dunder divergence: the na pathway does not dispatch operator syntax to
dunder methods on objs, so BOTH lanes call them explicitly
(``a.__getitem__(0)``, ``a.__setitem__``, ``a.__len__``, ``a.__add__``,
``a.__mul__``, ``a.__contains__``, ``a.__eq__``) -- explicit calls are legal
on CPython too, keeping the two lanes source-identical where possible.

Documented divergences NOT exercised here (they would spuriously fail):
  - ``buffer_info()[0]`` is a live address on BOTH lanes and differs across
    backends (raw addresses), so only ``[1]`` (the item count) is compared,
  - ``fromfile``/``tofile`` take a file-like ``any`` receiver whose method
    calls na cannot lower; they stay Python-only on the native lane,
  - 'u'/'w' typecodes, slicing, ``del``, and ``tobuffer``,
  - constructor/``extend`` iterables the ``any`` boundary cannot carry:
    ``tuple`` and ``range`` have no ``any`` box, ``dict`` element views are
    unsupported, and generators/``memoryview`` have no runtime shape the
    native lane can detect -- the py lane pins these under keys waived by
    the equivalence row's ``allow_missing``.

ES/JS opts out (``array_cl`` returns an empty dict).
"""

import from array { array }


def _digest(data: bytes) -> int {
    acc: int = 2166136261;
    n: int = len(data);
    i: int = 0;
    while i < n {
        acc = (acc * 131 + data[i]) % 2147483647;
        i += 1;
    }
    return acc;
}


def array_py -> dict[any, any] {
    a = array("i", [10, 20, 30]);
    a.append(40);
    a.extend([50, 60]);
    a.insert(0, 5);
    a2 = array("i");
    a2.frombytes(b"\x01\x00\x00\x00\x02\x00\x00\x00");
    f = array("d", [1.5, 2.5]);
    h = array("h", [1, 2]);
    h.byteswap();
    b = array("b", [1, 2, 3]);
    b.reverse();
    q = array("q", [1000000000000]);
    B = array("B", [200, 255]);
    popped = a.pop();
    popped0 = a.pop(0);
    bi = a.buffer_info();
    r: dict[str, any] = {
        "isize_i": a.itemsize,
        "isize_d": f.itemsize,
        "isize_h": h.itemsize,
        "isize_q": q.itemsize,
        "isize_B": B.itemsize,
        "len_a": a.__len__(),
        "g0": a.__getitem__(0),
        "g_last": a.__getitem__(a.__len__() - 1),
        "contains_20": 1 if a.__contains__(20) else 0,
        "contains_99": 1 if a.__contains__(99) else 0,
        "bytes_digest": _digest(a.tobytes()),
        "fb_list_0": a2.tolist()[0],
        "fb_list_1": a2.tolist()[1],
        "f_g0": f.__getitem__(0),
        "f_g1": f.__getitem__(1),
        "f_digest": _digest(f.tobytes()),
        "h_swapped_0": h.tolist()[0],
        "h_swapped_1": h.tolist()[1],
        "b_rev_0": b.tolist()[0],
        "b_rev_2": b.tolist()[2],
        "q_g0": q.__getitem__(0),
        "q_digest": _digest(q.tobytes()),
        "B_g1": B.__getitem__(1),
        "H_max": array("H", [65535]).__getitem__(0),
        "I_max": array("I", [4294967295]).__getitem__(0),
        "pop_last": popped,
        "pop_0": popped0,
        "len_after_pop": a.__len__(),
        "index_20": a.index(20),
        "count_20": a.count(20),
        "bi_len": bi[1],
        "add_len": a.__add__(array("i", [7, 8])).__len__(),
        "mul_len": b.__mul__(2).__len__(),
        "mul_g4": b.__mul__(2).__getitem__(4),
        "eq_same": 1 if a.__eq__(array("i", a.tolist())) else 0,
        "eq_diff": 1 if a.__eq__(b) else 0
    };
    a.remove(20);
    r["len_after_remove"] = a.__len__();
    a.__setitem__(0, 111);
    r["after_setitem"] = a.__getitem__(0);
    try {
        a.index(99);
        r["err_index"] = "noraise";
    } except ValueError as e {
        r["err_index"] = str(e);
    }
    try {
        array("i").pop();
        r["err_pop"] = "noraise";
    } except IndexError as e {
        r["err_pop"] = str(e);
    }
    try {
        a.pop(99);
        r["err_popoob"] = "noraise";
    } except IndexError as e {
        r["err_popoob"] = str(e);
    }
    try {
        a.remove(99);
        r["err_remove"] = "noraise";
    } except ValueError as e {
        r["err_remove"] = str(e);
    }
    try {
        array("z");
        r["err_tc"] = "noraise";
    } except ValueError as e {
        r["err_tc"] = str(e);
    }
    try {
        array("h", [65535]);
        r["err_over"] = "noraise";
    } except OverflowError as e {
        r["err_over"] = str(e);
    }
    try {
        array("i", [1.5]);
        r["err_float"] = "noraise";
    } except TypeError as e {
        r["err_float"] = str(e);
    }
    try {
        a.__getitem__(99);
        r["err_getitem"] = "noraise";
    } except IndexError as e {
        r["err_getitem"] = str(e);
    }
    # negative/absent stop slice semantics on index
    ai = array("i", [1, 2, 3]);
    try {
        ai.index(3, 0, -1);
        r["err_index_stop"] = "noraise";
    } except ValueError as e {
        r["err_index_stop"] = str(e);
    }
    try {
        ai.index(1, 0, -100);
        r["err_index_tooneg"] = "noraise";
    } except ValueError as e {
        r["err_index_tooneg"] = str(e);
    }
    r["index_start_neg"] = ai.index(1, -100, 2);
    # value-based cross-typecode equality (each side read via its own
    # typecode; NaN never equals itself)
    fb = array("b", [-1]);
    fu = array("B", [255]);
    r["eq_signed_unsigned"] = 1 if fb.__eq__(fu) else 0;
    r["ne_signed_unsigned"] = 1 if fb.__ne__(fu) else 0;
    fi = array("i", [1]);
    ff1 = array("f", [1.0]);
    ff2 = array("f", [2.0]);
    nan = float("nan");
    fn = array("f", [nan]);
    r["eq_int_float"] = 1 if fi.__eq__(ff1) else 0;
    r["eq_int_float_diff"] = 1 if fi.__eq__(ff2) else 0;
    r["eq_nan"] = 1 if fn.__eq__(fn) else 0;
    # Non-numeric values must raise TypeError on write paths (never store a
    # reinterpreted payload), and search compares by value across int/float.
    # Bad operands go through `any` locals so the sv lane's typeshed
    # `array[int]` signature does not reject them at compile time.
    ci = array("i", [1, 2, 3]);
    bad_str: any = "x";
    bad_none: any = None;
    bad_list: any = [7];
    bad_seq: list[any] = [];
    bad_seq.append("x");
    two_point_oh: any = 2.0;
    two: any = 2;
    try {
        ci.append(bad_str);
        r["err_append_str"] = "noraise";
    } except TypeError as e {
        r["err_append_str"] = str(e);
    }
    try {
        ci.append(bad_none);
        r["err_append_none"] = "noraise";
    } except TypeError as e {
        r["err_append_none"] = str(e);
    }
    try {
        ci.append(bad_list);
        r["err_append_list"] = "noraise";
    } except TypeError as e {
        r["err_append_list"] = str(e);
    }
    try {
        array("q").append(bad_str);
        r["err_append_q_str"] = "noraise";
    } except TypeError as e {
        r["err_append_q_str"] = str(e);
    }
    try {
        array("d").append(bad_str);
        r["err_d_append_str"] = "noraise";
    } except TypeError as e {
        r["err_d_append_str"] = str(e);
    }
    try {
        array("d").append(bad_none);
        r["err_d_append_none"] = "noraise";
    } except TypeError as e {
        r["err_d_append_none"] = str(e);
    }
    r["len_after_bad"] = ci.__len__();
    r["index_float_eq"] = ci.index(two_point_oh);
    r["count_float_eq"] = ci.count(two_point_oh);
    r["contains_float_eq"] = 1 if ci.__contains__(two_point_oh) else 0;
    r["d_index_int"] = array("d", [2.0]).index(two);
    try {
        ci.index(bad_str);
        r["err_index_str"] = "noraise";
    } except ValueError as e {
        r["err_index_str"] = str(e);
    }
    try {
        ci.remove(bad_str);
        r["err_remove_str"] = "noraise";
    } except ValueError as e {
        r["err_remove_str"] = str(e);
    }
    r["count_str"] = ci.count(bad_str);
    r["contains_str"] = 1 if ci.__contains__(bad_str) else 0;
    try {
        ci.__setitem__(0, bad_str);
        r["err_setitem_str"] = "noraise";
    } except TypeError as e {
        r["err_setitem_str"] = str(e);
    }
    try {
        ci.insert(0, bad_str);
        r["err_insert_str"] = "noraise";
    } except TypeError as e {
        r["err_insert_str"] = str(e);
    }
    try {
        ci.extend(bad_seq);
        r["err_extend_str"] = "noraise";
    } except TypeError as e {
        r["err_extend_str"] = str(e);
    }
    # extend/ctor accept arrays, bytes, bytearray, and lists: extending with
    # an array requires the same typecode (CPython's fast path), while the
    # constructor iterates any array element-wise. bytes/bytearray extend
    # element-wise, but constructor bytes/bytearray initializers decode raw.
    # fromfile/tofile take a file-like `any` receiver whose method calls na
    # cannot lower, so they stay Python-only and are not exercised here.
    ea = array("i", [1, 2]);
    ea.extend(array("i", [3, 4]));
    r["ext_arr_g3"] = ea.__getitem__(3);
    ea.extend(b"\x05\x00\x00\x00");
    r["ext_bytes_len"] = ea.__len__();
    ea.extend(bytearray(b"\x06\x00\x00\x00"));
    r["ext_ba_len"] = ea.__len__();
    try {
        array("d").extend(array("i", [8, 9]));
        r["ext_diffkind"] = "noraise";
    } except TypeError as e {
        r["ext_diffkind"] = str(e);
    }
    cb = array("i", b"\x07\x00\x00\x00");
    r["ctor_bytes"] = cb.__getitem__(0);
    cba = array("i", bytearray(b"\x08\x00\x00\x00"));
    r["ctor_ba"] = cba.__getitem__(0);
    ca = array("d", array("i", [8, 9]));
    r["ctor_arr_g1"] = ca.__getitem__(1);
    # extend/ctor also consume sets and frozensets element-wise (single
    # elements keep set order deterministic), str iterates characters and
    # fails element coercion, and non-iterables get CPython's
    # '<type>' object is not iterable TypeError.
    es = array("i");
    es.extend({9});
    r["ext_set_g0"] = es.__getitem__(0);
    ef = array("i");
    ef.extend(frozenset([4]));
    r["ext_frozenset_g0"] = ef.__getitem__(0);
    ess = array("i");
    ess.extend("");
    r["ext_empty_str_len"] = ess.__len__();
    bad_int: any = 5;
    try {
        array("i").extend(bad_int);
        r["err_extend_int"] = "noraise";
    } except TypeError as e {
        r["err_extend_int"] = str(e);
    }
    try {
        array("i").extend("ab");
        r["err_extend_strarg"] = "noraise";
    } except TypeError as e {
        r["err_extend_strarg"] = str(e);
    }
    try {
        array("i", "ab");
        r["err_ctor_str"] = "noraise";
    } except TypeError as e {
        r["err_ctor_str"] = str(e);
    }
    cs = array("i", {8});
    r["ctor_set_g0"] = cs.__getitem__(0);
    cf = array("i", frozenset([6]));
    r["ctor_frozenset_g0"] = cf.__getitem__(0);
    # Python-only on the native lane (waived in the equivalence row):
    # tuple/range cannot cross the `any` boundary, dict element views are
    # unsupported, and generators have no detectable runtime shape.
    ct = array("i", (11, 22));
    r["ctor_tuple_g1"] = ct.__getitem__(1);
    cr = array("i", range(3));
    r["ctor_range_g2"] = cr.__getitem__(2);
    cd = array("i", {1: "a", 2: "b"});
    r["ctor_dict_g1"] = cd.__getitem__(1);
    et = array("i");
    et.extend((30, 40));
    r["ext_tuple_g1"] = et.__getitem__(1);
    return r;
}


def array_cl -> dict[any, any] {
    return {};
}


def _digest_na(data: bytes) -> int {
    acc: int = 2166136261;
    n: int = len(data);
    i: int = 0;
    while i < n {
        acc = (acc * 131 + data[i]) % 2147483647;
        i += 1;
    }
    return acc;
}


def _core_na(r: dict[str, any]) {
    a = array("i", [10, 20, 30]);
    a.append(40);
    a.extend([50, 60]);
    a.insert(0, 5);
    popped = a.pop();
    popped0 = a.pop(0);
    # All entries below see the post-pop `a` ([10, 20, 30, 40, 50]), matching
    # the sv lane's ordering.
    r["isize_i"] = a.itemsize;
    r["len_a"] = a.__len__();
    r["g0"] = a.__getitem__(0);
    r["g_last"] = a.__getitem__(a.__len__() - 1);
    r["contains_20"] = 1 if a.__contains__(20) else 0;
    r["contains_99"] = 1 if a.__contains__(99) else 0;
    r["bytes_digest"] = _digest_na(a.tobytes());
    r["pop_last"] = popped;
    r["pop_0"] = popped0;
    r["len_after_pop"] = a.__len__();
    r["index_20"] = a.index(20);
    r["count_20"] = a.count(20);
    r["bi_len"] = a.buffer_info()[1];
    a.remove(20);
    r["len_after_remove"] = a.__len__();
    a.__setitem__(0, 111);
    r["after_setitem"] = a.__getitem__(0);
}


def _widths_na(r: dict[str, any]) {
    f = array("d", [1.5, 2.5]);
    h = array("h", [1, 2]);
    q = array("q", [1000000000000]);
    B = array("B", [200, 255]);
    r["isize_d"] = f.itemsize;
    r["isize_h"] = h.itemsize;
    r["isize_q"] = q.itemsize;
    r["isize_B"] = B.itemsize;
    r["f_g0"] = f.__getitem__(0);
    r["f_g1"] = f.__getitem__(1);
    r["f_digest"] = _digest_na(f.tobytes());
    r["q_g0"] = q.__getitem__(0);
    r["q_digest"] = _digest_na(q.tobytes());
    r["B_g1"] = B.__getitem__(1);
    r["H_max"] = array("H", [65535]).__getitem__(0);
    r["I_max"] = array("I", [4294967295]).__getitem__(0);
    h.byteswap();
    r["h_swapped_0"] = h.tolist()[0];
    r["h_swapped_1"] = h.tolist()[1];
}


def _ops_na(r: dict[str, any]) {
    # Same post-pop contents as the sv lane's `a`: [10, 20, 30, 40, 50].
    a = array("i", [10, 20, 30]);
    a.append(40);
    a.extend([50, 60]);
    a.insert(0, 5);
    a.pop();
    a.pop(0);
    a2 = array("i");
    a2.frombytes(b"\x01\x00\x00\x00\x02\x00\x00\x00");
    b = array("b", [1, 2, 3]);
    b.reverse();
    r["fb_list_0"] = a2.tolist()[0];
    r["fb_list_1"] = a2.tolist()[1];
    r["b_rev_0"] = b.tolist()[0];
    r["b_rev_2"] = b.tolist()[2];
    r["add_len"] = a.__add__(array("i", [7, 8])).__len__();
    r["mul_len"] = b.__mul__(2).__len__();
    r["mul_g4"] = b.__mul__(2).__getitem__(4);
    same = array("i");
    same.extend(a.tolist());
    r["eq_same"] = 1 if a.__eq__(same) else 0;
    r["eq_diff"] = 1 if a.__eq__(b) else 0;
}


def _err_na(r: dict[str, any]) {
    a = array("i", [10, 20, 30]);
    try {
        a.index(99);
        r["err_index"] = "noraise";
    } except ValueError as e {
        r["err_index"] = str(e);
    }
    try {
        array("i").pop();
        r["err_pop"] = "noraise";
    } except IndexError as e {
        r["err_pop"] = str(e);
    }
    try {
        a.pop(99);
        r["err_popoob"] = "noraise";
    } except IndexError as e {
        r["err_popoob"] = str(e);
    }
    try {
        a.remove(99);
        r["err_remove"] = "noraise";
    } except ValueError as e {
        r["err_remove"] = str(e);
    }
    try {
        array("z");
        r["err_tc"] = "noraise";
    } except ValueError as e {
        r["err_tc"] = str(e);
    }
    try {
        array("h", [65535]);
        r["err_over"] = "noraise";
    } except OverflowError as e {
        r["err_over"] = str(e);
    }
    try {
        array("i", [1.5]);
        r["err_float"] = "noraise";
    } except TypeError as e {
        r["err_float"] = str(e);
    }
    try {
        a.__getitem__(99);
        r["err_getitem"] = "noraise";
    } except IndexError as e {
        r["err_getitem"] = str(e);
    }
    try {
        a.index(30, 0, -1);
        r["err_index_stop"] = "noraise";
    } except ValueError as e {
        r["err_index_stop"] = str(e);
    }
    try {
        a.index(10, 0, -100);
        r["err_index_tooneg"] = "noraise";
    } except ValueError as e {
        r["err_index_tooneg"] = str(e);
    }
    r["index_start_neg"] = a.index(10, -100, 2);
}


def _coerce_na(r: dict[str, any]) {
    # Mirrors the sv lane's coercion/search probes exactly.
    ci = array("i", [1, 2, 3]);
    bad_str: any = "x";
    bad_none: any = None;
    bad_list: any = [7];
    bad_seq: list[any] = [];
    bad_seq.append("x");
    two_point_oh: any = 2.0;
    two: any = 2;
    try {
        ci.append(bad_str);
        r["err_append_str"] = "noraise";
    } except TypeError as e {
        r["err_append_str"] = str(e);
    }
    try {
        ci.append(bad_none);
        r["err_append_none"] = "noraise";
    } except TypeError as e {
        r["err_append_none"] = str(e);
    }
    try {
        ci.append(bad_list);
        r["err_append_list"] = "noraise";
    } except TypeError as e {
        r["err_append_list"] = str(e);
    }
    try {
        array("q").append(bad_str);
        r["err_append_q_str"] = "noraise";
    } except TypeError as e {
        r["err_append_q_str"] = str(e);
    }
    try {
        array("d").append(bad_str);
        r["err_d_append_str"] = "noraise";
    } except TypeError as e {
        r["err_d_append_str"] = str(e);
    }
    try {
        array("d").append(bad_none);
        r["err_d_append_none"] = "noraise";
    } except TypeError as e {
        r["err_d_append_none"] = str(e);
    }
    r["len_after_bad"] = ci.__len__();
    r["index_float_eq"] = ci.index(two_point_oh);
    r["count_float_eq"] = ci.count(two_point_oh);
    r["contains_float_eq"] = 1 if ci.__contains__(two_point_oh) else 0;
    r["d_index_int"] = array("d", [2.0]).index(two);
    try {
        ci.index(bad_str);
        r["err_index_str"] = "noraise";
    } except ValueError as e {
        r["err_index_str"] = str(e);
    }
    try {
        ci.remove(bad_str);
        r["err_remove_str"] = "noraise";
    } except ValueError as e {
        r["err_remove_str"] = str(e);
    }
    r["count_str"] = ci.count(bad_str);
    r["contains_str"] = 1 if ci.__contains__(bad_str) else 0;
    try {
        ci.__setitem__(0, bad_str);
        r["err_setitem_str"] = "noraise";
    } except TypeError as e {
        r["err_setitem_str"] = str(e);
    }
    try {
        ci.insert(0, bad_str);
        r["err_insert_str"] = "noraise";
    } except TypeError as e {
        r["err_insert_str"] = str(e);
    }
    try {
        ci.extend(bad_seq);
        r["err_extend_str"] = "noraise";
    } except TypeError as e {
        r["err_extend_str"] = str(e);
    }
}


def _eq_na(r: dict[str, any]) {
    # Value-based cross-typecode equality (each side read via its own
    # typecode; NaN never equals itself).
    fb = array("b", [-1]);
    fu = array("B", [255]);
    r["eq_signed_unsigned"] = 1 if fb.__eq__(fu) else 0;
    r["ne_signed_unsigned"] = 1 if fb.__ne__(fu) else 0;
    fi = array("i", [1]);
    ff1 = array("f", [1.0]);
    ff2 = array("f", [2.0]);
    nan = float("nan");
    fn = array("f", [nan]);
    r["eq_int_float"] = 1 if fi.__eq__(ff1) else 0;
    r["eq_int_float_diff"] = 1 if fi.__eq__(ff2) else 0;
    r["eq_nan"] = 1 if fn.__eq__(fn) else 0;
}


def _extend_na(r: dict[str, any]) {
    # Mirrors the sv lane's extend/ctor probes exactly.
    ea = array("i", [1, 2]);
    ea.extend(array("i", [3, 4]));
    r["ext_arr_g3"] = ea.__getitem__(3);
    ea.extend(b"\x05\x00\x00\x00");
    r["ext_bytes_len"] = ea.__len__();
    ea.extend(bytearray(b"\x06\x00\x00\x00"));
    r["ext_ba_len"] = ea.__len__();
    try {
        array("d").extend(array("i", [8, 9]));
        r["ext_diffkind"] = "noraise";
    } except TypeError as e {
        r["ext_diffkind"] = str(e);
    }
    cb = array("i", b"\x07\x00\x00\x00");
    r["ctor_bytes"] = cb.__getitem__(0);
    cba = array("i", bytearray(b"\x08\x00\x00\x00"));
    r["ctor_ba"] = cba.__getitem__(0);
    ca = array("d", array("i", [8, 9]));
    r["ctor_arr_g1"] = ca.__getitem__(1);
    # Mirrors the sv lane's iterable probes: sets/frozensets go element-wise,
    # str iterates characters into the element-coercion TypeError, and
    # non-iterables get CPython's '<type>' object is not iterable.
    es = array("i");
    es.extend({9});
    r["ext_set_g0"] = es.__getitem__(0);
    ef = array("i");
    ef.extend(frozenset([4]));
    r["ext_frozenset_g0"] = ef.__getitem__(0);
    ess = array("i");
    ess.extend("");
    r["ext_empty_str_len"] = ess.__len__();
    bad_int: any = 5;
    try {
        array("i").extend(bad_int);
        r["err_extend_int"] = "noraise";
    } except TypeError as e {
        r["err_extend_int"] = str(e);
    }
    try {
        array("i").extend("ab");
        r["err_extend_strarg"] = "noraise";
    } except TypeError as e {
        r["err_extend_strarg"] = str(e);
    }
    try {
        array("i", "ab");
        r["err_ctor_str"] = "noraise";
    } except TypeError as e {
        r["err_ctor_str"] = str(e);
    }
    cs = array("i", {8});
    r["ctor_set_g0"] = cs.__getitem__(0);
    cf = array("i", frozenset([6]));
    r["ctor_frozenset_g0"] = cf.__getitem__(0);
}


def array_na -> dict[str, any] {
    r: dict[str, any] = {};
    _core_na(r);
    _widths_na(r);
    _ops_na(r);
    _err_na(r);
    _coerce_na(r);
    _eq_na(r);
    _extend_na(r);
    return r;
}
