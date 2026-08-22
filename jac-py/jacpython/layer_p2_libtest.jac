# P2 wave-4 JacPython libtest harness (TODO.md Libtest on JacPython).
#
# Runs embedded Lib/test-style Python snippets inside jacpython's ceval with
# shim modules backed by ``jacpython/*.jac`` facades (mirrors staged Modules ports).
# This is the product-path leg: host CPython smoke stays in libtest_runner; staged ``jac run``
# differential stays separate; this path exercises ``import platform`` (etc.)
# through register_shim_module + exec_code.

import from objects { PyObj, PyStr, PyError, PyList, PyInt, PyBool, is_error, py_none, py_error, }
import from getplatform { Py_GetPlatform }
import from _bisectmodule {
    _p2_bisect_right,
    _p2_bisect_left,
    _p2_insort,
    _p2_insort_left,
}
import from _heapqmodule { _p2_heappush, _p2_heappop, _p2_heapify, }
import from _statmodule {
    _p2_S_ISDIR,
    _p2_S_ISCHR,
    _p2_S_ISBLK,
    _p2_S_ISREG,
    _p2_S_ISFIFO,
    _p2_S_ISLNK,
    _p2_S_ISSOCK,
    _p2_S_IMODE,
    _p2_S_IFMT,
    _p2_filemode,
    S_IFDIR,
    S_IFCHR,
    S_IFBLK,
    S_IFREG,
    S_IFIFO,
    S_IFLNK,
    S_IFSOCK,
}
import from _opcodemodule {
    _p2_stack_effect,
    _p2_is_valid,
    _p2_has_arg,
    _p2_has_const,
    _p2_has_name,
    _p2_has_jump,
    _p2_has_free,
    _p2_has_local,
    _p2_has_exc,
}
import from opcode_meta {
    OP_POP_TOP,
    OP_LOAD_CONST,
    OP_LOAD_FAST,
    OP_LOAD_DEREF,
    OP_JUMP_FORWARD,
    OP_FOR_ITER,
    OP_SETUP_FINALLY,
}
import from pyc_first {
    PyModule,
    register_shim_module,
    clear_shim_modules,
    host_compile_marshal,
    unmarshal,
    exec_code,
    to_host,
    from_host,
}

::py::
def _p2_wrap_snippet(source: str) -> str:
    return (
        "_libtest_lines = []\n"
        "def print(*args, **kwargs):\n"
        "    sep = kwargs.get('sep', ' ')\n"
        "    _libtest_lines.append(sep.join(str(a) for a in args))\n"
        + source
        + "\n"
    )

# ``platform.system`` / ``platform.machine`` are outside the getplatform port;
# seed shims from host CPython so libtest sees real strings on any OS.
import platform as _host_platform

def _p2_libtest_host_system() -> str:
    return _host_platform.system()

def _p2_libtest_host_machine() -> str:
    return _host_platform.machine()
::py::



obj P2LibtestPlatformFn(PyObj) {
    def tp_call(args: list[PyObj], kwargs: dict[str, PyObj]) -> PyObj {
        return PyStr(t="str", val=Py_GetPlatform());
    }
}

# Minimal stdlib ``platform`` shims for libtest snippets (not in getplatform port).
obj P2LibtestSystemFn(PyObj) {
    def tp_call(args: list[PyObj], kwargs: dict[str, PyObj]) -> PyObj {
        return PyStr(t="str", val=_p2_libtest_host_system());
    }
}

obj P2LibtestMachineFn(PyObj) {
    def tp_call(args: list[PyObj], kwargs: dict[str, PyObj]) -> PyObj {
        return PyStr(t="str", val=_p2_libtest_host_machine());
    }
}

def _p2_sync_pylist_from_host(py_list: PyList, host_list: any) -> None {
    new_items: list[PyObj] = [];
    for item in host_list {
        new_items.append(from_host(item));
    }
    py_list.items = new_items;
}

def _p2_optional_int_arg(args: list[PyObj], idx: int, `default: int) -> int {
    if len(args) > idx and isinstance(args[idx], PyInt) {
        return (args[idx] as PyInt).val;
    }
    return `default;
}

