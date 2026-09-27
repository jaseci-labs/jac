import math;
import from jaclang.compiler.types.ct_int {
    MAX_STR_DIGITS,
    mag_bit_length,
    mag_divmod,
    mag_from_int,
    mag_gcd,
    mag_isqrt,
    mag_low_bits_nonzero,
    mag_mul,
    mag_shl,
    mag_shr,
    mag_to_int
}
import from jaclang.compiler.types.ct_value {
    CT_FALSE,
    CtCaller,
    CT_NONE,
    CT_TRUE,
    CtBool,
    CtBuiltin,
    CtBytes,
    CtDict,
    CtError,
    CtExc,
    CtFloat,
    CtInt,
    CtList,
    CtMethod,
    CtModule,
    CtNone,
    CtRange,
    CtSet,
    CtStr,
    CtTuple,
    CtValue,
    CtView,
    as_ct_int,
    ct_eq,
    ct_exc,
    ct_exc_value,
    ct_iter,
    ct_len,
    ct_repr,
    ct_same_or_eq,
    ct_str,
    ct_truthy,
    ct_type_name,
    dict_copy,
    dict_delete,
    dict_get,
    dict_set,
    float_ceil,
    float_floor,
    float_to_ct_int,
    int_cmp,
    int_sign_mag,
    mk_bool,
    mk_bytes,
    mk_dict,
    mk_float,
    mk_int,
    mk_int_mag,
    mk_list,
    mk_set,
    mk_str,
    mk_tuple,
    range_len,
    set_add,
    set_discard,
    set_has
}
import from jaclang.compiler.types.ct_ops {
    ct_binop,
    ct_contains,
    ct_hash,
    ct_int_parse,
    ct_lt,
    ct_order,
    float_divmod,
    float_round_to_int,
    int_abs,
    int_add,
    int_bit_length,
    int_divmod,
    int_is_neg,
    int_is_zero,
    int_mul,
    int_prefixed,
    int_round,
    int_sub,
    int_to_float,
    set_algebra,
    slice_indices
}
import from jaclang.compiler.types.ct_format {
    ct_binary,
    ct_format,
    ct_str_format,
    pad_text
}

glob CT_BUILTIN_FUNCS: frozenset[str] = frozenset(
         {
             "len",
             "repr",
             "sorted",
             "range",
             "enumerate",
             "min",
             "max",
             "sum",
             "abs",
             "any",
             "all",
             "zip",
             "reversed",
             "round",
             "divmod",
             "ord",
             "chr",
             "hex",
             "bin",
             "oct",
             "format",
             "map",
             "filter",
             "isinstance",
             "hash"
         }
     ),
     CT_BUILTIN_TYPES: frozenset[str] = frozenset(
         {
             "int",
             "float",
             "str",
             "bool",
             "bytes",
             "list",
             "dict",
             "set",
             "tuple",
             "frozenset",
             "type",
             "object"
         }
     ),
     CT_BUILTIN_EXCEPTIONS: frozenset[str] = frozenset(
         {
             "Exception",
             "ValueError",
             "TypeError",
             "KeyError",
             "IndexError",
             "AttributeError",
             "ZeroDivisionError",
             "OverflowError",
             "RuntimeError",
             "AssertionError",
             "NotImplementedError",
             "LookupError",
             "ArithmeticError",
             "StopIteration"
         }
     ),
     CT_METHODS: dict[str, frozenset[str]] = {
         "str": frozenset(
             {
                 "upper",
                 "lower",
                 "casefold",
                 "capitalize",
                 "title",
                 "swapcase",
                 "strip",
                 "lstrip",
                 "rstrip",
                 "split",
                 "rsplit",
                 "splitlines",
                 "join",
                 "replace",
                 "startswith",
                 "endswith",
                 "find",
                 "rfind",
                 "index",
                 "rindex",
                 "count",
                 "isdigit",
                 "isalpha",
                 "isalnum",
                 "isspace",
                 "isupper",
                 "islower",
                 "isidentifier",
                 "isnumeric",
                 "isdecimal",
                 "istitle",
                 "isascii",
                 "isprintable",
                 "center",
                 "ljust",
                 "rjust",
                 "zfill",
                 "partition",
                 "rpartition",
                 "encode",
                 "removeprefix",
                 "removesuffix",
                 "format",
                 "expandtabs"
             }
         ),
         "bytes": frozenset(
             {
                 "decode",
                 "hex",
                 "startswith",
                 "endswith",
                 "find",
                 "rfind",
                 "index",
                 "count",
                 "replace",
                 "strip",
                 "lstrip",
                 "rstrip",
                 "split",
                 "join",
                 "upper",
                 "lower"
             }
         ),
         "list": frozenset(
             {
                 "append",
                 "extend",
                 "insert",
                 "pop",
                 "remove",
                 "index",
                 "count",
                 "reverse",
                 "sort",
                 "copy",
                 "clear"
             }
         ),
         "tuple": frozenset({"index", "count"}),
         "dict": frozenset(
             {
                 "get",
                 "keys",
                 "values",
                 "items",
                 "pop",
                 "popitem",
                 "setdefault",
                 "update",
                 "copy",
                 "clear",
                 "fromkeys"
             }
         ),
         "set": frozenset(
             {
                 "add",
                 "discard",
                 "remove",
                 "pop",
                 "clear",
                 "copy",
                 "update",
                 "union",
                 "intersection",
                 "difference",
                 "symmetric_difference",
                 "intersection_update",
                 "difference_update",
                 "symmetric_difference_update",
                 "issubset",
                 "issuperset",
                 "isdisjoint"
             }
         ),
         "frozenset": frozenset(
             {
                 "copy",
                 "union",
                 "intersection",
                 "difference",
                 "symmetric_difference",
                 "issubset",
                 "issuperset",
                 "isdisjoint"
             }
         ),
         "int": frozenset(
             {"bit_length", "bit_count", "is_integer", "conjugate", "as_integer_ratio"}
         ),
         "float": frozenset({"is_integer", "conjugate", "as_integer_ratio"}),
         "range": frozenset({"index", "count"})
     },
     CT_STATIC_METHODS: frozenset[str] = frozenset({"dict.fromkeys", "bytes.fromhex"}),
     CT_MATH_CONSTS: dict[str, float] = {
         "pi": math.pi,
         "e": math.e,
         "tau": math.tau,
         "inf": math.inf,
         "nan": math.nan
     },
     CT_MATH_FUNCS: frozenset[str] = frozenset(
         {
             "sqrt",
             "exp",
             "exp2",
             "expm1",
             "log",
             "log2",
             "log10",
             "log1p",
             "sin",
             "cos",
             "tan",
             "asin",
             "acos",
             "atan",
             "atan2",
             "sinh",
             "cosh",
             "tanh",
             "asinh",
             "acosh",
             "atanh",
             "hypot",
             "fabs",
             "fmod",
             "remainder",
             "copysign",
             "pow",
             "degrees",
             "radians",
             "cbrt",
             "isnan",
             "isinf",
             "isfinite",
             "isclose",
             "floor",
             "ceil",
             "trunc",
             "gcd",
             "lcm",
             "factorial",
             "isqrt",
             "comb",
             "perm",
             "prod",
             "fsum",
             "ldexp",
             "frexp",
             "modf"
         }
     ),
     CT_FACTORIAL_LIMIT: int = 5000,
     CT_ABSENT: CtNone = CtNone();

def ct_method_owner(v: CtValue) -> str {
    if isinstance(v, CtBool) {
        return "int";
    }
    if isinstance(v, CtSet) {
        return "frozenset" if v.frozen else "set";
    }
    return ct_type_name(v);
}

def ct_has_method(v: CtValue, name: str) -> bool {
    owner = ct_method_owner(v);
    return owner in CT_METHODS and name in CT_METHODS[owner];
}

def _arity(
    fname: str,
    args: list[CtValue],
    kwargs: dict[str, CtValue],
    names: list[str],
    required: int
) -> list[CtValue] {
    slots: list[CtValue] = [];
    for _ in names {
        slots.append(CT_ABSENT);
    }
    if len(args) > len(names) {
        raise ct_exc(
            "TypeError",
            f"{fname}() takes at most {len(names)} arguments ({len(args)} given)"
        );
    }
    for (i, a) in enumerate(args) {
        slots[i] = a;
    }
    for (k, v) in kwargs.items() {
        if k not in names {
            raise ct_exc(
                "TypeError", f"{fname}() got an unexpected keyword argument '{k}'"
            );
        }
        idx = names.index(k);
        if slots[idx] is not CT_ABSENT {
            raise ct_exc(
                "TypeError", f"{fname}() got multiple values for argument '{k}'"
            );
        }
        slots[idx] = v;
    }
    for i in range(required) {
        if slots[i] is CT_ABSENT {
            raise ct_exc(
                "TypeError",
                f"{fname}() missing required argument '{names[i]}' (pos {i + 1})"
            );
        }
    }
    return slots;
}

def _one_arg(fname: str, args: list[CtValue], kwargs: dict[str, CtValue]) -> CtValue {
    if kwargs {
        raise ct_exc("TypeError", f"{fname}() takes no keyword arguments");
    }
    if len(args) != 1 {
        raise ct_exc(
            "TypeError", f"{fname}() takes exactly one argument ({len(args)} given)"
        );
    }
    return args[0];
}

def _no_args(fname: str, args: list[CtValue], kwargs: dict[str, CtValue]) {
    if args or kwargs {
        raise ct_exc(
            "TypeError",
            f"{fname}() takes no arguments ({len(args) + len(kwargs)} given)"
        );
    }
}

def _as_index(v: CtValue) -> CtInt {
    iv = as_ct_int(v);
    if iv is None {
        raise ct_exc(
            "TypeError",
            f"'{ct_type_name(v)}' object cannot be interpreted as an integer"
        );
    }
    return iv;
}

def _as_small(v: CtValue) -> int {
    iv = _as_index(v);
    if iv.mag {
        raise ct_exc("OverflowError", "Python int too large to convert to C ssize_t");
    }
    return iv.small;
}

