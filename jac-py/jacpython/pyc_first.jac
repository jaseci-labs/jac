# C3 bootstrap (jac-py/PLAN.md P3 / TODO.md C3): pyc-first.
#
# Thesis: jacpython's object core + ceval can run real programs that TODAY's
# CPython compiled. So we bypass the entire front end (tokenizer -> parser ->
# symtable -> compile) by feeding host-compiled, marshalled code objects
# straight into the ceval. This decouples execution from compilation and gives
# us a free dual-interpreter oracle (the same .pyc run by CPython and jacpython).
#
# This file is the minimal vertical slice that proves it: a small PyObj model,
# a CPython 3.14 marshal reader, and a tiny ceval covering host-compiled
# arithmetic, list/string/sequence operations, and direct function calls
# (LOAD_FAST_BORROW*, LOAD_SMALL_INT, BINARY_OP, MAKE_FUNCTION, CALL,
# RETURN_VALUE, STORE_NAME/LOAD_NAME, ...).
#
# This slice now covers the core object-model and ceval seams needed by ordinary
# Python programs: attributes, host imports, jumps/iteration, exception-table
# unwinding, cells/freevars, and positional/keyword calls.  The transport is
# still CPython 3.14.6-specific; the front end and the full object protocol are
# intentionally outside this bootstrap module.

import marshal;

import from marshal_reader { unmarshal, }

import from ceval {
    PyClass,
    PyFunction,
    PyModule,
    PyUserObj,
    PyBoundMethod,
    PyGenerator,
    PyObj,
    PyStr,
    PyInt,
    register_shim_module,
    clear_shim_modules,
    shim_module_get,
    exec_code,
    exec_code_frame,
    exec_module,
    to_host,
    from_host,
    py_compare,
    py_hash,
    py_subscript,
    py_binop,
    py_truth,
    py_attr,
    py_invoke,
    py_isinstance,
    py_issubclass,
    bind_attribute,
    class_lookup_attr,
    py_raise_value,
    import_native,
    set_layer3_active,
    clear_sys3_modules,
    gen_send,
    build_copy_module,
}

import from objects {
    PyBool,
    PyFloat,
    PyCode,
    PyNoneType,
    PyDict,
    PyList,
    PyTuple,
    PySet,
    PyError,
    expect_int,
    expect_str,
    expect_float,
    expect_bool,
    is_error,
    py_none,
}

# ---------------- fixtures (real CPython 3.14.6 marshal output) ----------------
# Produced by: marshal.dumps(compile(src, '', 'exec').co_consts[0]) for funcs,
# or marshal.dumps(compile(src, '', 'exec')) for the module.

# ---------------- object model ----------------
glob ADD_MARSHAL: list[int] = [
         227,
         2,
         0,
         0,
         0,
         0,
         0,
         0,
         0,
         0,
         0,
         0,
         0,
         2,
         0,
         0,
         0,
         3,
         0,
         0,
         0,
         243,
         18,
         0,
         0,
         0,
         128,
         0,
         87,
         1,
         44,
         0,
         0,
         0,
         0,
         0,
         0,
         0,
         0,
         0,
         0,
         0,
         35,
         0,
         41,
         1,
         78,
         169,
         0,
         41,
         2,
         218,
         1,
         97,
         218,
         1,
         98,
         115,
         2,
         0,
         0,
         0,
         38,
         38,
         218,
         5,
         60,
         65,
         68,
         68,
         62,
         218,
         3,
         97,
         100,
         100,
         114,
         6,
         0,
         0,
         0,
         1,
         0,
         0,
         0,
         115,
         9,
         0,
         0,
         0,
         128,
         0,
         216,
         11,
         12,
         141,
         53,
         128,
         76,
         243,
         0,
         0,
         0,
         0
     ],
     MUL_MARSHAL: list[int] = [
         227,
         2,
         0,
         0,
         0,
         0,
         0,
         0,
         0,
         0,
         0,
         0,
         0,
         2,
         0,
         0,
         0,
         3,
         0,
         0,
         0,
         243,
         18,
         0,
         0,
         0,
         128,
         0,
         87,
         1,
         44,
         5,
         0,
         0,
         0,
         0,
         0,
         0,
         0,
         0,
         0,
         0,
         35,
         0,
         41,
         1,
         78,
         169,
         0,
         41,
         2,
         218,
         1,
         97,
         218,
         1,
         98,
         115,
         2,
         0,
         0,
         0,
         38,
         38,
         218,
         5,
         60,
         77,
         85,
         76,
         62,
         218,
         3,
         109,
         117,
         108,
         114,
         6,
         0,
         0,
         0,
         1,
         0,
         0,
         0,
         115,
         9,
         0,
         0,
         0,
         128,
         0,
         216,
         11,
         12,
         141,
         53,
         128,
         76,
         243,
         0,
         0,
         0,
         0
     ],
     MOD_MARSHAL: list[int] = [
         227,
         2,
         0,
         0,
         0,
         0,
         0,
         0,
         0,
         0,
         0,
         0,
         0,
         2,
         0,
         0,
         0,
         3,
         0,
         0,
         0,
         243,
         18,
         0,
         0,
         0,
         128,
         0,
         87,
         1,
         44,
         6,
         0,
         0,
         0,
         0,
         0,
         0,
         0,
         0,
         0,
         0,
         35,
         0,
         41,
         1,
         78,
         169,
         0,
         41,
         2,
         218,
         1,
         97,
         218,
         1,
         98,
         115,
         2,
         0,
         0,
         0,
         38,
         38,
         218,
         5,
         60,
         77,
         79,
         68,
         62,
         218,
         3,
         109,
         111,
         100,
         114,
         6,
         0,
         0,
         0,
         1,
         0,
         0,
         0,
         115,
         9,
         0,
         0,
         0,
         128,
         0,
         216,
         11,
         12,
         141,
         53,
         128,
         76,
         243,
         0,
         0,
         0,
         0
     ],
     SCALE_MARSHAL: list[int] = [
         227,
         1,
         0,
         0,
         0,
         0,
         0,
         0,
         0,
         0,
         0,
         0,
         0,
         2,
         0,
         0,
         0,
         3,
         0,
         0,
         0,
         243,
         20,
         0,
         0,
         0,
         128,
         0,
         86,
         0,
         94,
         10,
         44,
         5,
         0,
         0,
         0,
         0,
         0,
         0,
         0,
         0,
         0,
         0,
         35,
         0,
         41,
         1,
         233,
         10,
         0,
         0,
         0,
         169,
         0,
         41,
         1,
         218,
         1,
         97,
         115,
         1,
         0,
         0,
         0,
         38,
         218,
         7,
         60,
         83,
         67,
         65,
         76,
         69,
         62,
         218,
         5,
         115,
         99,
         97,
         108,
         101,
         114,
         6,
         0,
         0,
         0,
         1,
         0,
         0,
         0,
         115,
         11,
         0,
         0,
         0,
         128,
         0,
         216,
         11,
         12,
         136,
         114,
         141,
         54,
         128,
         77,
         243,
         0,
         0,
         0,
         0
     ],
     YMODULE_MARSHAL: list[int] = [
         227,
         0,
         0,
         0,
         0,
         0,
         0,
         0,
         0,
         0,
         0,
         0,
         0,
         1,
         0,
         0,
         0,
         0,
         0,
         0,
         0,
         243,
         10,
         0,
         0,
         0,
         128,
         0,
         94,
         43,
         116,
         0,
         82,
         1,
         35,
         0,
         41,
         2,
         233,
         6,
         0,
         0,
         0,
         78,
         41,
         1,
         218,
         1,
         121,
         169,
         0,
         243,
         0,
         0,
         0,
         0,
         218,
         9,
         60,
         89,
         77,
         79,
         68,
         85,
         76,
         69,
         62,
         218,
         8,
         60,
         109,
         111,
         100,
         117,
         108,
         101,
         62,
         114,
         7,
         0,
         0,
         0,
         1,
         0,
         0,
         0,
         115,
         10,
         0,
         0,
         0,
         240,
         3,
         1,
         1,
         1,
         216,
         4,
         13,
         130,
         1,
         114,
         5,
         0,
         0,
         0
     ];