obj P2LibtestBisectRightFn(PyObj) {
    def tp_call(args: list[PyObj], kwargs: dict[str, PyObj]) -> PyObj {
        if len(args) < 2 {
            return py_error("TypeError", "missing arguments");
        }
        data = args[0] as PyList;
        item = args[1];
        lo = _p2_optional_int_arg(args, 2, 0);
        hi = _p2_optional_int_arg(args, 3, -1);
        host_data = to_host(data);
        host_item = to_host(item);
        if hi < 0 {
            got = _p2_bisect_right(host_data, host_item, lo);
        } else {
            got = _p2_bisect_right(host_data, host_item, lo, hi);
        }
        return PyInt(t="int", val=got);
    }
}

obj P2LibtestBisectLeftFn(PyObj) {
    def tp_call(args: list[PyObj], kwargs: dict[str, PyObj]) -> PyObj {
        if len(args) < 2 {
            return py_error("TypeError", "missing arguments");
        }
        data = args[0] as PyList;
        item = args[1];
        lo = _p2_optional_int_arg(args, 2, 0);
        hi = _p2_optional_int_arg(args, 3, -1);
        host_data = to_host(data);
        host_item = to_host(item);
        if hi < 0 {
            got = _p2_bisect_left(host_data, host_item, lo);
        } else {
            got = _p2_bisect_left(host_data, host_item, lo, hi);
        }
        return PyInt(t="int", val=got);
    }
}

obj P2LibtestInsortFn(PyObj) {
    def tp_call(args: list[PyObj], kwargs: dict[str, PyObj]) -> PyObj {
        if len(args) < 2 {
            return py_error("TypeError", "missing arguments");
        }
        data = args[0] as PyList;
        item = args[1];
        lo = _p2_optional_int_arg(args, 2, 0);
        hi = _p2_optional_int_arg(args, 3, -1);
        host_data = to_host(data);
        host_item = to_host(item);
        if hi < 0 {
            _p2_insort(host_data, host_item, lo);
        } else {
            _p2_insort(host_data, host_item, lo, hi);
        }
        _p2_sync_pylist_from_host(data, host_data);
        return py_none();
    }
}

obj P2LibtestInsortLeftFn(PyObj) {
    def tp_call(args: list[PyObj], kwargs: dict[str, PyObj]) -> PyObj {
        if len(args) < 2 {
            return py_error("TypeError", "missing arguments");
        }
        data = args[0] as PyList;
        item = args[1];
        lo = _p2_optional_int_arg(args, 2, 0);
        hi = _p2_optional_int_arg(args, 3, -1);
        host_data = to_host(data);
        host_item = to_host(item);
        if hi < 0 {
            _p2_insort_left(host_data, host_item, lo);
        } else {
            _p2_insort_left(host_data, host_item, lo, hi);
        }
        _p2_sync_pylist_from_host(data, host_data);
        return py_none();
    }
}

obj P2LibtestHeappushFn(PyObj) {
    def tp_call(args: list[PyObj], kwargs: dict[str, PyObj]) -> PyObj {
        if len(args) < 2 {
            return py_error("TypeError", "missing arguments");
        }
        heap = args[0] as PyList;
        item = args[1];
        host_heap = to_host(heap);
        _p2_heappush(host_heap, to_host(item));
        _p2_sync_pylist_from_host(heap, host_heap);
        return py_none();
    }
}

obj P2LibtestHeappopFn(PyObj) {
    def tp_call(args: list[PyObj], kwargs: dict[str, PyObj]) -> PyObj {
        if len(args) < 1 {
            return py_error("TypeError", "missing arguments");
        }
        heap = args[0] as PyList;
        host_heap = to_host(heap);
        got = _p2_heappop(host_heap);
        _p2_sync_pylist_from_host(heap, host_heap);
        return from_host(got);
    }
}

obj P2LibtestHeapifyFn(PyObj) {
    def tp_call(args: list[PyObj], kwargs: dict[str, PyObj]) -> PyObj {
        if len(args) < 1 {
            return py_error("TypeError", "missing arguments");
        }
        heap = args[0] as PyList;
        host_heap = to_host(heap);
        _p2_heapify(host_heap);
        _p2_sync_pylist_from_host(heap, host_heap);
        return py_none();
    }
}

def _p2_single_int_arg(args: list[PyObj]) -> PyObj {
    if len(args) != 1 or not isinstance(args[0], PyInt) {
        return py_error("TypeError", "expected exactly one int argument");
    }
    return args[0];
}

obj P2StatSIsDirFn(PyObj) {
    def tp_call(args: list[PyObj], kwargs: dict[str, PyObj]) -> PyObj {
        arg: PyObj = _p2_single_int_arg(args);
        if is_error(arg) { return arg; }
        got: bool = _p2_S_ISDIR((arg as PyInt).val);
        return PyBool(t="bool", val=got);
    }
}