def _opt_small(v: CtValue) -> (int | None) {
    if isinstance(v, CtNone) {
        return None;
    }
    return _as_small(v);
}

def _as_str(v: CtValue, prefix: str) -> str {
    if not isinstance(v, CtStr) {
        raise ct_exc("TypeError", prefix + ct_type_name(v));
    }
    return v.value;
}

def _opt_str(v: CtValue, what: str) -> (str | None) {
    if isinstance(v, CtNone) {
        return None;
    }
    return _as_str(v, what);
}

def _str_list(items: list[str]) -> CtList {
    return mk_list([mk_str(x) for x in items]);
}

def ct_sort(
    ev: CtCaller, items: list[CtValue], key: (CtValue | None), reverse: bool
) -> list[CtValue] {
    keys: list[CtValue] = [];
    for item in items {
        if key is None or isinstance(key, CtNone) {
            keys.append(item);
        } else {
            keys.append(ev.call_value(key, [item], {}));
        }
    }
    idxs: list[int] = list(range(len(items)));
    if reverse {
        idxs.reverse();
    }
    n = len(idxs);
    if n >= 2 {
        run = 1;
        if ct_lt(keys[idxs[1]], keys[idxs[0]]) {
            run = 2;
            while run < n and ct_lt(keys[idxs[run]], keys[idxs[run - 1]]) {
                run += 1;
            }
            head = idxs[:run];
            head.reverse();
            idxs = head + idxs[run:];
        } else {
            run = 2;
            while run < n and not ct_lt(keys[idxs[run]], keys[idxs[run - 1]]) {
                run += 1;
            }
        }
        for start in range(run, n) {
            pivot = idxs[start];
            lo = 0;
            hi = start;
            while lo < hi {
                mid = lo + ((hi - lo) >> 1);
                if ct_lt(keys[pivot], keys[idxs[mid]]) {
                    hi = mid;
                } else {
                    lo = mid + 1;
                }
            }
            idxs.pop(start);
            idxs.insert(lo, pivot);
        }
    }
    if reverse {
        idxs.reverse();
    }
    return [items[i] for i in idxs];
}

def _minmax(
    ev: CtCaller, fname: str, args: list[CtValue], kwargs: dict[str, CtValue]
) -> CtValue {
    key: (CtValue | None) = None;
    dflt: (CtValue | None) = None;
    for (k, v) in kwargs.items() {
        if k == "key" {
            key = v;
        } elif k == "default" {
            dflt = v;
        } else {
            raise ct_exc(
                "TypeError", f"{fname}() got an unexpected keyword argument '{k}'"
            );
        }
    }
    if not args {
        raise ct_exc("TypeError", f"{fname} expected at least 1 argument, got 0");
    }
    if len(args) > 1 and dflt is not None {
        raise ct_exc(
            "TypeError",
            f"Cannot specify a default for {fname}() with multiple positional arguments"
        );
    }
    seq = ct_iter(args[0]) if len(args) == 1 else args;
    best: (CtValue | None) = None;
    best_key: (CtValue | None) = None;
    op = "<" if fname == "min" else ">";
    for item in seq {
        kv = item
            if key is None or isinstance(key, CtNone)
            else ev.call_value(key, [item], {});
        if best_key is None {
            best = item;
            best_key = kv;
        } elif ct_order(op, kv, best_key) {
            best = item;
            best_key = kv;
        }
    }
    if best is None {
        if dflt is not None {
            return dflt;
        }
        raise ct_exc("ValueError", f"{fname}() iterable argument is empty");
    }
    return best;
}

def _sum(args: list[CtValue], kwargs: dict[str, CtValue]) -> CtValue {
    slots = _arity("sum", args, kwargs, ["iterable", "start"], 1);
    items = ct_iter(slots[0]);
    result: CtValue = slots[1] if slots[1] is not CT_ABSENT else CtInt(small=0);
    if isinstance(result, CtStr) {
        raise ct_exc("TypeError", "sum() can't sum strings [use ''.join(seq) instead]");
    }
    if isinstance(result, CtBytes) {
        raise ct_exc("TypeError", "sum() can't sum bytes [use b''.join(seq) instead]");
    }
    i = 0;
    n = len(items);
    if isinstance(result, CtInt) {
        acc: CtInt = result;
        broke = False;
        while i < n {
            item = items[i];
            iv = as_ct_int(item);
            i += 1;
            if iv is not None {
                acc = int_add(acc, iv);
                continue;
            }
            result = ct_binop("+", acc, item);
            broke = True;
            break;
        }
        if not broke {
            result = acc;
        }
    }
    if isinstance(result, CtFloat) {
        f = result.value;
        c = 0.0;
        done = False;
        while i < n {
            item = items[i];
            i += 1;
            x: float = 0.0;
            usable = False;
            if isinstance(item, CtFloat) {
                x = item.value;
                usable = True;
            } else {
                iv2 = as_ct_int(item);
                if iv2 is not None and not iv2.mag {
                    x = float(iv2.small);
                    usable = True;
                } elif iv2 is not None and mag_bit_length(iv2.mag) <= 63 {
                    x = int_to_float(iv2);
                    usable = True;
                }
            }
            if usable {
                t = f + x;
                if abs(f) >= abs(x) {
                    c += (f - t) + x;
                } else {
                    c += (x - t) + f;
                }
                f = t;
                continue;
            }
            if c != 0.0 and c - c == 0.0 {
                f += c;
            }
            result = ct_binop("+", mk_float(f), item);
            done = True;
            break;
        }
        if not done {
            if c != 0.0 and c - c == 0.0 {
                f += c;
            }
            return mk_float(f);
        }
    }
    while i < n {
        result = ct_binop("+", result, items[i]);
        i += 1;
    }
    return result;
}

def _range(args: list[CtValue], kwargs: dict[str, CtValue]) -> CtRange {
    if kwargs {
        raise ct_exc("TypeError", "range() takes no keyword arguments");
    }
    if not args or len(args) > 3 {
        raise ct_exc(
            "TypeError",
            f"range expected at least 1 argument, got {len(args)}"
                if not args
                else f"range expected at most 3 arguments, got {len(args)}"
        );
    }
    vals: list[int] = [];
    for a in args {
        iv = _as_index(a);
        if iv.mag {
            raise CtError(
                "range() bounds beyond 64 bits are not supported in comptime code"
            );
        }
        vals.append(iv.small);
    }
    if len(vals) == 1 {
        return CtRange(start=0, stop=vals[0], step=1);
    }
    step = vals[2] if len(vals) == 3 else 1;
    if step == 0 {
        raise ct_exc("ValueError", "range() arg 3 must not be zero");
    }
    return CtRange(start=vals[0], stop=vals[1], step=step);
}

def _round(args: list[CtValue], kwargs: dict[str, CtValue]) -> CtValue {
    slots = _arity("round", args, kwargs, ["number", "ndigits"], 1);
    num = slots[0];
    nd = slots[1];
    iv = as_ct_int(num);
    if iv is not None {
        if nd is None or isinstance(nd, CtNone) {
            return iv;
        }
        return int_round(iv, _as_small(nd));
    }
    if isinstance(num, CtFloat) {
        if nd is None or isinstance(nd, CtNone) {
            return float_round_to_int(num.value);
        }
        try {
            return mk_float(round(num.value, _as_small(nd)));
        } except OverflowError as e {
            raise ct_exc("OverflowError", str(e));
        }
    }
    raise ct_exc(
        "TypeError", f"type {ct_type_name(num)} doesn't define __round__ method"
    );
}

def _divmod(a: CtValue, b: CtValue) -> CtValue {
    ai = as_ct_int(a);
    bi = as_ct_int(b);
    if ai is not None and bi is not None {
        (q, r) = int_divmod(ai, bi);
        return mk_tuple([q, r]);
    }
    if (isinstance(a, CtFloat) or ai is not None)
        and (isinstance(b, CtFloat) or bi is not None) {
        x = 0.0;
        y = 0.0;
        if isinstance(a, CtFloat) {
            x = a.value;
        } elif ai is not None {
            x = int_to_float(ai);
        }
        if isinstance(b, CtFloat) {
            y = b.value;
        } elif bi is not None {
            y = int_to_float(bi);
        }
        (fq, fr) = float_divmod(x, y);
        return mk_tuple([mk_float(fq), mk_float(fr)]);
    }
    raise ct_exc(
        "TypeError",
        f"unsupported operand type(s) for divmod(): '{ct_type_name(a)}' and '{ct_type_name(
            b
        )}'"
    );
}

def _reversed(v: CtValue) -> CtList {
    if isinstance(v, (CtList, CtTuple, CtStr, CtBytes, CtRange, CtDict, CtView)) {
        items = ct_iter(v);
        items.reverse();
        return mk_list(items);
    }
    raise ct_exc("TypeError", f"'{ct_type_name(v)}' object is not reversible");
}

