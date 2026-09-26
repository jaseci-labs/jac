"""The compile-time evaluator's typed value model matches CPython value for value.

Compile-time results are written into generated code, so every operation the
evaluator re-implements over its own value model (arbitrary-precision ints,
float division and rounding, formatting, repr, hashing, container ordering
and equality, exception messages) must agree exactly with the host CPython.
These tests drive the typed operations and CPython over the same inputs and
compare the observable outcome: the repr of the result, or the exception type
and message.
"""
import builtins;
import math;
import random;
import from jaclang.compiler.types.ct_value {
    CT_NONE,
    CtBool,
    CtBytes,
    CtDict,
    CtError,
    CtFloat,
    CtInt,
    CtList,
    CtNone,
    CtRaise,
    CtSet,
    CtStr,
    CtTuple,
    CtValue,
    ct_eq,
    ct_repr,
    ct_str,
    dict_set,
    mk_bool,
    mk_bytes,
    mk_dict,
    mk_float,
    mk_int,
    mk_list,
    mk_set,
    mk_str,
    mk_tuple
}
import from jaclang.compiler.types.ct_ops {
    ct_binop,
    ct_compare,
    ct_getitem,
    ct_getslice,
    ct_hash,
    ct_unary,
    int_to_float
}
import from jaclang.compiler.types.ct_format {
    ct_binary,
    ct_format,
    ct_percent_format,
    ct_str_format
}
import from jaclang.compiler.types.ct_builtins { ct_call_math, ct_construct_builtin }
import from jaclang.compiler.types.ct_eval { CtEvaluator }
import from jaclang.compiler.driver.program { JacProgram }
import from jaclang.compiler.driver.compile_options { CompileOptions }

def py2ct(x: object) -> CtValue {
    if x is None {
        return CT_NONE;
    }
    if isinstance(x, bool) {
        return mk_bool(x);
    }
    if isinstance(x, int) {
        return mk_int(x);
    }
    if isinstance(x, float) {
        return mk_float(x);
    }
    if isinstance(x, str) {
        return mk_str(x);
    }
    if isinstance(x, bytes) {
        return mk_bytes(x);
    }
    if isinstance(x, list) {
        return mk_list([py2ct(i) for i in x]);
    }
    if isinstance(x, tuple) {
        return mk_tuple([py2ct(i) for i in x]);
    }
    if isinstance(x, dict) {
        d = mk_dict();
        for (k, v) in x.items() {
            dict_set(d, py2ct(k), py2ct(v));
        }
        return d;
    }
    if isinstance(x, frozenset) {
        return mk_set([py2ct(i) for i in x], frozen=True);
    }
    if isinstance(x, set) {
        return mk_set([py2ct(i) for i in x]);
    }
    raise TypeError(f"no comptime value for {x!r}");
}

def py_outcome(f: object) -> str {
    try {
        return "ok:" + repr(f());
    } except Exception as e {
        return f"{type(e).__name__}:{e}";
    }
}

def ct_outcome(f: object) -> str {
    try {
        got = f();
        if isinstance(got, CtValue) {
            return "ok:" + ct_repr(got);
        }
        return "ok:" + repr(got);
    } except CtRaise as e {
        return f"{e.exc.kind}:{ct_str(e.exc)}";
    }
}

def same(label: str, py_f: object, ct_f: object) {
    want = py_outcome(py_f);
    got = ct_outcome(ct_f);
    assert want == got , f"{label}: CPython {want!r} != comptime {got!r}";
}

def complex_pow(a: float, b: float) -> bool {
    if not a < 0 or abs(a) == math.inf or b != b or abs(b) == math.inf {
        return False;
    }
    return b != math.floor(b);
}