# Bootstrap transport: host compile() + marshal (PLAN.md P0.3 transitional).
# Canonical copy kept here for re-export; ceval.jac carries a duplicate for
# acyclic import (see PLAN.md §4 module-boundary constraint).
def host_compile_marshal(source: str) -> list[int] {
    raw = marshal.dumps(compile(source, "<jacpython-host>", "exec"));
    return raw as list[int];
}

# ---------------- tests ----------------
def run_source(source: str) -> dict[str, PyObj] {
    return exec_module(unmarshal(host_compile_marshal(source)));
}

test "pyc-first: attributes and imports" {
    imported = run_source(
        "import math\nfrom math import sqrt\nresult = math.floor(sqrt(81))\n"
    );
    assert expect_int(imported["result"]) == 9;

    classes = run_source(
        "class Box:\n"
        "    def __init__(self, value): self.value = value\n"
        "    def get(self): return self.value\n"
        "box = Box(7)\n"
        "result = box.value + box.get()\n"
    );
    assert expect_int(classes["result"]) == 14;
}

test "pyc-first: control flow and iteration" {
    branch = run_source(
        "def choose(x):\n"
        "    if x > 3:\n"
        "        return x * 2\n"
        "    return x - 1\n"
        "result = choose(4)\n"
    );
    assert expect_int(branch["result"]) == 8;

    loop = run_source(
        "total = 0\n"
        "for i in range(5):\n"
        "    total = total + i\n"
        "result = total\n"
    );
    assert expect_int(loop["result"]) == 10;

    while_loop = run_source(
        "i = 0\n" "while i < 4:\n" "    i = i + 1\n" "result = i\n"
    );
    assert expect_int(while_loop["result"]) == 4;

    mapping = run_source("values = {'answer': 42}\nresult = values['answer']\n");
    assert expect_int(mapping["result"]) == 42;
}

test "pyc-first: exception table unwinding" {
    result = run_source(
        "def safe(x):\n"
        "    try:\n"
        "        return 10 // x\n"
        "    except ZeroDivisionError:\n"
        "        return 99\n"
        "result = safe(0)\n"
    );
    assert expect_int(result["result"]) == 99;

    multiple = run_source(
        "try:\n"
        "    1 // 0\n"
        "except ValueError:\n"
        "    result = 1\n"
        "except ZeroDivisionError:\n"
        "    result = 2\n"
    );
    assert expect_int(multiple["result"]) == 2;

    raised = run_source(
        "try:\n"
        "    raise ValueError('bad')\n"
        "except ValueError as error:\n"
        "    result = 3\n"
    );
    assert expect_int(raised["result"]) == 3;
}

test "pyc-first: closure cells" {
    result = run_source(
        "def make_adder(x):\n"
        "    def add(y):\n"
        "        return x + y\n"
        "    return add\n"
        "result = make_adder(7)(5)\n"
    );
    assert expect_int(result["result"]) == 12;

    counter = run_source(
        "def make_counter():\n"
        "    value = 0\n"
        "    def increment():\n"
        "        nonlocal value\n"
        "        value = value + 1\n"
        "        return value\n"
        "    return increment\n"
        "counter = make_counter()\n"
        "counter()\n"
        "result = counter()\n"
    );
    assert expect_int(counter["result"]) == 2;
}

test "pyc-first: keyword calls and defaults" {
    result = run_source(
        "def greet(name, punctuation='!'):\n"
        "    return name + punctuation\n"
        "result = greet(punctuation='?', name='hi')\n"
    );
    assert expect_str(result["result"]) == "hi?";
}

test "pyc-first: real CPython 3.14 marshal -> jacpython ceval" {
    add_co = unmarshal(ADD_MARSHAL);
    assert add_co.t == "code";
    add_args: list[PyObj] = [PyInt(t="int", val=2), PyInt(t="int", val=3)];
    add_res = exec_code(add_co, add_args, {});
    assert add_res.t == "int";
    assert expect_int(add_res) == 5;

    mul_co = unmarshal(MUL_MARSHAL);
    mul_res = exec_code(mul_co, [PyInt(t="int", val=4), PyInt(t="int", val=5)], {});
    assert expect_int(mul_res) == 20;

    mod_co = unmarshal(MOD_MARSHAL);
    mod_res = exec_code(mod_co, [PyInt(t="int", val=17), PyInt(t="int", val=5)], {});
    assert expect_int(mod_res) == 2;

    scale_co = unmarshal(SCALE_MARSHAL);
    scale_res = exec_code(scale_co, [PyInt(t="int", val=5)], {});
    assert expect_int(scale_res) == 50;

    ym_co = unmarshal(YMODULE_MARSHAL);
    globals = exec_module(ym_co);
    assert "y" in globals;
    assert expect_int(globals["y"]) == 43;

    # The source boundary is real host compile -> marshal -> Jac unmarshal;
    # this is deliberately not another embedded byte fixture.
    source = "numbers = [4, 5, 6]\nanswer = numbers[1] + 2\nword = 'a' + 'b'\n";
    source_co = unmarshal(host_compile_marshal(source));
    source_globals = exec_module(source_co);
    assert expect_int(source_globals["answer"]) == 7;
    assert expect_str(source_globals["word"]) == "ab";
    assert expect_int(py_subscript(source_globals["numbers"], PyInt(t="int", val=1)))
        == 5;

    function_source = "def add(a, b):\n    return a + b\nresult = add(2, 3)\n";
    function_co = unmarshal(host_compile_marshal(function_source));
    function_globals = exec_module(function_co);
    assert expect_int(function_globals["result"]) == 5;
}

test "pyc-first: augmented assignment (NB_INPLACE_* binops) matches base ops" {
    # BINARY_OP opargs 13..25 are the in-place operators; jacpython folds them to
    # their base binop (x += y == x = x + y) since these values are immutable.
    ops = run_source(
        "a = 10\na += 5\n"
        "b = 10\nb -= 3\n"
        "c = 4\nc *= 3\n"
        "d = 17\nd %= 5\n"
        "e = 20\ne //= 6\n"
        "f = 2\nf **= 5\n"
        "g = 6\ng &= 3\n"
        "h = 5\nh |= 2\n"
        "i = 5\ni ^= 1\n"
        "j = 1\nj <<= 4\n"
        "k = 'ab'\nk += 'cd'\n"
    );
    assert expect_int(ops["a"]) == 15;
    assert expect_int(ops["b"]) == 7;
    assert expect_int(ops["c"]) == 12;
    assert expect_int(ops["d"]) == 2;
    assert expect_int(ops["e"]) == 3;
    assert expect_int(ops["f"]) == 32;
    assert expect_int(ops["g"]) == 2;
    assert expect_int(ops["h"]) == 7;
    assert expect_int(ops["i"]) == 4;
    assert expect_int(ops["j"]) == 16;
    assert expect_str(ops["k"]) == "abcd";
}

