# Layer 2 shim unittest harness (TODO.md "Layer 2", jac-py/PLAN.md §6.6).
#
# A ~200-line proxy-free unittest + test.support stub installed as
# sys.modules["unittest"] / sys.modules["test.support"], so unmodified test_*.py
# files whose usage stays inside the shim surface run inside jacpython without
# dragging the real unittest closure (re, traceback, io, ...) through host
# proxies. Run test files standalone -- never via regrtest.
import from layer0_replay { ReplayResult }
import from objects {
    PyObj,
    PyBool,
    PyInt,
    PyStr,
    PyException,
    PyExceptionType,
    PyError,
    is_error,
    py_none,
    py_error,
    py_exception_type
}
import from pyc_first {
    PyClass,
    PyFunction,
    PyModule,
    PyUserObj,
    PyBoundMethod,
    register_shim_module,
    clear_shim_modules,
    shim_module_get,
    host_compile_marshal,
    unmarshal,
    exec_code,
    py_issubclass,
    py_isinstance,
    py_invoke,
    bind_attribute,
    to_host,
    class_lookup_attr,
    py_raise_value,
    py_truth
}

::py::
def _l2_host_equal(a, b):
    try:
        if a != a and b != b:
            return True
        return bool(a == b)
    except BaseException:
        return False
::py::



glob layer2_module_globals: dict[str, PyObj] = {};

# ---------------- assertion helpers -----------------------------------------

def layer2_values_equal(first: PyObj, second: PyObj) -> bool {
    return _l2_host_equal(to_host(first), to_host(second)) as bool;
}

def layer2_fail(msg: str) -> PyObj {
    return py_raise_value(
        PyException(t="exception", type_name="AssertionError", message=msg)
    );
}

def layer2_skip(msg: str) -> PyObj {
    return py_raise_value(
        PyException(t="exception", type_name="SkipTest", message=msg)
    );
}

# TestCase.assert* dispatch target (bound via PyBoundMethod).
obj PyShimMethod(PyObj) {
    has kind: str;

    def tp_getattro(name: str) -> PyObj {
        if name == "__name__" {
            return PyStr(t="str", val="shim_" + self.kind);
        }
        return py_error("AttributeError", name);
    }

    def tp_call(args: list[PyObj], kwargs: dict[str, PyObj]) -> PyObj {
        if len(args) == 0 {
            return py_error("TypeError", "missing self");
        }
        self_obj = args[0];
        rest: list[PyObj] = [];
        i = 1;
        while i < len(args) {
            rest.append(args[i]);
            i = i + 1;
        }
        if self.kind == "equal" and len(rest) >= 2 {
            return layer2_assert_equal(self_obj, rest[0], rest[1]);
        }
        if self.kind == "not_equal" and len(rest) >= 2 {
            return layer2_assert_not_equal(self_obj, rest[0], rest[1]);
        }
        if self.kind == "true" and len(rest) >= 1 {
            return layer2_assert_true(self_obj, rest[0]);
        }
        if self.kind == "false" and len(rest) >= 1 {
            return layer2_assert_false(self_obj, rest[0]);
        }
        if self.kind == "is" and len(rest) >= 2 {
            return layer2_assert_is(self_obj, rest[0], rest[1]);
        }
        if self.kind == "is_not" and len(rest) >= 2 {
            return layer2_assert_is_not(self_obj, rest[0], rest[1]);
        }
        if self.kind == "is_none" and len(rest) >= 1 {
            return layer2_assert_is_none(self_obj, rest[0]);
        }
        if self.kind == "is_not_none" and len(rest) >= 1 {
            return layer2_assert_is_not_none(self_obj, rest[0]);
        }
        if self.kind == "gt" and len(rest) >= 2 {
            return layer2_compare_assert(self_obj, rest[0], rest[1], "gt");
        }
        if self.kind == "lt" and len(rest) >= 2 {
            return layer2_compare_assert(self_obj, rest[0], rest[1], "lt");
        }
        if self.kind == "ge" and len(rest) >= 2 {
            return layer2_compare_assert(self_obj, rest[0], rest[1], "ge");
        }
        if self.kind == "le" and len(rest) >= 2 {
            return layer2_compare_assert(self_obj, rest[0], rest[1], "le");
        }
        if self.kind == "raises" {
            expected = py_none();
            if len(rest) >= 1 {
                expected = rest[0];
            }
            call_args: list[PyObj] = [];
            j = 1;
            while j < len(rest) {
                call_args.append(rest[j]);
                j = j + 1;
            }
            callee = py_none();
            if len(call_args) >= 1 {
                callee = call_args[0];
                trimmed: list[PyObj] = [];
                k = 1;
                while k < len(call_args) {
                    trimmed.append(call_args[k]);
                    k = k + 1;
                }
                call_args = trimmed;
            }
            return layer2_assert_raises(self_obj, expected, callee, call_args, kwargs);
        }
        if self.kind == "fail" {
            return layer2_fail("fail");
        }
        return py_error("TypeError", "bad shim method call");
    }
}

