"""Shared cross-backend equivalence harness.

Helpers for running one fixture across the Python reference (sv runtime),
ECMAScript/JS (cl, via Node.js), and native LLVM (na, via ctypes), then
comparing the results. Lives in a non-test module so multiple test files
(`test_prim_equivalence`, `test_osp_equivalence`, ...) can import it without
re-registering each other's `test` blocks.

Each fixture exposes one function per backend returning a JSON-able dict:
  - def func_py()       Python reference (always run)
  - cl def func_cl()    ECMAScript/JS via Node.js
  - na { def func_na() } Native LLVM JIT via ctypes

compare_results uses intersection semantics: only keys present in both dicts
are checked, so a backend that returns {} (unimplemented) is silently skipped.
"""

import ctypes;
import importlib;
import json;
import os;
import struct;
import subprocess;
import sys;
import from pathlib { Path }
import jaclang;
import from jaclang.compiler.passes.ecmascript { EsastGenPass }
import from jaclang.compiler.passes.ecmascript.es_unparse { es_to_js }
import from jaclang.compiler.passes.ecmascript.estree { Node as EsNode }
import from jaclang.jac0core.program { JacProgram }

glob FIXTURES = str(
         Path(jaclang.__file__).parent / "compiler" / "tests" / "fixtures"
     );

# -----------------------------------------------------------------------
# Python reference helper
# -----------------------------------------------------------------------
def run_py_fixture(fixture_stem: str, func_name: str) -> dict {
    added = False;
    if FIXTURES not in sys.path {
        sys.path.insert(0, FIXTURES);
        added = True;
    }
    try {
        sys.modules.pop(fixture_stem, None);
        mod = importlib.import_module(fixture_stem);
        fn = getattr(mod, func_name);
        return json.loads(json.dumps(fn()));
    } finally {
        if added {
            sys.path.remove(FIXTURES);
        }
        sys.modules.pop(fixture_stem, None);
    }
}

# -----------------------------------------------------------------------
# ES (ECMAScript / JavaScript) helpers
# -----------------------------------------------------------------------
def compile_fixture_to_js(fixture_name: str) -> str {
    fixture_path = os.path.join(FIXTURES, fixture_name);
    prog = JacProgram();
    ir = prog.compile(file_path=fixture_path, no_cgen=True);
    assert not prog.errors_had , (
        f"Compilation errors in {fixture_name}: {[str(e) for e in prog.errors_had]}"
    );
    es_pass = EsastGenPass(ir_in=ir, prog=prog);
    es_ir = es_pass.ir_out;
    assert isinstance(es_ir.gen.es_ast, EsNode) , "es_ast should be an EsNode";
    return es_to_js(es_ir.gen.es_ast);
}

def run_js_function(js_code: str, func_name: str) -> dict {
    wrapper = js_code + "\nconsole.log(JSON.stringify(" + func_name + "()));";
    result = subprocess.run(
        ["node", "-e", wrapper], capture_output=True, text=True, timeout=10
    );
    assert result.returncode == 0 , f"Node.js failed: {result.stderr}";
    return json.loads(result.stdout.strip());
}

# -----------------------------------------------------------------------
# NA (Native / LLVM) helpers
# -----------------------------------------------------------------------
def compile_native(fixture: str) -> tuple {
    prog = JacProgram();
    ir = prog.compile(file_path=str(os.path.join(FIXTURES, fixture)));
    errors = [str(e) for e in prog.errors_had] if prog.errors_had else [];
    assert not prog.errors_had , f"Compilation errors in {fixture}: {errors}";
    eng = ir.gen.native_engine;
    assert eng is not None , f"No native engine produced for {fixture}";
    return (eng, ir);
}

def get_func(eng: object, name: str, restype: type, *argtypes: type) -> object {
    addr = eng.get_function_address(name);
    assert addr != 0 , f"Function '{name}' not found in JIT engine";
    functype = ctypes.CFUNCTYPE(restype, *argtypes);
    return functype(addr);
}

class JacVal(ctypes.Structure) {
    has _fields_: list = [("tag", ctypes.c_int8), ("payload", ctypes.c_int64)];
}

def unbox_jacval(jv: JacVal) -> object {
    if jv.tag == 0 {
        return jv.payload;
    } elif jv.tag == 1 {
        return struct.unpack('d', struct.pack('q', jv.payload))[0];
    } elif jv.tag == 2 {
        if jv.payload == 0 {
            return "";
        }
        return ctypes.cast(jv.payload, ctypes.c_char_p).value.decode("utf-8");
    } elif jv.tag == 3 {
        # List pointer: struct { i64 len, i64 cap, i64* data } (List.i64 layout)
        if jv.payload == 0 {
            return [];
        }
        class ListStruct(ctypes.Structure) {
            has _fields_: list = [
                ("len", ctypes.c_int64),
                ("cap", ctypes.c_int64),
                ("data", ctypes.POINTER(ctypes.c_int64))
            ];
        }
        lst_ptr = ctypes.cast(jv.payload, ctypes.POINTER(ListStruct));
        n = lst_ptr.contents.len;
        return [lst_ptr.contents.data[i] for i in range(n)];
    } elif jv.tag == 4 {
        # Dict pointer: struct { i64 len, i64 cap, i8** keys, JacVal* vals }
        if jv.payload == 0 {
            return {};
        }
        class InnerDictStruct(ctypes.Structure) {
            has _fields_: list = [
                ("len", ctypes.c_int64),
                ("cap", ctypes.c_int64),
                ("keys", ctypes.POINTER(ctypes.c_char_p)),
                ("vals", ctypes.POINTER(JacVal))
            ];
        }
        dct_ptr = ctypes.cast(jv.payload, ctypes.POINTER(InnerDictStruct));
        n = dct_ptr.contents.len;
        result: dict = {};
        for i in range(n) {
            k = dct_ptr.contents.keys[i].decode("utf-8");
            result[k] = unbox_jacval(dct_ptr.contents.vals[i]);
        }
        return result;
    } elif jv.tag == 5 {
        # Set pointer: struct { i64 len, i64 cap, i64* elems } (Set.i64 layout)
        if jv.payload == 0 {
            return set();
        }
        class SetStruct(ctypes.Structure) {
            has _fields_: list = [
                ("len", ctypes.c_int64),
                ("cap", ctypes.c_int64),
                ("elems", ctypes.POINTER(ctypes.c_int64))
            ];
        }
        st_ptr = ctypes.cast(jv.payload, ctypes.POINTER(SetStruct));
        n = st_ptr.contents.len;
        return {st_ptr.contents.elems[i] for i in range(n)};
    } elif jv.tag == 7 {
        # bool: kept distinct from int (tag 0) so it round-trips as True/False
        # rather than 1/0, matching the Python reference exactly.
        return jv.payload != 0;
    }
    return None;
}

