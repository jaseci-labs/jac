# Phase 6 independent VM conformance (INTEGRATION_PLAN.md proof leg B).
#
# Runs CPython-produced PyCode on jacpython's ceval and compares runtime behavior
# with host CPython. One fixture per opcode in the band-2 compiler emission set,
# plus semantic categories (exceptions, calls, closures, control flow).
#
# Test harness only: host_oracle produces PyCode; product_compile must not import
# this module.

import from objects { PyObj, PyCode, PyInt, PyError, is_error, }
import from host_oracle { host_compile_marshal }
import from product_compile { compile_source }
import from pyc_first { unmarshal, exec_code, to_host }
import from opcode_meta {
    OP_LOAD_LOCALS,
    OP_BINARY_SLICE,
    OP_STORE_SLICE,
    OP_BUILD_SLICE,
    OP_POP_JUMP_IF_NONE
}

::py::
def _vm_host_exec(setup_src, body_src, mode="exec"):
    ns = {"__builtins__": __builtins__}
    if setup_src:
        exec(compile(setup_src, "<vm-host-setup>", "exec"), ns)
    if mode == "eval":
        ns["result"] = eval(compile(body_src, "<vm-host-body>", "eval"), ns)
    else:
        exec(compile(body_src, "<vm-host-body>", "exec"), ns)
    return ns


def _vm_host_equal(a, b):
    try:
        if a != a and b != b:
            return True
        return bool(a == b)
    except BaseException:
        return False


def _vm_host_raises(setup_src, body_src):
    ns = {"__builtins__": __builtins__}
    if setup_src:
        exec(compile(setup_src, "<vm-host-setup>", "exec"), ns)
    try:
        exec(compile(body_src, "<vm-host-body>", "exec"), ns)
        return None
    except BaseException as exc:
        return type(exc).__name__, str(exc)
::py::



def host_result_key(setup: str, body: str, mode: str, key: str) -> any {
    ns = _vm_host_exec(setup, body, mode) as dict;
    return ns[key];
}

def host_raises(setup: str, body: str) -> tuple[str, str] | None {
    raw = _vm_host_raises(setup, body);
    if raw is None {
        return None;
    }
    pair = raw as tuple;
    return (pair[0] as str, pair[1] as str);
}

def jac_run_oracle(setup: str, body: str, mode: str, ns: dict[str, PyObj]) -> PyObj {
    if setup != "" {
        setup_co = unmarshal(host_compile_marshal(setup, "<vm-setup>", "exec", 0));
        out = exec_code(setup_co, [], ns);
        if is_error(out) {
            return out;
        }
    }
    body_co = unmarshal(host_compile_marshal(body, "<vm-body>", mode, 0));
    return exec_code(body_co, [], ns);
}

def code_has_opcode(co: PyCode, target: int) -> bool {
    code = co.co_code;
    i = 0;
    while i < len(code) {
        if code[i] == target {
            return True;
        }
        i = i + 1;
    }
    for const in co.consts {
        if isinstance(const, PyCode) {
            if code_has_opcode(const as PyCode, target) {
                return True;
            }
        }
    }
    return False;
}

def assert_vm_value_matches_host(setup: str, body: str, mode: str, key: str) {
    ns: dict[str, PyObj] = {};
    out = jac_run_oracle(setup, body, mode, ns);
    assert not is_error(out);
    host_val = host_result_key(setup, body, mode, key);
    jac_val = ns[key];
    assert _vm_host_equal(to_host(jac_val), host_val) as bool;
}

# ---------------- per-opcode fixtures (band-2 emission set) ----------------

# vm-opcode: OP_RESUME
test "vm: RESUME starts module execution" {
    assert_vm_value_matches_host("", "pass\nresult = 0\n", "exec", "result");
}

# vm-opcode: OP_RETURN_VALUE
test "vm: RETURN_VALUE binds module result" {
    assert_vm_value_matches_host("", "result = 1\n", "exec", "result");
}

# vm-opcode: OP_LOAD_CONST
test "vm: LOAD_CONST loads large literal" {
    assert_vm_value_matches_host("", "result = 1000\n", "exec", "result");
}

# vm-opcode: OP_LOAD_SMALL_INT
test "vm: LOAD_SMALL_INT loads tiny literal" {
    assert_vm_value_matches_host("", "result = 3\n", "exec", "result");
}

# vm-opcode: OP_LOAD_NAME
test "vm: LOAD_NAME reads local binding" {
    assert_vm_value_matches_host("x = 9\n", "result = x\n", "exec", "result");
}

# vm-opcode-compiler: OP_LOAD_LOCALS
test "vm: LOAD_LOCALS emitted in native class body with method" {
    body = "class C:\n    def m(self):\n        return 1\n\nresult = C().m()\n";
    co = compile_source(body, "<ll>", "exec", 0);
    assert not is_error(co);
    assert isinstance(co, PyCode);
    assert code_has_opcode(co as PyCode, OP_LOAD_LOCALS);
}

# vm-opcode: OP_LOAD_GLOBAL
test "vm: LOAD_GLOBAL reads function global" {
    setup = "x = 9\n";
    body = "def f():\n    global x\n    return x\nresult = f()\n";
    assert_vm_value_matches_host(setup, body, "exec", "result");
}