def ct_call_builtin(
    ev: CtCaller, name: str, args: list[CtValue], kwargs: dict[str, CtValue]
) -> CtValue {
    if name.startswith("math.") {
        return ct_call_math(name[5:], args, kwargs);
    }
    if name == "len" {
        return mk_int(ct_len(_one_arg("len", args, kwargs)));
    }
    if name == "repr" {
        return mk_str(ct_repr(_one_arg("repr", args, kwargs)));
    }
    if name == "hash" {
        return ct_hash(_one_arg("hash", args, kwargs));
    }
    if name == "abs" {
        v = _one_arg("abs", args, kwargs);
        iv = as_ct_int(v);
        if iv is not None {
            return int_abs(iv);
        }
        if isinstance(v, CtFloat) {
            return mk_float(abs(v.value));
        }
        raise ct_exc("TypeError", f"bad operand type for abs(): '{ct_type_name(v)}'");
    }
    if name in ("any", "all") {
        v2 = _one_arg(name, args, kwargs);
        want = name == "any";
        for item in ct_iter(v2) {
            if ct_truthy(item) == want {
                return mk_bool(want);
            }
        }
        return mk_bool(not want);
    }
    if name == "format" {
        slots = _arity("format", args, kwargs, ["value", "format_spec"], 1);
        spec = "";
        if slots[1] is not CT_ABSENT {
            if not isinstance(slots[1], CtStr) {
                raise ct_exc(
                    "TypeError",
                    f"format() argument 2 must be str, not {ct_type_name(slots[1])}"
                );
            }
            spec = slots[1].value;
        }
        return mk_str(ct_format(slots[0], spec));
    }
    if name == "sorted" {
        if len(args) != 1 {
            raise ct_exc("TypeError", f"sorted expected 1 argument, got {len(args)}");
        }
        key: (CtValue | None) = None;
        rev = False;
        for (k, v3) in kwargs.items() {
            if k == "key" {
                key = v3;
            } elif k == "reverse" {
                rev = ct_truthy(v3);
            } else {
                raise ct_exc(
                    "TypeError", f"sort() got an unexpected keyword argument '{k}'"
                );
            }
        }
        return mk_list(ct_sort(ev, ct_iter(args[0]), key, rev));
    }
    if name == "range" {
        return _range(args, kwargs);
    }
    if name == "enumerate" {
        slots2 = _arity("enumerate", args, kwargs, ["iterable", "start"], 1);
        start = _as_index(slots2[1]) if slots2[1] is not CT_ABSENT else CtInt(small=0);
        out: list[CtValue] = [];
        cur = start;
        for item in ct_iter(slots2[0]) {
            out.append(mk_tuple([cur, item]));
            cur = int_add(cur, CtInt(small=1));
        }
        return mk_list(out);
    }
    if name == "zip" {
        strict = False;
        for (k, v4) in kwargs.items() {
            if k != "strict" {
                raise ct_exc(
                    "TypeError", f"zip() got an unexpected keyword argument '{k}'"
                );
            }
            strict = ct_truthy(v4);
        }
        seqs = [ct_iter(a) for a in args];
        out2: list[CtValue] = [];
        if seqs {
            n = min([len(s) for s in seqs]);
            if strict and max([len(s) for s in seqs]) != n {
                raise ct_exc("ValueError", "zip() arguments have unequal lengths");
            }
            for i in range(n) {
                out2.append(mk_tuple([s[i] for s in seqs]));
            }
        }
        return mk_list(out2);
    }
    if name == "reversed" {
        return _reversed(_one_arg("reversed", args, kwargs));
    }
    if name in ("min", "max") {
        return _minmax(ev, name, args, kwargs);
    }
    if name == "sum" {
        return _sum(args, kwargs);
    }
    if name == "round" {
        return _round(args, kwargs);
    }
    if name == "divmod" {
        if len(args) != 2 or kwargs {
            raise ct_exc("TypeError", f"divmod expected 2 arguments, got {len(args)}");
        }
        return _divmod(args[0], args[1]);
    }
    if name == "ord" {
        c = _one_arg("ord", args, kwargs);
        if isinstance(c, CtStr) {
            if len(c.value) != 1 {
                raise ct_exc(
                    "TypeError",
                    f"ord() expected a character, but string of length {len(
                        c.value
                    )} found"
                );
            }
            return mk_int(ord(c.value));
        }
        if isinstance(c, CtBytes) {
            if len(c.value) != 1 {
                raise ct_exc(
                    "TypeError",
                    f"ord() expected a character, but string of length {len(
                        c.value
                    )} found"
                );
            }
            return mk_int(c.value[0]);
        }
        raise ct_exc(
            "TypeError",
            f"ord() expected string of length 1, but {ct_type_name(c)} found"
        );
    }
    if name == "chr" {
        ci = _as_index(_one_arg("chr", args, kwargs));
        if ci.mag or ci.small < 0 or ci.small > 1114111 {
            raise ct_exc("ValueError", "chr() arg not in range(0x110000)");
        }
        return mk_str(chr(ci.small));
    }
    if name in ("hex", "oct", "bin") {
        hv = _as_index(_one_arg(name, args, kwargs));
        base = 16 if name == "hex" else (8 if name == "oct" else 2);
        return mk_str(int_prefixed(hv, base));
    }
    if name == "map" {
        if len(args) < 2 {
            raise ct_exc("TypeError", "map() must have at least two arguments.");
        }
        fn = args[0];
        seqs2 = [ct_iter(a) for a in args[1:]];
        n2 = min([len(s) for s in seqs2]);
        out3: list[CtValue] = [];
        for i in range(n2) {
            out3.append(ev.call_value(fn, [s[i] for s in seqs2], {}));
        }
        return mk_list(out3);
    }
    if name == "filter" {
        if len(args) != 2 {
            raise ct_exc("TypeError", f"filter expected 2 arguments, got {len(args)}");
        }
        fn2 = args[0];
        out4: list[CtValue] = [];
        for item in ct_iter(args[1]) {
            keep = ct_truthy(item)
                if isinstance(fn2, CtNone)
                else ct_truthy(ev.call_value(fn2, [item], {}));
            if keep {
                out4.append(item);
            }
        }
        return mk_list(out4);
    }
    if name == "isinstance" {
        if len(args) != 2 {
            raise ct_exc(
                "TypeError", f"isinstance expected 2 arguments, got {len(args)}"
            );
        }
        return mk_bool(ev.ct_isinstance(args[0], args[1]));
    }
    raise CtError(f"builtin '{name}' is not supported in comptime code");
}

def _pairs_into(d: CtDict, src: CtValue) {
    if isinstance(src, CtDict) {
        for (i, k) in enumerate(src.keys) {
            dict_set(d, k, src.vals[i]);
        }
        return;
    }
    for (idx, item) in enumerate(ct_iter(src)) {
        if not isinstance(
            item, (CtList, CtTuple, CtStr, CtBytes, CtSet, CtRange, CtDict, CtView)
        ) {
            raise ct_exc(
                "TypeError",
                f"cannot convert dictionary update sequence element #{idx} to a sequence"
            );
        }
        pair = ct_iter(item);
        if len(pair) != 2 {
            raise ct_exc(
                "ValueError",
                f"dictionary update sequence element #{idx} has length {len(
                    pair
                )}; 2 is required"
            );
        }
        dict_set(d, pair[0], pair[1]);
    }
}

def _parse_int_text(text: str, shown: str, base: int) -> CtInt {
    got = ct_int_parse(text, base);
    if got is None {
        raise ct_exc(
            "ValueError", f"invalid literal for int() with base {base}: {shown}"
        );
    }
    return got;
}

def ct_construct_builtin(
    name: str, args: list[CtValue], kwargs: dict[str, CtValue]
) -> CtValue {
    if name == "int" {
        slots = _arity("int", args, kwargs, ["x", "base"], 0);
        x = slots[0];
        if x is None {
            if slots[1] is not CT_ABSENT {
                raise ct_exc("TypeError", "int() missing string argument");
            }
            return CtInt(small=0);
        }
        if slots[1] is not CT_ABSENT {
            base = _as_small(slots[1]);
            if base != 0 and (base < 2 or base > 36) {
                raise ct_exc("ValueError", "int() base must be >= 2 and <= 36, or 0");
            }
            if isinstance(x, CtStr) {
                return _parse_int_text(x.value, ct_repr(x), base);
            }
            if isinstance(x, CtBytes) {
                return _parse_int_text(x.value.decode("latin-1"), ct_repr(x), base);
            }
            raise ct_exc(
                "TypeError", "int() can't convert non-string with explicit base"
            );
        }
        iv = as_ct_int(x);
        if iv is not None {
            return iv;
        }
        if isinstance(x, CtFloat) {
            return float_to_ct_int(x.value);
        }
        if isinstance(x, CtStr) {
            return _parse_int_text(x.value, ct_repr(x), 10);
        }
        if isinstance(x, CtBytes) {
            return _parse_int_text(x.value.decode("latin-1"), ct_repr(x), 10);
        }
        raise ct_exc(
            "TypeError",
            f"int() argument must be a string, a bytes-like object or a real number, not '{ct_type_name(
                x
            )}'"
        );
    }
    if name == "float" {
        if kwargs or len(args) > 1 {
            raise ct_exc(
                "TypeError", f"float expected at most 1 argument, got {len(args)}"
            );
        }
        if not args {
            return mk_float(0.0);
        }
        fx = args[0];
        if isinstance(fx, CtFloat) {
            return fx;
        }
        iv2 = as_ct_int(fx);
        if iv2 is not None {
            return mk_float(int_to_float(iv2));
        }
        if isinstance(fx, CtStr) {
            try {
                return mk_float(float(fx.value));
            } except ValueError {
                raise ct_exc(
                    "ValueError", f"could not convert string to float: {ct_repr(fx)}"
                );
            }
        }
        raise ct_exc(
            "TypeError",
            f"float() argument must be a string or a real number, not '{ct_type_name(
                fx
            )}'"
        );
    }
    if name == "str" {
        slots2 = _arity("str", args, kwargs, ["object", "encoding", "errors"], 0);
        if slots2[0] is CT_ABSENT {
            return mk_str("");
        }
        if slots2[1] is CT_ABSENT and slots2[2] is CT_ABSENT {
            return mk_str(ct_str(slots2[0]));
        }
        src = slots2[0];
        if not isinstance(src, CtBytes) {
            raise ct_exc(
                "TypeError",
                f"decoding to str: need a bytes-like object, {ct_type_name(src)} found"
            );
        }
        return _decode(
            src.value,
            _opt_str(slots2[1], "str() argument 'encoding' must be str, not ")
                or "utf-8",
            _opt_str(slots2[2], "str() argument 'errors' must be str, not ") or "strict"
        );
    }
    if name == "bool" {
        if kwargs or len(args) > 1 {
            raise ct_exc(
                "TypeError", f"bool expected at most 1 argument, got {len(args)}"
            );
        }
        return mk_bool(ct_truthy(args[0]) if args else False);
    }
    if name == "bytes" {
        slots3 = _arity("bytes", args, kwargs, ["source", "encoding", "errors"], 0);
        bsrc = slots3[0];
        if bsrc is None {
            return mk_bytes(b"");
        }
        if isinstance(bsrc, CtStr) {
            if slots3[1] is CT_ABSENT {
                raise ct_exc("TypeError", "string argument without an encoding");
            }
            return _encode(
                bsrc.value,
                _as_str(slots3[1], "bytes() argument 'encoding' must be str, not "),
                _opt_str(slots3[2], "bytes() argument 'errors' must be str, not ")
                    or "strict"
            );
        }
        if slots3[1] is not CT_ABSENT {
            raise ct_exc("TypeError", "encoding without a string argument");
        }
        if isinstance(bsrc, CtBytes) {
            return bsrc;
        }
        biv = as_ct_int(bsrc);
        if biv is not None {
            if int_is_neg(biv) {
                raise ct_exc("ValueError", "negative count");
            }
            if biv.mag or biv.small > 100000000 {
                raise CtError("comptime bytes() size is too large");
            }
            return mk_bytes(bytes([0] * biv.small));
        }
        vals: list[int] = [];
        for item in ct_iter(bsrc) {
            bv = _as_index(item);
            if bv.mag or bv.small < 0 or bv.small > 255 {
                raise ct_exc("ValueError", "bytes must be in range(0, 256)");
            }
            vals.append(bv.small);
        }
        return mk_bytes(bytes(vals));
    }
    if name in ("list", "tuple", "set", "frozenset") {
        if kwargs {
            raise ct_exc("TypeError", f"{name}() takes no keyword arguments");
        }
        if len(args) > 1 {
            raise ct_exc(
                "TypeError", f"{name} expected at most 1 argument, got {len(args)}"
            );
        }
        items = ct_iter(args[0]) if args else [];
        if name == "list" {
            return mk_list(items);
        }
        if name == "tuple" {
            return mk_tuple(items);
        }
        return mk_set(items, frozen=name == "frozenset");
    }
    if name == "dict" {
        if len(args) > 1 {
            raise ct_exc(
                "TypeError", f"dict expected at most 1 argument, got {len(args)}"
            );
        }
        d = mk_dict();
        if args {
            _pairs_into(d, args[0]);
        }
        for (k, v) in kwargs.items() {
            dict_set(d, mk_str(k), v);
        }
        return d;
    }
    if name == "object" {
        raise CtError("object() cannot be constructed at compile time");
    }
    if name in CT_BUILTIN_EXCEPTIONS {
        if kwargs {
            raise ct_exc("TypeError", f"{name}() takes no keyword arguments");
        }
        return CtExc(kind=name, args=args.copy());
    }
    raise CtError(f"cannot construct builtin '{name}' at compile time");
}