test "pyc-first: true divide, xor, unary neg/invert on non-constant int operands" {
    # Non-constant operands defeat the compiler's constant folding, so these hit
    # the native PyInt.nb_binop / unary slots. True divide (oparg 11) must yield a
    # float even when it divides evenly; XOR is a distinct oparg (12).
    ops = run_source(
        "a = 6\nb = 2\n"
        "q_even = a / b\n"
        "c = 7\nq_frac = c / b\n"
        "x = 6\ny = 3\nz = x ^ y\n"
        "n = 5\nneg = -n\ninv = ~n\n"
    );
    assert ops["q_even"].t == "float";
    assert expect_float(ops["q_even"]) == 3.0;
    assert expect_float(ops["q_frac"]) == 3.5;
    assert ops["z"].t == "int";
    assert expect_int(ops["z"]) == 5;
    assert expect_int(ops["neg"]) == -5;
    assert expect_int(ops["inv"]) == -6;

    # int / 0 raises ZeroDivisionError natively rather than returning a bogus int.
    zdiv = PyInt(t="int", val=1).nb_binop(11, PyInt(t="int", val=0));
    assert is_error(zdiv);

    # A negative shift count is a ValueError, not a native crash (oparg 3 = <<).
    negshift = PyInt(t="int", val=1).nb_binop(3, PyInt(t="int", val=-1));
    assert is_error(negshift);

    # test_augassign::testBasic verbatim: the trailing `x /= 2` on int 6 must
    # produce float 3.0 (this is the case the true-divide/XOR oparg swap broke).
    basic = run_source(
        "x = 2\nx += 1\nx *= 2\nx **= 2\nx -= 8\nx //= 5\n"
        "x %= 3\nx &= 2\nx |= 5\nx ^= 1\nx /= 2\n"
    );
    assert basic["x"].t == "float";
    assert expect_float(basic["x"]) == 3.0;
}

test "pyc-first: UNPACK_SEQUENCE, DELETE_SUBSCR, MAP_ADD, DICT_UPDATE opcodes" {
    # Sequence unpacking from tuple, list, and string.
    un = run_source("ta, tb = (10, 20)\n" "la, lb, lc = [1, 2, 3]\n" "s1, s2 = 'hi'\n");
    assert expect_int(un["ta"]) == 10;
    assert expect_int(un["tb"]) == 20;
    assert expect_int(un["la"]) == 1;
    assert expect_int(un["lc"]) == 3;
    assert expect_str(un["s1"]) == "h";
    assert expect_str(un["s2"]) == "i";

    # del on dict and list; the deleted keys/indices are gone afterward.
    dl = run_source(
        "d = {'x': 1, 'y': 2}\ndel d['x']\n"
        "has_x = 'x' in d\nkept = d['y']\n"
        "L = [1, 2, 3]\ndel L[1]\nl0 = L[0]\nl1 = L[1]\n"
    );
    assert expect_bool(dl["has_x"]) == False;
    assert expect_int(dl["kept"]) == 2;
    assert expect_int(dl["l0"]) == 1;
    assert expect_int(dl["l1"]) == 3;

    # dict comprehension (MAP_ADD + STORE_FAST_STORE_FAST) with str keys, which
    # the str-keyed native PyDict supports.
    dc = run_source("m = {c: c + c for c in ['a', 'b']}\nma = m['a']\nmb = m['b']\n");
    assert expect_str(dc["ma"]) == "aa";
    assert expect_str(dc["mb"]) == "bb";

    # {**a, **b} dict-display merge (DICT_UPDATE); later mapping wins on overlap.
    mg = run_source(
        "merged = {**{'a': 1, 'b': 2}, **{'b': 3, 'c': 4}}\n"
        "va = merged['a']\nvb = merged['b']\nvc = merged['c']\n"
    );
    assert expect_int(mg["va"]) == 1;
    assert expect_int(mg["vb"]) == 3;
    assert expect_int(mg["vc"]) == 4;
}

test "pyc-first: PyFloat nb_binop/tp_richcompare drive natively" {
    # Arithmetic promotes int/bool operands to float and routes through the
    # native PyFloat.nb_binop slot (not the host fallback).
    ops = run_source(
        "add = 1.5 + 2\n"
        "sub = 5.0 - 1.5\n"
        "mul = 2.5 * 4\n"
        "div = 7.0 / 2\n"
        "flr = 7.5 // 2.0\n"
        "mod = 7.5 % 2.0\n"
        "pw = 2.0 ** 3\n"
        "mixed = 1.5 + True\n"
    );
    assert expect_float(ops["add"]) == 3.5;
    assert expect_float(ops["sub"]) == 3.5;
    assert expect_float(ops["mul"]) == 10.0;
    assert expect_float(ops["div"]) == 3.5;
    assert expect_float(ops["flr"]) == 3.0;
    assert expect_float(ops["mod"]) == 1.5;
    assert expect_float(ops["pw"]) == 8.0;
    assert expect_float(ops["mixed"]) == 2.5;

    # Ordered comparisons -- previously the tag-comparing default gave wrong
    # answers for float-on-left.
    cmps = run_source(
        "lt = 1.5 < 2.5\n"
        "gt = 1.5 > 2.5\n"
        "eq = 2.5 == 2.5\n"
        "le = 2.0 <= 2\n"
        "mixed_eq = 3.0 == 3\n"
    );
    assert expect_bool(cmps["lt"]) == True;
    assert expect_bool(cmps["gt"]) == False;
    assert expect_bool(cmps["eq"]) == True;
    assert expect_bool(cmps["le"]) == True;
    assert expect_bool(cmps["mixed_eq"]) == True;

    # NaN: every comparison but != is False; != is True.
    nans = run_source(
        "n = float('nan')\n"
        "self_eq = n == n\n"
        "self_ne = n != n\n"
        "self_lt = n < n\n"
    );
    assert expect_bool(nans["self_eq"]) == False;
    assert expect_bool(nans["self_ne"]) == True;
    assert expect_bool(nans["self_lt"]) == False;

    # Division by zero raises rather than falling through to host.
    zdiv = PyFloat(t="float", val=1.0).nb_binop(11, PyFloat(t="float", val=0.0));
    assert is_error(zdiv);
}

test "pyc-first: PyInt tp_richcompare handles float/bool right operand" {
    # int-on-left, float-on-right: previously the tag-mismatch default returned
    # a bogus bool. Now int promotes to float and compares correctly.
    cmps = run_source(
        "lt = 1 < 2.5\n"
        "gt = 5 > 2.5\n"
        "ge = 3 >= 3.0\n"
        "le = 2 <= 2.5\n"
        "eqf = 3 == 3.0\n"
        "nef = 3 != 3.5\n"
    );
    assert expect_bool(cmps["lt"]) == True;
    assert expect_bool(cmps["gt"]) == True;
    assert expect_bool(cmps["ge"]) == True;
    assert expect_bool(cmps["le"]) == True;
    assert expect_bool(cmps["eqf"]) == True;
    assert expect_bool(cmps["nef"]) == True;

    # int vs bool (bool is an int subclass -- compare by numeric value).
    bools = run_source(
        "eqt = 1 == True\n" "eqf0 = 0 == False\n" "gtb = 2 > True\n" "ltb = 0 < True\n"
    );
    assert expect_bool(bools["eqt"]) == True;
    assert expect_bool(bools["eqf0"]) == True;
    assert expect_bool(bools["gtb"]) == True;
    assert expect_bool(bools["ltb"]) == True;

    # int vs NaN on the right: only != is True.
    nans = run_source(
        "n = float('nan')\n" "eqn = 1 == n\n" "nen = 1 != n\n" "ltn = 1 < n\n"
    );
    assert expect_bool(nans["eqn"]) == False;
    assert expect_bool(nans["nen"]) == True;
    assert expect_bool(nans["ltn"]) == False;
}