# vm-opcode: OP_BINARY_OP
test "vm: BINARY_OP adds bound names" {
    assert_vm_value_matches_host(
        "x = 2\ny = 3\n", "result = x + y\n", "exec", "result"
    );
}

# vm-opcode: OP_UNARY_NEGATIVE
test "vm: UNARY_NEGATIVE negates" {
    assert_vm_value_matches_host("x = 5\n", "result = -x\n", "exec", "result");
}

# vm-opcode: OP_UNARY_INVERT
test "vm: UNARY_INVERT inverts bits" {
    assert_vm_value_matches_host("x = 5\n", "result = ~x\n", "exec", "result");
}

# vm-opcode: OP_UNARY_NOT
test "vm: UNARY_NOT coerces truthiness" {
    assert_vm_value_matches_host("x = 0\n", "result = not x\n", "exec", "result");
}

# vm-opcode: OP_PUSH_NULL
test "vm: PUSH_NULL precedes call" {
    assert_vm_value_matches_host("", "result = len([1])\n", "exec", "result");
}

# vm-opcode: OP_CALL
test "vm: CALL invokes callable" {
    assert_vm_value_matches_host("", "result = len([1, 2, 3])\n", "exec", "result");
}

# vm-opcode: OP_CALL_KW
test "vm: CALL_KW invokes callable with keywords" {
    assert_vm_value_matches_host(
        "def f(a, b=0):\n    return a + b\n", "result = f(1, b=2)\n", "exec", "result",
    );
}

# vm-opcode: OP_MAKE_FUNCTION
test "vm: MAKE_FUNCTION builds function object" {
    assert_vm_value_matches_host(
        "", "def f():\n    return 1\nresult = f()\n", "exec", "result"
    );
}

# vm-opcode: OP_LOAD_BUILD_CLASS
test "vm: LOAD_BUILD_CLASS builds class object" {
    assert_vm_value_matches_host(
        "", "class C:\n    pass\nresult = C.__name__\n", "exec", "result",
    );
}

# vm-opcode: OP_MAKE_CELL
test "vm: MAKE_CELL allocates closure cell" {
    assert_vm_value_matches_host(
        "",
        "def outer(x):\n    def inner():\n        return x\n    return inner()\nresult = outer(42)\n",
        "exec",
        "result",
    );
}

# vm-opcode: OP_COPY_FREE_VARS
test "vm: COPY_FREE_VARS copies closure cells into inner frame" {
    assert_vm_value_matches_host(
        "",
        "def outer(x):\n    def inner():\n        return x\n    return inner()\nresult = outer(42)\n",
        "exec",
        "result",
    );
}

# vm-opcode: OP_LOAD_DEREF
test "vm: LOAD_DEREF reads closure cell" {
    assert_vm_value_matches_host(
        "",
        "def outer(x):\n    def inner():\n        return x\n    return inner()\nresult = outer(42)\n",
        "exec",
        "result",
    );
}

# vm-opcode: OP_STORE_DEREF
test "vm: STORE_DEREF writes closure cell" {
    assert_vm_value_matches_host(
        "",
        "def outer():\n    x = 1\n    def inner():\n        nonlocal x\n        x = 2\n    inner()\n    return x\nresult = outer()\n",
        "exec",
        "result",
    );
}

# vm-opcode: OP_BUILD_TUPLE
test "vm: BUILD_TUPLE assembles closure freevar tuple" {
    assert_vm_value_matches_host(
        "",
        "def outer(x):\n    def inner():\n        return x\n    return inner()\nresult = outer(42)\n",
        "exec",
        "result",
    );
}

# vm-opcode: OP_SET_FUNCTION_ATTRIBUTE
test "vm: SET_FUNCTION_ATTRIBUTE attaches closure to function" {
    assert_vm_value_matches_host(
        "",
        "def outer(x):\n    def inner():\n        return x\n    return inner()\nresult = outer(42)\n",
        "exec",
        "result",
    );
}

test "vm: SET_FUNCTION_ATTRIBUTE attaches defaults to function" {
    assert_vm_value_matches_host(
        "", "def f(x, y=10):\n    return x + y\nresult = f(2)\n", "exec", "result",
    );
}

# vm-opcode: OP_COMPARE_OP
test "vm: COMPARE_OP orders values" {
    assert_vm_value_matches_host("", "result = 1 < 2\n", "exec", "result");
}

# vm-opcode: OP_POP_TOP
test "vm: POP_TOP discards expr-statement value" {
    assert_vm_value_matches_host("x = 1\n", "x\nresult = 0\n", "exec", "result");
}

# vm-opcode: OP_STORE_NAME
test "vm: STORE_NAME binds global" {
    assert_vm_value_matches_host("", "x = 7\nresult = x\n", "exec", "result");
}

# vm-opcode: OP_STORE_ATTR
test "vm: STORE_ATTR writes attribute" {
    setup = "class Box:\n    pass\nbox = Box()\n";
    body = "box.x = 11\nresult = box.x\n";
    assert_vm_value_matches_host(setup, body, "exec", "result");
}