def _decode(data: bytes, encoding: str, errors: str) -> CtStr {
    enc = encoding.lower().replace("_", "-");
    if enc not in ("utf-8", "utf8", "ascii", "latin-1", "latin1", "iso-8859-1") {
        raise CtError(f"encoding '{encoding}' is not supported in comptime code");
    }
    if errors not in ("strict", "replace", "ignore") {
        raise CtError(f"error handler '{errors}' is not supported in comptime code");
    }
    try {
        return mk_str(data.decode(encoding, errors));
    } except UnicodeDecodeError as e {
        raise ct_exc("UnicodeDecodeError", str(e));
    }
}

def _encode(text: str, encoding: str, errors: str) -> CtBytes {
    enc = encoding.lower().replace("_", "-");
    if enc not in ("utf-8", "utf8", "ascii", "latin-1", "latin1", "iso-8859-1") {
        raise CtError(f"encoding '{encoding}' is not supported in comptime code");
    }
    if errors not in ("strict", "replace", "ignore") {
        raise CtError(f"error handler '{errors}' is not supported in comptime code");
    }
    try {
        return mk_bytes(text.encode(encoding, errors));
    } except UnicodeEncodeError as e {
        raise ct_exc("UnicodeEncodeError", str(e));
    }
}

def ct_value_attr(v: CtValue, name: str) -> CtValue {
    if ct_has_method(v, name) {
        return CtMethod(owner=ct_method_owner(v), name=name, recv=v);
    }
    iv = as_ct_int(v);
    if iv is not None {
        if name in ("real", "numerator") {
            return iv;
        }
        if name == "imag" {
            return CtInt(small=0);
        }
        if name == "denominator" {
            return CtInt(small=1);
        }
    }
    if isinstance(v, CtFloat) {
        if name == "real" {
            return v;
        }
        if name == "imag" {
            return mk_float(0.0);
        }
    }
    if isinstance(v, CtRange) {
        if name == "start" {
            return mk_int(v.start);
        }
        if name == "stop" {
            return mk_int(v.stop);
        }
        if name == "step" {
            return mk_int(v.step);
        }
    }
    if isinstance(v, CtExc) and name == "args" {
        return mk_tuple(v.args.copy());
    }
    if isinstance(v, CtModule) and v.name == "math" {
        if name in CT_MATH_CONSTS {
            return mk_float(CT_MATH_CONSTS[name]);
        }
        if name in CT_MATH_FUNCS {
            return CtBuiltin(name="math." + name);
        }
        raise CtError(f"math.{name} is not available in comptime code");
    }
    raise CtError(f"'{ct_type_name(v)}' has no attribute '{name}'");
}

def ct_type_attr(type_name: str, attr: str) -> CtValue {
    if f"{type_name}.{attr}" in CT_STATIC_METHODS {
        return CtMethod(owner=type_name, name=attr, recv=None);
    }
    if type_name in CT_METHODS and attr in CT_METHODS[type_name] {
        return CtMethod(owner=type_name, name=attr, recv=None);
    }
    raise CtError(f"{type_name} has no comptime attribute '{attr}'");
}

def ct_call_method_value(
    ev: CtCaller, m: CtMethod, args: list[CtValue], kwargs: dict[str, CtValue]
) -> CtValue {
    if m.recv is not None {
        return ct_call_method(ev, m.recv, m.name, args, kwargs);
    }
    qual = f"{m.owner}.{m.name}";
    if qual == "dict.fromkeys" {
        slots = _arity("fromkeys", args, kwargs, ["iterable", "value"], 1);
        d = mk_dict();
        fill = slots[1] if slots[1] is not CT_ABSENT else CT_NONE;
        for k in ct_iter(slots[0]) {
            dict_set(d, k, fill);
        }
        return d;
    }
    if qual == "bytes.fromhex" {
        text = _as_str(
            _one_arg("fromhex", args, kwargs), "fromhex() argument must be str, not "
        );
        try {
            return mk_bytes(bytes.fromhex(text));
        } except ValueError as e {
            raise ct_exc("ValueError", str(e));
        }
    }
    if not args {
        raise ct_exc(
            "TypeError", f"unbound method {m.owner}.{m.name}() needs an argument"
        );
    }
    recv = args[0];
    if ct_method_owner(recv) != m.owner
        and not (m.owner == "frozenset" and isinstance(recv, CtSet)) {
        raise ct_exc(
            "TypeError",
            f"descriptor '{m.name}' for '{m.owner}' objects doesn't apply to a '{ct_type_name(
                recv
            )}' object"
        );
    }
    return ct_call_method(ev, recv, m.name, args[1:], kwargs);
}

def ct_call_method(
    ev: CtCaller,
    recv: CtValue,
    name: str,
    args: list[CtValue],
    kwargs: dict[str, CtValue]
) -> CtValue {
    if not ct_has_method(recv, name) {
        raise CtError(f"'{ct_type_name(recv)}' has no callable attribute '{name}'");
    }
    try {
        if isinstance(recv, CtStr) {
            return _str_method(recv, name, args, kwargs);
        }
        if isinstance(recv, CtBytes) {
            return _bytes_method(recv, name, args, kwargs);
        }
        if isinstance(recv, CtList) {
            return _list_method(ev, recv, name, args, kwargs);
        }
        if isinstance(recv, CtTuple) {
            return _seq_index_count(recv.items, "tuple", name, args, kwargs);
        }
        if isinstance(recv, CtDict) {
            return _dict_method(recv, name, args, kwargs);
        }
        if isinstance(recv, CtSet) {
            return _set_method(recv, name, args, kwargs);
        }
        if isinstance(recv, CtRange) {
            return _seq_index_count(ct_iter(recv), "range", name, args, kwargs);
        }
        if isinstance(recv, CtFloat) {
            return _float_method(recv, name, args, kwargs);
        }
        iv = as_ct_int(recv);
        if iv is not None {
            return _int_method(iv, name, args, kwargs);
        }
    } except ValueError as e {
        raise ct_exc("ValueError", str(e));
    } except OverflowError as e {
        raise ct_exc("OverflowError", str(e));
    }
    raise CtError(f"'{ct_type_name(recv)}' has no callable attribute '{name}'");
}

