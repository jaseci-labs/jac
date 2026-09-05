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
import from jaclang.compiler.backends.es { EsastGenPass }
import from jaclang.compiler.backends.es.es_unparse { es_to_js }
import from jaclang.compiler.backends.es.estree { Node as EsNode }
import from jaclang.compiler.frontend.codeinfo {
    JAC_ENTRY_SYMBOL,
    native_symbol_name,
    native_unit_prefix
}
import from jaclang.compiler.driver.program { JacProgram }

glob FIXTURES = str(
         Path(jaclang.__file__).parent / "compiler" / "tests" / "fixtures"
     ),
     _FIXTURE_SHADOW: list[str] = [],
     _ENGINE_UNITS: dict[int, tuple[str, any]] = {};

# -----------------------------------------------------------------------
# Python reference helper
# -----------------------------------------------------------------------
def _fixture_shadow_dir -> str {
    # The reference lane imports the fixture from a copy of the fixtures
    # directory that lives outside the jaclang tree: a module under jaclang/
    # imported while the package itself is being served skips analysis (a
    # bootstrap guard), and this lane needs the checker's annotations
    # (coerce_to) so the server codegen emits the same conversions the native
    # and client lanes emit. Importing keeps the compile on the ordinary
    # module path, so no compiler state leaks into the client and native
    # compiles that follow in the same process.
    import shutil;
    import tempfile;
    if not _FIXTURE_SHADOW {
        base_dir = tempfile.mkdtemp(prefix="jac_xbackend_fixtures_");
        shadow = os.path.join(base_dir, "fixtures");
        shutil.copytree(FIXTURES, shadow);
        _FIXTURE_SHADOW.append(shadow);
    }
    return _FIXTURE_SHADOW[0];
}

def call_py_fixture(fixture_stem: str, func_name: str) -> any {
    shadow = _fixture_shadow_dir();
    added = False;
    if shadow not in sys.path {
        sys.path.insert(0, shadow);
        added = True;
    }
    try {
        sys.modules.pop(fixture_stem, None);
        mod = importlib.import_module(fixture_stem);
        fn = getattr(mod, func_name);
        return fn();
    } finally {
        if added {
            sys.path.remove(shadow);
        }
        sys.modules.pop(fixture_stem, None);
    }
}

def run_py_fixture(fixture_stem: str, func_name: str) -> dict {
    return json.loads(json.dumps(call_py_fixture(fixture_stem, func_name)));
}

"""The server lane's API encoder, which is what a walker response travels
through: Serializer in api_mode applies the wire rule, json.dumps writes it."""
def encode_py_wire(value: any) -> str {
    import from jaclang.data.serializer { Serializer }
    return json.dumps(Serializer.serialize(value, api_mode=True), sort_keys=True);
}

# -----------------------------------------------------------------------
# ES (ECMAScript / JavaScript) helpers
# -----------------------------------------------------------------------
def compile_fixture_to_js(fixture_name: str) -> str {
    import from jaclang.compiler.passes.type_checker_pass { TypeCheckPass }
    fixture_path = os.path.join(FIXTURES, fixture_name);
    prog = JacProgram();
    # EsastGenPass consumes core call facts (call_kind/
    # callee_decl) that only the inference schedule stamps.
    ir = prog.compile(file_path=fixture_path, no_cgen=True);
    fatal = [
        e
        for e in prog.errors_had
        if not issubclass(e.from_pass, TypeCheckPass)
    ];
    assert not fatal , (
        f"Compilation errors in {fixture_name}: {[str(e) for e in fatal]}"
    );
    es_pass = EsastGenPass(ir_in=ir, prog=prog);
    es_ir = es_pass.ir_out;
    assert isinstance(es_ir.gen.es_ast, EsNode) , "es_ast should be an EsNode";
    return es_to_js(es_ir.gen.es_ast);
}

def run_js_function(js_code: str, func_name: str) -> dict {
    # The bundle's own replacer, not a BigInt.prototype patch: this is the same
    # encoder the client transport uses, so what the harness reads is what a
    # browser would put on the wire.
    wrapper = js_code
        + (
            "\nconst __jac_enc = (typeof _jac !== 'undefined' && _jac.fw)"
            " ? _jac.fw.stringify : JSON.stringify;"
            "\nconsole.log(__jac_enc("
            + func_name
            + "()));"
        );
    result = subprocess.run(
        ["node", "-e", wrapper], capture_output=True, text=True, timeout=10
    );
    assert result.returncode == 0 , f"Node.js failed: {result.stderr}";
    return json.loads(result.stdout.strip());
}