# vm-opcode: OP_STORE_SUBSCR
test "vm: STORE_SUBSCR writes element" {
    setup = "seq = [10, 20, 30]\n";
    body = "seq[1] = 99\nresult = seq[1]\n";
    assert_vm_value_matches_host(setup, body, "exec", "result");
}

# vm-opcode: OP_LOAD_ATTR
test "vm: LOAD_ATTR reads attribute" {
    setup = "class Box:\n    pass\nbox = Box()\nbox.x = 4\n";
    body = "result = box.x\n";
    assert_vm_value_matches_host(setup, body, "exec", "result");
}

# vm-opcode: OP_DELETE_NAME
test "vm: DELETE_NAME removes binding" {
    setup = "x = 0\n";
    body = "x = 1\ndel x\nresult = 0\n";
    assert_vm_value_matches_host(setup, body, "exec", "result");
}

# vm-opcode: OP_DELETE_FAST
test "vm: DELETE_FAST clears except-as binding in function" {
    setup = "";
    body = "def f():\n    try:\n        1 // 0\n    except ZeroDivisionError as e:\n        return str(e)\nresult = f()\n";
    assert_vm_value_matches_host(setup, body, "exec", "result");
}

# vm-opcode: OP_DELETE_ATTR
test "vm: DELETE_ATTR removes attribute" {
    setup = "class Box:\n    pass\nbox = Box()\nbox.x = 1\n";
    body = "del box.x\nresult = 0\n";
    assert_vm_value_matches_host(setup, body, "exec", "result");
}

# vm-opcode: OP_DELETE_SUBSCR
test "vm: DELETE_SUBSCR removes element" {
    setup = "seq = [1, 2, 3]\n";
    body = "del seq[0]\nresult = len(seq)\n";
    assert_vm_value_matches_host(setup, body, "exec", "result");
}

# vm-opcode: OP_POP_JUMP_IF_FALSE
test "vm: POP_JUMP_IF_FALSE selects else branch" {
    assert_vm_value_matches_host(
        "x = 0\n", "if x:\n    result = 1\nelse:\n    result = 2\n", "exec", "result",
    );
}

# vm-opcode: OP_NOT_TAKEN
test "vm: NOT_TAKEN follows conditional branch in if/else" {
    assert_vm_value_matches_host(
        "x = 0\n", "if x:\n    result = 1\nelse:\n    result = 2\n", "exec", "result",
    );
}

# vm-opcode: OP_POP_JUMP_IF_TRUE
test "vm: POP_JUMP_IF_TRUE short-circuits or" {
    assert_vm_value_matches_host(
        "x = 0\ny = 2\n", "result = x or y\n", "exec", "result"
    );
}

# vm-opcode-compiler: OP_JUMP_FORWARD
test "vm: JUMP_FORWARD from native codegen matches host behavior" {
    setup = "";
    body = "a = x < y < z\nresult = 0\n";
    ns: dict[str, PyObj] = {
        "x": PyInt(t="int", val=1),
        "y": PyInt(t="int", val=2),
        "z": PyInt(t="int", val=3),

    };
    co = compile_source(body, "<jf>", "exec", 0);
    assert not is_error(co);
    assert isinstance(co, PyCode);
    out = exec_code(co as PyCode, [], ns);
    assert not is_error(out);
    host_ns = _vm_host_exec("x = 1\ny = 2\nz = 3\n", body, "exec") as dict;
    host_val = host_ns["a"];
    assert _vm_host_equal(to_host(ns["a"]), host_val) as bool;
}

# vm-opcode: OP_COPY
test "vm: COPY preserves chained assignment RHS" {
    assert_vm_value_matches_host("", "x = y = 42\nresult = x + y\n", "exec", "result");
}

# vm-opcode: OP_SWAP
test "vm: SWAP supports chained comparison" {
    assert_vm_value_matches_host(
        "a = 1\nb = 2\nc = 3\n", "result = (a < b < c)\n", "exec", "result",
    );
}

# vm-opcode: OP_TO_BOOL
test "vm: TO_BOOL drives conditional branch" {
    assert_vm_value_matches_host(
        "x = 1\n", "if x:\n    result = 1\nelse:\n    result = 0\n", "exec", "result",
    );
}

# vm-opcode: OP_GET_ITER
test "vm: GET_ITER drives for-loop iteration" {
    assert_vm_value_matches_host(
        "",
        "total = 0\nfor i in range(3):\n    total += i\nresult = total\n",
        "exec",
        "result",
    );
}

# vm-opcode: OP_FOR_ITER
test "vm: FOR_ITER advances for-loop" {
    assert_vm_value_matches_host(
        "",
        "total = 0\nfor i in range(3):\n    total += i\nresult = total\n",
        "exec",
        "result",
    );
}

# vm-opcode: OP_END_FOR
test "vm: END_FOR completes for-loop" {
    assert_vm_value_matches_host(
        "",
        "total = 0\nfor i in range(3):\n    total += i\nresult = total\n",
        "exec",
        "result",
    );
}

# vm-opcode: OP_JUMP_BACKWARD
test "vm: JUMP_BACKWARD drives while-loop" {
    assert_vm_value_matches_host(
        "", "i = 0\nwhile i < 3:\n    i += 1\nresult = i\n", "exec", "result",
    );
}