test "pyc-first: DELETE_NAME unbinds a module global" {
    deleted = run_source("x = 5\ndel x\nresult = 1\n");
    assert expect_int(deleted["result"]) == 1;
    assert not ("x" in deleted);
}

test "pyc-first: value-keyed dicts via the hash-key protocol (H2)" {
    # int / float / bool keys with Python's numeric collapse: 1, 1.0 and True
    # all address the same slot, so the last write wins and len stays 2.
    numk = run_source(
        "d = {1: 'a', 2: 'b'}\n"
        "d[1.0] = 'c'\n"
        "d[True] = 'd'\n"
        "one = d[1]\ntwo = d[2]\nsize = len(d)\n"
    );
    assert expect_str(numk["one"]) == "d";
    assert expect_str(numk["two"]) == "b";
    assert expect_int(numk["size"]) == 2;

    # tuple keys (recursive, length-framed hashkey), including a nested tuple.
    tupk = run_source(
        "d = {(1, 2): 'x', (3, (4, 5)): 'y'}\n"
        "a = d[(1, 2)]\nb = d[(3, (4, 5))]\nhas = (1, 2) in d\n"
    );
    assert expect_str(tupk["a"]) == "x";
    assert expect_str(tupk["b"]) == "y";
    assert expect_bool(tupk["has"]) == True;

    # int-keyed dict comprehension -- previously fell back to an opaque host map.
    comp = run_source(
        "sq = {n: n * n for n in range(4)}\n" "s0 = sq[0]\ns3 = sq[3]\nn = len(sq)\n"
    );
    assert expect_int(comp["s0"]) == 0;
    assert expect_int(comp["s3"]) == 9;
    assert expect_int(comp["n"]) == 4;

    # del with a non-str key; float/int collapse means del d[2.0] removes key 2.
    deld = run_source(
        "d = {1: 'a', 2: 'b', 3: 'c'}\ndel d[2.0]\n" "has2 = 2 in d\nkept = d[3]\n"
    );
    assert expect_bool(deld["has2"]) == False;
    assert expect_str(deld["kept"]) == "c";

    # str "1" and int 1 are distinct keys (prefix disambiguation), no collision.
    mix = run_source(
        "d = {'1': 'str-one', 1: 'int-one'}\n" "s = d['1']\ni = d[1]\nn = len(d)\n"
    );
    assert expect_str(mix["s"]) == "str-one";
    assert expect_str(mix["i"]) == "int-one";
    assert expect_int(mix["n"]) == 2;

    # A missing non-str key raises KeyError, not a silent wrong value.
    miss = run_source(
        "d = {1: 'a'}\nout = 0\ntry:\n    d[9]\nexcept KeyError:\n    out = 1\n"
    );
    assert expect_int(miss["out"]) == 1;

    # An unhashable key (list) is a TypeError at the slot, not a mis-key.
    unh = PyDict(t="dict", items={}).mp_ass_subscript(
        PyList(t="list", items=[]), PyStr(t="str", val="v")
    );
    assert is_error(unh);
}

test "pyc-first: native sets via the hash-key protocol (H3)" {
    # Membership + numeric collapse: 2.0 and True find the same slots as 2 / 1.
    mem = run_source(
        "s = {1, 2, 3}\n" "a = 2.0 in s\nb = True in s\nc = 4 in s\nn = len(s)\n"
    );
    assert expect_bool(mem["a"]) == True;
    assert expect_bool(mem["b"]) == True;
    assert expect_bool(mem["c"]) == False;
    assert expect_int(mem["n"]) == 3;

    # Set algebra runs natively (PySet.nb_binop). Compare sizes to dodge
    # element-order noise across the boundary.
    ops = run_source(
        "u = len({1, 2, 3} | {3, 4})\n"
        "i = len({1, 2, 3} & {2, 3, 4})\n"
        "d = len({1, 2, 3} - {2})\n"
        "x = len({1, 2, 3} ^ {2, 3, 4})\n"
    );
    assert expect_int(ops["u"]) == 4;
    assert expect_int(ops["i"]) == 2;
    assert expect_int(ops["d"]) == 2;
    assert expect_int(ops["x"]) == 2;

    # Subset / equality comparisons.
    cmp = run_source(
        "sub = {1, 2} <= {1, 2, 3}\n"
        "eq = {1, 2} == {2, 1}\n"
        "psub = {1, 2} < {1, 2}\n"
        "sup = {1, 2, 3} > {1, 2}\n"
    );
    assert expect_bool(cmp["sub"]) == True;
    assert expect_bool(cmp["eq"]) == True;
    assert expect_bool(cmp["psub"]) == False;
    assert expect_bool(cmp["sup"]) == True;

    # Set comprehension dedupes value-equal members (1 and 1.0 collapse).
    comp = run_source("s = {n % 3 for n in range(10)}\nn = len(s)\n");
    assert expect_int(comp["n"]) == 3;

    # frozenset is hashable and order-independent as a dict key.
    fz = run_source(
        "d = {frozenset({1, 2}): 'x'}\n"
        "hit = d[frozenset({2, 1})]\nmem = frozenset({1, 2}) in d\n"
    );
    assert expect_str(fz["hit"]) == "x";
    assert expect_bool(fz["mem"]) == True;

    # A mutable set is unhashable.
    unh = PySet(t="set", items={}, frozen=False).tp_hashkey();
    assert unh == "";
}

test "pyc-first: builtin subclassing (Track B)" {
    # Subclass of int: operator + hashkey delegation to the boxed value, plus a
    # method override, and isinstance/issubclass across the builtin ancestor.
    mi = run_source(
        "class MyInt(int):\n"
        "    def double(self):\n"
        "        return self * 2\n"
        "x = MyInt(5)\n"
        "add = x + 1\n"
        "radd = 1 + x\n"
        "dbl = x.double()\n"
        "isi = isinstance(x, int)\n"
        "iso = isinstance(x, object)\n"
        "iss = isinstance(x, str)\n"
        "sub = issubclass(MyInt, int)\n"
        "d = {x: 'five'}\nkeyed = d[5]\n"
    );
    assert expect_int(mi["add"]) == 6;
    assert expect_int(mi["radd"]) == 6;
    assert expect_int(mi["dbl"]) == 10;
    assert expect_bool(mi["isi"]) == True;
    assert expect_bool(mi["iso"]) == True;
    assert expect_bool(mi["iss"]) == False;
    assert expect_bool(mi["sub"]) == True;
    assert expect_str(mi["keyed"]) == "five";

    # Subclass of str: base-method delegation (upper) + operator (concat).
    ms = run_source(
        "class MyStr(str):\n    pass\n"
        "m = MyStr('hi')\nup = m.upper()\ncat = m + '!'\n"
        "iss = isinstance(m, str)\n"
    );
    assert expect_str(ms["up"]) == "HI";
    assert expect_str(ms["cat"]) == "hi!";
    assert expect_bool(ms["iss"]) == True;

    # Plain user-class hierarchy: method override + inherited attr + super().
    uc = run_source(
        "class Animal:\n"
        "    def __init__(self, n):\n"
        "        self.n = n\n"
        "    def speak(self):\n"
        "        return self.n\n"
        "class Dog(Animal):\n"
        "    def __init__(self, n, breed):\n"
        "        super().__init__(n)\n"
        "        self.breed = breed\n"
        "    def speak(self):\n"
        "        return super().speak() + ' woof'\n"
        "d = Dog('rex', 'lab')\n"
        "name = d.n\nbreed = d.breed\nsound = d.speak()\n"
        "isa = isinstance(d, Animal)\nisd = isinstance(d, Dog)\n"
        "sub = issubclass(Dog, Animal)\n"
    );
    assert expect_str(uc["name"]) == "rex";
    assert expect_str(uc["breed"]) == "lab";
    assert expect_str(uc["sound"]) == "rex woof";
    assert expect_bool(uc["isa"]) == True;
    assert expect_bool(uc["isd"]) == True;
    assert expect_bool(uc["sub"]) == True;
}