def _str_method(
    recv: CtStr, name: str, args: list[CtValue], kwargs: dict[str, CtValue]
) -> CtValue {
    s = recv.value;
    if name == "format" {
        return mk_str(ct_str_format(s, args, kwargs));
    }
    if name in ("upper", "lower", "casefold", "capitalize", "title", "swapcase") {
        _no_args(name, args, kwargs);
        if name == "upper" {
            return mk_str(s.upper());
        }
        if name == "lower" {
            return mk_str(s.lower());
        }
        if name == "casefold" {
            return mk_str(s.casefold());
        }
        if name == "capitalize" {
            return mk_str(s.capitalize());
        }
        if name == "title" {
            return mk_str(s.title());
        }
        return mk_str(s.swapcase());
    }
    if name
        in (
            "isdigit",
            "isalpha",
            "isalnum",
            "isspace",
            "isupper",
            "islower",
            "isidentifier",
            "isnumeric",
            "isdecimal",
            "istitle",
            "isascii",
            "isprintable"
        ) {
        _no_args(name, args, kwargs);
        if name == "isdigit" {
            return mk_bool(s.isdigit());
        }
        if name == "isalpha" {
            return mk_bool(s.isalpha());
        }
        if name == "isalnum" {
            return mk_bool(s.isalnum());
        }
        if name == "isspace" {
            return mk_bool(s.isspace());
        }
        if name == "isupper" {
            return mk_bool(s.isupper());
        }
        if name == "islower" {
            return mk_bool(s.islower());
        }
        if name == "isidentifier" {
            return mk_bool(s.isidentifier());
        }
        if name == "isnumeric" {
            return mk_bool(s.isnumeric());
        }
        if name == "isdecimal" {
            return mk_bool(s.isdecimal());
        }
        if name == "istitle" {
            return mk_bool(s.istitle());
        }
        if name == "isascii" {
            return mk_bool(s.isascii());
        }
        return mk_bool(s.isprintable());
    }
    if name in ("strip", "lstrip", "rstrip") {
        slots = _arity(name, args, kwargs, ["chars"], 0);
        chars = _opt_str(slots[0], f"{name} arg must be None or str, not ");
        if chars is None {
            if name == "strip" {
                return mk_str(s.strip());
            }
            if name == "lstrip" {
                return mk_str(s.lstrip());
            }
            return mk_str(s.rstrip());
        }
        if name == "strip" {
            return mk_str(s.strip(chars));
        }
        if name == "lstrip" {
            return mk_str(s.lstrip(chars));
        }
        return mk_str(s.rstrip(chars));
    }
    if name in ("split", "rsplit") {
        slots2 = _arity(name, args, kwargs, ["sep", "maxsplit"], 0);
        sep = _opt_str(slots2[0], "must be str or None, not ");
        maxsplit = _opt_small(slots2[1]);
        limit = maxsplit if maxsplit is not None else -1;
        if sep is None {
            return _str_list(str_split_ws(s, limit, name == "rsplit"));
        }
        if sep == "" {
            raise ct_exc("ValueError", "empty separator");
        }
        return _str_list(str_split_sep(s, sep, limit, name == "rsplit"));
    }
    if name == "splitlines" {
        slots3 = _arity(name, args, kwargs, ["keepends"], 0);
        keep = ct_truthy(slots3[0]) if slots3[0] is not CT_ABSENT else False;
        return _str_list(s.splitlines(keep));
    }
    if name == "join" {
        parts: list[str] = [];
        for (i, item) in enumerate(ct_iter(_one_arg("join", args, kwargs))) {
            if not isinstance(item, CtStr) {
                raise ct_exc(
                    "TypeError",
                    f"sequence item {i}: expected str instance, {ct_type_name(
                        item
                    )} found"
                );
            }
            parts.append(item.value);
        }
        return mk_str(s.join(parts));
    }
    if name == "replace" {
        slots4 = _arity(name, args, kwargs, ["old", "new", "count"], 2);
        old = _as_str(slots4[0], "replace() argument 1 must be str, not ");
        new = _as_str(slots4[1], "replace() argument 2 must be str, not ");
        count = _opt_small(slots4[2]);
        return mk_str(s.replace(old, new, count if count is not None else -1));
    }
    if name in ("startswith", "endswith") {
        slots5 = _arity(name, args, kwargs, ["prefix", "start", "end"], 1);
        start = _opt_small(slots5[1]);
        end = _opt_small(slots5[2]);
        cands: list[str] = [];
        probe = slots5[0];
        if isinstance(probe, CtTuple) {
            for p in probe.items {
                cands.append(
                    _as_str(p, f"tuple for {name} must only contain str, not ")
                );
            }
        } elif isinstance(probe, CtStr) {
            cands.append(probe.value);
        } else {
            raise ct_exc(
                "TypeError",
                f"{name} first arg must be str or a tuple of str, not {ct_type_name(
                    probe
                )}"
            );
        }
        for c in cands {
            if str_tailmatch(s, c, start, end, name == "endswith") {
                return CT_TRUE;
            }
        }
        return CT_FALSE;
    }
    if name in ("find", "rfind", "index", "rindex", "count") {
        slots6 = _arity(name, args, kwargs, ["sub", "start", "end"], 1);
        sub = _as_str(slots6[0], "must be str, not ");
        (lo, hi) = adjust_indices(len(s), _opt_small(slots6[1]), _opt_small(slots6[2]));
        if name == "count" {
            if hi - lo < len(sub) {
                return mk_int(0);
            }
            return mk_int(s[lo:hi].count(sub));
        }
        pos = -1;
        if hi - lo >= len(sub) {
            window = s[lo:hi];
            found = window.find(sub);
            if name in ("rfind", "rindex") {
                found = window.rfind(sub);
            }
            if found >= 0 {
                pos = found + lo;
            }
        }
        if pos < 0 and name in ("index", "rindex") {
            raise ct_exc("ValueError", "substring not found");
        }
        return mk_int(pos);
    }
    if name in ("center", "ljust", "rjust") {
        slots7 = _arity(name, args, kwargs, ["width", "fillchar"], 1);
        width = _as_small(slots7[0]);
        fill = _opt_str(
            slots7[1], "The fill character must be a unicode character, not "
        )
            or " ";
        if len(fill) != 1 {
            raise ct_exc(
                "TypeError", "The fill character must be exactly one character long"
            );
        }
        if name == "center" {
            return mk_str(s.center(width, fill));
        }
        if name == "ljust" {
            return mk_str(s.ljust(width, fill));
        }
        return mk_str(s.rjust(width, fill));
    }
    if name == "zfill" {
        return mk_str(s.zfill(_as_small(_one_arg("zfill", args, kwargs))));
    }
    if name in ("partition", "rpartition") {
        sep2 = _as_str(_one_arg(name, args, kwargs), "must be str, not ");
        if not sep2 {
            raise ct_exc("ValueError", "empty separator");
        }
        (a, b, c2) = s.partition(sep2) if name == "partition" else s.rpartition(sep2);
        return mk_tuple([mk_str(a), mk_str(b), mk_str(c2)]);
    }
    if name == "encode" {
        slots8 = _arity(name, args, kwargs, ["encoding", "errors"], 0);
        return _encode(
            s,
            _opt_str(slots8[0], "encode() argument 'encoding' must be str, not ")
                or "utf-8",
            _opt_str(slots8[1], "encode() argument 'errors' must be str, not ")
                or "strict"
        );
    }
    if name in ("removeprefix", "removesuffix") {
        affix = _as_str(
            _one_arg(name, args, kwargs), f"{name}() argument must be str, not "
        );
        if name == "removeprefix" {
            return mk_str(s.removeprefix(affix));
        }
        return mk_str(s.removesuffix(affix));
    }
    if name == "expandtabs" {
        slots9 = _arity(name, args, kwargs, ["tabsize"], 0);
        tabsize = _opt_small(slots9[0]);
        return mk_str(s.expandtabs(tabsize if tabsize is not None else 8));
    }
    raise CtError(f"'str' has no callable attribute '{name}'");
}

def _as_bytes_arg(v: CtValue) -> bytes {
    if isinstance(v, CtBytes) {
        return v.value;
    }
    raise ct_exc(
        "TypeError", f"a bytes-like object is required, not '{ct_type_name(v)}'"
    );
}

def _bytes_method(
    recv: CtBytes, name: str, args: list[CtValue], kwargs: dict[str, CtValue]
) -> CtValue {
    b = recv.value;
    if name == "decode" {
        slots = _arity(name, args, kwargs, ["encoding", "errors"], 0);
        return _decode(
            b,
            _opt_str(slots[0], "decode() argument 'encoding' must be str, not ")
                or "utf-8",
            _opt_str(slots[1], "decode() argument 'errors' must be str, not ")
                or "strict"
        );
    }
    if name == "hex" {
        _no_args(name, args, kwargs);
        return mk_str(b.hex());
    }
    if name in ("upper", "lower") {
        _no_args(name, args, kwargs);
        if name == "upper" {
            return mk_bytes(b.upper());
        }
        return mk_bytes(b.lower());
    }
    if name in ("startswith", "endswith") {
        probe = _as_bytes_arg(_one_arg(name, args, kwargs));
        if name == "startswith" {
            return mk_bool(b.startswith(probe));
        }
        return mk_bool(b.endswith(probe));
    }
    if name in ("find", "rfind", "index", "count") {
        sub = _as_bytes_arg(_one_arg(name, args, kwargs));
        if name == "count" {
            return mk_int(b.count(sub));
        }
        pos = bytes_find(b, sub, name == "rfind");
        if name == "index" and pos < 0 {
            raise ct_exc("ValueError", "subsection not found");
        }
        return mk_int(pos);
    }
    if name == "replace" {
        slots2 = _arity(name, args, kwargs, ["old", "new", "count"], 2);
        cnt = _opt_small(slots2[2]);
        return mk_bytes(
            b.replace(
                _as_bytes_arg(slots2[0]),
                _as_bytes_arg(slots2[1]),
                cnt if cnt is not None else -1
            )
        );
    }
    if name in ("strip", "lstrip", "rstrip") {
        slots3 = _arity(name, args, kwargs, ["bytes"], 0);
        chars: (bytes | None) = None;
        if slots3[0] is not CT_ABSENT and not isinstance(slots3[0], CtNone) {
            chars = _as_bytes_arg(slots3[0]);
        }
        if name == "strip" {
            return mk_bytes(b.strip(chars));
        }
        if name == "lstrip" {
            return mk_bytes(b.lstrip(chars));
        }
        return mk_bytes(b.rstrip(chars));
    }
    if name == "split" {
        slots4 = _arity(name, args, kwargs, ["sep", "maxsplit"], 0);
        sep: (bytes | None) = None;
        if slots4[0] is not CT_ABSENT and not isinstance(slots4[0], CtNone) {
            sep = _as_bytes_arg(slots4[0]);
            if not sep {
                raise ct_exc("ValueError", "empty separator");
            }
        }
        ms = _opt_small(slots4[1]);
        return mk_list(
            [mk_bytes(x) for x in b.split(sep, ms if ms is not None else -1)]
        );
    }
    if name == "join" {
        parts: list[bytes] = [];
        for (i, item) in enumerate(ct_iter(_one_arg("join", args, kwargs))) {
            if not isinstance(item, CtBytes) {
                raise ct_exc(
                    "TypeError",
                    f"sequence item {i}: expected a bytes-like object, {ct_type_name(
                        item
                    )} found"
                );
            }
            parts.append(item.value);
        }
        return mk_bytes(b.join(parts));
    }
    raise CtError(f"'bytes' has no callable attribute '{name}'");
}