def sample_ints(rng: random.Random) -> list[int] {
    base = [
        0,
        1,
        -1,
        2,
        -2,
        7,
        -7,
        255,
        256,
        -256,
        2 ** 30 - 1,
        2 ** 30,
        2 ** 31,
        2 ** 53,
        2 ** 53 + 1,
        -(2 ** 53) - 1,
        2 ** 61 - 1,
        2 ** 61,
        2 ** 62 - 1,
        2 ** 62,
        -(2 ** 62),
        2 ** 63 - 1,
        -(2 ** 63),
        2 ** 64,
        2 ** 64 - 1,
        10 ** 20,
        -(10 ** 20),
        3 ** 100,
        -(7 ** 90),
        2 ** 1023,
        2 ** 1024,
        2 ** 1024 - 2 ** 970,
        2 ** 1024 - 2 ** 971
    ];
    for _ in range(40) {
        bits = rng.choice([8, 31, 62, 63, 64, 90, 200, 700]);
        v = rng.getrandbits(bits);
        base.append(-v if rng.random() < 0.5 else v);
    }
    return base;
}

test "int arithmetic matches CPython across the small/big boundary" {
    rng = random.Random(8675309);
    vals = sample_ints(rng);
    ops = ["+", "-", "*", "//", "%", "&", "|", "^", "/"];
    for a in vals {
        for b in rng.sample(vals, 12) {
            for op in ops {
                same(
                    f"{a} {op} {b}",
                    lambda { eval(f"a {op} b", {"a": a, "b": b}); },
                    lambda { ct_binop(op, mk_int(a), mk_int(b)); }
                );
            }
            same(
                f"{a} == {b}",
                lambda { a == b; },
                lambda { ct_compare("==", mk_int(a), mk_int(b)); }
            );
            same(
                f"{a} < {b}",
                lambda { a < b; },
                lambda { ct_compare("<", mk_int(a), mk_int(b)); }
            );
        }
        for sh in [0, 1, 5, 29, 30, 31, 61, 62, 63, 64, 100] {
            same(
                f"{a} << {sh}",
                lambda { a << sh; },
                lambda { ct_binop("<<", mk_int(a), mk_int(sh)); }
            );
            same(
                f"{a} >> {sh}",
                lambda { a >> sh; },
                lambda { ct_binop(">>", mk_int(a), mk_int(sh)); }
            );
        }
        same(f"-{a}", lambda { -a; }, lambda { ct_unary("-", mk_int(a)); });
        same(f"~{a}", lambda { ~a; }, lambda { ct_unary("~", mk_int(a)); });
        same(
            f"float({a})",
            lambda { float(a); },
            lambda { mk_float(int_to_float(mk_int(a))); }
        );
        same(f"hash({a})", lambda { hash(a); }, lambda { ct_hash(mk_int(a)); });
        same(f"str({a})", lambda { str(a); }, lambda { mk_str(ct_str(mk_int(a))); });
        for spec in [
            "x",
            "#X",
            "b",
            "o",
            "_x",
            ",",
            "_",
            "+",
            " d",
            "025,",
            "=+20_d",
            "^30",
            "#012_b",
            "e",
            ".3g"
        ] {
            same(
                f"format({a}, {spec!r})",
                lambda { format(a, spec); },
                lambda { mk_str(ct_format(mk_int(a), spec)); }
            );
        }
    }
    for base in [2, 3, -3, 10, -10, 2 ** 40 + 1] {
        for e in [0, 1, 2, 3, 17, 64, 65, 100, -1, -2] {
            same(
                f"{base} ** {e}",
                lambda { base ** e; },
                lambda { ct_binop("**", mk_int(base), mk_int(e)); }
            );
        }
    }
}

test "int and float comparisons are exact" {
    pairs = [
        (2 ** 53 + 1, 2.0 ** 53),
        (2 ** 53, 2.0 ** 53),
        (-(2 ** 63), -9.223372036854776e18),
        (10 ** 400, float("inf")),
        (-(10 ** 400), float("-inf")),
        (5, float("nan")),
        (3, 3.5),
        (4, 3.5),
        (-4, -3.5),
        (2 ** 1024, 1.7976931348623157e308),
        (1, 1.0),
        (True, 1.0)
    ];
    for (i, f) in pairs {
        for op in ["==", "!=", "<", "<=", ">", ">="] {
            same(
                f"{i} {op} {f}",
                lambda { eval(f"i {op} f", {"i": i, "f": f}); },
                lambda { ct_compare(op, py2ct(i), py2ct(f)); }
            );
            same(
                f"{f} {op} {i}",
                lambda { eval(f"f {op} i", {"i": i, "f": f}); },
                lambda { ct_compare(op, py2ct(f), py2ct(i)); }
            );
        }
    }
}

