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

glob _PRELUDE_CWD: list[str] = [];
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
import from jaclang.compiler.driver.compile_options { CompileOptions }

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

def run_py_fixture(fixture_stem: str, func_name: str) -> dict[str, any] {
    return json.loads(json.dumps(call_py_fixture(fixture_stem, func_name)));
}

"""The server lane's API encoder, which is what a walker response travels
through: Serializer in api_mode applies the wire rule, json.dumps writes it."""
def encode_py_wire(value: any) -> str {
    return json.dumps(Serializer.serialize(value, api_mode=True), sort_keys=True);
}

# -----------------------------------------------------------------------
# ES (ECMAScript / JavaScript) helpers
# -----------------------------------------------------------------------
def compile_fixture_to_js(fixture_name: str) -> str {
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
    es_pass = run_walker(EsastGenPass, module=ir, prog=prog);
    es_ir = es_pass.module;
    assert isinstance(es_ir.gen.es_ast, EsNode) , "es_ast should be an EsNode";
    return es_to_js(es_ir.gen.es_ast);
}

"""A directory where node can resolve the virtual `@jac/prelude` module.

The `node -` runs below evaluate a bundle from stdin, so resolution is rooted
at the working directory rather than at a file; staging once and running there
is what lets the emitted prelude import resolve.
"""
def _prelude_cwd -> str {
    import tempfile;
    if not _PRELUDE_CWD {
        stage = tempfile.mkdtemp(prefix="jac_xbackend_");
        stage_jac_prelude_package(stage);
        _PRELUDE_CWD.append(stage);
    }
    return _PRELUDE_CWD[0];
}

def run_js_function(js_code: str, func_name: str) -> dict[str, any] {
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
        ["node", "-"],
        input=wrapper,
        capture_output=True,
        text=True,
        timeout=10,
        cwd=_prelude_cwd()
    );
    assert result.returncode == 0 , f"Node.js failed: {result.stderr}";
    return json.loads(result.stdout.strip());
}

def run_js_module_fixture(fixture: str, func_name: str) -> dict[str, any] {
    import from tempfile { TemporaryDirectory }
    prog = JacProgram();
    source = (Path(_fixture_shadow_dir()) / fixture).resolve();
    prog.compile(str(source), no_cgen=True);
    assert not prog.errors_had , "\n".join(str(e) for e in prog.errors_had);

    def compile_module(path: Path, source_root: Path | None = None) -> ClientArtifact {
        artifact = prog._get_compiler().get_client_artifact(str(path), prog);
        assert artifact is not None , f"no client artifact for {path}: "
            + "\n".join(str(e) for e in prog.errors_had);
        return artifact;
    }

    with TemporaryDirectory() as directory {
        output = Path(directory);
        compiler = JacClientCompiler(
            project_dir=source.parent,
            runtime_path=None,
            compile_to_js_func=compile_module,
            extract_exports_func=lambda (manifest: ClientManifest | None) { return list(
                manifest.exports
            )
                if manifest is not None
                else []; },
            extract_globals_func=lambda (manifest: any, module: any) { return {}; },
            compiled_dir=output
        );
        source_root = Path(source.anchor);
        compiler.emit_dependencies(source, source_root=source_root);
        stage_jac_prelude_package(str(output));
        (output / "package.json").write_text('{"type":"module"}');
        js_entry = compiler._output_path_for(source, source_root);
        with js_entry.open("a") as stream {
            stream.write("\nconsole.log(JSON.stringify(" + func_name + "()));\n");
        }
        result = subprocess.run(
            ["node", str(js_entry)], capture_output=True, text=True, timeout=30
        );
        assert result.returncode == 0 , f"Node.js failed: {result.stderr}";
        return json.loads(result.stdout.strip());
    }
}

"""Evaluate one JS expression against a compiled bundle and return its value.

The bundle is in scope, so the expression can reach `_jac` and assert on the
runtime itself rather than only on what a fixture function returns.
"""
def run_js_expr(js_code: str, expr: str) -> any {
    wrapper = js_code + "\nconsole.log(JSON.stringify(" + expr + "));";
    result = subprocess.run(
        ["node", "-"],
        input=wrapper,
        capture_output=True,
        text=True,
        timeout=10,
        cwd=_prelude_cwd()
    );
    assert result.returncode == 0 , f"Node.js failed: {result.stderr}";
    return json.loads(result.stdout.strip());
}

# -----------------------------------------------------------------------
# NA (Native / LLVM) helpers
# -----------------------------------------------------------------------
def compile_native(fixture: str, *, no_ir_cache: bool = False) -> tuple[any, ...] {
    prog = JacProgram();
    path = str(os.path.join(_fixture_shadow_dir(), fixture));
    ir = prog.compile(file_path=path, options=CompileOptions(no_ir_cache=no_ir_cache));
    errors = [str(e) for e in prog.errors_had] if prog.errors_had else [];
    assert not prog.errors_had , f"Compilation errors in {fixture}: {errors}";
    eng = ir.gen.native_engine;
    assert eng is not None , f"No native engine produced for {fixture}";
    # The engine carries the link plan's ordered initializers
    # (`static_init_symbols`) and runs them itself on the first address it
    # hands out for a non-chained symbol; remember which unit it was built
    # from so bare Jac names resolve to the unit's qualified symbols.
    remember_engine_unit(eng, ir, path);
    return (eng, ir);
}