test "pyc-first: user-class operator overloading (__add__/__eq__/... dispatch)" {
    # A plain user class defines operators as dunder methods; nb_binop /
    # tp_richcompare route through the MRO (normal slot, then reflected) instead
    # of only the builtin native slots.
    ops = run_source(
        "class V:\n"
        "    def __init__(self, x):\n"
        "        self.x = x\n"
        "    def __add__(self, o):\n"
        "        return V(self.x + o.x)\n"
        "    def __mul__(self, k):\n"
        "        return V(self.x * k)\n"
        "    def __eq__(self, o):\n"
        "        return self.x == o.x\n"
        "    def __lt__(self, o):\n"
        "        return self.x < o.x\n"
        "add = (V(3) + V(4)).x\n"
        "mul = (V(5) * 3).x\n"
        "eq = (V(5) == V(5))\n"
        "ne = (V(5) != V(6))\n"
        "lt = (V(1) < V(2))\n"
        "gt = (V(3) < V(2))\n"
    );
    assert expect_int(ops["add"]) == 7;
    assert expect_int(ops["mul"]) == 15;
    assert expect_bool(ops["eq"]) == True;
    assert expect_bool(ops["ne"]) == True;
    assert expect_bool(ops["lt"]) == True;
    assert expect_bool(ops["gt"]) == False;

    # Reflected slot: a builtin left operand with no matching native path falls
    # to the user right operand's __radd__ / __rmul__.
    refl = run_source(
        "class R:\n"
        "    def __radd__(self, o):\n"
        "        return o + 100\n"
        "    def __rmul__(self, o):\n"
        "        return o * 10\n"
        "a = 1 + R()\n"
        "b = 5 * R()\n"
    );
    assert expect_int(refl["a"]) == 101;
    assert expect_int(refl["b"]) == 50;

    # __add__ returning NotImplemented yields to the other operand's __radd__.
    ni = run_source(
        "class A:\n"
        "    def __add__(self, o):\n"
        "        return NotImplemented\n"
        "class B:\n"
        "    def __radd__(self, o):\n"
        "        return 77\n"
        "w = A() + B()\n"
    );
    assert expect_int(ni["w"]) == 77;

    # A user-defined __hash__ (+ __eq__) makes an instance a value-keyed dict key
    # and set member; a plain user object keys by identity. Verified through the
    # fully native mp_subscript / set_contains paths (no host round-trip).
    hk = run_source(
        "class H:\n"
        "    def __init__(self, k):\n"
        "        self.k = k\n"
        "    def __hash__(self):\n"
        "        return self.k\n"
        "    def __eq__(self, o):\n"
        "        return self.k == o.k\n"
        "d = {H(1): 'one', H(2): 'two'}\n"
        "v1 = d[H(1)]\nv2 = d[H(2)]\n"
        "s = {H(1), H(2)}\n"
        "hit = H(1) in s\nmiss = H(3) in s\n"
    );
    assert expect_str(hk["v1"]) == "one";
    assert expect_str(hk["v2"]) == "two";
    assert expect_bool(hk["hit"]) == True;
    assert expect_bool(hk["miss"]) == False;

    # An exception raised inside a comparison dunder propagates (it is not
    # swallowed as NotImplemented) -- the substrate the corpus's raising-__eq__
    # cases build on.
    raising = run_source(
        "class Bad:\n"
        "    def __eq__(self, o):\n"
        "        raise ValueError('boom')\n"
        "hit = 0\n"
        "try:\n"
        "    Bad() == Bad()\n"
        "except ValueError:\n"
        "    hit = 1\n"
    );
    assert expect_int(raising["hit"]) == 1;
}

test "pyc-first: len() reads native container size in-VM (no to_host drain)" {
    # len() over the native container types is measured from their own storage.
    sizes = run_source(
        "a = len('hello')\n"
        "b = len(b'ab')\n"
        "c = len((1, 2, 3))\n"
        "d = len([1, 2])\n"
        "e = len({'x': 1, 'y': 2})\n"
        "f = len({1, 2, 3, 3})\n"
    );
    assert expect_int(sizes["a"]) == 5;
    assert expect_int(sizes["b"]) == 2;
    assert expect_int(sizes["c"]) == 3;
    assert expect_int(sizes["d"]) == 2;
    assert expect_int(sizes["e"]) == 2;
    assert expect_int(sizes["f"]) == 3;

    # The regression: a native set/list/dict of PLAIN user objects. Each member
    # to_host-es to None, so counting a host copy loses them; the native path
    # reads the real member count. __hash__/__eq__ make them distinct set/key
    # members without collapsing.
    plain = run_source(
        "class P:\n"
        "    def __init__(self, k):\n"
        "        self.k = k\n"
        "    def __hash__(self):\n"
        "        return self.k\n"
        "    def __eq__(self, o):\n"
        "        return self.k == o.k\n"
        "s = len({P(1), P(2), P(3)})\n"
        "l = len([P(1), P(1), P(1)])\n"
        "d = len({P(1): 'a', P(2): 'b'})\n"
    );
    assert expect_int(plain["s"]) == 3;
    assert expect_int(plain["l"]) == 3;
    assert expect_int(plain["d"]) == 2;

    # A user class with __len__ dispatches to it; truthiness of the count works.
    dunder = run_source(
        "class Box:\n"
        "    def __init__(self, n):\n"
        "        self.n = n\n"
        "    def __len__(self):\n"
        "        return self.n\n"
        "z = len(Box(7))\n"
    );
    assert expect_int(dunder["z"]) == 7;

    # A user object with no __len__ raises TypeError (recoverable).
    err = run_source(
        "class Bare:\n"
        "    pass\n"
        "hit = 0\n"
        "try:\n"
        "    len(Bare())\n"
        "except TypeError:\n"
        "    hit = 1\n"
    );
    assert expect_int(err["hit"]) == 1;
}

test "pyc-first: object identity -- is / id (Track I)" {
    # None/bool singletons + small-int cache match CPython; mutable containers
    # and big ints use real reference identity. Previously IS_OP compared type
    # tags, so [] is [] wrongly returned True.
    ident = run_source(
        "n = None is None\n"
        "t = True is True\n"
        "f = False is False\n"
        "tf = True is False\n"
        "k1 = 200\nk2 = 56\nc256 = 256\nsi = (k1 + k2) is c256\n"
        "b1 = 1000\nb2 = 1\nc1001 = 1001\nbi = (b1 + b2) is c1001\n"
        "el = [] is []\n"
        "nn = None is not None\n"
    );
    assert expect_bool(ident["n"]) == True;
    assert expect_bool(ident["t"]) == True;
    assert expect_bool(ident["f"]) == True;
    assert expect_bool(ident["tf"]) == False;
    assert expect_bool(ident["si"]) == True;
    assert expect_bool(ident["bi"]) == False;
    assert expect_bool(ident["el"]) == False;
    assert expect_bool(ident["nn"]) == False;

    # Aliasing: an object is identical to itself, distinct from an equal literal.
    alias = run_source("a = [1, 2]\nb = a\nsame = a is b\nc = [1, 2]\ndiff = a is c\n");
    assert expect_bool(alias["same"]) == True;
    assert expect_bool(alias["diff"]) == False;

    # id() is stable, singleton-consistent, and distinct for distinct live objects.
    ids = run_source(
        "x = [1]\nself_id = id(x) == id(x)\n"
        "none_id = id(None) == id(None)\n"
        "small_id = id(5) == id(5)\n"
        "p = [1]\nq = [2]\ndistinct = id(p) != id(q)\n"
    );
    assert expect_bool(ids["self_id"]) == True;
    assert expect_bool(ids["none_id"]) == True;
    assert expect_bool(ids["small_id"]) == True;
    assert expect_bool(ids["distinct"]) == True;
}