"""Evaluate one JS expression against a compiled bundle and return its value.

The bundle is in scope, so the expression can reach `_jac` and assert on the
runtime itself rather than only on what a fixture function returns.
"""
def run_js_expr(js_code: str, expr: str) -> any {
    wrapper = js_code + "\nconsole.log(JSON.stringify(" + expr + "));";
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
    path = str(os.path.join(FIXTURES, fixture));
    ir = prog.compile(file_path=path);
    errors = [str(e) for e in prog.errors_had] if prog.errors_had else [];
    assert not prog.errors_had , f"Compilation errors in {fixture}: {errors}";
    eng = ir.gen.native_engine;
    assert eng is not None , f"No native engine produced for {fixture}";
    # The engine carries the link plan's ordered initializers
    # (`static_init_symbols`) and runs them itself on the first address it
    # hands out for a non-chained symbol; remember which unit it was built
    # from so bare Jac names resolve to the unit's qualified symbols.
    unit_path = ir.loc.mod_path if (ir?.loc and ir.loc.mod_path) else path;
    _ENGINE_UNITS[id(eng)] = (unit_path, ir.gen.native_iface, );
    return (eng, ir);
}

"""The engine symbol for a Jac-level name.

`jac_entry` is synthesized by the link plan and keeps its bare name, `:pub`
symbols keep theirs, and every other external symbol of the unit lives
under `native_unit_prefix(path)`; the unit's interface records the exact
symbol when the compile produced one.
"""
def native_symbol_for(eng: object, name: str) -> str {
    if name == JAC_ENTRY_SYMBOL {
        return name;
    }
    found = _ENGINE_UNITS.get(id(eng));
    if found is None {
        return name;
    }
    (unit_path, iface) = found;
    if iface is not None {
        sym = iface.symbol_of(name);
        if sym {
            return sym;
        }
    }
    return native_symbol_name(native_unit_prefix(unit_path), name);
}

def get_func(eng: object, name: str, restype: type, *argtypes: type) -> object {
    symbol = native_symbol_for(eng, name);
    addr = eng.get_function_address(symbol);
    if addr == 0 and symbol != name {
        # A `:pub` function the interface did not list keeps its bare name.
        addr = eng.get_function_address(name);
    }
    assert addr != 0 , f"Function '{name}' ({symbol}) not found in JIT engine";
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
        # List pointer: {i64 len, i64 cap, T* data}. The RC header's type-tag
        # string (at payload - 24) names the concrete storage (list_i64,
        # list_f64, list_jacval, ...) so hetero payloads decode by element tag.
        if jv.payload == 0 {
            return [];
        }
        class ListStruct(ctypes.Structure) {
            has _fields_: list = [
                ("len", ctypes.c_int64),
                ("cap", ctypes.c_int64),
                ("data", ctypes.c_void_p)
            ];
        }
        tname = "";
        try {
            _tslot = ctypes.cast(jv.payload - 24, ctypes.POINTER(ctypes.c_void_p));
            _tp = _tslot.contents.value;
            if _tp {
                tname = ctypes.string_at(_tp).decode("utf-8", errors="replace");
            }
        } except Exception {
            tname = "";
        }
        lst_ptr = ctypes.cast(jv.payload, ctypes.POINTER(ListStruct));
        n = lst_ptr.contents.len;
        data = lst_ptr.contents.data;
        if (n == 0 or not data) {
            return [];
        }
        if tname == "list_jacval" {
            jarr = (JacVal * n).from_address(data);
            return [unbox_jacval(jarr[i]) for i in range(n)];
        }
        if tname == "list_f64" {
            farr = (ctypes.c_double * n).from_address(data);
            return [float(farr[i]) for i in range(n)];
        }
        iarr = (ctypes.c_int64 * n).from_address(data);
        return [int(iarr[i]) for i in range(n)];
    } elif jv.tag == 4 {
        # Dict pointer: struct { i64 len, i64 cap, i8** keys, JacVal* vals }
        if jv.payload == 0 {
            return {};
        }
        # Hash-table dict layout (see DictStruct below). `order[0..len]` holds the
        # keys/vals slot of each entry in insertion order (Python dict semantics),
        # so iterate order[i] -> keys[slot]/vals[slot].
        class InnerDictStruct(ctypes.Structure) {
            has _fields_: list = [
                ("len", ctypes.c_int64),
                ("cap", ctypes.c_int64),
                ("keys", ctypes.POINTER(ctypes.c_char_p)),
                ("vals", ctypes.POINTER(JacVal)),
                ("ctrl", ctypes.POINTER(ctypes.c_uint8)),
                ("used", ctypes.c_int64),
                ("order", ctypes.POINTER(ctypes.c_int64))
            ];
        }
        dct_ptr = ctypes.cast(jv.payload, ctypes.POINTER(InnerDictStruct));
        result: dict = {};
        for i in range(dct_ptr.contents.len) {
            slot = dct_ptr.contents.order[i];
            k = dct_ptr.contents.keys[slot].decode("utf-8");
            result[k] = unbox_jacval(dct_ptr.contents.vals[slot]);
        }
        return result;
    } elif jv.tag == 5 {
        # Set pointer: hash-table Set.i64 layout
        #   {i64 len, i64 cap, i64* keys, i8* ctrl, i64 used, i64* order}
        if jv.payload == 0 {
            return set();
        }
        class SetStruct(ctypes.Structure) {
            has _fields_: list = [
                ("len", ctypes.c_int64),
                ("cap", ctypes.c_int64),
                ("keys", ctypes.POINTER(ctypes.c_int64)),
                ("ctrl", ctypes.POINTER(ctypes.c_uint8)),
                ("used", ctypes.c_int64),
                ("order", ctypes.POINTER(ctypes.c_int64))
            ];
        }
        st_ptr = ctypes.cast(jv.payload, ctypes.POINTER(SetStruct));
        n = st_ptr.contents.len;
        return {st_ptr.contents.keys[st_ptr.contents.order[i]] for i in range(n)};
    } elif jv.tag == 7 {
        # bool: kept distinct from int (tag 0) so it round-trips as True/False
        # rather than 1/0, matching the Python reference exactly.
        return jv.payload != 0;
    }
    return None;
}