obj P2StatSIsChrFn(PyObj) {
    def tp_call(args: list[PyObj], kwargs: dict[str, PyObj]) -> PyObj {
        arg: PyObj = _p2_single_int_arg(args);
        if is_error(arg) { return arg; }
        got: bool = _p2_S_ISCHR((arg as PyInt).val);
        return PyBool(t="bool", val=got);
    }
}

obj P2StatSIsBlkFn(PyObj) {
    def tp_call(args: list[PyObj], kwargs: dict[str, PyObj]) -> PyObj {
        arg: PyObj = _p2_single_int_arg(args);
        if is_error(arg) { return arg; }
        got: bool = _p2_S_ISBLK((arg as PyInt).val);
        return PyBool(t="bool", val=got);
    }
}

obj P2StatSIsRegFn(PyObj) {
    def tp_call(args: list[PyObj], kwargs: dict[str, PyObj]) -> PyObj {
        arg: PyObj = _p2_single_int_arg(args);
        if is_error(arg) { return arg; }
        got: bool = _p2_S_ISREG((arg as PyInt).val);
        return PyBool(t="bool", val=got);
    }
}

obj P2StatSIsFifoFn(PyObj) {
    def tp_call(args: list[PyObj], kwargs: dict[str, PyObj]) -> PyObj {
        arg: PyObj = _p2_single_int_arg(args);
        if is_error(arg) { return arg; }
        got: bool = _p2_S_ISFIFO((arg as PyInt).val);
        return PyBool(t="bool", val=got);
    }
}

obj P2StatSIsLnkFn(PyObj) {
    def tp_call(args: list[PyObj], kwargs: dict[str, PyObj]) -> PyObj {
        arg: PyObj = _p2_single_int_arg(args);
        if is_error(arg) { return arg; }
        got: bool = _p2_S_ISLNK((arg as PyInt).val);
        return PyBool(t="bool", val=got);
    }
}

obj P2StatSIsSockFn(PyObj) {
    def tp_call(args: list[PyObj], kwargs: dict[str, PyObj]) -> PyObj {
        arg: PyObj = _p2_single_int_arg(args);
        if is_error(arg) { return arg; }
        got: bool = _p2_S_ISSOCK((arg as PyInt).val);
        return PyBool(t="bool", val=got);
    }
}

obj P2StatSImodeFn(PyObj) {
    def tp_call(args: list[PyObj], kwargs: dict[str, PyObj]) -> PyObj {
        arg: PyObj = _p2_single_int_arg(args);
        if is_error(arg) { return arg; }
        got: int = _p2_S_IMODE((arg as PyInt).val);
        return PyInt(t="int", val=got);
    }
}

obj P2StatSIfmtFn(PyObj) {
    def tp_call(args: list[PyObj], kwargs: dict[str, PyObj]) -> PyObj {
        arg: PyObj = _p2_single_int_arg(args);
        if is_error(arg) { return arg; }
        got: int = _p2_S_IFMT((arg as PyInt).val);
        return PyInt(t="int", val=got);
    }
}

obj P2StatFilemodeFn(PyObj) {
    def tp_call(args: list[PyObj], kwargs: dict[str, PyObj]) -> PyObj {
        arg: PyObj = _p2_single_int_arg(args);
        if is_error(arg) { return arg; }
        got: str = _p2_filemode((arg as PyInt).val);
        return PyStr(t="str", val=got);
    }
}

def _p2_opcode_pred_result(fn: any, args: list[PyObj]) -> PyObj {
    arg: PyObj = _p2_single_int_arg(args);
    if is_error(arg) { return arg; }
    got: bool = fn((arg as PyInt).val);
    return PyBool(t="bool", val=got);
}

obj P2OpcodeIsValidFn(PyObj) {
    def tp_call(args: list[PyObj], kwargs: dict[str, PyObj]) -> PyObj {
        return _p2_opcode_pred_result(_p2_is_valid, args);
    }
}

obj P2OpcodeHasArgFn(PyObj) {
    def tp_call(args: list[PyObj], kwargs: dict[str, PyObj]) -> PyObj {
        return _p2_opcode_pred_result(_p2_has_arg, args);
    }
}

obj P2OpcodeHasConstFn(PyObj) {
    def tp_call(args: list[PyObj], kwargs: dict[str, PyObj]) -> PyObj {
        return _p2_opcode_pred_result(_p2_has_const, args);
    }
}