obj PyAssertRaisesCtx(PyObj) {
    has expected: PyObj;

    def tp_getattro(name: str) -> PyObj {
        if name == "__enter__" {
            return PyCtxEnter(t="function", parent=self);
        }
        if name == "__exit__" {
            return PyCtxExit(t="function", parent=self);
        }
        return py_error("AttributeError", name);
    }
}

obj PyCtxEnter(PyObj) {
    has parent: PyAssertRaisesCtx;

    def tp_call(args: list[PyObj], kwargs: dict[str, PyObj]) -> PyObj {
        return self.parent;
    }
}

obj PyCtxExit(PyObj) {
    has parent: PyAssertRaisesCtx;

    def tp_call(args: list[PyObj], kwargs: dict[str, PyObj]) -> PyObj {
        # __exit__(exc_type, exc_val, tb), or bound __exit__(self, ...) when
        # CALL / WITH_EXCEPT_START prepends the context manager as self.
        exc_offset = 0;
        if len(args) >= 4 {
            exc_offset = 1;
        }
        if len(args) < 3 + exc_offset {
            return PyBool(t="bool", val=False);
        }
        exc_val = args[1 + exc_offset];
        if exc_val.t == "none" {
            return layer2_fail("assertRaises: no exception raised");
        }
        got = layer2_error_type_name(exc_val);
        want = layer2_exception_type_name(self.parent.expected);
        if got == want and got != "" {
            return PyBool(t="bool", val=True);
        }
        return PyBool(t="bool", val=False);
    }
}

obj PySupportSkip(PyObj) {
    def tp_call(args: list[PyObj], kwargs: dict[str, PyObj]) -> PyObj {
        if len(args) == 0 {
            return py_error("TypeError", "decorator needs a target");
        }
        target = args[0];
        if isinstance(target, PyClass) {
            return layer2_skip_wrap_class(target as PyClass);
        }
        return PySkipWrapper(t="function", wrapped=target);
    }
}

def layer2_skip_wrap_class(cls: PyClass) -> PyClass {
    wrapped_attrs: dict[str, PyObj] = {};
    for attr in cls.attrs {
        val = cls.attrs[attr];
        if attr.startswith("test_") {
            wrapped_attrs[attr] = PySkipWrapper(t="function", wrapped=val);
        } else {
            wrapped_attrs[attr] = val;
        }
    }
    return PyClass(
        t="class",
        name=cls.name,
        attrs=wrapped_attrs,
        bases=cls.bases,
        native_base=cls.native_base
    );
}

obj PySkipWrapper(PyObj) {
    has wrapped: PyObj;

    def tp_call(args: list[PyObj], kwargs: dict[str, PyObj]) -> PyObj {
        return layer2_skip("skipped by test.support decorator");
    }
}

obj PyUnittestSkip(PyObj) {
    def tp_call(args: list[PyObj], kwargs: dict[str, PyObj]) -> PyObj {
        if len(args) == 0 {
            return py_error("TypeError", "skip decorator needs a function");
        }
        return PySkipWrapper(t="skip_wrapper", wrapped=args[0]);
    }
}

obj PyUnittestMain(PyObj) {
    def tp_call(args: list[PyObj], kwargs: dict[str, PyObj]) -> PyObj {
        _ = layer2_run_discovered(layer2_discover_tests(layer2_module_globals));
        return py_none();
    }
}

def layer2_assert_equal(
    self: PyObj, first: PyObj, second: PyObj, msg: str = ""
) -> PyObj {
    if layer2_values_equal(first, second) {
        return py_none();
    }
    detail = " != ";
    if msg != "" {
        detail = ": " + msg;
    }
    return layer2_fail("assertEqual" + detail);
}

def layer2_assert_not_equal(
    self: PyObj, first: PyObj, second: PyObj, msg: str = ""
) -> PyObj {
    if not layer2_values_equal(first, second) {
        return py_none();
    }
    return layer2_fail("assertNotEqual");
}