test "float division, modulo, powers, and rounding follow CPython" {
    vals = [
        0.0,
        -0.0,
        1.0,
        -1.0,
        2.5,
        -2.5,
        7.0,
        -7.5,
        1e300,
        -1e-300,
        0.1,
        3,
        -3,
        float("inf"),
        float("-inf"),
        float("nan")
    ];
    for a in vals {
        for b in vals {
            for op in ["/", "//", "%", "**", "+", "-", "*"] {
                if op == "**" and complex_pow(a, b) {
                    continue;
                }
                same(
                    f"{a!r} {op} {b!r}",
                    lambda { eval(f"a {op} b", {"a": a, "b": b}); },
                    lambda { ct_binop(op, py2ct(a), py2ct(b)); }
                );
            }
        }
    }
    for x in [
        0.5,
        1.5,
        2.5,
        -0.5,
        -1.5,
        2.675,
        1e300,
        123.456,
        -0.0,
        float("inf"),
        float("nan")
    ] {
        same(
            f"round({x!r})",
            lambda { round(x); },
            lambda { _call_builtin("round", [py2ct(x)]); }
        );
        same(
            f"round({x!r}, 2)",
            lambda { round(x, 2); },
            lambda { _call_builtin("round", [py2ct(x), mk_int(2)]); }
        );
        same(
            f"int({x!r})",
            lambda { int(x); },
            lambda { ct_construct_builtin("int", [py2ct(x)], {}); }
        );
        same(
            f"hash({x!r})",
            lambda { hash(x) if x == x else "nan"; },
            lambda { ct_hash(py2ct(x)) if x == x else "nan"; }
        );
    }
    for n in [15, 25, -15, 1250, 1350, 10 ** 30 + 5 * 10 ** 29] {
        for nd in [-1, -2, 0, 2] {
            same(
                f"round({n}, {nd})",
                lambda { round(n, nd); },
                lambda { _call_builtin("round", [mk_int(n), mk_int(nd)]); }
            );
        }
    }
}

def _call_builtin(name: str, args: list[CtValue]) -> CtValue {
    return _call_builtin_kw(name, args, {});
}