test "pyc-first: hash() builtin + float.__hash__ collapse (H4)" {
    # Native ``py_hash`` routes ints/floats/tuples through object helpers; host
    # fallback remains for types not yet ported (see ``abstract_protocol``).
    # hash(1) == hash(1.0) == hash(True). float.__hash__ and tuple hashing work.
    h = run_source(
        "collapse = hash(1) == hash(1.0) == hash(True)\n"
        "fh = (2.0).__hash__() == hash(2)\n"
        "th = hash((1, 2)) == hash((1, 2))\n"
    );
    assert expect_bool(h["collapse"]) == True;
    assert expect_bool(h["fh"]) == True;
    assert expect_bool(h["th"]) == True;
}

test "pyc-first: hash routing applies long sentinel and bool/int symmetry" {
    # ``hash((-1,))`` must not propagate raw ``-1`` lanes; ``True == 1`` must
    # match ``1 == True`` (bool is an int subclass on both sides).
    probe = run_source(
        "neg1_lane = hash((-1,)) != -1\n"
        "str_stable = hash('a') == hash('a')\n"
        "float_stable = hash(1.5) == hash(1.5)\n"
        "true_eq = True == 1\n"
        "int_eq = 1 == True\n"
    );
    assert expect_bool(probe["neg1_lane"]) == True;
    assert expect_bool(probe["str_stable"]) == True;
    assert expect_bool(probe["float_stable"]) == True;
    assert expect_bool(probe["true_eq"]) == True;
    assert expect_bool(probe["int_eq"]) == True;
}

test "pyc-first: cross-type ordering raises TypeError" {
    err = run_source(
        "hit = 0\n"
        "try:\n"
        "    1 < 'a'\n"
        "except TypeError:\n"
        "    hit = hit + 1\n"
        "try:\n"
        "    (1, 2) < 'a'\n"
        "except TypeError:\n"
        "    hit = hit + 1\n"
    );
    assert expect_int(err["hit"]) == 2;
}

test "pyc-first: full generator functions (def + yield) drive natively" {
    # A CO_GENERATOR-flagged def returns a generator on call; the body only runs
    # on resume. Plain iteration (list/sum) drains through gen_drain.
    simple = run_source(
        "def g():\n"
        "    yield 1\n"
        "    yield 2\n"
        "    yield 3\n"
        "result = list(g())\n"
        "total = sum(g())\n"
    );
    assert expect_int(py_subscript(simple["result"], PyInt(t="int", val=0))) == 1;
    assert expect_int(py_subscript(simple["result"], PyInt(t="int", val=2))) == 3;
    assert expect_int(simple["total"]) == 6;
}

test "pyc-first: generator .send() round-trips values through the yield" {
    # `v = yield total` binds the sent value; a just-started generator is primed
    # with send(None). Each send resumes at the suspended yield.
    accum = run_source(
        "def accumulate():\n"
        "    total = 0\n"
        "    while True:\n"
        "        v = yield total\n"
        "        total = total + v\n"
        "gen = accumulate()\n"
        "first = gen.send(None)\n"
        "a = gen.send(10)\n"
        "b = gen.send(5)\n"
    );
    assert expect_int(accum["first"]) == 0;
    assert expect_int(accum["a"]) == 10;
    assert expect_int(accum["b"]) == 15;
}

test "pyc-first: next() drives one step and honors a StopIteration default" {
    stepped = run_source(
        "def two():\n"
        "    yield 1\n"
        "    yield 2\n"
        "gen = two()\n"
        "a = next(gen)\n"
        "b = next(gen)\n"
        "c = next(gen, 99)\n"
    );
    assert expect_int(stepped["a"]) == 1;
    assert expect_int(stepped["b"]) == 2;
    assert expect_int(stepped["c"]) == 99;
}

test "pyc-first: yield from delegates and captures the sub-generator return" {
    # SEND / END_SEND / GET_YIELD_FROM_ITER: `yield from inner()` re-yields each
    # of inner's values and binds inner's `return` as the yield-from result.
    delegated = run_source(
        "def inner():\n"
        "    yield 1\n"
        "    yield 2\n"
        "    return 3\n"
        "def outer():\n"
        "    r = yield from inner()\n"
        "    yield r\n"
        "result = list(outer())\n"
    );
    assert expect_int(py_subscript(delegated["result"], PyInt(t="int", val=0))) == 1;
    assert expect_int(py_subscript(delegated["result"], PyInt(t="int", val=1))) == 2;
    assert expect_int(py_subscript(delegated["result"], PyInt(t="int", val=2))) == 3;
}

test "pyc-first: yield from a plain (native) iterable re-yields its items" {
    delegated = run_source(
        "def outer():\n" "    yield from [10, 20, 30]\n" "result = list(outer())\n"
    );
    assert expect_int(py_subscript(delegated["result"], PyInt(t="int", val=0))) == 10;
    assert expect_int(py_subscript(delegated["result"], PyInt(t="int", val=2))) == 30;
}

test "pyc-first: gen.throw() raises at the suspend point for the body to catch" {
    caught = run_source(
        "def catcher():\n"
        "    try:\n"
        "        yield 1\n"
        "    except ValueError:\n"
        "        yield 2\n"
        "    yield 3\n"
        "gen = catcher()\n"
        "a = next(gen)\n"
        "b = gen.throw(ValueError)\n"
        "c = next(gen)\n"
    );
    assert expect_int(caught["a"]) == 1;
    assert expect_int(caught["b"]) == 2;
    assert expect_int(caught["c"]) == 3;
}

test "pyc-first: send() and throw() thread through yield from into the sub" {
    # Values sent into the delegating generator reach the sub-generator's yields,
    # and its return becomes the yield-from result.
    threaded = run_source(
        "def inner():\n"
        "    a = yield 1\n"
        "    b = yield a + 1\n"
        "    return b\n"
        "def outer():\n"
        "    r = yield from inner()\n"
        "    yield r\n"
        "gen = outer()\n"
        "x = next(gen)\n"
        "y = gen.send(10)\n"
        "z = gen.send(20)\n"
    );
    assert expect_int(threaded["x"]) == 1;
    assert expect_int(threaded["y"]) == 11;
    assert expect_int(threaded["z"]) == 20;

    # A throw is delegated into the sub-generator, which catches it.
    caught = run_source(
        "def inner():\n"
        "    try:\n"
        "        yield 1\n"
        "    except ValueError:\n"
        "        yield 2\n"
        "    yield 3\n"
        "def outer():\n"
        "    yield from inner()\n"
        "gen = outer()\n"
        "a = next(gen)\n"
        "b = gen.throw(ValueError)\n"
        "c = next(gen)\n"
    );
    assert expect_int(caught["a"]) == 1;
    assert expect_int(caught["b"]) == 2;
    assert expect_int(caught["c"]) == 3;
}