def layer2_assert_true(self: PyObj, expr: PyObj, msg: str = "") -> PyObj {
    if py_truth(expr) {
        return py_none();
    }
    return layer2_fail("assertTrue");
}

def layer2_assert_false(self: PyObj, expr: PyObj, msg: str = "") -> PyObj {
    if not py_truth(expr) {
        return py_none();
    }
    return layer2_fail("assertFalse");
}

def layer2_assert_is(self: PyObj, first: PyObj, second: PyObj, msg: str = "") -> PyObj {
    if first is second {
        return py_none();
    }
    return layer2_fail("assertIs");
}

def layer2_assert_is_not(
    self: PyObj, first: PyObj, second: PyObj, msg: str = ""
) -> PyObj {
    if first is not second {
        return py_none();
    }
    return layer2_fail("assertIsNot");
}

def layer2_assert_is_none(self: PyObj, value: PyObj, msg: str = "") -> PyObj {
    if value.t == "none" {
        return py_none();
    }
    return layer2_fail("assertIsNone");
}

def layer2_assert_is_not_none(self: PyObj, value: PyObj, msg: str = "") -> PyObj {
    if value.t != "none" {
        return py_none();
    }
    return layer2_fail("assertIsNotNone");
}

def layer2_compare_assert(
    self: PyObj, first: PyObj, second: PyObj, kind: str, msg: str = ""
) -> PyObj {
    left = to_host(first);
    right = to_host(second);
    ok = False;
    if kind == "gt" {
        ok = left > right;
    } elif kind == "lt" {
        ok = left < right;
    } elif kind == "ge" {
        ok = left >= right;
    } elif kind == "le" {
        ok = left <= right;
    }
    if ok as bool {
        return py_none();
    }
    return layer2_fail("assert" + kind);
}

def layer2_exception_type_name(typ: PyObj) -> str {
    if typ.t == "exception_type" {
        return (typ as PyExceptionType).name;
    }
    if typ.t == "exception" {
        return (typ as PyException).type_name;
    }
    return "";
}

def layer2_error_type_name(err: PyObj) -> str {
    if err.t == "error" {
        return (err as PyError).exception.type_name;
    }
    if err.t == "exception" {
        return (err as PyException).type_name;
    }
    return "";
}

def layer2_assert_raises(
    self: PyObj,
    expected: PyObj,
    callable_obj: PyObj = py_none(),
    args: list[PyObj] = [],
    kwargs: dict[str, PyObj] = {}
) -> PyObj {
    want = layer2_exception_type_name(expected);
    # Callable form: assertRaises(E, fn, *args, **kwargs)
    if callable_obj.t != "none" {
        outcome = py_invoke(callable_obj, args, kwargs);
        if is_error(outcome) {
            if layer2_error_type_name(outcome) == want and want != "" {
                return py_none();
            }
            return layer2_fail(
                "assertRaises: " + layer2_error_type_name(outcome) + " raised"
            );
        }
        return layer2_fail("assertRaises: no exception raised");
    }
    # Context-manager form: with self.assertRaises(E):
    return PyAssertRaisesCtx(t="assert_raises_ctx", expected=expected);
}

# ---------------- unittest.TestCase (native PyClass) -------------------------

def build_testcase_class -> PyClass {
    attrs: dict[str, PyObj] = {
        "assertEqual": PyShimMethod(t="function", kind="equal"),
        "assertNotEqual": PyShimMethod(t="function", kind="not_equal"),
        "assertTrue": PyShimMethod(t="function", kind="true"),
        "assertFalse": PyShimMethod(t="function", kind="false"),
        "assertIs": PyShimMethod(t="function", kind="is"),
        "assertIsNot": PyShimMethod(t="function", kind="is_not"),
        "assertIsNone": PyShimMethod(t="function", kind="is_none"),
        "assertIsNotNone": PyShimMethod(t="function", kind="is_not_none"),
        "assertGreater": PyShimMethod(t="function", kind="gt"),
        "assertLess": PyShimMethod(t="function", kind="lt"),
        "assertGreaterEqual": PyShimMethod(t="function", kind="ge"),
        "assertLessEqual": PyShimMethod(t="function", kind="le"),
        "assertRaises": PyShimMethod(t="function", kind="raises"),
        "fail": PyShimMethod(t="function", kind="fail"),

    };
    return PyClass(t="class", name="TestCase", attrs=attrs, bases=[], native_base="");
}