test "format specs, percent formatting, and str.format match CPython" {
    for v in [0, 5, -5, 1234567, -1234567, 255, 2 ** 70, True, False] {
        for spec in [
            "",
            "d",
            ">8",
            "<8",
            "^9",
            "x^9",
            "=+10",
            "08",
            "08,",
            "010,",
            "0=12,",
            "012_",
            "#x",
            "#o",
            "#b",
            "X",
            "c",
            "+c",
            "#c",
            "n",
            ",x",
            "x,",
            "5.2",
            ".2f",
            "08.3f",
            "%",
            "e",
            ",_",
            "z",
            "q",
            "abc"
        ] {
            same(
                f"format({v!r}, {spec!r})",
                lambda { format(v, spec); },
                lambda { mk_str(ct_format(py2ct(v), spec)); }
            );
        }
    }
    for s in ["", "a", "héllo", "abc"] {
        for spec in [
            "",
            "s",
            "5",
            ">5",
            "*^7.2",
            ".1",
            "05",
            "=5",
            "+",
            "#",
            ",",
            "d",
            "z",
            "x<3"
        ] {
            same(
                f"format({s!r}, {spec!r})",
                lambda { format(s, spec); },
                lambda { mk_str(ct_format(mk_str(s), spec)); }
            );
        }
    }
    for f in [0.0, -0.0, 3.14159, -2.5e-8, 1e22, float("inf")] {
        for spec in ["", ".2f", "e", "g", "+.3", "08.2f", "%", ",.2f", "z.1f"] {
            same(
                f"format({f!r}, {spec!r})",
                lambda { format(f, spec); },
                lambda { mk_str(ct_format(mk_float(f), spec)); }
            );
        }
    }
    percent_cases = [
        ("%s|%r|%d", (1, "a", 7)),
        (
            "%.3d|%5.1s|%-6x|%+d|% d|%05d|%#o|%c|%%|%e|%g|%i",
            (5, "abc", 255, 3, 3, -3, 8, 65, 1.5, 0.0001, 7)
        ),
        ("%*d", (5, 3)),
        ("%d", 3.9),
        ("%s %s", (1, )),
        ("%s", (1, 2)),
        ("%d", "x"),
        ("%c", "ab"),
        ("%x", 2 ** 70),
        ("%#X", -255),
        ("%-5s|", "ab"),
        ("%5.2f|%-8.3e|%G", (3.14159, 12345.678, 1e-10)),
        ("abc", {}),
        ("%(a)d-%(b)r", {"a": 1, "b": "x"})
    ];
    for (fmt, args) in percent_cases {
        same(
            f"{fmt!r} % {args!r}",
            lambda { fmt % args; },
            lambda { mk_str(ct_percent_format(fmt, py2ct(args))); }
        );
    }
    fmt_cases = [
        ("{} {x!r:>5}", [1], {"x": "a"}),
        ("{0}{1}{0}", ["a", "b"], {}),
        ("{:{w}}|", ["a"], {"w": 4}),
        ("{0[1]} {k[z]}", [[1, 2]], {"k": {"z": 9}}),
        ("{{}}{}", [3], {}),
        ("{}{0}", [1], {}),
        ("{1}", [1], {}),
        ("a}", [], {}),
        ("a{", [], {}),
        ("{k}", [], {}),
        ("{:,} {:08.3f} {!a}", [1234567, 3.14159, "é"], {})
    ];
    for (fmt2, pos, kw) in fmt_cases {
        same(
            f"{fmt2!r}.format",
            lambda { fmt2.format(*pos, **kw); },
            lambda { mk_str(
                ct_str_format(
                    fmt2,
                    [py2ct(x) for x in pos],
                    {k: py2ct(v) for (k, v) in kw.items()}
                )
            ); }
        );
    }
}