"""Pin the unit an engine was built from, so bare Jac names resolve to the
unit's qualified symbols; every compile path that hands an engine to
`get_func` calls this."""
def remember_engine_unit(eng: object, ir: object, path: str = "") {
    unit_path = ir.loc.mod_path if (ir?.loc and ir.loc.mod_path) else path;
    _ENGINE_UNITS[id(eng)] = (unit_path, ir.gen.native_iface, );
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

def compile_native_errors(fixture: str) -> list[str] {
    # compile_native for fixtures whose native lane is EXPECTED to emit
    # diagnostics; returns the rendered errors for assertion.
    prog = JacProgram();
    prog.compile(
        file_path=str(os.path.join(_fixture_shadow_dir(), fixture)),
        options=CompileOptions()
    );
    return [str(e) for e in prog.errors_had] if prog.errors_had else [];
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

glob NATIVE_TAG_INT: int = 0,
     NATIVE_TAG_FLOAT: int = 1,
     NATIVE_TAG_STR: int = 2,
     NATIVE_TAG_LIST: int = 3,
     NATIVE_TAG_DICT: int = 4,
     NATIVE_TAG_SET: int = 5,
     NATIVE_TAG_BOOL: int = 7,
     NATIVE_TAG_NONE: int = 8,
     NATIVE_KIND_INT: int = 0,
     NATIVE_KIND_FLOAT: int = 1,
     NATIVE_KIND_BOOL: int = 2,
     NATIVE_KIND_STR: int = 3,
     NATIVE_KIND_UINT: int = 7,
     NATIVE_DROPS: dict[str, tuple[str, str]] = {
         "_list_drop_plain": ("lists", "p"),
         "_list_drop_str": ("lists", "s"),
         "_list_drop_ref": ("lists", "r"),
         "_dict_drop_pp": ("dicts", "pp"),
         "_dict_drop_sp": ("dicts", "sp"),
         "_dict_drop_ss": ("dicts", "ss"),
         "_dict_drop_sr": ("dicts", "sr"),
         "_dict_drop_rp": ("dicts", "rp"),
         "_dict_drop_rs": ("dicts", "rs"),
         "_dict_drop_rr": ("dicts", "rr")
     },
     _NATIVE_DROP_KINDS: dict[int, str] = {};

def _learn_native_drops(eng: any) {
    _NATIVE_DROP_KINDS.clear();
    runtime = Path(jaclang.__file__).parent / "runtime" / "native";
    for (name, (unit, kinds)) in NATIVE_DROPS.items() {
        symbol = native_symbol_name(
            native_unit_prefix(str(runtime / f"{unit}.jac")), name
        );
        try {
            address = int(eng.get_function_address(symbol));
        } except Exception {
            address = 0;
        }
        if address {
            _NATIVE_DROP_KINDS[address] = kinds;
        }
    }
}

def _native_word(addr: int) -> int {
    return ctypes.c_int64.from_address(addr).value;
}

def _native_header(addr: int) -> str {
    if addr == 0 {
        return "";
    }
    named = ctypes.c_void_p.from_address(addr - 24).value;
    return ctypes.string_at(named).decode("utf-8", errors="replace") if named else "";
}

def _native_kinds(addr: int) -> str {
    return _NATIVE_DROP_KINDS.get(_native_word(addr - 8) & 0xFFFFFFFFFFFFFFFF, "");
}

def _native_text(addr: int) -> str {
    if addr == 0 {
        return "";
    }
    tag = _native_word(addr - 8);
    size = ((tag & 0x7FFFFFFFFFFFFFFF) >> 1)
        if tag & 1
        else len(ctypes.string_at(addr));
    return ctypes.string_at(addr, size).decode("utf-8", errors="replace");
}

def _native_float(bits: int) -> float {
    return struct.unpack("d", struct.pack("q", bits))[0];
}

def _guide_of(like: any, index: int) -> any {
    if isinstance(like, (list, tuple)) and like {
        return like[index] if index < len(like) else like[0];
    }
    if isinstance(like, set) and like {
        return next(iter(like));
    }
    return None;
}

def _native_slot(bits: int, kind: str, like: any) -> any {
    if kind == "s" {
        return _native_text(bits);
    }
    if kind == "r" {
        return _native_object(bits, like);
    }
    if isinstance(like, bool) {
        return bits != 0;
    }
    if isinstance(like, float) {
        return _native_float(bits);
    }
    return bits;
}

def _native_object(addr: int, like: any = None) -> any {
    if addr == 0 {
        return None;
    }
    name = _native_header(addr);
    if name == "any" {
        return native_any(_native_word(addr), _native_word(addr + 8), like);
    }
    if name == "str" {
        return _native_text(addr);
    }
    if name == "list" {
        kind = _native_kinds(addr) or "p";
        count = _native_word(addr);
        data = _native_word(addr + 16);
        return [
            _native_slot(_native_word(data + i * 8), kind, _guide_of(like, i))
            for i in range(count)
        ];
    }
    if name == "tuple" {
        count = _native_word(addr);
        out: list[any] = [];
        for i in range(count) {
            kind = _native_word(addr + 8 + i * 8);
            bits = _native_word(addr + 8 + (count + i) * 8);
            if kind == NATIVE_KIND_FLOAT {
                out.append(_native_float(bits));
            } elif kind == NATIVE_KIND_BOOL {
                out.append(bits != 0);
            } elif kind in (NATIVE_KIND_INT, NATIVE_KIND_UINT) {
                out.append(bits);
            } elif kind == NATIVE_KIND_STR {
                out.append(_native_text(bits));
            } else {
                out.append(_native_object(bits, _guide_of(like, i)));
            }
        }
        return tuple(out);
    }
    if name in ("dict", "set") {
        kinds = _native_kinds(addr) or "pp";
        used = _native_word(addr + 40);
        keys = _native_word(addr + 16);
        vals = _native_word(addr + 24);
        order = _native_word(addr + 48);
        key_like = next(iter(like)) if isinstance(like, (dict, set)) and like else None;
        if name == "set" {
            members: set[any] = set();
            for i in range(used) {
                if _native_word(order + i * 8) >= 0 {
                    members.add(
                        _native_slot(_native_word(keys + i * 8), kinds[0], key_like)
                    );
                }
            }
            return members;
        }
        result: dict[any, any] = {};
        for i in range(used) {
            if _native_word(order + i * 8) < 0 {
                continue;
            }
            key = _native_slot(_native_word(keys + i * 8), kinds[0], key_like);
            value_like = like.get(key) if isinstance(like, dict) else None;
            result[key] = _native_slot(
                _native_word(vals + i * 8), kinds[1], value_like
            );
        }
        return result;
    }
    return addr;
}

def native_any(tag: int, payload: int, like: any = None) -> any {
    tag = tag & 0xFF;
    if tag == NATIVE_TAG_INT {
        return payload;
    }
    if tag == NATIVE_TAG_FLOAT {
        return _native_float(payload);
    }
    if tag == NATIVE_TAG_BOOL {
        return payload != 0;
    }
    if tag == NATIVE_TAG_NONE {
        return None;
    }
    if tag == NATIVE_TAG_STR {
        return _native_text(payload);
    }
    if tag in (NATIVE_TAG_LIST, NATIVE_TAG_DICT, NATIVE_TAG_SET) {
        return _native_object(payload, like);
    }
    return payload;
}

def run_native_function(
    eng: object, func_name: str, ir: object = None, like: any = None
) -> dict[str, any] {
    f = get_func(eng, func_name, ctypes.c_void_p);
    made = f() or 0;
    _learn_native_drops(eng);
    decoded = _native_object(made, like if isinstance(like, dict) else {});
    return decoded if isinstance(decoded, dict) else {};
}

# -----------------------------------------------------------------------
# Comparison: intersection-based (only keys present in BOTH dicts)
# -----------------------------------------------------------------------
def compare_results(
    py_result: dict[str, any],
    backend_result: dict[str, any],
    label: str,
    tolerance: float = 1e-9
) -> None {
    common_keys = set(py_result.keys()) & set(backend_result.keys());
    if not common_keys {
        return;
    }
    for key in sorted(common_keys) {
        py_val = py_result[key];
        bk_val = backend_result[key];
        if not label.endswith("[ES]")
            and isinstance(py_val, float) != isinstance(bk_val, float) {
            assert False , (
                f"[{label}] Type mismatch on '{key}': py={py_val!r} backend={bk_val!r}"
            );
        }
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
    py_result: dict[str, any],
    backend_result: dict[str, any],
    label: str,
    allow_missing: (list[any] | None) = None
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
    require: (list[any] | None) = None,
    strict_keys: bool = True,
    allow_missing: (list[any] | None) = None,
    client_modules: bool = False
) {
    # `require` names backends ("cl"/"na") that must actually participate: if a
    # required backend fails to compile/run or shares no comparable keys with
    # the py reference, that is a hard failure rather than a silent skip. This
    # turns "support landed" into an enforced regression guard.
    reqd: list[any] = require if require is not None else [];
    stem = fixture[:-4] if fixture.endswith(".jac") else fixture;
    py_result = run_py_fixture(stem, py_fn);
    label = fixture;
    cl_keys: int = 0;
    try {
        if client_modules {
            cl_result = run_js_module_fixture(fixture, cl_fn);
        } else {
            js_code = compile_fixture_to_js(fixture);
            cl_result = run_js_function(js_code, cl_fn);
        }
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
        na_result = run_native_function(eng, na_fn, na_ir, py_result);
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