def _seq_index_count(
    items: list[CtValue],
    owner: str,
    name: str,
    args: list[CtValue],
    kwargs: dict[str, CtValue]
) -> CtValue {
    if name == "count" {
        target = _one_arg("count", args, kwargs);
        n = 0;
        for x in items {
            if ct_same_or_eq(x, target) {
                n += 1;
            }
        }
        return mk_int(n);
    }
    slots = _arity("index", args, kwargs, ["value", "start", "stop"], 1);
    (start, stop, _, _) = slice_indices(len(items), slots[1], slots[2], None);
    for i in range(start, stop) {
        if ct_same_or_eq(items[i], slots[0]) {
            return mk_int(i);
        }
    }
    if owner == "range" {
        raise ct_exc("ValueError", f"{ct_repr(slots[0])} is not in range");
    }
    raise ct_exc("ValueError", f"{owner}.index(x): x not in {owner}");
}

def _list_method(
    ev: CtCaller,
    recv: CtList,
    name: str,
    args: list[CtValue],
    kwargs: dict[str, CtValue]
) -> CtValue {
    items = recv.items;
    if name == "append" {
        items.append(_one_arg("append", args, kwargs));
        return CT_NONE;
    }
    if name == "extend" {
        items.extend(ct_iter(_one_arg("extend", args, kwargs)));
        return CT_NONE;
    }
    if name == "insert" {
        if len(args) != 2 or kwargs {
            raise ct_exc("TypeError", f"insert expected 2 arguments, got {len(args)}");
        }
        items.insert(_as_small(args[0]), args[1]);
        return CT_NONE;
    }
    if name == "pop" {
        slots = _arity("pop", args, kwargs, ["index"], 0);
        if not items {
            raise ct_exc("IndexError", "pop from empty list");
        }
        idx = _as_small(slots[0]) if slots[0] is not CT_ABSENT else -1;
        if idx < 0 {
            idx += len(items);
        }
        if idx < 0 or idx >= len(items) {
            raise ct_exc("IndexError", "pop index out of range");
        }
        return items.pop(idx);
    }
    if name == "remove" {
        target = _one_arg("remove", args, kwargs);
        for (i, x) in enumerate(items) {
            if ct_same_or_eq(x, target) {
                items.pop(i);
                return CT_NONE;
            }
        }
        raise ct_exc("ValueError", "list.remove(x): x not in list");
    }
    if name in ("index", "count") {
        return _seq_index_count(items, "list", name, args, kwargs);
    }
    if name == "reverse" {
        _no_args(name, args, kwargs);
        items.reverse();
        return CT_NONE;
    }
    if name == "sort" {
        if args {
            raise ct_exc("TypeError", "sort() takes no positional arguments");
        }
        key: (CtValue | None) = None;
        rev = False;
        for (k, v) in kwargs.items() {
            if k == "key" {
                key = v;
            } elif k == "reverse" {
                rev = ct_truthy(v);
            } else {
                raise ct_exc(
                    "TypeError", f"sort() got an unexpected keyword argument '{k}'"
                );
            }
        }
        recv.items = ct_sort(ev, items.copy(), key, rev);
        return CT_NONE;
    }
    if name == "copy" {
        _no_args(name, args, kwargs);
        return mk_list(items.copy());
    }
    if name == "clear" {
        _no_args(name, args, kwargs);
        recv.items = [];
        return CT_NONE;
    }
    raise CtError(f"'list' has no callable attribute '{name}'");
}

def _dict_method(
    recv: CtDict, name: str, args: list[CtValue], kwargs: dict[str, CtValue]
) -> CtValue {
    if name == "get" {
        slots = _arity("get", args, kwargs, ["key", "default"], 1);
        got = dict_get(recv, slots[0]);
        if got is not None {
            return got;
        }
        return slots[1] if slots[1] is not CT_ABSENT else CT_NONE;
    }
    if name in ("keys", "values", "items") {
        _no_args(name, args, kwargs);
        return CtView(kind=name, source=recv);
    }
    if name == "pop" {
        if kwargs or not args or len(args) > 2 {
            raise ct_exc(
                "TypeError", f"pop expected at least 1 argument, got {len(args)}"
            );
        }
        got2 = dict_get(recv, args[0]);
        if got2 is None {
            if len(args) == 2 {
                return args[1];
            }
            raise ct_exc_value("KeyError", args[0]);
        }
        dict_delete(recv, args[0]);
        return got2;
    }
    if name == "popitem" {
        _no_args(name, args, kwargs);
        if not recv.keys {
            raise ct_exc("KeyError", "popitem(): dictionary is empty");
        }
        k = recv.keys[-1];
        v = recv.vals[-1];
        dict_delete(recv, k);
        return mk_tuple([k, v]);
    }
    if name == "setdefault" {
        slots2 = _arity("setdefault", args, kwargs, ["key", "default"], 1);
        got3 = dict_get(recv, slots2[0]);
        if got3 is not None {
            return got3;
        }
        dflt = slots2[1] if slots2[1] is not CT_ABSENT else CT_NONE;
        dict_set(recv, slots2[0], dflt);
        return dflt;
    }
    if name == "update" {
        if len(args) > 1 {
            raise ct_exc(
                "TypeError", f"update expected at most 1 argument, got {len(args)}"
            );
        }
        if args {
            _pairs_into(recv, args[0]);
        }
        for (k2, v2) in kwargs.items() {
            dict_set(recv, mk_str(k2), v2);
        }
        return CT_NONE;
    }
    if name == "copy" {
        _no_args(name, args, kwargs);
        return dict_copy(recv);
    }
    if name == "clear" {
        _no_args(name, args, kwargs);
        recv.keys = [];
        recv.vals = [];
        recv.index = {};
        return CT_NONE;
    }
    raise CtError(f"'dict' has no callable attribute '{name}'");
}

def _as_set(v: CtValue) -> CtSet {
    if isinstance(v, CtSet) {
        return v;
    }
    return mk_set(ct_iter(v));
}

def _set_method(
    recv: CtSet, name: str, args: list[CtValue], kwargs: dict[str, CtValue]
) -> CtValue {
    if kwargs {
        raise ct_exc("TypeError", f"{name}() takes no keyword arguments");
    }
    if name == "add" {
        set_add(recv, _one_arg("add", args, kwargs));
        return CT_NONE;
    }
    if name == "discard" {
        set_discard(recv, _one_arg("discard", args, kwargs));
        return CT_NONE;
    }
    if name == "remove" {
        item = _one_arg("remove", args, kwargs);
        if not set_discard(recv, item) {
            raise ct_exc_value("KeyError", item);
        }
        return CT_NONE;
    }
    if name == "pop" {
        _no_args(name, args, kwargs);
        if not recv.items {
            raise ct_exc("KeyError", "pop from an empty set");
        }
        first = recv.items[0];
        set_discard(recv, first);
        return first;
    }
    if name == "clear" {
        _no_args(name, args, kwargs);
        recv.items = [];
        recv.index = {};
        return CT_NONE;
    }
    if name == "copy" {
        _no_args(name, args, kwargs);
        return mk_set(recv.items.copy(), frozen=recv.frozen);
    }
    if name in ("union", "intersection", "difference") {
        sym = "|" if name == "union" else ("&" if name == "intersection" else "-");
        acc = mk_set(recv.items.copy(), frozen=recv.frozen);
        for other in args {
            acc = set_algebra(sym, acc, _as_set(other), recv.frozen);
        }
        return acc;
    }
    if name == "symmetric_difference" {
        return set_algebra(
            "^", recv, _as_set(_one_arg(name, args, kwargs)), recv.frozen
        );
    }
    if name
        in (
            "update",
            "intersection_update",
            "difference_update",
            "symmetric_difference_update"
        ) {
        sym2 = "|";
        if name == "intersection_update" {
            sym2 = "&";
        } elif name == "difference_update" {
            sym2 = "-";
        } elif name == "symmetric_difference_update" {
            sym2 = "^";
        }
        cur = recv;
        for other in args {
            cur = set_algebra(sym2, cur, _as_set(other), False);
        }
        recv.items = cur.items;
        recv.index = cur.index;
        return CT_NONE;
    }
    other2 = _as_set(_one_arg(name, args, kwargs));
    if name == "issubset" {
        return mk_bool(ct_order("<=", recv, other2));
    }
    if name == "issuperset" {
        return mk_bool(ct_order(">=", recv, other2));
    }
    if name == "isdisjoint" {
        for item in recv.items {
            if set_has(other2, item) {
                return CT_FALSE;
            }
        }
        return CT_TRUE;
    }
    raise CtError(f"'set' has no callable attribute '{name}'");
}

def _int_method(
    recv: CtInt, name: str, args: list[CtValue], kwargs: dict[str, CtValue]
) -> CtValue {
    _no_args(name, args, kwargs);
    if name == "bit_length" {
        return mk_int(int_bit_length(recv));
    }
    if name == "bit_count" {
        (_, m) = int_sign_mag(recv);
        total = 0;
        for limb in m {
            x = limb;
            while x {
                total += x & 1;
                x = x >> 1;
            }
        }
        return mk_int(total);
    }
    if name == "is_integer" {
        return CT_TRUE;
    }
    if name == "conjugate" {
        return recv;
    }
    return mk_tuple([recv, CtInt(small=1)]);
}