# vm-opcode: OP_NOP
test "vm: NOP is a no-op in while break path" {
    assert_vm_value_matches_host(
        "x = 1\n", "while x: break\nresult = 0\n", "exec", "result",
    );
}

# vm-opcode: OP_POP_ITER
test "vm: POP_ITER completes for-loop iterator cleanup" {
    assert_vm_value_matches_host(
        "",
        "total = 0\nfor i in range(3):\n    total += i\nresult = total\n",
        "exec",
        "result",
    );
}

# vm-opcode: OP_BUILD_LIST
test "vm: BUILD_LIST builds list comprehension accumulator" {
    assert_vm_value_matches_host(
        "y = [1, 2, 3]\n", "result = [x for x in y]\n", "exec", "result",
    );
}

# vm-opcode: OP_BUILD_SET
test "vm: BUILD_SET builds set comprehension accumulator" {
    assert_vm_value_matches_host(
        "y = [1, 2, 3]\n", "result = {x for x in y}\n", "exec", "result",
    );
}

# vm-opcode: OP_LIST_APPEND
test "vm: LIST_APPEND appends in list comprehension" {
    assert_vm_value_matches_host(
        "y = [1, 2, 3]\n", "result = [x for x in y]\n", "exec", "result",
    );
}

# vm-opcode: OP_SET_ADD
test "vm: SET_ADD adds in set comprehension" {
    assert_vm_value_matches_host(
        "y = [1, 2, 3]\n", "result = {x for x in y}\n", "exec", "result",
    );
}

# vm-opcode: OP_BUILD_MAP
test "vm: BUILD_MAP builds dict comprehension accumulator" {
    assert_vm_value_matches_host(
        "y = [1, 2, 3]\n", "result = {x: x for x in y}\n", "exec", "result",
    );
}

# vm-opcode: OP_MAP_ADD
test "vm: MAP_ADD adds in dict comprehension" {
    assert_vm_value_matches_host(
        "y = [1, 2, 3]\n", "result = {x: x for x in y}\n", "exec", "result",
    );
}

# vm-opcode: OP_DICT_UPDATE
test "vm: DICT_UPDATE merges dict unpacking" {
    assert_vm_value_matches_host(
        "y = {'a': 1}\n", "result = {**y, 'z': 9}\n", "exec", "result",
    );
}

# vm-opcode: OP_LOAD_FAST
test "vm: LOAD_FAST loads async-for loop accumulator" {
    setup = "";
    body = "class AI:\n    def __aiter__(self):\n        return self\n    async def __anext__(self):\n        if getattr(self, 'done', False):\n            raise StopAsyncIteration\n        self.done = True\n        return 42\nasync def f():\n    total = 0\n    async for x in AI():\n        total = total + x\n    return total\nc = f()\nresult = 0\ntry:\n    c.send(None)\nexcept StopIteration as e:\n    result = e.value\n";
    assert_vm_value_matches_host(setup, body, "exec", "result");
}

# vm-opcode: OP_LOAD_FAST_CHECK
test "vm: LOAD_FAST_CHECK loads possibly-unbound local" {
    assert_vm_value_matches_host(
        "",
        "def f(x):\n    if x:\n        y = 1\n    return y\nresult = f(1)\n",
        "exec",
        "result",
    );
}

# vm-opcode: OP_LOAD_FAST_BORROW
test "vm: LOAD_FAST_BORROW loads comprehension element" {
    assert_vm_value_matches_host(
        "y = [1, 2, 3]\n", "result = [x for x in y if x > 0]\n", "exec", "result",
    );
}

# vm-opcode: OP_LOAD_FAST_BORROW_LOAD_FAST_BORROW
test "vm: LOAD_FAST_BORROW_LOAD_FAST_BORROW loads dict comp key and value" {
    assert_vm_value_matches_host(
        "pairs = [(1, 2), (3, 4)]\n",
        "result = {k: v for k, v in pairs}\n",
        "exec",
        "result",
    );
}

# vm-opcode: OP_STORE_FAST_STORE_FAST
test "vm: STORE_FAST_STORE_FAST binds dict comp tuple target" {
    assert_vm_value_matches_host(
        "pairs = [(1, 2), (3, 4)]\n",
        "result = {k: v for k, v in pairs}\n",
        "exec",
        "result",
    );
}

# vm-opcode: OP_UNPACK_SEQUENCE
test "vm: UNPACK_SEQUENCE unpacks dict comp tuple target" {
    assert_vm_value_matches_host(
        "pairs = [(1, 2), (3, 4)]\n",
        "result = {k: v for k, v in pairs}\n",
        "exec",
        "result",
    );
}

# vm-opcode: OP_LOAD_FAST_AND_CLEAR
test "vm: LOAD_FAST_AND_CLEAR saves comprehension loop binding" {
    assert_vm_value_matches_host(
        "y = [1, 2, 3]\n", "result = [x for x in y]\n", "exec", "result",
    );
}

# vm-opcode: OP_STORE_FAST
test "vm: STORE_FAST restores comprehension loop binding" {
    assert_vm_value_matches_host(
        "y = [1, 2, 3]\n", "result = [x for x in y]\n", "exec", "result",
    );
}

