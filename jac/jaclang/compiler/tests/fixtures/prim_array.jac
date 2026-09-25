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
  - bytes/array constructor initializers (na: use ``frombytes`` /
    ``extend_array`` -- the ctor takes ``list[any]``),
  - ``buffer_info()[0]`` is a live address on BOTH lanes and differs across
    backends (raw addresses), so only ``[1]`` (the item count) is compared,
  - 'u'/'w' typecodes, slicing, ``del``, and ``tobuffer``.

ES/JS opts out (``array_cl`` returns an empty dict).
"""

import array;


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
    a = array.array("i", [10, 20, 30]);
    a.append(40);
    a.extend([50, 60]);
    a.insert(0, 5);
    a2 = array.array("i");
    a2.frombytes(b"\x01\x00\x00\x00\x02\x00\x00\x00");
    f = array.array("d", [1.5, 2.5]);
    h = array.array("h", [1, 2]);
    h.byteswap();
    b = array.array("b", [1, 2, 3]);
    b.reverse();
    q = array.array("q", [1000000000000]);
    B = array.array("B", [200, 255]);
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
        "pop_last": popped,
        "pop_0": popped0,
        "len_after_pop": a.__len__(),
        "index_20": a.index(20),
        "count_20": a.count(20),
        "bi_len": bi[1],
        "add_len": a.__add__(array.array("i", [7, 8])).__len__(),
        "mul_len": b.__mul__(2).__len__(),
        "mul_g4": b.__mul__(2).__getitem__(4),
        "eq_same": 1 if a.__eq__(array.array("i", a.tolist())) else 0,
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
        array.array("i").pop();
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
        array.array("z");
        r["err_tc"] = "noraise";
    } except ValueError as e {
        r["err_tc"] = str(e);
    }
    try {
        array.array("h", [65535]);
        r["err_over"] = "noraise";
    } except OverflowError as e {
        r["err_over"] = str(e);
    }
    try {
        array.array("i", [1.5]);
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
    ai = array.array("i", [1, 2, 3]);
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
    fb = array.array("b", [-1]);
    fu = array.array("B", [255]);
    r["eq_signed_unsigned"] = 1 if fb.__eq__(fu) else 0;
    r["ne_signed_unsigned"] = 1 if fb.__ne__(fu) else 0;
    fi = array.array("i", [1]);
    ff1 = array.array("f", [1.0]);
    ff2 = array.array("f", [2.0]);
    nan = float("nan");
    fn = array.array("f", [nan]);
    r["eq_int_float"] = 1 if fi.__eq__(ff1) else 0;
    r["eq_int_float_diff"] = 1 if fi.__eq__(ff2) else 0;
    r["eq_nan"] = 1 if fn.__eq__(fn) else 0;
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
    a = array.array("i", [10, 20, 30]);
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
    f = array.array("d", [1.5, 2.5]);
    h = array.array("h", [1, 2]);
    q = array.array("q", [1000000000000]);
    B = array.array("B", [200, 255]);
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
    h.byteswap();
    r["h_swapped_0"] = h.tolist()[0];
    r["h_swapped_1"] = h.tolist()[1];
}


def _ops_na(r: dict[str, any]) {
    # Same post-pop contents as the sv lane's `a`: [10, 20, 30, 40, 50].
    a = array.array("i", [10, 20, 30]);
    a.append(40);
    a.extend([50, 60]);
    a.insert(0, 5);
    a.pop();
    a.pop(0);
    a2 = array.array("i");
    a2.frombytes(b"\x01\x00\x00\x00\x02\x00\x00\x00");
    b = array.array("b", [1, 2, 3]);
    b.reverse();
    r["fb_list_0"] = a2.tolist()[0];
    r["fb_list_1"] = a2.tolist()[1];
    r["b_rev_0"] = b.tolist()[0];
    r["b_rev_2"] = b.tolist()[2];
    r["add_len"] = a.__add__(array.array("i", [7, 8])).__len__();
    r["mul_len"] = b.__mul__(2).__len__();
    r["mul_g4"] = b.__mul__(2).__getitem__(4);
    same = array.array("i");
    same.extend(a.tolist());
    r["eq_same"] = 1 if a.__eq__(same) else 0;
    r["eq_diff"] = 1 if a.__eq__(b) else 0;
}


def _err_na(r: dict[str, any]) {
    a = array.array("i", [10, 20, 30]);
    try {
        a.index(99);
        r["err_index"] = "noraise";
    } except ValueError as e {
        r["err_index"] = str(e);
    }
    try {
        array.array("i").pop();
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
        array.array("z");
        r["err_tc"] = "noraise";
    } except ValueError as e {
        r["err_tc"] = str(e);
    }
    try {
        array.array("h", [65535]);
        r["err_over"] = "noraise";
    } except OverflowError as e {
        r["err_over"] = str(e);
    }
    try {
        array.array("i", [1.5]);
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


def _eq_na(r: dict[str, any]) {
    # Value-based cross-typecode equality (each side read via its own
    # typecode; NaN never equals itself).
    fb = array.array("b", [-1]);
    fu = array.array("B", [255]);
    r["eq_signed_unsigned"] = 1 if fb.__eq__(fu) else 0;
    r["ne_signed_unsigned"] = 1 if fb.__ne__(fu) else 0;
    fi = array.array("i", [1]);
    ff1 = array.array("f", [1.0]);
    ff2 = array.array("f", [2.0]);
    nan = float("nan");
    fn = array.array("f", [nan]);
    r["eq_int_float"] = 1 if fi.__eq__(ff1) else 0;
    r["eq_int_float_diff"] = 1 if fi.__eq__(ff2) else 0;
    r["eq_nan"] = 1 if fn.__eq__(fn) else 0;
}


def array_na -> dict[str, any] {
    r: dict[str, any] = {};
    _core_na(r);
    _widths_na(r);
    _ops_na(r);
    _err_na(r);
    _eq_na(r);
    return r;
}