test "containers keep CPython repr, equality, key identity, and ordering" {
    values = [
        [1, 2.5, "a", b"x'\"\x00\xff", None, True],
        (1, ),
        (),
        {"a": 1, 2: [3], (1, 2): None},
        {1: "a", True: "b", 1.0: "c"},
        frozenset(),
        [[], {}, ()],
        "quote's \"both\"\n\t\x01é",
        b"",
        -0.0,
        1e16,
        1e-7
    ];
    for v in values {
        same(
            f"repr({v!r})", lambda { repr(v); }, lambda { mk_str(ct_repr(py2ct(v))); }
        );
    }
    same("set repr", lambda { repr({3}); }, lambda { mk_str(ct_repr(py2ct({3}))); });
    same(
        "frozenset repr",
        lambda { repr(frozenset({3})); },
        lambda { mk_str(ct_repr(py2ct(frozenset({3})))); }
    );
    loop: CtList = mk_list([]);
    loop.items.append(loop);
    assert ct_repr(loop) == "[[...]]";
    assert ct_eq(py2ct([1, (2, 3)]), py2ct([1.0, (2, 3.0)]));
    assert not ct_eq(py2ct([1]), py2ct((1, )));
    assert ct_eq(py2ct({1}), py2ct(frozenset({1.0})));
    assert ct_eq(py2ct({"a": 1, "b": 2}), py2ct({"b": 2, "a": 1}));
    for seq in [[5, 1, 4, 1, 3], "hello world", (1, 2, 3, 4, 5, 6), b"bytes!"] {
        for (lo, hi, st) in [
            (None, None, None),
            (1, None, None),
            (None, -1, None),
            (-3, None, 2),
            (None, None, -1),
            (5, 0, -2),
            (-100, 100, 3),
            (2, 2, None)
        ] {
            same(
                f"{seq!r}[{lo}:{hi}:{st}]",
                lambda { seq[lo:hi:st]; },
                lambda { ct_getslice(py2ct(seq), py2ct(lo), py2ct(hi), py2ct(st)); }
            );
        }
        for i in [0, -1, 3, 100, -100] {
            same(
                f"{seq!r}[{i}]",
                lambda { seq[i]; },
                lambda { ct_getitem(py2ct(seq), mk_int(i)); }
            );
        }
    }
    same(
        "str index str",
        lambda { eval("s[k]", {"s": "a", "k": "a"}); },
        lambda { ct_getitem(mk_str("a"), mk_str("a")); }
    );
    same(
        "list index str",
        lambda { eval("s[k]", {"s": [1], "k": "a"}); },
        lambda { ct_getitem(py2ct([1]), mk_str("a")); }
    );
    same(
        "dict missing",
        lambda { {}["k"]; },
        lambda { ct_getitem(mk_dict(), mk_str("k")); }
    );
    same(
        "dict unhashable",
        lambda { eval("{}[[1]]"); },
        lambda { ct_getitem(mk_dict(), py2ct([1])); }
    );
    same(
        "list < str",
        lambda { eval("a < b", {"a": [1], "b": "a"}); },
        lambda { ct_compare("<", py2ct([1]), mk_str("a")); }
    );
    same(
        "in int",
        lambda { eval("a in b", {"a": 1, "b": 5}); },
        lambda { ct_compare("in", mk_int(1), mk_int(5)); }
    );
    same(
        "tuple hash",
        lambda { hash((1, 2.5, None, True, (3, ))); },
        lambda { ct_hash(py2ct((1, 2.5, None, True, (3, )))); }
    );
    same("empty tuple hash", lambda { hash(()); }, lambda { ct_hash(py2ct(())); });
    same("None hash", lambda { hash(None); }, lambda { ct_hash(CT_NONE); });
    same(
        "list + tuple",
        lambda { eval("a + b", {"a": [], "b": ()}); },
        lambda { ct_binop("+", py2ct([]), py2ct(())); }
    );
    same(
        "str * big",
        lambda { eval("'a' * (2 ** 70)"); },
        lambda { ct_binop("*", mk_str("a"), mk_int(2 ** 70)); }
    );
    same(
        "unary float ~",
        lambda { eval("~1.0"); },
        lambda { ct_unary("~", mk_float(1.0)); }
    );
    same(
        "bool ops",
        lambda { (True & False, True | 2, -True); },
        lambda { mk_tuple(
            [
                ct_binop("&", mk_bool(True), mk_bool(False)),
                ct_binop("|", mk_bool(True), mk_int(2)),
                ct_unary("-", mk_bool(True))
            ]
        ); }
    );
}

