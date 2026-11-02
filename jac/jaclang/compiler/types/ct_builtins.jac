import math;

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

def ct_method_owner(v: CtValue) -> str;

def ct_has_method(v: CtValue, name: str) -> bool;

def _arity(
    fname: str,
    args: list[CtValue],
    kwargs: dict[str, CtValue],
    names: list[str],
    required: int
) -> list[CtValue];

def _one_arg(fname: str, args: list[CtValue], kwargs: dict[str, CtValue]) -> CtValue;

def _no_args(fname: str, args: list[CtValue], kwargs: dict[str, CtValue]);

def _as_index(v: CtValue) -> CtInt;

def _as_small(v: CtValue) -> int;

def _opt_small(v: CtValue) -> (int | None);

def _as_str(v: CtValue, prefix: str) -> str;

def _opt_str(v: CtValue, what: str) -> (str | None);

def _str_list(items: list[str]) -> CtList;

def ct_sort(
    ev: CtCaller, items: list[CtValue], key: (CtValue | None), reverse: bool
) -> list[CtValue];

def _minmax(
    ev: CtCaller, fname: str, args: list[CtValue], kwargs: dict[str, CtValue]
) -> CtValue;

def _sum(args: list[CtValue], kwargs: dict[str, CtValue]) -> CtValue;

def _range(args: list[CtValue], kwargs: dict[str, CtValue]) -> CtRange;

def _round(args: list[CtValue], kwargs: dict[str, CtValue]) -> CtValue;

def _divmod(a: CtValue, b: CtValue) -> CtValue;

def _reversed(v: CtValue) -> CtList;

def ct_call_builtin(
    ev: CtCaller, name: str, args: list[CtValue], kwargs: dict[str, CtValue]
) -> CtValue;

def _pairs_into(d: CtDict, src: CtValue);

def _parse_int_text(text: str, shown: str, base: int) -> CtInt;

def ct_construct_builtin(
    name: str, args: list[CtValue], kwargs: dict[str, CtValue]
) -> CtValue;

def _decode(data: bytes, encoding: str, errors: str) -> CtStr;

def _encode(text: str, encoding: str, errors: str) -> CtBytes;

def ct_value_attr(v: CtValue, name: str) -> CtValue;

def ct_type_attr(type_name: str, attr: str) -> CtValue;

def ct_call_method_value(
    ev: CtCaller, m: CtMethod, args: list[CtValue], kwargs: dict[str, CtValue]
) -> CtValue;

def ct_call_method(
    ev: CtCaller,
    recv: CtValue,
    name: str,
    args: list[CtValue],
    kwargs: dict[str, CtValue]
) -> CtValue;

def _str_method(
    recv: CtStr, name: str, args: list[CtValue], kwargs: dict[str, CtValue]
) -> CtValue;

def _as_bytes_arg(v: CtValue) -> bytes;

def _bytes_method(
    recv: CtBytes, name: str, args: list[CtValue], kwargs: dict[str, CtValue]
) -> CtValue;

def _seq_index_count(
    items: list[CtValue],
    owner: str,
    name: str,
    args: list[CtValue],
    kwargs: dict[str, CtValue]
) -> CtValue;

def _list_method(
    ev: CtCaller,
    recv: CtList,
    name: str,
    args: list[CtValue],
    kwargs: dict[str, CtValue]
) -> CtValue;

def _dict_method(
    recv: CtDict, name: str, args: list[CtValue], kwargs: dict[str, CtValue]
) -> CtValue;

def _as_set(v: CtValue) -> CtSet;

def _set_method(
    recv: CtSet, name: str, args: list[CtValue], kwargs: dict[str, CtValue]
) -> CtValue;

def _int_method(
    recv: CtInt, name: str, args: list[CtValue], kwargs: dict[str, CtValue]
) -> CtValue;

def _float_method(
    recv: CtFloat, name: str, args: list[CtValue], kwargs: dict[str, CtValue]
) -> CtValue;

def _pow2(e: int) -> CtInt;

def _math_float(v: CtValue) -> float;

def int_frexp(a: CtInt) -> tuple[float, int];

def _log_of(v: CtValue, which: str) -> float;

def _log_raw(x: float, which: str) -> float;

def _range_error(r: float, inputs_finite: bool) -> float;

def _finite(x: float) -> bool;

def _math_int_arg(v: CtValue) -> CtInt;

def ct_call_math(
    name: str, args: list[CtValue], kwargs: dict[str, CtValue]
) -> CtValue;


def _math_log(name: str, args: list[CtValue], kwargs: dict[str, CtValue]) -> CtValue;

def _math_integer(
    name: str, args: list[CtValue], kwargs: dict[str, CtValue]
) -> CtValue;

def _math_reduce(
    name: str, args: list[CtValue], kwargs: dict[str, CtValue]
) -> CtValue;

def _math_classify(
    name: str, args: list[CtValue], kwargs: dict[str, CtValue]
) -> CtValue;

def _math_parts(name: str, args: list[CtValue], kwargs: dict[str, CtValue]) -> CtValue;

def _factorial(n: CtInt) -> CtInt;

def _math2(name: str, x: float, y: float) -> float;

def _math1(name: str, x: float) -> float;

def adjust_indices(n: int, start: (int | None), end: (int | None)) -> tuple[int, int];

def str_tailmatch(
    s: str, sub: str, start: (int | None), end: (int | None), suffix: bool
) -> bool;

def str_split_ws(s: str, maxsplit: int, from_right: bool) -> list[str];

def str_split_sep(s: str, sep: str, maxsplit: int, from_right: bool) -> list[str];

def _bytes_match_at(b: bytes, sub: bytes, at: int) -> bool;

def bytes_find(b: bytes, sub: bytes, from_right: bool) -> int;