def testcase_call_setup(instance: PyUserObj) -> PyObj {
    setup = class_lookup_attr(instance.cls, "setUp");
    if is_error(setup) {
        return py_none();
    }
    return bind_attribute(setup, instance).tp_call([], {});
}

def testcase_call_teardown(instance: PyUserObj) -> PyObj {
    td = class_lookup_attr(instance.cls, "tearDown");
    if is_error(td) {
        return py_none();
    }
    return bind_attribute(td, instance).tp_call([], {});
}

# ---------------- test.support skip decorators -----------------------------

def build_support_module -> PyModule {
    skip_fn = PySupportSkip(t="support_skip");
    attrs: dict[str, PyObj] = {
        "cpython_only": skip_fn,
        "requires_resource": skip_fn,
        "bigmemtest": skip_fn,
        "bigaddrspacetest": skip_fn,
        "requires_subprocess": skip_fn,
        "requires_zlib": skip_fn,
        "requires_IEEE_754": skip_fn,
        "requires_gzip": skip_fn,
        "requires_bz2": skip_fn,
        "requires_lzma": skip_fn,
        "requires_zstd": skip_fn,
        "requires_fork": skip_fn,
        "requires_mac_ver": skip_fn,
        "requires_freebsd_version": skip_fn,
        "requires_linux_version": skip_fn,
        "requires_gil_enabled": skip_fn,
        "requires_working_socket": skip_fn,
        "requires_working_threading": skip_fn,
        "requires_hashdigest": skip_fn,
        "anticipate_failure": skip_fn,
        "force_not_colorized": skip_fn,
        "force_not_colorized_test_class": skip_fn,
        "skip_if_pgo_task": skip_fn,
        "refcount_test": skip_fn,
        "MS_WINDOWS": PyBool(t="bool", val=False),
        "is_jython": PyBool(t="bool", val=False),
        "is_android": PyBool(t="bool", val=False),
        "verbose": PyBool(t="bool", val=False),
        "max_memuse": PyInt(t="int", val=0),

    };
    return PyModule(t="module", name="test.support", attrs=attrs);
}

def build_test_package(support_mod: PyModule) -> PyModule {
    return PyModule(t="module", name="test", attrs={"support": support_mod});
}

def build_unittest_module(testcase: PyClass) -> PyModule {
    skip_exc = py_exception_type("SkipTest");
    attrs: dict[str, PyObj] = {
        "TestCase": testcase,
        "SkipTest": skip_exc,
        "skip": PyUnittestSkip(t="unittest_skip"),
        "main": PyUnittestMain(t="unittest_main"),

    };
    return PyModule(t="module", name="unittest", attrs=attrs);
}

def install_layer2_shims {
    clear_shim_modules();
    testcase = build_testcase_class();
    support = build_support_module();
    register_shim_module("unittest", build_unittest_module(testcase));
    register_shim_module("test", build_test_package(support));
    register_shim_module("test.support", support);
}

def layer2_testcase_base -> PyObj {
    mod = shim_module_get("unittest");
    if is_error(mod) {
        return mod;
    }
    return (mod as PyModule).attrs["TestCase"];
}

# ---------------- discovery + execution --------------------------------------

def layer2_is_skip(exc: PyObj) -> bool {
    if exc.t == "error" {
        return (exc as PyError).exception.type_name == "SkipTest";
    }
    return False;
}

def layer2_is_assertion(exc: PyObj) -> bool {
    if exc.t == "error" {
        return (exc as PyError).exception.type_name == "AssertionError";
    }
    return False;
}

def layer2_discover_tests(
    globals: dict[str, PyObj]
) -> list[tuple[PyClass, str, PyObj]] {
    found: list[tuple[PyClass, str, PyObj]] = [];
    base_obj = layer2_testcase_base();
    if is_error(base_obj) or not isinstance(base_obj, PyClass) {
        return found;
    }
    base = base_obj as PyClass;
    for key in globals {
        value = globals[key];
        if not isinstance(value, PyClass) {
            continue;
        }
        cls = value as PyClass;
        if cls is base {
            continue;
        }
        if not (py_issubclass(cls, base) as bool) {
            continue;
        }
        for attr in cls.attrs {
            if not attr.startswith("test_") {
                continue;
            }
            found.append((cls, attr, cls.attrs[attr]));
        }
    }
    return found;
}