test "builtins and math agree with CPython on results and messages" {
    cases: list[tuple[str, list[object], dict[str, object]]] = [
        ("sorted", [[3, 1, 2, 1]], {}),
        ("sorted", [[(1, "b"), (0, "a"), (1, "a")]], {"reverse": True}),
        ("sorted", [[2, 1, "a"]], {}),
        ("max", [[1, "a"]], {}),
        ("min", [["a", 1]], {}),
        ("max", [[]], {}),
        ("max", [[]], {"default": 5}),
        ("max", [3, 7, 7, 1], {}),
        ("sum", [[0.1] * 10], {}),
        ("sum", [[1, 2.5, 0.1, 0.2]], {}),
        ("sum", [[1e100, 1.0, -1e100]], {}),
        ("sum", [[2 ** 100, 1]], {}),
        ("sum", [["a"], ""], {}),
        ("divmod", [-7, 2], {}),
        ("divmod", [-7.0, 2], {}),
        ("divmod", [1, 0], {}),
        ("abs", [-2 ** 70], {}),
        ("hex", [-255], {}),
        ("bin", [2 ** 65], {}),
        ("oct", [8], {}),
        ("hex", [1.5], {}),
        ("chr", [-1], {}),
        ("ord", ["ab"], {}),
        ("len", [5], {}),
        ("enumerate", [["a", "b"], 3], {}),
        ("zip", [[1, 2, 3], "ab"], {}),
        ("reversed", [(1, 2, 3)], {}),
        ("any", [[0, "", None]], {}),
        ("all", [[1, "x"]], {}),
        ("range", [1, 10, 3], {}),
        ("range", [1, 2, 0], {})
    ];
    for (name, args, kw) in cases {
        py_fn = getattr(builtins, name);
        wrap = name in ("enumerate", "zip", "reversed");
        same(
            f"{name}{args}{kw}",
            lambda { list(py_fn(*args, **kw)) if wrap else py_fn(*args, **kw); },
            lambda { _call_builtin_kw(
                name, [py2ct(a) for a in args], {k: py2ct(v) for (k, v) in kw.items()}
            ); }
        );
    }
    ctor_cases: list[tuple[str, list[object]]] = [
        ("int", ["  -0b101  ", 0]),
        ("int", ["1_000"]),
        ("int", ["1__0"]),
        ("int", ["010", 0]),
        ("int", ["z", 36]),
        ("int", ["9", 8]),
        ("int", ["1", 1]),
        ("int", [[1]]),
        ("int", ["1" * 5000]),
        ("int", [1e20]),
        ("float", [" 1_0.5 "]),
        ("float", ["x"]),
        ("float", [2 ** 1024]),
        ("bytes", [[1, 2, 255]]),
        ("bytes", [[256]]),
        ("str", [b"\xc3\xa9", "utf-8"]),
        ("dict", [[(1, 2), (3, 4)]]),
        ("dict", [[(1, 2, 3)]]),
        ("tuple", ["ab"]),
        ("list", [5])
    ];
    for (tname, targs) in ctor_cases {
        py_t = getattr(builtins, tname);
        same(
            f"{tname}{targs}",
            lambda { py_t(*targs); },
            lambda { ct_construct_builtin(tname, [py2ct(a) for a in targs], {}); }
        );
    }
    math_cases: list[tuple[str, list[object]]] = [
        ("sqrt", [-1.0]),
        ("sqrt", [2]),
        ("log", [0]),
        ("log", [-1.0]),
        ("log", [10 ** 400]),
        ("log", [8, 2]),
        ("log2", [2 ** 3000]),
        ("log10", [10 ** 350]),
        ("log1p", [-1.0]),
        ("exp", [1000.0]),
        ("asin", [2.0]),
        ("atanh", [1.0]),
        ("acosh", [0]),
        ("sin", [float("inf")]),
        ("floor", [1e300]),
        ("ceil", [-2.5]),
        ("trunc", [-2.5]),
        ("floor", ["a"]),
        ("factorial", [30]),
        ("factorial", [-1]),
        ("factorial", [2.0]),
        ("gcd", [2 ** 100, 6 ** 50]),
        ("lcm", [4, 6, 10]),
        ("isqrt", [10 ** 41]),
        ("comb", [50, 20]),
        ("comb", [5, -1]),
        ("perm", [10, 3]),
        ("pow", [-8.0, 1 / 3]),
        ("pow", [10.0, 400.0]),
        ("fmod", [1.0, 0.0]),
        ("fmod", [-7.5, 2.0]),
        ("hypot", [3, 4]),
        ("isclose", [1.0, 1.0 + 1e-10]),
        ("frexp", [48.0]),
        ("ldexp", [1.0, 5000]),
        ("modf", [-3.25]),
        ("copysign", [1.0, -0.0]),
        ("prod", [[1, 2, 3, 4]])
    ];
    for (mname, margs) in math_cases {
        py_m = getattr(math, mname);
        same(
            f"math.{mname}{margs}",
            lambda { py_m(*margs); },
            lambda { ct_call_math(mname, [py2ct(a) for a in margs], {}); }
        );
    }
}

def _evaluator -> CtEvaluator {
    return CtEvaluator(evaluator=JacProgram().get_type_evaluator());
}

def _call_builtin_kw(
    name: str, args: list[CtValue], kwargs: dict[str, CtValue]
) -> CtValue {
    ev = _evaluator();
    fn = ev._builtin_value(name);
    assert fn is not None;
    return ev.call_value(fn, args, kwargs);
}