def _float_method(
    recv: CtFloat, name: str, args: list[CtValue], kwargs: dict[str, CtValue]
) -> CtValue {
    _no_args(name, args, kwargs);
    f = recv.value;
    if name == "is_integer" {
        return mk_bool(f - f == 0.0 and float_floor(f) == f);
    }
    if name == "conjugate" {
        return recv;
    }
    if f != f {
        raise ct_exc("ValueError", "cannot convert NaN to integer ratio");
    }
    if f - f != 0.0 {
        raise ct_exc("OverflowError", "cannot convert Infinity to integer ratio");
    }
    (m, e) = math.frexp(f);
    for _ in range(300) {
        if m == float_floor(m) {
            break;
        }
        m *= 2.0;
        e -= 1;
    }
    num = float_to_ct_int(m);
    den = CtInt(small=1);
    if e > 0 {
        num = int_mul(num, _pow2(e));
    } else {
        den = _pow2(-e);
    }
    return mk_tuple([num, den]);
}

def _pow2(e: int) -> CtInt {
    return mk_int_mag(False, mag_shl([1], e));
}

def _math_float(v: CtValue) -> float {
    if isinstance(v, CtFloat) {
        return v.value;
    }
    iv = as_ct_int(v);
    if iv is not None {
        return int_to_float(iv);
    }
    raise ct_exc("TypeError", f"must be real number, not {ct_type_name(v)}");
}

def int_frexp(a: CtInt) -> tuple[float, int] {
    (_, m) = int_sign_mag(a);
    n = mag_bit_length(m);
    if n <= 55 {
        return math.frexp(float(mag_to_int(m)));
    }
    shift = n - 55;
    q = mag_to_int(mag_shr(m, shift));
    if mag_low_bits_nonzero(m, shift) {
        q = q | 1;
    }
    corrections = [0, -1, -2, 1, 0, -1, 2, 1];
    q += corrections[q & 7];
    x = math.ldexp(float(q), -55);
    if x == 1.0 {
        return (0.5, n + 1);
    }
    return (x, n);
}

def _log_of(v: CtValue, which: str) -> float {
    iv = as_ct_int(v);
    if iv is not None {
        if int_is_neg(iv) or int_is_zero(iv) {
            raise ct_exc("ValueError", "expected a positive input");
        }
        if not iv.mag or mag_bit_length(iv.mag) <= 1000 {
            return _log_raw(int_to_float(iv), which);
        }
        (x, e) = int_frexp(iv);
        return _log_raw(x, which) + _log_raw(2.0, which) * float(e);
    }
    f = _math_float(v);
    if f != f {
        return f;
    }
    if f <= 0.0 {
        raise ct_exc("ValueError", f"expected a positive input, got {repr(f)}");
    }
    return _log_raw(f, which);
}

def _log_raw(x: float, which: str) -> float {
    if which == "log2" {
        return math.log2(x);
    }
    if which == "log10" {
        return math.log10(x);
    }
    return math.log(x);
}

def _range_error(r: float, inputs_finite: bool) -> float {
    if inputs_finite and r - r != 0.0 and r == r {
        raise ct_exc("OverflowError", "math range error");
    }
    return r;
}

def _finite(x: float) -> bool {
    return x - x == 0.0;
}

def _math_int_arg(v: CtValue) -> CtInt {
    return _as_index(v);
}

def ct_call_math(
    name: str, args: list[CtValue], kwargs: dict[str, CtValue]
) -> CtValue {
    if name in ("log", "log2", "log10") {
        return _math_log(name, args, kwargs);
    }
    if name in ("gcd", "lcm", "factorial", "isqrt", "comb", "perm") {
        return _math_integer(name, args, kwargs);
    }
    if name in ("prod", "fsum") {
        return _math_reduce(name, args, kwargs);
    }
    if name in ("floor", "ceil", "trunc", "isnan", "isinf", "isfinite", "isclose") {
        return _math_classify(name, args, kwargs);
    }
    if name in ("hypot", "ldexp", "frexp", "modf") {
        return _math_parts(name, args, kwargs);
    }
    if name in ("atan2", "copysign", "fmod", "remainder", "pow") {
        if len(args) != 2 or kwargs {
            raise ct_exc("TypeError", f"{name} expected 2 arguments, got {len(args)}");
        }
        x2 = _math_float(args[0]);
        y2 = _math_float(args[1]);
        return mk_float(_math2(name, x2, y2));
    }
    return mk_float(_math1(name, _math_float(_one_arg(name, args, kwargs))));
}


def _math_log(name: str, args: list[CtValue], kwargs: dict[str, CtValue]) -> CtValue {
    if name in ("log", "log2", "log10") {
        if kwargs {
            raise ct_exc("TypeError", f"{name}() takes no keyword arguments");
        }
        if name == "log" and len(args) == 2 {
            num = _log_of(args[0], "log");
            den = _log_of(args[1], "log");
            if den == 0.0 {
                raise ct_exc("ZeroDivisionError", "division by zero");
            }
            return mk_float(num / den);
        }
        return mk_float(_log_of(_one_arg(name, args, kwargs), name));
    }
    raise CtError(f"math.{name} is not available in comptime code");
}

def _math_integer(
    name: str, args: list[CtValue], kwargs: dict[str, CtValue]
) -> CtValue {
    if name in ("gcd", "lcm") {
        if kwargs {
            raise ct_exc("TypeError", f"{name}() takes no keyword arguments");
        }
        acc = CtInt(small=0 if name == "gcd" else 1);
        for a in args {
            (_, am) = int_sign_mag(_math_int_arg(a));
            (_, cm) = int_sign_mag(acc);
            if name == "gcd" {
                acc = mk_int_mag(False, mag_gcd(cm, am));
            } elif not am or not cm {
                acc = CtInt(small=0);
            } else {
                g = mag_gcd(cm, am);
                (q, _) = mag_divmod(cm, g);
                acc = mk_int_mag(False, mag_mul(q, am));
            }
        }
        return acc;
    }
    if name == "factorial" {
        n = _math_int_arg(_one_arg(name, args, kwargs));
        if int_is_neg(n) {
            raise ct_exc("ValueError", "factorial() not defined for negative values");
        }
        return _factorial(n);
    }
    if name == "isqrt" {
        n2 = _math_int_arg(_one_arg(name, args, kwargs));
        if int_is_neg(n2) {
            raise ct_exc("ValueError", "isqrt() argument must be nonnegative");
        }
        (_, nm) = int_sign_mag(n2);
        return mk_int_mag(False, mag_isqrt(nm));
    }
    if name in ("comb", "perm") {
        if kwargs or not args or len(args) > 2 or (name == "comb" and len(args) != 2) {
            raise ct_exc("TypeError", f"{name} expected 2 arguments, got {len(args)}");
        }
        n3 = _math_int_arg(args[0]);
        if name == "perm" and len(args) == 1 {
            if int_is_neg(n3) {
                raise ct_exc(
                    "ValueError", "factorial() not defined for negative values"
                );
            }
            return _factorial(n3);
        }
        k = _math_int_arg(args[1]);
        if int_is_neg(n3) {
            raise ct_exc("ValueError", "n must be a non-negative integer");
        }
        if int_is_neg(k) {
            raise ct_exc("ValueError", "k must be a non-negative integer");
        }
        if int_cmp(k, n3) > 0 {
            return CtInt(small=0);
        }
        if k.mag {
            raise CtError("comptime comb/perm argument is too large");
        }
        kk = k.small;
        if name == "comb" {
            nk = int_sub(n3, k);
            if not nk.mag and nk.small < kk {
                kk = nk.small;
            }
        }
        if kk > CT_FACTORIAL_LIMIT {
            raise CtError("comptime comb/perm argument is too large");
        }
        result = CtInt(small=1);
        for i in range(kk) {
            result = int_mul(result, int_sub(n3, CtInt(small=i)));
            if name == "comb" {
                (result, _) = int_divmod(result, CtInt(small=i + 1));
            }
        }
        return result;
    }
    raise CtError(f"math.{name} is not available in comptime code");
}

def _math_reduce(
    name: str, args: list[CtValue], kwargs: dict[str, CtValue]
) -> CtValue {
    if name == "prod" {
        slots = _arity("prod", args, {}, ["iterable"], 1);
        acc2: CtValue = CtInt(small=1);
        for (k2, v2) in kwargs.items() {
            if k2 != "start" {
                raise ct_exc(
                    "TypeError", f"prod() got an unexpected keyword argument '{k2}'"
                );
            }
            acc2 = v2;
        }
        for item in ct_iter(slots[0]) {
            acc2 = ct_binary("*", acc2, item);
        }
        return acc2;
    }
    if name == "fsum" {
        vals: list[float] = [
            _math_float(x) for x in ct_iter(_one_arg(name, args, kwargs))
        ];
        try {
            return mk_float(math.fsum(vals));
        } except OverflowError as e {
            raise ct_exc("OverflowError", str(e));
        } except ValueError as e {
            raise ct_exc("ValueError", str(e));
        }
    }
    raise CtError(f"math.{name} is not available in comptime code");
}

def _math_classify(
    name: str, args: list[CtValue], kwargs: dict[str, CtValue]
) -> CtValue {
    if name in ("floor", "ceil", "trunc") {
        v3 = _one_arg(name, args, kwargs);
        iv = as_ct_int(v3);
        if iv is not None {
            return iv;
        }
        f = _math_float(v3);
        if name == "floor" {
            return float_to_ct_int(float_floor(f));
        }
        if name == "ceil" {
            return float_to_ct_int(float_ceil(f));
        }
        return float_to_ct_int(f);
    }
    if name in ("isnan", "isinf", "isfinite") {
        f2 = _math_float(_one_arg(name, args, kwargs));
        if name == "isnan" {
            return mk_bool(f2 != f2);
        }
        if name == "isinf" {
            return mk_bool(f2 == f2 and f2 - f2 != 0.0);
        }
        return mk_bool(f2 - f2 == 0.0);
    }
    if name == "isclose" {
        slots2 = _arity("isclose", args, kwargs, ["a", "b", "rel_tol", "abs_tol"], 2);
        a = _math_float(slots2[0]);
        b = _math_float(slots2[1]);
        rel = _math_float(slots2[2]) if slots2[2] is not CT_ABSENT else 1e-09;
        abs_tol = _math_float(slots2[3]) if slots2[3] is not CT_ABSENT else 0.0;
        if rel < 0.0 or abs_tol < 0.0 {
            raise ct_exc("ValueError", "tolerances must be non-negative");
        }
        return mk_bool(math.isclose(a, b, rel_tol=rel, abs_tol=abs_tol));
    }
    raise CtError(f"math.{name} is not available in comptime code");
}