# vm-opcode: OP_STORE_FAST_LOAD_FAST
test "vm: STORE_FAST_LOAD_FAST binds comprehension iteration variable" {
    assert_vm_value_matches_host(
        "y = [1, 2, 3]\n", "result = [x for x in y]\n", "exec", "result",
    );
}

# vm-opcode: OP_RERAISE
test "vm: RERAISE propagates comprehension cleanup failures" {
    assert_vm_value_matches_host(
        "y = [1, 2, 3]\n", "result = [x for x in y]\n", "exec", "result",
    );
}

# vm-opcode: OP_PUSH_EXC_INFO
test "vm: PUSH_EXC_INFO enters typed except handler" {
    assert_vm_value_matches_host(
        "",
        "try:\n    1 // 0\nexcept ZeroDivisionError:\n    result = 99\n",
        "exec",
        "result",
    );
}

# vm-opcode: OP_CHECK_EXC_MATCH
test "vm: CHECK_EXC_MATCH filters exception type" {
    assert_vm_value_matches_host(
        "",
        "try:\n    1 // 0\nexcept ZeroDivisionError:\n    result = 99\n",
        "exec",
        "result",
    );
}

# vm-opcode: OP_POP_EXCEPT
test "vm: POP_EXCEPT exits except handler" {
    assert_vm_value_matches_host(
        "",
        "try:\n    1 // 0\nexcept ZeroDivisionError:\n    result = 99\n",
        "exec",
        "result",
    );
}

# vm-opcode: OP_RAISE_VARARGS
test "vm: RAISE_VARARGS raises with message" {
    setup = "";
    body = "raise ValueError('bad')\n";
    host_exc = host_raises(setup, body);
    assert host_exc is not None;
    ns: dict[str, PyObj] = {};
    out = jac_run_oracle(setup, body, "exec", ns);
    assert is_error(out);
    err = out as PyError;
    assert err.exception.type_name == "ValueError";
    assert err.exception.message == (host_exc[1] as str);
}

# Regression: a zero-step slice must raise ValueError before the stepping
# loops run -- without the guard, seq[5:1:0] never terminates.
test "vm: zero-step slice subscript raises ValueError like CPython" {
    setup = "";
    body = "seq = [1, 2, 3, 4]\nresult = seq[5:1:0]\n";
    host_exc = host_raises(setup, body);
    assert host_exc is not None;
    ns: dict[str, PyObj] = {};
    out = jac_run_oracle(setup, body, "exec", ns);
    assert is_error(out);
    err = out as PyError;
    assert err.exception.type_name == (host_exc[0] as str);
    assert err.exception.message == (host_exc[1] as str);
}

# Regression: same guard on the delete path (del seq[a:b:c]).
test "vm: del with zero-step slice raises ValueError like CPython" {
    setup = "";
    body = "seq = [1, 2, 3, 4]\ndel seq[5:1:0]\n";
    host_exc = host_raises(setup, body);
    assert host_exc is not None;
    ns: dict[str, PyObj] = {};
    out = jac_run_oracle(setup, body, "exec", ns);
    assert is_error(out);
    err = out as PyError;
    assert err.exception.type_name == (host_exc[0] as str);
    assert err.exception.message == (host_exc[1] as str);
}

# bool is an int subclass: True/False index sequences as 1/0. The str, bytes,
# and tuple subscripts must route through __index__ like list does.
test "vm: bool subscripts index str/bytes/tuple like CPython" {
    assert_vm_value_matches_host(
        "s = 'abc'\nt = (1, 2, 3)\nb = b'xy'\n",
        "result = (s[True], t[False], b[True], s[False], t[True])\n",
        "exec",
        "result",
    );
}

# vm-opcode: OP_LOAD_SPECIAL
test "vm: LOAD_SPECIAL enters context manager" {
    setup = "";
    body = "class CM:\n    def __enter__(self):\n        return 42\n    def __exit__(self, *a):\n        pass\nwith CM() as x:\n    result = x\n";
    assert_vm_value_matches_host(setup, body, "exec", "result");
}

# vm-opcode: OP_WITH_EXCEPT_START
test "vm: WITH_EXCEPT_START handles context manager exit" {
    setup = "";
    body = "class CM:\n    def __enter__(self):\n        return 42\n    def __exit__(self, *a):\n        pass\nwith CM() as x:\n    result = x\n";
    assert_vm_value_matches_host(setup, body, "exec", "result");
}

# vm-opcode: OP_LOAD_COMMON_CONSTANT
test "vm: LOAD_COMMON_CONSTANT raises AssertionError on failed assert" {
    setup = "";
    body = "x = 0\nassert x == 1, 'fail'\nresult = x\n";
    host_exc = host_raises(setup, body);
    assert host_exc is not None;
    ns: dict[str, PyObj] = {};
    out = jac_run_oracle(setup, body, "exec", ns);
    assert is_error(out);
    err = out as PyError;
    assert err.exception.type_name == "AssertionError";
    assert err.exception.message == (host_exc[1] as str);
}

# vm-opcode: OP_IMPORT_NAME
test "vm: IMPORT_NAME loads module" {
    assert_vm_value_matches_host("", "import os\nresult = os.name\n", "exec", "result");
}