test "pyc-first: gen.close() finalizes; further next() reports exhaustion" {
    closed = run_source(
        "def g():\n"
        "    yield 1\n"
        "    yield 2\n"
        "gen = g()\n"
        "a = next(gen)\n"
        "gen.close()\n"
        "c = next(gen, -1)\n"
    );
    assert expect_int(closed["a"]) == 1;
    assert expect_int(closed["c"]) == -1;

    # A generator that catches GeneratorExit and returns a value: close()
    # surfaces that value (CPython 3.13+), and a second close() returns None.
    returning = run_source(
        "def f():\n"
        "    try:\n"
        "        yield\n"
        "    except GeneratorExit:\n"
        "        return 7\n"
        "gen = f()\n"
        "gen.send(None)\n"
        "first = gen.close()\n"
        "second = gen.close()\n"
    );
    assert expect_int(returning["first"]) == 7;
    assert returning["second"].t == "none";
}

test "pyc-first: async def / await drives a coroutine through the SEND path" {
    # A CO_COROUTINE-flagged def returns a coroutine on call; the body only runs
    # on drive. `await inner()` lowers to GET_AWAITABLE + the same SEND loop
    # `yield from` uses, so awaiting a native coroutine completes synchronously.
    outs = run_source(
        "async def inner():\n"
        "    return 42\n"
        "async def main():\n"
        "    x = await inner()\n"
        "    return x + 1\n"
        "c = main()\n"
    );
    coro = outs["c"];
    assert coro.t == "coroutine";
    # Driving a coroutine to completion raises StopIteration(return value), the
    # same protocol asyncio's event loop reads to collect a coroutine's result.
    done = gen_send(coro as PyGenerator, py_none());
    assert is_error(done);
    finished = (done as PyError).exception;
    assert finished.type_name == "StopIteration";
    assert expect_int(finished.value as PyObj) == 43;

    # await chains: main -> b -> a, each awaiting the next. The nested SEND loops
    # thread the returned values back up through END_SEND.
    chain = run_source(
        "async def a():\n"
        "    return 10\n"
        "async def b():\n"
        "    r = await a()\n"
        "    return r * 2\n"
        "async def main():\n"
        "    return await b()\n"
        "c = main()\n"
    );
    chained = gen_send(chain["c"] as PyGenerator, py_none());
    assert is_error(chained);
    assert expect_int((chained as PyError).exception.value as PyObj) == 20;
}

test "pyc-first: dict equality invokes element __eq__ (container compare, Track a)" {
    # dict richcompare walks keys/values through py_compare, so a user element's
    # __eq__ runs (and a raise propagates) instead of the by-hashkey model
    # silently answering. Value-level inequality is now detected, not tag-matched.
    basics = run_source(
        "a = ({1: 2} == {1: 2})\n"
        "b = ({1: 2} == {1: 3})\n"
        "c = ({1: 2} == {2: 2})\n"
        "d = ({1: 1} == {1: 1, 2: 2})\n"
        "e = ({1: 2} != {1: 3})\n"
        "f = ({} == {})\n"
    );
    assert expect_bool(basics["a"]) == True;
    assert expect_bool(basics["b"]) == False;
    assert expect_bool(basics["c"]) == False;
    assert expect_bool(basics["d"]) == False;
    assert expect_bool(basics["e"]) == True;
    assert expect_bool(basics["f"]) == True;

    # test_dict.test_eq verbatim: BadCmp hashes to 1 (colliding with int 1) and
    # its __eq__ raises, so `{BadCmp(): 1} == {1: 1}` must raise, not compare equal.
    raised = run_source(
        "class Exc(Exception): pass\n"
        "class BadCmp:\n"
        "    def __eq__(self, other): raise Exc()\n"
        "    def __hash__(self): return 1\n"
        "hit = 0\n"
        "try:\n"
        "    {BadCmp(): 1} == {1: 1}\n"
        "except Exc:\n"
        "    hit = 1\n"
    );
    assert expect_int(raised["hit"]) == 1;
}

test "pyc-first: user-defined exception classes raise and match (except UserExc)" {
    # `class Exc(Exception)` instances raise as an exception tagged with the class
    # name and match `except Exc` / `except Exception` by MRO; a raised class
    # auto-instantiates; a sibling except does not catch.
    caught = run_source(
        "class Exc(Exception): pass\n"
        "class MyErr(ValueError): pass\n"
        "a = b = c = d = 0\n"
        "try:\n"
        "    raise Exc()\n"
        "except Exc:\n"
        "    a = 1\n"
        "try:\n"
        "    raise MyErr()\n"
        "except Exception:\n"
        "    b = 1\n"
        "try:\n"
        "    raise Exc\n"
        "except Exc:\n"
        "    c = 1\n"
        "class A(Exception): pass\n"
        "class B(Exception): pass\n"
        "try:\n"
        "    try:\n"
        "        raise A()\n"
        "    except B:\n"
        "        d = 9\n"
        "except A:\n"
        "    d = 1\n"
    );
    assert expect_int(caught["a"]) == 1;
    assert expect_int(caught["b"]) == 1;
    assert expect_int(caught["c"]) == 1;
    assert expect_int(caught["d"]) == 1;
}

test "pyc-first: set literal first-value-wins + native .pop()/methods (Track d/e)" {
    # {1, 1.0, True} collapses to one member and KEEPS the first (int 1) it saw.
    lit = run_source(
        "s = {1, 1.0, True}\n"
        "n = len(s)\n"
        "popped = s.pop()\n"
        "kind = type(popped).__name__\n"
    );
    assert expect_int(lit["n"]) == 1;
    assert expect_str(lit["kind"]) == "int";

    # Native set algebra methods over arbitrary iterables.
    methods = run_source(
        "a = str(sorted({1, 2, 3}.difference([2])))\n"
        "b = str(sorted({1, 2}.union([3, 4])))\n"
        "c = str(sorted({1, 2, 3}.intersection([2, 3, 4])))\n"
        "d = {1, 2}.issubset([1, 2, 3])\n"
        "e = {1, 2}.isdisjoint([3, 4])\n"
        "s = {1, 2}\n"
        "s.update([3])\n"
        "f = str(sorted(s))\n"
    );
    assert expect_str(methods["a"]) == "[1, 3]";
    assert expect_str(methods["b"]) == "[1, 2, 3, 4]";
    assert expect_str(methods["c"]) == "[2, 3]";
    assert expect_bool(methods["d"]) == True;
    assert expect_bool(methods["e"]) == True;
    assert expect_str(methods["f"]) == "[1, 2, 3]";

    # test_set.test_issue_37219: a non-iterable difference arg is a TypeError.
    err = run_source(
        "h1 = h2 = 0\n"
        "try:\n"
        "    set().difference(123)\n"
        "except TypeError:\n"
        "    h1 = 1\n"
        "try:\n"
        "    set().difference_update(123)\n"
        "except TypeError:\n"
        "    h2 = 1\n"
    );
    assert expect_int(err["h1"]) == 1;
    assert expect_int(err["h2"]) == 1;

    # M9: issubset / isdisjoint use element ``==``, not hashkey bucket only.
    # Identity-keyed user objects (no ``__hash__``) can be ``==`` without sharing
    # a hashkey — CPython set algebra still treats them as members.
    subset_eq = run_source(
        "class AlwaysEq:\n"
        "    def __eq__(self, other):\n"
        "        return isinstance(other, AlwaysEq)\n"
        "a, b = AlwaysEq(), AlwaysEq()\n"
        "sub = {a}.issubset({b})\n"
        "le = {a} <= {b}\n"
        "dis = {a}.isdisjoint({b})\n"
        "mem = a in {b}\n"
    );
    assert expect_bool(subset_eq["sub"]) == True;
    assert expect_bool(subset_eq["le"]) == True;
    assert expect_bool(subset_eq["dis"]) == False;
    assert expect_bool(subset_eq["mem"]) == True;
}