def _math_parts(name: str, args: list[CtValue], kwargs: dict[str, CtValue]) -> CtValue {
    if name == "hypot" {
        if kwargs {
            raise ct_exc("TypeError", "hypot() takes no keyword arguments");
        }
        hv: list[float] = [_math_float(x) for x in args];
        if not hv {
            return mk_float(0.0);
        }
        if len(hv) == 1 {
            return mk_float(abs(hv[0]));
        }
        if len(hv) == 2 {
            return mk_float(math.hypot(hv[0], hv[1]));
        }
        if len(hv) == 3 {
            return mk_float(math.hypot(hv[0], hv[1], hv[2]));
        }
        raise CtError(
            "math.hypot() with more than three coordinates is not supported in comptime code"
        );
    }
    if name == "ldexp" {
        if len(args) != 2 or kwargs {
            raise ct_exc("TypeError", f"ldexp expected 2 arguments, got {len(args)}");
        }
        x = _math_float(args[0]);
        ei = as_ct_int(args[1]);
        if ei is None {
            raise ct_exc("TypeError", "Expected an int as second argument to ldexp.");
        }
        if x == 0.0 or not _finite(x) {
            return mk_float(x);
        }
        e = ei.small if not ei.mag else (-100000 if ei.neg else 100000);
        e = max(-100000, min(100000, e));
        try {
            r = math.ldexp(x, max(-2200, min(2200, e)));
        } except OverflowError {
            raise ct_exc("OverflowError", "math range error");
        }
        return mk_float(_range_error(r, True));
    }
    if name == "frexp" {
        f3 = _math_float(_one_arg(name, args, kwargs));
        (fm, fe) = math.frexp(f3);
        return mk_tuple([mk_float(fm), mk_int(fe)]);
    }
    if name == "modf" {
        f4 = _math_float(_one_arg(name, args, kwargs));
        (frac, whole) = math.modf(f4);
        return mk_tuple([mk_float(frac), mk_float(whole)]);
    }
    raise CtError(f"math.{name} is not available in comptime code");
}

def _factorial(n: CtInt) -> CtInt {
    if n.mag or n.small > CT_FACTORIAL_LIMIT {
        raise CtError("comptime factorial argument is too large");
    }
    result = CtInt(small=1);
    for i in range(2, n.small + 1) {
        result = int_mul(result, CtInt(small=i));
    }
    return result;
}

def _math2(name: str, x: float, y: float) -> float {
    if name == "atan2" {
        return math.atan2(x, y);
    }
    if name == "copysign" {
        return math.copysign(x, y);
    }
    if name in ("fmod", "remainder") {
        if x != x or y != y {
            return float("nan");
        }
        if not _finite(x) or y == 0.0 {
            raise ct_exc("ValueError", "math domain error");
        }
        if name == "fmod" {
            return math.fmod(x, y) if _finite(y) else x;
        }
        return math.remainder(x, y) if _finite(y) else x;
    }
    if x == 0.0 and y < 0.0 and _finite(y) {
        raise ct_exc("ValueError", "math domain error");
    }
    if x < 0.0 and _finite(x) and _finite(y) and float_floor(y) != y {
        raise ct_exc("ValueError", "math domain error");
    }
    try {
        r = math.pow(x, y);
    } except OverflowError {
        raise ct_exc("OverflowError", "math range error");
    } except ValueError {
        raise ct_exc("ValueError", "math domain error");
    }
    return _range_error(r, _finite(x) and _finite(y));
}

def _math1(name: str, x: float) -> float {
    got = repr(x);
    finite = _finite(x);
    if name == "sqrt" {
        if x < 0.0 {
            raise ct_exc("ValueError", f"expected a nonnegative input, got {got}");
        }
        return math.sqrt(x);
    }
    if name == "log1p" {
        if x <= -1.0 {
            raise ct_exc("ValueError", f"expected argument value > -1, got {got}");
        }
        return math.log1p(x);
    }
    if name in ("asin", "acos") {
        if x == x and (x < -1.0 or x > 1.0) {
            raise ct_exc(
                "ValueError", f"expected a number in range from -1 up to 1, got {got}"
            );
        }
        return math.asin(x) if name == "asin" else math.acos(x);
    }
    if name == "atanh" {
        if x == x and (x <= -1.0 or x >= 1.0) {
            raise ct_exc(
                "ValueError", f"expected a number between -1 and 1, got {got}"
            );
        }
        return math.atanh(x);
    }
    if name == "acosh" {
        if x < 1.0 {
            raise ct_exc(
                "ValueError", f"expected argument value not less than 1, got {got}"
            );
        }
        return math.acosh(x);
    }
    if name in ("sin", "cos", "tan") {
        if x == x and not finite {
            raise ct_exc("ValueError", f"expected a finite input, got {got}");
        }
        if name == "sin" {
            return math.sin(x);
        }
        if name == "cos" {
            return math.cos(x);
        }
        return math.tan(x);
    }
    try {
        if name == "exp" {
            return _range_error(math.exp(x), finite);
        }
        if name == "exp2" {
            return _range_error(math.exp2(x), finite);
        }
        if name == "expm1" {
            return _range_error(math.expm1(x), finite);
        }
        if name == "sinh" {
            return _range_error(math.sinh(x), finite);
        }
        if name == "cosh" {
            return _range_error(math.cosh(x), finite);
        }
    } except OverflowError {
        raise ct_exc("OverflowError", "math range error");
    }
    if name == "atan" {
        return math.atan(x);
    }
    if name == "tanh" {
        return math.tanh(x);
    }
    if name == "asinh" {
        return math.asinh(x);
    }
    if name == "fabs" {
        return abs(x);
    }
    if name == "degrees" {
        return math.degrees(x);
    }
    if name == "radians" {
        return math.radians(x);
    }
    if name == "cbrt" {
        return math.cbrt(x);
    }
    raise CtError(f"math.{name} is not available in comptime code");
}

def adjust_indices(n: int, start: (int | None), end: (int | None)) -> tuple[int, int] {
    hi = n if end is None else end;
    if hi > n {
        hi = n;
    } elif hi < 0 {
        hi += n;
        if hi < 0 {
            hi = 0;
        }
    }
    lo = 0 if start is None else start;
    if lo < 0 {
        lo += n;
        if lo < 0 {
            lo = 0;
        }
    }
    return (lo, hi);
}

def str_tailmatch(
    s: str, sub: str, start: (int | None), end: (int | None), suffix: bool
) -> bool {
    (lo, hi) = adjust_indices(len(s), start, end);
    if hi - len(sub) < lo {
        return False;
    }
    if suffix {
        return s[hi - len(sub):hi] == sub;
    }
    return s[lo:lo + len(sub)] == sub;
}

def str_split_ws(s: str, maxsplit: int, from_right: bool) -> list[str] {
    out: list[str] = [];
    n = len(s);
    count = 0;
    if not from_right {
        i = 0;
        while maxsplit < 0 or count < maxsplit {
            while i < n and s[i].isspace() {
                i += 1;
            }
            if i == n {
                break;
            }
            j = i;
            i += 1;
            while i < n and not s[i].isspace() {
                i += 1;
            }
            out.append(s[j:i]);
            count += 1;
        }
        if i < n {
            while i < n and s[i].isspace() {
                i += 1;
            }
            if i != n {
                out.append(s[i:n]);
            }
        }
        return out;
    }
    k = n - 1;
    while maxsplit < 0 or count < maxsplit {
        while k >= 0 and s[k].isspace() {
            k -= 1;
        }
        if k < 0 {
            break;
        }
        j = k;
        k -= 1;
        while k >= 0 and not s[k].isspace() {
            k -= 1;
        }
        out.append(s[k + 1:j + 1]);
        count += 1;
    }
    if k >= 0 {
        while k >= 0 and s[k].isspace() {
            k -= 1;
        }
        if k >= 0 {
            out.append(s[0:k + 1]);
        }
    }
    out.reverse();
    return out;
}

def str_split_sep(s: str, sep: str, maxsplit: int, from_right: bool) -> list[str] {
    out: list[str] = [];
    count = 0;
    if not from_right {
        i = 0;
        while maxsplit < 0 or count < maxsplit {
            pos = s[i:].find(sep);
            if pos < 0 {
                break;
            }
            out.append(s[i:i + pos]);
            i = i + pos + len(sep);
            count += 1;
        }
        out.append(s[i:]);
        return out;
    }
    j = len(s);
    while maxsplit < 0 or count < maxsplit {
        pos = s[:j].rfind(sep);
        if pos < 0 {
            break;
        }
        out.append(s[pos + len(sep):j]);
        j = pos;
        count += 1;
    }
    out.append(s[:j]);
    out.reverse();
    return out;
}

def _bytes_match_at(b: bytes, sub: bytes, at: int) -> bool {
    for k in range(len(sub)) {
        if b[at + k] != sub[k] {
            return False;
        }
    }
    return True;
}

def bytes_find(b: bytes, sub: bytes, from_right: bool) -> int {
    n = len(b);
    m = len(sub);
    if m > n {
        return -1;
    }
    if from_right {
        i = n - m;
        while i >= 0 {
            if _bytes_match_at(b, sub, i) {
                return i;
            }
            i -= 1;
        }
        return -1;
    }
    for j in range(n - m + 1) {
        if _bytes_match_at(b, sub, j) {
            return j;
        }
    }
    return -1;
}