test "methods on typed values match CPython" {
    ev = _evaluator();
    method_cases: list[tuple[object, str, list[object]]] = [
        ("a,b,,c", "split", [","]),
        ("  a  b ", "split", []),
        ("a b c", "rsplit", [None, 1]),
        ("x", "join", [["a", "b"]]),
        ("x", "join", [[1]]),
        ("abc", "index", ["z"]),
        ("abcabc", "rfind", ["b"]),
        ("abc", "center", [9, "*"]),
        ("ab", "zfill", [5]),
        ("-12", "zfill", [5]),
        ("a=b=c", "partition", ["="]),
        ("a=b=c", "rpartition", ["="]),
        ("Hello World", "swapcase", []),
        ("hello world", "title", []),
        ("line1\nline2\r\n", "splitlines", [True]),
        ("prefix-body", "removeprefix", ["prefix-"]),
        ("héllo", "encode", []),
        ("abc", "startswith", [("x", "a")]),
        ("abc", "replace", ["b", "BB"]),
        ("{} and {name}", "format", [1]),
        (b"hi\xff", "hex", []),
        (b"a,b", "split", [b","]),
        (b"caf\xc3\xa9", "decode", []),
        (b"\xff", "decode", []),
        ([3, 1, 2], "index", [5]),
        ([1, 2, 1], "count", [1]),
        ((1, 2), "index", [3]),
        (7, "bit_length", []),
        (-(2 ** 70), "bit_length", []),
        (255, "bit_count", []),
        (0.375, "as_integer_ratio", []),
        (1e-300, "as_integer_ratio", []),
        (2.0, "is_integer", [])
    ];
    for (recv, mname, margs) in method_cases {
        kwargs: dict[str, object] = {"name": "N"} if mname == "format" else {};
        same(
            f"{recv!r}.{mname}{margs}",
            lambda { getattr(recv, mname)(*margs, **kwargs); },
            lambda { ev._call_attr(
                py2ct(recv),
                mname,
                [py2ct(a) for a in margs],
                {k: py2ct(v) for (k, v) in kwargs.items()}
            ); }
        );
    }
    lst = py2ct([3, 1, 2]);
    ev._call_attr(lst, "append", [mk_int(0)], {});
    ev._call_attr(lst, "sort", [], {"reverse": mk_bool(True)});
    assert ct_repr(lst) == "[3, 2, 1, 0]";
    d = py2ct({"a": 1});
    assert ct_repr(ev._call_attr(d, "items", [], {})) == "dict_items([('a', 1)])";
    assert ct_repr(ev._call_attr(d, "setdefault", [mk_str("b"), mk_int(2)], {})) == "2";
    assert ct_repr(d) == "{'a': 1, 'b': 2}";
    same(
        "dict.pop missing",
        lambda { {}.pop("a"); },
        lambda { ev._call_attr(mk_dict(), "pop", [mk_str("a")], {}); }
    );
    same(
        "list.pop empty",
        lambda { [].pop(); },
        lambda { ev._call_attr(mk_list([]), "pop", [], {}); }
    );
    same(
        "list.remove missing",
        lambda { [1].remove(3); },
        lambda { ev._call_attr(py2ct([1]), "remove", [mk_int(3)], {}); }
    );
    with testraises(CtError) {
        ev._call_attr(mk_str("a"), "maketrans", [], {});
    }
    with testraises(CtError) {
        ct_hash(mk_str("seeded"));
    }
}

def _check_program(label: str, src: str) {
    program = JacProgram();
    program.compile(
        file_path=f"{label}.jac",
        use_str=src,
        options=CompileOptions(no_cgen=True, no_ir_cache=True, force_codespace="server")
    );
    assert not program.errors_had , label
        + ":\n"
        + "\n".join(error.pretty_print() for error in program.errors_had);
}

