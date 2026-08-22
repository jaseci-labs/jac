# na cliff: the dict-value -> native-call boundary AT SCALE -- a large N-way
# method-id switch, the ONLY na-legal encoding when a value fetched from a dict
# must select a static call target and there are no function values.
#
# jac-py core site: pyc_first.jac binop_dunder/compare_dunder + objects.jac
# PyInt.nb_binop(kind:int, ...) -- an integer "kind" pulled from data selects a
# behavior through a closed switch (na resolves every call statically, so an
# operator table CANNOT be a fn-pointer array; it is a switch on an int slot-id,
# exactly the CPython nb_* table shape). This fixture pushes that switch to 40
# arms to prove na survives a large closed switch on a runtime-computed id.
#
# Uncheatable properties (an easy compile proves nothing):
#  * method_id is RUNTIME-computed -- fetched from a dict[str,int] keyed by an
#    op-name iterated from a DATA list, never a literal at the call site;
#  * operands are boxed PyObj pulled from runtime DATA lists, so no arm folds to
#    a constant (DCE cannot collapse the switch to one hot arm);
#  * the switch is exercised across ALL 40 arms for every operand pair, and each
#    arm does genuinely different arithmetic/compare/bitwise work;
#  * every arm's result flows into an accumulator WEIGHTED by (method_id+1), so a
#    single mislowered arm shifts the asserted total;
#  * the union the dict-driven boxed operand presents is narrowed via
#    isinstance/as before its int is read (na T|None-receiver-drop landmine).
# Memories: na-native-no-indirect-calls, na-method-call-on-union-receiver,
# na-dict-literal-subclass-upcast-ice.

obj PyObj {
    has t: str;
}

obj PyInt(PyObj) {
    has val: int;
}

obj PyBool(PyObj) {
    has val: bool;
}

def py_error(type_name: str, message: str) -> PyObj {
    return PyObj(t="error");
}

# Narrow the boxed-operand union before reading its int -- PyInt or PyBool both
# carry an integer value (bool is an int subclass). Anything else is not numeric.
def expect_num(o: PyObj) -> int {
    if isinstance(o, PyInt) {
        return (o as PyInt).val;
    }
    if isinstance(o, PyBool) {
        if (o as PyBool).val {
            return 1;
        }
        return 0;
    }
    return 0;
}