obj P2OpcodeHasNameFn(PyObj) {
    def tp_call(args: list[PyObj], kwargs: dict[str, PyObj]) -> PyObj {
        return _p2_opcode_pred_result(_p2_has_name, args);
    }
}

obj P2OpcodeHasJumpFn(PyObj) {
    def tp_call(args: list[PyObj], kwargs: dict[str, PyObj]) -> PyObj {
        return _p2_opcode_pred_result(_p2_has_jump, args);
    }
}

obj P2OpcodeHasFreeFn(PyObj) {
    def tp_call(args: list[PyObj], kwargs: dict[str, PyObj]) -> PyObj {
        return _p2_opcode_pred_result(_p2_has_free, args);
    }
}

obj P2OpcodeHasLocalFn(PyObj) {
    def tp_call(args: list[PyObj], kwargs: dict[str, PyObj]) -> PyObj {
        return _p2_opcode_pred_result(_p2_has_local, args);
    }
}

obj P2OpcodeHasExcFn(PyObj) {
    def tp_call(args: list[PyObj], kwargs: dict[str, PyObj]) -> PyObj {
        return _p2_opcode_pred_result(_p2_has_exc, args);
    }
}

obj P2OpcodeStackEffectFn(PyObj) {
    def tp_call(args: list[PyObj], kwargs: dict[str, PyObj]) -> PyObj {
        if len(args) < 1 or not isinstance(args[0], PyInt) {
            return py_error("TypeError", "stack_effect expected opcode int");
        }
        op = (args[0] as PyInt).val;
        oparg: int | None = None;
        if len(args) > 1 and isinstance(args[1], PyInt) {
            oparg = (args[1] as PyInt).val;
        } elif len(args) > 1 and args[1].t != "none" {
            return py_error("TypeError", "stack_effect oparg must be int or None");
        }
        jump: int | None = None;
        if len(args) > 2 {
            j = args[2];
            if j.t == "bool" {
                if (j as PyBool).val {
                    jump = 1;
                } else {
                    jump = 0;
                }
            } elif j.t != "none" {
                return py_error(
                    "ValueError", "stack_effect: jump must be False, True or None"
                );
            }
        }
        got = _p2_stack_effect(op, oparg, jump);
        if got is None {
            return py_error("ValueError", "invalid opcode or oparg");
        }
        return PyInt(t="int", val=got);
    }
}