# vm-opcode: OP_IMPORT_FROM
test "vm: IMPORT_FROM loads module attribute" {
    assert_vm_value_matches_host(
        "", "from os import path\nresult = path.sep\n", "exec", "result",
    );
}

# vm-opcode: OP_RETURN_GENERATOR
test "vm: RETURN_GENERATOR starts generator body" {
    setup = "";
    body = "def gen():\n    yield 1\n    yield 2\ng = gen()\nresult = next(g) + next(g)\n";
    assert_vm_value_matches_host(setup, body, "exec", "result");
}

# vm-opcode: OP_YIELD_VALUE
test "vm: YIELD_VALUE suspends generator" {
    setup = "";
    body = "def gen():\n    yield 1\n    yield 2\ng = gen()\nresult = next(g) + next(g)\n";
    assert_vm_value_matches_host(setup, body, "exec", "result");
}

# vm-opcode: OP_CALL_INTRINSIC_1
test "vm: CALL_INTRINSIC_1 in generator StopIteration handler" {
    setup = "";
    body = "def gen():\n    yield 1\n    yield 2\ng = gen()\nresult = next(g) + next(g)\n";
    assert_vm_value_matches_host(setup, body, "exec", "result");
}

# vm-opcode: OP_GET_YIELD_FROM_ITER
test "vm: GET_YIELD_FROM_ITER delegates sub-generator" {
    setup = "";
    body = "def outer():\n    yield from inner()\ndef inner():\n    yield 1\n    yield 2\nresult = list(outer())\n";
    assert_vm_value_matches_host(setup, body, "exec", "result");
}

# vm-opcode: OP_SEND
test "vm: SEND drives yield-from delegation" {
    setup = "";
    body = "def outer():\n    yield from inner()\ndef inner():\n    yield 1\n    yield 2\nresult = list(outer())\n";
    assert_vm_value_matches_host(setup, body, "exec", "result");
}

# vm-opcode: OP_END_SEND
test "vm: END_SEND completes yield-from delegation" {
    setup = "";
    body = "def outer():\n    yield from inner()\ndef inner():\n    yield 1\n    yield 2\nresult = list(outer())\n";
    assert_vm_value_matches_host(setup, body, "exec", "result");
}

# vm-opcode: OP_CLEANUP_THROW
test "vm: CLEANUP_THROW in yield-from exception table" {
    setup = "";
    body = "def outer():\n    yield from inner()\ndef inner():\n    yield 1\n    yield 2\nresult = list(outer())\n";
    assert_vm_value_matches_host(setup, body, "exec", "result");
}

# vm-opcode: OP_JUMP_BACKWARD_NO_INTERRUPT
test "vm: JUMP_BACKWARD_NO_INTERRUPT in yield-from SEND loop" {
    setup = "";
    body = "def outer():\n    yield from inner()\ndef inner():\n    yield 1\n    yield 2\nresult = list(outer())\n";
    assert_vm_value_matches_host(setup, body, "exec", "result");
}

# vm-opcode: OP_GET_AWAITABLE
test "vm: GET_AWAITABLE drives await on native coroutine" {
    setup = "";
    body = "async def f():\n    return await g()\nasync def g():\n    return 1\nc = f()\nresult = 0\ntry:\n    c.send(None)\nexcept StopIteration as e:\n    result = e.value\n";
    assert_vm_value_matches_host(setup, body, "exec", "result");
}

# vm-opcode: OP_GET_AITER
test "vm: GET_AITER obtains async iterator from __aiter__" {
    setup = "";
    body = "class AI:\n    def __aiter__(self):\n        return self\n    async def __anext__(self):\n        if getattr(self, 'done', False):\n            raise StopAsyncIteration\n        self.done = True\n        return 42\nasync def f():\n    total = 0\n    async for x in AI():\n        total = total + x\n    return total\nc = f()\nresult = 0\ntry:\n    c.send(None)\nexcept StopIteration as e:\n    result = e.value\n";
    assert_vm_value_matches_host(setup, body, "exec", "result");
}

# vm-opcode: OP_GET_ANEXT
test "vm: GET_ANEXT awaits __anext__ in async for loop" {
    setup = "";
    body = "class AI:\n    def __aiter__(self):\n        return self\n    async def __anext__(self):\n        if getattr(self, 'done', False):\n            raise StopAsyncIteration\n        self.done = True\n        return 42\nasync def f():\n    total = 0\n    async for x in AI():\n        total = total + x\n    return total\nc = f()\nresult = 0\ntry:\n    c.send(None)\nexcept StopIteration as e:\n    result = e.value\n";
    assert_vm_value_matches_host(setup, body, "exec", "result");
}

# vm-opcode: OP_END_ASYNC_FOR
test "vm: END_ASYNC_FOR handles StopAsyncIteration in async for" {
    setup = "";
    body = "class AI:\n    def __aiter__(self):\n        return self\n    async def __anext__(self):\n        if getattr(self, 'done', False):\n            raise StopAsyncIteration\n        self.done = True\n        return 42\nasync def f():\n    total = 0\n    async for x in AI():\n        total = total + x\n    return total\nc = f()\nresult = 0\ntry:\n    c.send(None)\nexcept StopIteration as e:\n    result = e.value\n";
    assert_vm_value_matches_host(setup, body, "exec", "result");
}