def run_native_function(eng: object, func_name: str, ir: object = None) -> dict {
    # Open-addressing hash-table dict:
    #   {i64 len, i64 cap, i8** keys, JacVal* vals, i8* ctrl, i64 used, i64* order}
    # Live entries sit at sparse hashed slots across `cap`. `order[0..len]` holds
    # the keys/vals slot index of each entry in INSERTION ORDER (Python dict
    # semantics), so iterate order[i] -> keys[slot] / vals[slot].
    class DictStruct(ctypes.Structure) {
        has _fields_: list = [
            ("len", ctypes.c_int64),
            ("cap", ctypes.c_int64),
            ("keys", ctypes.POINTER(ctypes.c_char_p)),
            ("vals", ctypes.POINTER(JacVal)),
            ("ctrl", ctypes.POINTER(ctypes.c_uint8)),
            ("used", ctypes.c_int64),
            ("order", ctypes.POINTER(ctypes.c_int64))
        ];
    }
    # Module-level and `static has` globals whose values are not compile-time
    # constants (strings, constructor calls) are populated by the unit
    # initializers the link plan ordered onto the engine
    # (`engine.static_init_symbols`, dependencies first). The engine runs
    # them itself the first time it hands out the address of a non-chained
    # symbol, so looking the fixture function up is what initializes this
    # unit and every native import it links. `ir` is accepted for callers
    # that still pass the module; nothing is read from it.
    f = get_func(eng, func_name, ctypes.POINTER(DictStruct));
    dict_ptr = f();
    result: dict = {};
    # Iterate in insertion order via order[0..len].
    for i in range(dict_ptr.contents.len) {
        slot = dict_ptr.contents.order[i];
        key = dict_ptr.contents.keys[slot].decode("utf-8");
        jv = dict_ptr.contents.vals[slot];
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
def assert_full_parity(
    py_result: dict,
    backend_result: dict,
    label: str,
    allow_missing: (list | None) = None
) {
    waived = set(allow_missing or []);
    missing = sorted((set(py_result.keys()) - set(backend_result.keys())) - waived);
    extra = sorted(set(backend_result.keys()) - set(py_result.keys()));
    stale = sorted(waived - (set(py_result.keys()) - set(backend_result.keys())));
    assert not missing and not extra , (
        f"[{label}] required backend key set drifted from the py reference: "
        f"missing {missing}, extra {extra}. A lane that genuinely cannot "
        "produce a row declares it in allow_missing at the call site, so the "
        "gap is visible rather than silently dropped from the comparison."
    );
    assert not stale , (
        f"[{label}] allow_missing names rows the backend now produces: "
        f"{stale} -- drop them from the waiver"
    );
}

def run_with_both(
    fixture: str,
    py_fn: str,
    cl_fn: str,
    na_fn: str,
    tolerance: float = 1e-9,
    require: (list | None) = None,
    strict_keys: bool = True,
    allow_missing: (list | None) = None
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
        if strict_keys and "cl" in reqd {
            assert_full_parity(py_result, cl_result, f"{label} [ES]", allow_missing);
        }
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
        (eng, na_ir) = compile_native(fixture);
        na_result = run_native_function(eng, na_fn, na_ir);
        na_keys = len(set(py_result.keys()) & set(na_result.keys()));
        if strict_keys and "na" in reqd {
            assert_full_parity(py_result, na_result, f"{label} [NA]", allow_missing);
        }
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