def run_native_function(eng: object, func_name: str) -> dict {
    class DictStruct(ctypes.Structure) {
        has _fields_: list = [
            ("len", ctypes.c_int64),
            ("cap", ctypes.c_int64),
            ("keys", ctypes.POINTER(ctypes.c_char_p)),
            ("vals", ctypes.POINTER(JacVal))
        ];
    }
    # Run the module initializer first so module-level and `static has` globals
    # whose values are not compile-time constants (strings, constructor calls)
    # are populated before the fixture function reads them. Prefer jac_entry
    # (chains __jac_glob_init across this module and every linked import); fall
    # back to this module's __jac_glob_init when no `with entry` block emitted a
    # jac_entry. Fixtures carry no entry block, so this only runs initializers.
    init_addr = eng.get_function_address("jac_entry");
    if init_addr == 0 {
        init_addr = eng.get_function_address("__jac_glob_init");
    }
    if init_addr != 0 {
        ctypes.CFUNCTYPE(None)(init_addr)();
    }
    f = get_func(eng, func_name, ctypes.POINTER(DictStruct));
    dict_ptr = f();
    result: dict = {};
    for i in range(dict_ptr.contents.len) {
        key = dict_ptr.contents.keys[i].decode("utf-8");
        jv = dict_ptr.contents.vals[i];
        result[key] = unbox_jacval(jv);
    }
    return result;
}

# -----------------------------------------------------------------------
# Comparison: intersection-based (only keys present in BOTH dicts)
# -----------------------------------------------------------------------
def compare_results(
    py_result: dict, backend_result: dict, label: str, tolerance: float = 1e-9
) -> None {
    common_keys = set(py_result.keys()) & set(backend_result.keys());
    if not common_keys {
        return;
    }
    for key in sorted(common_keys) {
        py_val = py_result[key];
        bk_val = backend_result[key];
        if isinstance(py_val, float) or isinstance(bk_val, float) {
            assert abs(float(py_val) - float(bk_val)) < tolerance , (
                f"[{label}] Float mismatch on '{key}': py={py_val} backend={bk_val}"
            );
        } elif isinstance(py_val, list) and isinstance(bk_val, list) {
            assert py_val == bk_val , (
                f"[{label}] List mismatch on '{key}': py={py_val} backend={bk_val}"
            );
        } elif isinstance(py_val, dict) and isinstance(bk_val, dict) {
            assert py_val == bk_val , (
                f"[{label}] Dict mismatch on '{key}': py={py_val} backend={bk_val}"
            );
        } else {
            assert py_val == bk_val , (
                f"[{label}] Mismatch on '{key}': py={py_val!r} backend={bk_val!r}"
            );
        }
    }
}

# -----------------------------------------------------------------------
# Dispatch helper: run py reference, then try ES and NA backends
# -----------------------------------------------------------------------
def run_with_both(
    fixture: str,
    py_fn: str,
    cl_fn: str,
    na_fn: str,
    tolerance: float = 1e-9,
    require: (list | None) = None
) {
    # `require` names backends ("cl"/"na") that must actually participate: if a
    # required backend fails to compile/run or shares no comparable keys with
    # the py reference, that is a hard failure rather than a silent skip. This
    # turns "support landed" into an enforced regression guard.
    reqd: list = require if require is not None else [];
    stem = fixture[:-4] if fixture.endswith(".jac") else fixture;
    py_result = run_py_fixture(stem, py_fn);
    label = fixture;
    cl_keys: int = 0;
    try {
        js_code = compile_fixture_to_js(fixture);
        cl_result = run_js_function(js_code, cl_fn);
        cl_keys = len(set(py_result.keys()) & set(cl_result.keys()));
        compare_results(py_result, cl_result, f"{label} [ES]", tolerance);
    } except Exception {
        if "cl" in reqd {
            raise;
        }
    }
    if ("cl" in reqd) and (cl_keys == 0) {
        raise AssertionError(
            f"[{label}] cl backend was required but produced no comparable data"
        );
    }
    na_keys: int = 0;
    try {
        (eng, _) = compile_native(fixture);
        na_result = run_native_function(eng, na_fn);
        na_keys = len(set(py_result.keys()) & set(na_result.keys()));
        compare_results(py_result, na_result, f"{label} [NA]", tolerance);
    } except Exception {
        if "na" in reqd {
            raise;
        }
    }
    if ("na" in reqd) and (na_keys == 0) {
        raise AssertionError(
            f"[{label}] na backend was required but produced no comparable data"
        );
    }
}