def p2_libtest_reset {
    clear_shim_modules();
    platform_attrs: dict[str, PyObj] = {
        "platform": P2LibtestPlatformFn(t="function"),
        "system": P2LibtestSystemFn(t="function"),
        "machine": P2LibtestMachineFn(t="function"),

    };
    register_shim_module(
        "platform", PyModule(t="module", name="platform", attrs=platform_attrs)
    );
    bisect_right_fn = P2LibtestBisectRightFn(t="function");
    bisect_left_fn = P2LibtestBisectLeftFn(t="function");
    insort_fn = P2LibtestInsortFn(t="function");
    insort_left_fn = P2LibtestInsortLeftFn(t="function");
    bisect_attrs: dict[str, PyObj] = {
        "bisect_right": bisect_right_fn,
        "bisect_left": bisect_left_fn,
        "insort": insort_fn,
        "insort_left": insort_left_fn,
        "bisect": bisect_right_fn,
        "insort_right": insort_fn,
    };
    register_shim_module(
        "bisect", PyModule(t="module", name="bisect", attrs=bisect_attrs)
    );
    heapq_attrs: dict[str, PyObj] = {
        "heappush": P2LibtestHeappushFn(t="function"),
        "heappop": P2LibtestHeappopFn(t="function"),
        "heapify": P2LibtestHeapifyFn(t="function"),
    };
    register_shim_module(
        "heapq", PyModule(t="module", name="heapq", attrs=heapq_attrs)
    );
    stat_attrs: dict[str, PyObj] = {
        "S_ISDIR": P2StatSIsDirFn(t="function"),
        "S_ISCHR": P2StatSIsChrFn(t="function"),
        "S_ISBLK": P2StatSIsBlkFn(t="function"),
        "S_ISREG": P2StatSIsRegFn(t="function"),
        "S_ISFIFO": P2StatSIsFifoFn(t="function"),
        "S_ISLNK": P2StatSIsLnkFn(t="function"),
        "S_ISSOCK": P2StatSIsSockFn(t="function"),
        "S_IMODE": P2StatSImodeFn(t="function"),
        "S_IFMT": P2StatSIfmtFn(t="function"),
        "filemode": P2StatFilemodeFn(t="function"),
        "S_IFMT_": PyInt(t="int", val=0o170000),
        "S_IFDIR": PyInt(t="int", val=S_IFDIR),
        "S_IFCHR": PyInt(t="int", val=S_IFCHR),
        "S_IFBLK": PyInt(t="int", val=S_IFBLK),
        "S_IFREG": PyInt(t="int", val=S_IFREG),
        "S_IFIFO": PyInt(t="int", val=S_IFIFO),
        "S_IFLNK": PyInt(t="int", val=S_IFLNK),
        "S_IFSOCK": PyInt(t="int", val=S_IFSOCK),
    };
    register_shim_module(
        "stat", PyModule(t="module", name="stat", attrs=stat_attrs)
    );
    opcode_attrs: dict[str, PyObj] = {
        "stack_effect": P2OpcodeStackEffectFn(t="function"),
        "is_valid": P2OpcodeIsValidFn(t="function"),
        "has_arg": P2OpcodeHasArgFn(t="function"),
        "has_const": P2OpcodeHasConstFn(t="function"),
        "has_name": P2OpcodeHasNameFn(t="function"),
        "has_jump": P2OpcodeHasJumpFn(t="function"),
        "has_free": P2OpcodeHasFreeFn(t="function"),
        "has_local": P2OpcodeHasLocalFn(t="function"),
        "has_exc": P2OpcodeHasExcFn(t="function"),
        "POP_TOP": PyInt(t="int", val=OP_POP_TOP),
        "LOAD_CONST": PyInt(t="int", val=OP_LOAD_CONST),
        "LOAD_FAST": PyInt(t="int", val=OP_LOAD_FAST),
        "LOAD_DEREF": PyInt(t="int", val=OP_LOAD_DEREF),
        "JUMP_FORWARD": PyInt(t="int", val=OP_JUMP_FORWARD),
        "FOR_ITER": PyInt(t="int", val=OP_FOR_ITER),
        "SETUP_FINALLY": PyInt(t="int", val=OP_SETUP_FINALLY),
    };
    register_shim_module(
        "_opcode", PyModule(t="module", name="_opcode", attrs=opcode_attrs)
    );
}


def p2_libtest_run_snippet(source: str) -> tuple[bool, str] {
    p2_libtest_reset();
    wrapped = _p2_wrap_snippet(source);
    co = unmarshal(host_compile_marshal(wrapped));
    if is_error(co) {
        return (False, "compile failed");
    }
    globals: dict[str, PyObj] = {"__name__": PyStr(t="str", val="__main__"),};
    outcome = exec_code(co, [], globals);
    if is_error(outcome) {
        exc = (outcome as PyError).exception;
        return (False, exc.type_name + ": " + exc.message);
    }
    if "_libtest_lines" not in globals {
        return (False, "missing _libtest_lines capture");
    }
    lines_obj = globals["_libtest_lines"];
    host_lines = to_host(lines_obj);
    if not isinstance(host_lines, list) {
        return (False, "print capture is not a list");
    }
    if len(host_lines) == 0 {
        return (False, "no printed output");
    }
    return (True, str(host_lines[len(host_lines) - 1]).strip());
}


def p2_libtest_expect_ok(source: str, expect_stdout: str = "ok") -> tuple[bool, str] {
    (ok, detail) = p2_libtest_run_snippet(source);
    if not ok {
        return (False, detail);
    }
    if detail != expect_stdout {
        return (False, f"expected stdout {expect_stdout!r}, got {detail!r}");
    }
    return (True, detail);
}


test "layer_p2_libtest: platform_basic snippet prints ok on JacPython" {
    snippet = (
        "import platform\n"
        "plat = platform.platform()\n"
        "assert isinstance(plat, str) and len(plat) > 0\n"
        "assert platform.platform() == platform.platform()\n"
        "assert isinstance(platform.system(), str)\n"
        "assert isinstance(platform.machine(), str)\n"
        "print('ok')\n"
    );
    (ok, detail) = p2_libtest_expect_ok(snippet);
    assert ok , detail;
}