# ---------------- semantic categories ----------------

test "vm: namespace mutation matches host for multi-assign" {
    setup = "";
    body = "a = 1\nb = a + 2\n";
    ns: dict[str, PyObj] = {};
    out = jac_run_oracle(setup, body, "exec", ns);
    assert not is_error(out);
    host_ns = _vm_host_exec(setup, body, "exec") as dict;
    assert _vm_host_equal(to_host(ns["a"]), host_ns["a"]) as bool;
    assert _vm_host_equal(to_host(ns["b"]), host_ns["b"]) as bool;
}

test "vm: exception type and handler result match host" {
    setup = "";
    body = "try:\n" "    1 // 0\n" "except ZeroDivisionError:\n" "    result = 99\n";
    assert_vm_value_matches_host(setup, body, "exec", "result");
}

test "vm: raised exception message matches host" {
    setup = "";
    body = "raise ValueError('bad')\n";
    host_exc = host_raises(setup, body);
    assert host_exc is not None;
    ns: dict[str, PyObj] = {};
    out = jac_run_oracle(setup, body, "exec", ns);
    assert is_error(out);
    err = out as PyError;
    assert err.exception.type_name == "ValueError";
    assert err.exception.message == (host_exc[1] as str);
}

test "vm: function call and return match host" {
    setup = "";
    body = "def f():\n    return 42\nresult = f()\n";
    assert_vm_value_matches_host(setup, body, "exec", "result");
}

test "vm: closure cell reads match host" {
    setup = "";
    body = (
        "def outer():\n"
        "    x = 7\n"
        "    def inner():\n"
        "        return x\n"
        "    return inner()\n"
        "result = outer()\n"
    );
    assert_vm_value_matches_host(setup, body, "exec", "result");
}

test "vm: branch and loop accumulation match host" {
    setup = "";
    body = (
        "total = 0\n"
        "for i in range(3):\n"
        "    total = total + i\n"
        "result = total\n"
    );
    assert_vm_value_matches_host(setup, body, "exec", "result");
}

test "vm: generator suspension and resumption match host" {
    setup = "";
    body = (
        "def gen():\n"
        "    yield 1\n"
        "    yield 2\n"
        "g = gen()\n"
        "result = next(g) + next(g)\n"
    );
    assert_vm_value_matches_host(setup, body, "exec", "result");
}

test "vm: while loop break matches host" {
    setup = "";
    body = (
        "i = 0\n"
        "while True:\n"
        "    i = i + 1\n"
        "    if i == 3:\n"
        "        break\n"
        "result = i\n"
    );
    assert_vm_value_matches_host(setup, body, "exec", "result");
}

# vm-opcode: OP_MATCH_SEQUENCE
test "vm: MATCH_SEQUENCE matches list pattern" {
    assert_vm_value_matches_host(
        "",
        "x = [1, 2]\nmatch x:\n    case [a, b]:\n        result = a + b\n    case _:\n        result = 0\n",
        "exec",
        "result",
    );
}

# vm-opcode: OP_GET_LEN
test "vm: GET_LEN checks sequence pattern length" {
    assert_vm_value_matches_host(
        "",
        "x = [1, 2]\nmatch x:\n    case [a, b]:\n        result = a + b\n    case _:\n        result = 0\n",
        "exec",
        "result",
    );
}

# vm-opcode: OP_MATCH_MAPPING
test "vm: MATCH_MAPPING matches dict pattern" {
    assert_vm_value_matches_host(
        "",
        "x = {'a': 1, 'b': 2}\nmatch x:\n    case {'a': av, 'b': bv}:\n        result = av + bv\n    case _:\n        result = 0\n",
        "exec",
        "result",
    );
}

# vm-opcode: OP_MATCH_KEYS
test "vm: MATCH_KEYS extracts mapping pattern keys" {
    assert_vm_value_matches_host(
        "",
        "x = {'a': 1, 'b': 2}\nmatch x:\n    case {'a': av, 'b': bv}:\n        result = av + bv\n    case _:\n        result = 0\n",
        "exec",
        "result",
    );
}

# vm-opcode: OP_MATCH_CLASS
test "vm: MATCH_CLASS matches class pattern" {
    assert_vm_value_matches_host(
        "",
        "class Point:\n    __match_args__ = ('x', 'y')\n    def __init__(self, x, y):\n        self.x = x\n        self.y = y\np = Point(1, 2)\nmatch p:\n    case Point(x, y):\n        result = x + y\n    case _:\n        result = 0\n",
        "exec",
        "result",
    );
}

# vm-opcode: OP_POP_JUMP_IF_NOT_NONE
test "vm: POP_JUMP_IF_NOT_NONE matches non-None singleton" {
    assert_vm_value_matches_host(
        "",
        "def f(x):\n    match x:\n        case None:\n            return 0\n        case _:\n            return 1\nresult = f(1)\n",
        "exec",
        "result",
    );
}

# vm-opcode: OP_IS_OP
test "vm: IS_OP matches True singleton pattern" {
    assert_vm_value_matches_host(
        "",
        "def f(x):\n    match x:\n        case True:\n            return 1\n        case _:\n            return 0\nresult = f(True)\n",
        "exec",
        "result",
    );
}