test "comptime programs fold to CPython's observable values" {
    _check_program(
        "ct_numbers",
        "comptime BIG: int = 2 ** 100 + 7;\n"
            + "comptime MASKED: int = (0xcbf29ce484222325 * 0x100000001b3) & 0xFFFFFFFFFFFFFFFF;\n"
            + "comptime RATIO: float = (10 ** 30) / 7;\n"
            + "comptime LOW: int = -7 // 2;\n"
            + "comptime FMOD: float = -7.5 % 2;\n"
            + "comptime NAME: str = 'ab';\n"
            + "with entry {\n"
            + "    comptime assert str(BIG) == '1267650600228229401496703205383';\n"
            + "    comptime assert MASKED == 12638153115695167455;\n"
            + "    comptime assert repr(RATIO) == '1.4285714285714285e+29';\n"
            + "    comptime assert LOW == -4 and FMOD == 0.5;\n"
            + "    comptime assert f'{BIG:,}' == '1,267,650,600,228,229,401,496,703,205,383';\n"
            + "    comptime assert format(255, '#010x') + f'|{3.14159:>8.2f}|{NAME!r:^6}' == \"0x000000ff|    3.14| 'ab' \";\n"
            + "    comptime assert '%-4d|%05.1f' % (7, 2.25) == '7   |002.2';\n"
            + "    comptime assert '{0}-{k}'.format(1, k='z') == '1-z';\n"
            + "}\n"
    );
    _check_program(
        "ct_containers",
        "comptime D: dict[int, str] = {1: 'a', True: 'b', 2: 'c'};\n"
            + "comptime S: list[int] = sorted({3, 1, 2}, reverse=True);\n"
            + "comptime KEYS: list[int] = [k for k in D];\n"
            + "with entry {\n"
            + "    comptime assert repr(D) == \"{1: 'b', 2: 'c'}\";\n"
            + "    comptime assert S == [3, 2, 1] and KEYS == [1, 2];\n"
            + "    comptime assert repr((1,)) == '(1,)' and repr(frozenset()) == 'frozenset()';\n"
            + "    comptime assert [1, 2] + [3] == [1, 2, 3] and (1, 2) != [1, 2];\n"
            + "    comptime assert 'abc'[::-1] == 'cba' and list(range(10)[2:8:3]) == [2, 5];\n"
            + "}\n"
    );
    _check_program(
        "ct_control",
        "import math;\n"
            + "comptime def safe_div(a: int, b: int) -> str {\n"
            + "    try {\n"
            + "        return str(a // b);\n"
            + "    } except ZeroDivisionError as e {\n"
            + "        return 'err:' + str(e);\n"
            + "    }\n"
            + "}\n"
            + "comptime def rethrow -> str {\n"
            + "    out = '';\n"
            + "    try {\n"
            + "        try {\n"
            + "            {}['k'];\n"
            + "        } except KeyError {\n"
            + "            out += 'inner;';\n"
            + "            raise;\n"
            + "        } finally {\n"
            + "            out += 'fin;';\n"
            + "        }\n"
            + "    } except LookupError as e {\n"
            + "        out += repr(e);\n"
            + "    }\n"
            + "    return out;\n"
            + "}\n"
            + "comptime def total -> int {\n"
            + "    acc = [];\n"
            + "    for i in range(5) {\n"
            + "        if i == 3 { continue; }\n"
            + "        acc += [i * i];\n"
            + "    }\n"
            + "    return sum(acc);\n"
            + "}\n"
            + "with entry {\n"
            + "    comptime assert safe_div(7, 2) == '3' and safe_div(1, 0) == 'err:division by zero';\n"
            + "    comptime assert rethrow() == \"inner;fin;KeyError('k')\";\n"
            + "    comptime assert total() == 21;\n"
            + "    comptime assert math.floor(2.5) == 2 and math.isqrt(99) == 9 and math.pi > 3.14;\n"
            + "}\n"
    );
}

test "comptime refuses what it cannot reproduce" {
    program = JacProgram();
    program.compile(
        file_path="ct_refusals.jac",
        use_str="comptime H: int = hash('seeded');\n"
            + "comptime C: float = (-8) ** 0.5;\n",
        options=CompileOptions(no_cgen=True, no_ir_cache=True, force_codespace="server")
    );
    messages = "\n".join(error.pretty_print() for error in program.errors_had);
    assert "not reproducible at compile time" in messages , messages;
    assert "complex" in messages , messages;
}