# Run one test method on an instance. Returns 1 pass, 0 fail, -1 error, 2 skip.
def layer2_run_method(instance: PyUserObj, method: PyObj) -> int {
    setup_out = testcase_call_setup(instance);
    if is_error(setup_out) {
        if layer2_is_skip(setup_out) {
            return 2;
        }
        return -1;
    }
    outcome = bind_attribute(method, instance).tp_call([], {});
    teardown_out = testcase_call_teardown(instance);
    if is_error(outcome) {
        if layer2_is_skip(outcome) {
            return 2;
        }
        if layer2_is_assertion(outcome) {
            return 0;
        }
        return -1;
    }
    if is_error(teardown_out) {
        if layer2_is_skip(teardown_out) {
            return 2;
        }
        return -1;
    }
    return 1;
}

def layer2_run_discovered(tests: list[tuple[PyClass, str, PyObj]]) -> ReplayResult {
    result = ReplayResult();
    for item in tests {
        cls = item[0];
        method_name = item[1];
        method = item[2];
        instance_out = cls.tp_call([], {});
        if is_error(instance_out) {
            result.errored = result.errored + 1;
            result.errors.append(method_name);
            continue;
        }
        if not isinstance(instance_out, PyUserObj) {
            result.errored = result.errored + 1;
            result.errors.append(method_name);
            continue;
        }
        verdict = layer2_run_method(instance_out as PyUserObj, method);
        if verdict == 1 {
            result.passed = result.passed + 1;
        } elif verdict == 0 {
            result.failed = result.failed + 1;
            result.failures.append(method_name);
        } elif verdict == 2 {
            result.skipped = result.skipped + 1;
        } else {
            result.errored = result.errored + 1;
            result.errors.append(method_name);
        }
    }
    return result;
}

def layer2_exec_source(source: str) -> dict[str, PyObj] {
    install_layer2_shims();
    layer2_module_globals = {"__name__": PyStr(t="str", val="__main__"),};
    outcome = exec_code(
        unmarshal(host_compile_marshal(source) as list[int]), [], layer2_module_globals
    );
    if is_error(outcome) {
        return {};
    }
    return layer2_module_globals;
}

def layer2_run_source(source: str) -> ReplayResult {
    globals = layer2_exec_source(source);
    if len(globals) == 0 {
        result = ReplayResult();
        result.errored = 1;
        result.errors.append("<module>");
        return result;
    }
    return layer2_run_discovered(layer2_discover_tests(globals));
}

# ---------------- tests ----------------------------------------------------

test "layer2: shim unittest runs a minimal test file proxy-free" {
    src = "import unittest\n"
    "class TestShim(unittest.TestCase):\n"
    "    def test_add(self):\n"
    "        self.assertEqual(1 + 1, 2)\n"
    "        self.assertTrue(3 < 5)\n"
    "    def test_raises(self):\n"
    "        self.assertRaises(ValueError, int, 'x')\n";
    result = layer2_run_source(src);
    assert result.passed == 2;
    assert result.failed == 0;
    assert result.errored == 0;
}

test "layer2: callable assertRaises form works" {
    src = "import unittest\n"
    "class TestRaises(unittest.TestCase):\n"
    "    def test_raises(self):\n"
    "        self.assertRaises(ValueError, int, 'x')\n";
    result = layer2_run_source(src);
    assert result.passed == 1;
    assert result.errored == 0;
}

test "layer2: with assertRaises context manager form works" {
    src = "import unittest\n"
    "class TestRaises(unittest.TestCase):\n"
    "    def test_raises(self):\n"
    "        with self.assertRaises(ValueError):\n"
    "            int('x')\n";
    result = layer2_run_source(src);
    assert result.passed == 1;
    assert result.failed == 0;
    assert result.errored == 0;
}

test "layer2: test.support skip decorator marks a test skipped" {
    src = "import unittest\n"
    "from test import support\n"
    "@support.cpython_only\n"
    "class TestSkip(unittest.TestCase):\n"
    "    def test_never_runs(self):\n"
    "        self.fail('should be skipped')\n";
    result = layer2_run_source(src);
    assert result.skipped == 1;
    assert result.failed == 0;
}

test "layer2: setUp state is visible inside test methods" {
    src = "import unittest\n"
    "class TestSetup(unittest.TestCase):\n"
    "    def setUp(self):\n"
    "        self.value = 7\n"
    "    def test_value(self):\n"
    "        self.assertEqual(self.value, 7)\n";
    result = layer2_run_source(src);
    assert result.passed == 1;
    assert result.failed == 0;
}