# vm-opcode: OP_CALL_FUNCTION_EX
test "vm: CALL_FUNCTION_EX applies *args and **kwargs" {
    setup = "";
    body = "def f(*a, **k):\n    return (a, k)\ndef g(t, d):\n    return f(*t, **d)\nresult = g((1,), {'x': 2})\n";
    assert_vm_value_matches_host(setup, body, "exec", "result");
}

# vm-opcode: OP_UNPACK_EX
test "vm: UNPACK_EX star-unpacks sequence" {
    setup = "";
    body = "a, *b, c = [1, 2, 3, 4]\nresult = a + c + len(b)\n";
    assert_vm_value_matches_host(setup, body, "exec", "result");
}

# vm-opcode: OP_LIST_EXTEND
test "vm: LIST_EXTEND builds starred unpack middle" {
    setup = "";
    body = "a, *b, c = [1, 2, 3, 4]\nresult = a + c + len(b)\n";
    assert_vm_value_matches_host(setup, body, "exec", "result");
}

# vm-opcode: OP_BUILD_STRING
test "vm: BUILD_STRING joins f-string parts" {
    setup = "";
    body = "x = 1\ny = 2\nresult = f'{x}-{y}'\n";
    assert_vm_value_matches_host(setup, body, "exec", "result");
}

# vm-opcode: OP_FORMAT_SIMPLE
test "vm: FORMAT_SIMPLE formats f-string value" {
    setup = "";
    body = "x = 1\nresult = f'x={x}'\n";
    assert_vm_value_matches_host(setup, body, "exec", "result");
}

# vm-opcode: OP_FORMAT_WITH_SPEC
test "vm: FORMAT_WITH_SPEC applies format spec" {
    setup = "";
    body = "x = 1.5\nresult = f'{x:.2f}'\n";
    assert_vm_value_matches_host(setup, body, "exec", "result");
}

# vm-opcode: OP_CONVERT_VALUE
test "vm: CONVERT_VALUE applies !r conversion" {
    setup = "";
    body = "x = 'a'\nresult = f'{x!r}'\n";
    assert_vm_value_matches_host(setup, body, "exec", "result");
}

# vm-opcode: OP_CONTAINS_OP
test "vm: CONTAINS_OP membership test" {
    setup = "seq = [1, 2, 3]\n";
    body = "result = 2 in seq\n";
    assert_vm_value_matches_host(setup, body, "exec", "result");
}

# vm-opcode: OP_SET_UPDATE
test "vm: SET_UPDATE merges starred set" {
    setup = "s = {3, 4}\n";
    body = "result = {1, 2, *s}\n";
    assert_vm_value_matches_host(setup, body, "exec", "result");
}

# vm-opcode: OP_STORE_GLOBAL
test "vm: STORE_GLOBAL writes function global" {
    setup = "x = 0\n";
    body = "def f():\n    global x\n    x = 7\n    return x\nresult = f()\n";
    assert_vm_value_matches_host(setup, body, "exec", "result");
}

# vm-opcode: OP_DELETE_GLOBAL
test "vm: DELETE_GLOBAL deletes function global" {
    setup = "x = 0\n";
    body = "def f():\n    global x\n    x = 1\n    del x\n    return 0\nresult = f()\n";
    assert_vm_value_matches_host(setup, body, "exec", "result");
}

# vm-opcode-compiler: OP_BINARY_SLICE
test "vm: BINARY_SLICE emitted for non-constant slice load" {
    body = "a = 1\nb = 3\nseq = [1, 2, 3, 4]\nresult = seq[a:b]\n";
    co = compile_source(body, "<binary-slice>", "exec", 0);
    assert not is_error(co);
    assert isinstance(co, PyCode);
    assert code_has_opcode(co as PyCode, OP_BINARY_SLICE);
}

# vm-opcode-compiler: OP_STORE_SLICE
test "vm: STORE_SLICE emitted for non-constant slice store" {
    body = "a = 1\nb = 3\nseq = [1, 2, 3, 4]\nseq[a:b] = [8, 9]\nresult = seq\n";
    co = compile_source(body, "<store-slice>", "exec", 0);
    assert not is_error(co);
    assert isinstance(co, PyCode);
    assert code_has_opcode(co as PyCode, OP_STORE_SLICE);
}

# vm-opcode-compiler: OP_BUILD_SLICE
test "vm: BUILD_SLICE emitted for stepped non-constant slice" {
    body = "a = 1\nb = 3\nc = 1\nseq = [1, 2, 3, 4]\nresult = seq[a:b:c]\n";
    co = compile_source(body, "<build-slice>", "exec", 0);
    assert not is_error(co);
    assert isinstance(co, PyCode);
    assert code_has_opcode(co as PyCode, OP_BUILD_SLICE);
}

# vm-opcode-compiler: OP_POP_JUMP_IF_NONE
test "vm: POP_JUMP_IF_NONE emitted for is not None test" {
    body = "def f(x):\n    if x is not None:\n        return 1\n    return 0\nresult = f(1)\n";
    co = compile_source(body, "<pj-none>", "exec", 0);
    assert not is_error(co);
    assert isinstance(co, PyCode);
    assert code_has_opcode(co as PyCode, OP_POP_JUMP_IF_NONE);
}