test "layer_p2_libtest: bisect_precomputed snippet prints ok on JacPython" {
    snippet = (
        "import bisect\n"
        "cases = [\n"
        "    (bisect.bisect_right, [], 1, 0),\n"
        "    (bisect.bisect_right, [1, 2, 3], 2, 2),\n"
        "    (bisect.bisect_left, [1, 1, 2, 2], 1.5, 2),\n"
        "    (bisect.bisect_left, [1, 2, 2, 3, 3, 3, 4, 4, 4, 4], 3, 3),\n"
        "]\n"
        "for func, data, elem, expected in cases:\n"
        "    got = func(data, elem)\n"
        "    assert got == expected, (func.__name__, data, elem, got, expected)\n"
        "print('ok')\n"
    );
    (ok, detail) = p2_libtest_expect_ok(snippet);
    assert ok , detail;
}

test "layer_p2_libtest: bisect_insort snippet prints ok on JacPython" {
    snippet = (
        "import bisect\n"
        "data = [1, 2, 3]\n"
        "bisect.insort(data, 2)\n"
        "assert data == [1, 2, 2, 3]\n"
        "bisect.insort_left(data, 2)\n"
        "assert data == [1, 2, 2, 2, 3]\n"
        "print('ok')\n"
    );
    (ok, detail) = p2_libtest_expect_ok(snippet);
    assert ok , detail;
}

test "layer_p2_libtest: heapq_push_pop snippet prints ok on JacPython" {
    snippet = (
        "import heapq\n"
        "heap = []\n"
        "data = [3, 1, 4, 1, 5, 9, 2, 6]\n"
        "for x in data:\n"
        "    heapq.heappush(heap, x)\n"
        "out = []\n"
        "while heap:\n"
        "    out.append(heapq.heappop(heap))\n"
        "assert out == sorted(data)\n"
        "print('ok')\n"
    );
    (ok, detail) = p2_libtest_expect_ok(snippet);
    assert ok , detail;
}

test "layer_p2_libtest: heapq_heapify snippet prints ok on JacPython" {
    snippet = (
        "import heapq\n"
        "data = [3, 1, 4, 1, 5, 9, 2, 6]\n"
        "heapq.heapify(data)\n"
        "parent_ok = all(data[(i - 1) >> 1] <= data[i] for i in range(1, len(data)))\n"
        "assert parent_ok\n"
        "assert sorted(data) == [1, 1, 2, 3, 4, 5, 6, 9]\n"
        "print('ok')\n"
    );
    (ok, detail) = p2_libtest_expect_ok(snippet);
    assert ok , detail;
}

test "layer_p2_libtest: stat_filemode snippet prints ok on JacPython" {
    snippet = (
        "import stat\n"
        "assert stat.S_ISDIR(stat.S_IFDIR)\n"
        "assert stat.S_ISREG(stat.S_IFREG)\n"
        "assert not stat.S_ISREG(stat.S_IFDIR)\n"
        "assert stat.S_IMODE(0o100755) == 0o755\n"
        "assert stat.S_IFMT(0o100755) == stat.S_IFREG\n"
        "assert stat.filemode(0o100755) == '-rwxr-xr-x'\n"
        "dir_mode = stat.S_IFDIR | 0o640\n"
        "assert stat.filemode(dir_mode) == 'drw-r-----'\n"
        "print('ok')\n"
    );
    (ok, detail) = p2_libtest_expect_ok(snippet);
    assert ok , detail;
}

test "layer_p2_libtest: opcode_stack_effect snippet prints ok on JacPython" {
    snippet = (
        "import _opcode\n"
        "POP_TOP = 31\n"
        "LOAD_CONST = 82\n"
        "LOAD_FAST = 84\n"
        "JUMP_FORWARD = 77\n"
        "FOR_ITER = 70\n"
        "SETUP_FINALLY = 264\n"
        "assert _opcode.is_valid(POP_TOP)\n"
        "assert not _opcode.is_valid(1000)\n"
        "assert _opcode.has_arg(LOAD_CONST)\n"
        "assert not _opcode.has_arg(POP_TOP)\n"
        "assert _opcode.has_const(LOAD_CONST)\n"
        "assert _opcode.has_local(LOAD_FAST)\n"
        "assert not _opcode.has_free(LOAD_FAST)\n"
        "assert _opcode.has_jump(JUMP_FORWARD)\n"
        "assert _opcode.has_exc(SETUP_FINALLY)\n"
        "assert _opcode.stack_effect(POP_TOP) == -1\n"
        "assert _opcode.stack_effect(FOR_ITER, 0) == 1\n"
        "assert _opcode.stack_effect(JUMP_FORWARD, 0) == 0\n"
        "print('ok')\n"
    );
    (ok, detail) = p2_libtest_expect_ok(snippet);
    assert ok , detail;
}