test "pyc-first: dict mutation during iteration raises RuntimeError (Track b)" {
    # A size change OR a net-zero delete+reinsert bumps the dict version, which
    # the native iterator snapshots and checks -- both raise, matching CPython.
    insert = run_source(
        "d = {}\n"
        "d[1] = 1\n"
        "hit = 0\n"
        "try:\n"
        "    for i in d:\n"
        "        d[i + 1] = 1\n"
        "except RuntimeError:\n"
        "    hit = 1\n"
    );
    assert expect_int(insert["hit"]) == 1;

    reinsert = run_source(
        "d = {}\n"
        "d[0] = 0\n"
        "hit = 0\n"
        "try:\n"
        "    for i in d:\n"
        "        del d[0]\n"
        "        d[0] = 0\n"
        "except RuntimeError:\n"
        "    hit = 1\n"
    );
    assert expect_int(reinsert["hit"]) == 1;

    # A clean iteration (no mutation) still runs to completion.
    clean = run_source(
        "d = {1: 10, 2: 20, 3: 30}\n"
        "total = 0\n"
        "for k in d:\n"
        "    total = total + k\n"
    );
    assert expect_int(clean["total"]) == 6;
}

test "pyc-first: native dict views -- set ops + element-eq compare (Track c)" {
    # keys()/items() are set-like: comparison and | & - ^ against sets/views work.
    mixed = run_source(
        "a = ({1: 1}.keys() == {1})\n"
        "b = ({1} == {1: 1}.keys())\n"
        "c = str(sorted({1: 1}.keys() | {2}))\n"
        "d = str(sorted({2} | {1: 1}.keys()))\n"
        "e = ({1: 1}.items() == {(1, 1)})\n"
        "k1 = {1: 1, 2: 2}.keys()\n"
        "k2 = {1: 1, 2: 2, 3: 3}.keys()\n"
        "f = str(sorted(k2 - k1))\n"
        "g = str(sorted(k1 & k2))\n"
    );
    assert expect_bool(mixed["a"]) == True;
    assert expect_bool(mixed["b"]) == True;
    assert expect_str(mixed["c"]) == "[1, 2]";
    assert expect_str(mixed["d"]) == "[1, 2]";
    assert expect_bool(mixed["e"]) == True;
    assert expect_str(mixed["f"]) == "[3]";
    assert expect_str(mixed["g"]) == "[1, 2]";

    # test_dict.test_errors_in_view_containment_check: an items-view comparison
    # looks up keys and compares values, so a raising element __eq__ propagates.
    raising = run_source(
        "class C:\n"
        "    def __eq__(self, other): raise RuntimeError\n"
        "d1 = {1: C()}\n"
        "d2 = {1: C()}\n"
        "eqh = neh = leh = 0\n"
        "try:\n"
        "    d1.items() == d2.items()\n"
        "except RuntimeError:\n"
        "    eqh = 1\n"
        "try:\n"
        "    d1.items() != d2.items()\n"
        "except RuntimeError:\n"
        "    neh = 1\n"
        "try:\n"
        "    d1.items() <= d2.items()\n"
        "except RuntimeError:\n"
        "    leh = 1\n"
    );
    assert expect_int(raising["eqh"]) == 1;
    assert expect_int(raising["neh"]) == 1;
    assert expect_int(raising["leh"]) == 1;

    # Mutation while iterating a values()/items() view also raises.
    view_ns = run_source(
        "d = {}\n"
        "d[0] = 0\n"
        "hit = 0\n"
        "try:\n"
        "    for i in d.items():\n"
        "        del d[0]\n"
        "        d[0] = 0\n"
        "except RuntimeError:\n"
        "    hit = 1\n"
    );
    assert expect_int(view_ns["hit"]) == 1;
}

test "pyc-first: STORE_SUBSCR errors reach the handler; popitem is LIFO" {
    # An exception from item assignment (tuple is immutable) must be catchable by
    # the surrounding try/except -- STORE_SUBSCR routes through recover_exception.
    r = run_source(
        "hit = 0\n"
        "t = (1, 2)\n"
        "try:\n"
        "    t[0] = 5\n"
        "except TypeError:\n"
        "    hit = 1\n"
        # dict.popitem() is LIFO: returns the LAST inserted pair.
        "d = {'a': 1, 'b': 2}\n"
        "pk = d.popitem()[0]\n"
    );
    assert expect_int(r["hit"]) == 1;
    assert expect_str(r["pk"]) == "b";
}

test "pyc-first: int ** negative is float; raise-from records __cause__" {
    r = run_source(
        "p = 2 ** -1\n"
        "z = 0\n"
        "try:\n"
        "    _ = 0 ** -1\n"
        "except ZeroDivisionError:\n"
        "    z = 1\n"
        "hc = 0\n"
        "try:\n"
        "    raise ValueError('v') from KeyError('k')\n"
        "except ValueError as e:\n"
        "    hc = 1 if e.__cause__ is not None else 0\n"
    );
    assert expect_float(r["p"]) == 0.5;
    assert expect_int(r["z"]) == 1;
    assert expect_int(r["hc"]) == 1;
}

test "pyc-first: builtin-subclass __eq__ + reflected-operator subclass priority" {
    r = run_source(
        # A builtin subclass's own __eq__ override is honored (was skipped by the
        # _has_base guard that user_binop never had).
        "class MyInt(int):\n"
        "    def __eq__(self, other): return 'custom'\n"
        "eqr = MyInt(5) == 5\n"
        # type(rhs) a proper subclass of type(lhs) overriding the reflected slot
        # runs first: A() + B() -> B.__radd__.
        "class A:\n"
        "    def __add__(self, o): return 'A'\n"
        "class B(A):\n"
        "    def __radd__(self, o): return 'B'\n"
        "rr = A() + B()\n"
    );
    assert expect_str(r["eqr"]) == "custom";
    assert expect_str(r["rr"]) == "B";
}

test "pyc-first: PEP 487 __init_subclass__ fires on subclass creation" {
    r = run_source(
        "class Base:\n"
        "    def __init_subclass__(cls, **kw): cls.registered = True\n"
        "class Sub(Base): pass\n"
        "isc = 1 if getattr(Sub, 'registered', False) else 0\n"
    );
    assert expect_int(r["isc"]) == 1;
}

test "pyc-first: C3 MRO resolves a diamond in strict order; value overwrite in a loop is legal" {
    r = run_source(
        # Diamond W(Y, Z), Y(X), Z(X); m on Z and X only. C3 MRO [W,Y,Z,X] picks Z,
        # a DFS order [W,Y,X,Z] would wrongly pick X.
        "class X:\n"
        "    def m(self): return 'X'\n"
        "class Y(X): pass\n"
        "class Z(X):\n"
        "    def m(self): return 'Z'\n"
        "class W(Y, Z): pass\n"
        "c3 = W().m()\n"
        # A same-key value overwrite during iteration is NOT a size change, so it
        # must not raise (previously the version bump tripped a false RuntimeError).
        "d = {1: 10, 2: 20}\n"
        "ok = 1\n"
        "try:\n"
        "    for k in d:\n"
        "        d[k] = d[k] + 1\n"
        "except RuntimeError:\n"
        "    ok = 0\n"
        "s1 = d[1]\n"
    );
    assert expect_str(r["c3"]) == "Z";
    assert expect_int(r["ok"]) == 1;
    assert expect_int(r["s1"]) == 11;
}