# THE SWITCH: a 40-arm closed dispatch on a runtime int method_id. This is the
# only na-legal shape for a dict-value -> static-call-target mapping (no fn
# values). Each arm narrows both operands, does distinct work, returns a PyObj.
def invoke(method_id: int, a: PyObj, b: PyObj) -> PyObj {
    x = expect_num(a);
    y = expect_num(b);
    # y is guaranteed > 0 by the operand data, so //, % need no zero-guard here.
    if method_id == 0 {
        return PyInt(t="int", val=x + y);
    }
    if method_id == 1 {
        return PyInt(t="int", val=x - y);
    }
    if method_id == 2 {
        return PyInt(t="int", val=x * y);
    }
    if method_id == 3 {
        return PyInt(t="int", val=x // y);
    }
    if method_id == 4 {
        return PyInt(t="int", val=x % y);
    }
    if method_id == 5 {
        return PyInt(t="int", val=x & y);
    }
    if method_id == 6 {
        return PyInt(t="int", val=x | y);
    }
    if method_id == 7 {
        return PyInt(t="int", val=x ^ y);
    }
    if method_id == 8 {
        return PyInt(t="int", val=x << (y % 8));
    }
    if method_id == 9 {
        return PyInt(t="int", val=x >> (y % 8));
    }
    if method_id == 10 {
        return PyBool(t="bool", val=x < y);
    }
    if method_id == 11 {
        return PyBool(t="bool", val=x <= y);
    }
    if method_id == 12 {
        return PyBool(t="bool", val=x == y);
    }
    if method_id == 13 {
        return PyBool(t="bool", val=x != y);
    }
    if method_id == 14 {
        return PyBool(t="bool", val=x > y);
    }
    if method_id == 15 {
        return PyBool(t="bool", val=x >= y);
    }
    if method_id == 16 {
        return PyInt(t="int", val=-x);
    }
    if method_id == 17 {
        return PyInt(t="int", val=-y);
    }
    if method_id == 18 {
        return PyInt(t="int", val=x + 2 * y);
    }
    if method_id == 19 {
        return PyInt(t="int", val=2 * x + y);
    }
    if method_id == 20 {
        return PyInt(t="int", val=x * x - y);
    }
    if method_id == 21 {
        return PyInt(t="int", val=x + y * y);
    }
    if method_id == 22 {
        return PyInt(t="int", val=(x + y) * (x - y));
    }
    if method_id == 23 {
        return PyInt(t="int", val=x * y + x + y);
    }
    if method_id == 24 {
        return PyInt(t="int", val=x % (y + 1));
    }
    if method_id == 25 {
        return PyInt(t="int", val=(x + 1) * (y + 1));
    }
    if method_id == 26 {
        return PyInt(t="int", val=x - y - 1);
    }
    if method_id == 27 {
        return PyInt(t="int", val=x * 3 - y * 2);
    }
    if method_id == 28 {
        return PyInt(t="int", val=x ^ (y << 1));
    }
    if method_id == 29 {
        return PyInt(t="int", val=(x & y) + (x | y));
    }
    if method_id == 30 {
        return PyInt(t="int", val=x * x + y * y);
    }
    if method_id == 31 {
        return PyInt(t="int", val=x + y + 17);
    }
    if method_id == 32 {
        return PyInt(t="int", val=x * 7 % 100);
    }
    if method_id == 33 {
        return PyInt(t="int", val=y * 7 % 100);
    }
    if method_id == 34 {
        return PyInt(t="int", val=(x << 2) - y);
    }
    if method_id == 35 {
        return PyInt(t="int", val=x * x * x - y);
    }
    if method_id == 36 {
        # abs(x - y) without a builtin, so the arm body is genuinely distinct.
        d = x - y;
        if d < 0 {
            return PyInt(t="int", val=-d);
        }
        return PyInt(t="int", val=d);
    }
    if method_id == 37 {
        # max(x, y)
        if x > y {
            return PyInt(t="int", val=x);
        }
        return PyInt(t="int", val=y);
    }
    if method_id == 38 {
        # min(x, y)
        if x < y {
            return PyInt(t="int", val=x);
        }
        return PyInt(t="int", val=y);
    }
    if method_id == 39 {
        return PyInt(t="int", val=x * y - (x + y));
    }
    return py_error("KeyError", "no such method id");
}

# Build the op-name -> method_id table EMPTY then subscript-store (na dict-literal
# with heterogeneous/subclass values ICEs; base-typed empty + store is safe).
def build_table(names: list[str]) -> dict[str, int] {
    table: dict[str, int] = {};
    idx = 0;
    for nm in names {
        table[nm] = idx;
        idx = idx + 1;
    }
    return table;
}

def run -> int {
    # 40 op names, position == its method_id -- the dict maps name -> id at
    # runtime, so the call-site never sees a literal id.
    names: list[str] = [
        "add",
        "sub",
        "mul",
        "floordiv",
        "mod",
        "and",
        "or",
        "xor",
        "lshift",
        "rshift",
        "lt",
        "le",
        "eq",
        "ne",
        "gt",
        "ge",
        "neg",
        "rneg",
        "add2y",
        "twox",
        "sqsub",
        "addsq",
        "diffsq",
        "poly",
        "modp1",
        "incprod",
        "subm1",
        "affine",
        "xorshift",
        "andor",
        "sumsq",
        "plus17",
        "x7",
        "y7",
        "shl2",
        "cube",
        "absd",
        "maxxy",
        "minxy",
        "prodsub"
    ];
    table = build_table(names);

    # Operand pairs, boxed as PyObj and pulled from runtime DATA lists so no arm
    # folds to a constant. Every b > 0 to keep //, %, shifts well-defined.
    lefts: list[PyObj] = [
        PyInt(t="int", val=7),
        PyInt(t="int", val=12),
        PyInt(t="int", val=9)
    ];
    rights: list[PyObj] = [
        PyInt(t="int", val=3),
        PyInt(t="int", val=5),
        PyInt(t="int", val=4)
    ];

    total = 0;
    pair = 0;
    while pair < len(lefts) {
        a: PyObj = lefts[pair];
        b: PyObj = rights[pair];
        # Iterate ALL 40 op-names -> runtime method_id via the dict -> the switch.
        for nm in names {
            mid = table[nm];
            r = invoke(mid, a, b);
            v = expect_num(r);
            # Weight by (mid+1) so a single mislowered arm shifts the total.
            total = total + v * (mid + 1);
        }
        pair = pair + 1;
    }
    return total;
}

with entry {
    print(run());
}
