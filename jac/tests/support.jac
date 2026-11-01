"""Shared path anchor for the test suite.

Tests must not assume the editable-install layout (`jaclang.__file__` sitting
next to the repo `tests/`): under the single `jac` binary, jaclang lives in the
sealed runtime cache, not beside the tests. This module resolves the repo root
from its OWN location inside `tests/`, so every test imports one stable anchor
instead of re-deriving it with a `Path(__file__).resolve().parents` walk.

Imported as `from tests.support`, which resolves identically under the single
`jac` binary and a source checkout (same mechanism as `tests.fixtures_list`).

Every compile here goes through the kernel, the only compiler: a test that
compiles and checks results uses the compile entry (`kernel_compile_file`,
`kernel_compile_source`), the check entry (`kernel_check_file`,
`kernel_check_source`) or a session (`project.kernel_call.open_kernel_session`);
native tests JIT the kernel's products (`compile_native`) or read the decision
step's MIR and demoted set (`compile_mir`). A test that inspects compiler
internals (the tree, symbol tables, pass outputs) is not written here: it is a
kernel test case in `jaclang/compiler/kernel_tests/`, run inside the kernel by
`tests/compiler/test_kernel_suites.jac` (`kernel_cases`, `run_kernel_case`).
"""

import ctypes;

import from pathlib { Path }
import type from jaclang.compiler.driver.compile_options { CompileOptions }
import type from jaclang.compiler.backends.native.llvm.jit { ExecutionEngine }
import type from jaclang.compiler.kernel_api {
    CheckResult,
    CompileResult,
    CompiledUnit,
    KernelTestCase
}

# `tests/`: the directory holding this file.
glob TESTS_DIR: str = str(Path(__file__).resolve().parent),
     # Repo root (the `jac/` dir): the parent of `tests/`.
     JAC_ROOT: str = str(Path(__file__).resolve().parent.parent);

"""The JavaScript runtime this process runs (js_engine or bun), or None when
neither is built: suites that need one skip on None, and strict lanes, which
ship a kit with bun, never see it."""
def js_runtime_or_none -> (str | None) {
    import from jaclang.artifacts.model { ArtifactUnavailable }
    import from jaclang.client.js_runtime { js_runtime_path }
    try {
        return js_runtime_path();
    } except ArtifactUnavailable {
        return None;
    }
}

"""Environment overrides isolating every machine-wide cache family."""
def cache_env(cache_dir: Path | str) -> dict[str, str] {
    import from jaclang.cache.registry { BUCKETS }
    base = Path(cache_dir).resolve();
    env = {"JAC_CACHE_HOME": str(base), "XDG_CACHE_HOME": str(base)};
    for b in BUCKETS {
        if b.root_env {
            env[b.root_env] = str(base / b.root_prefix);
        }
    }
    return env;
}

"""Let a child under a private cache root reuse this process's Postgres
distribution instead of provisioning its own (a system Postgres it finds
by itself)."""
def share_postgres(cache_home: Path | str) {
    import from jaclang.data.pg_dist { dist_cache_dir, postgres_bin_dir }
    dist = Path(postgres_bin_dir()).parent;
    if not dist.is_relative_to(Path(dist_cache_dir())) {
        return;
    }
    link = Path(cache_home) / "pg" / "dist" / dist.name;
    link.parent.mkdir(parents=True, exist_ok=True);
    if not link.exists() {
        link.symlink_to(dist, target_is_directory=True);
    }
}

"""Run as a project whose jac.toml sets `[network] offline`."""
def offline_project -> any {
    import from unittest.mock { patch }
    return patch("jaclang.project.config.offline_mode", return_value=True);
}

"""Select the parent's compiler, or an explicit checkout for comparative tests."""
def compiler_python_command(
    source: str, *args: str, compiler_root: str | None = None
) -> list[str] {
    import jaclang;
    import sys;
    package_root = str(Path(str(jaclang.__file__)).resolve().parent.parent)
        if compiler_root is None
        else str(Path(compiler_root).resolve());
    if not (Path(package_root) / "jaclang" / "__init__.py").is_file() {
        raise ValueError(f"No compiler package at {package_root}");
    }
    boot = (
        "import sys\nsys.path.insert(0, "
        + repr(package_root)
        + ")\n"
        + "sys.path.extend("
        + repr(sys.path)
        + ")\n"
        + source
    );
    return [sys.executable, "-c", boot, *args];
}

"""Invoke the selected compiler's CLI, including from a checkout working directory."""
def jac_command(*args: str, compiler_root: str | None = None) -> list[str] {
    return compiler_python_command(
        "import runpy\nrunpy.run_module('jaclang', run_name='__main__', alter_sys=True)",
        *args,
        compiler_root=compiler_root
    );
}

"""CompileOptions that force a fixture into the native codespace.

The retired .na.jac marker used to do this from the filename; tests that
compile a fixture and expect a JIT engine now state the mandate explicitly.
Forced placement keeps lowering failures loud (no server demotion), exactly
like the old suffix.
"""
def native_force_opts -> CompileOptions {
    import from jaclang.compiler.driver.compile_options { CompileOptions }
    return CompileOptions(force_codespace='native');
}


class JacStrABI(ctypes.Structure) {
    has _fields_: list[tuple[str, type]] = [
        ("root", ctypes.c_void_p),
        ("data", ctypes.c_void_p)
    ];
}

def native_str_func(eng: any, name: str, restype: type | None, *argtypes: type) -> any {
    # descriptor-ABI JIT getter shared by native tests: a c_char_p
    # spelling means a Jac str (the by-value {root, data, len}
    # descriptor); LLVM decomposes the by-value param into three scalar
    # slots, so str args pass as (root, data, len) built via
    # jac_str_new, and str returns read back as a two-pointer pair with
    # the payload NUL-bounded at data
    addr = native_address(eng, name);
    assert addr != 0 , f"Function '{name}' not found in JIT engine";
    real_res: any = JacStrABI if restype == ctypes.c_char_p else restype;
    str_slots: list[bool] = [];
    real_args: list[any] = [];
    for a in argtypes {
        if a == ctypes.c_char_p {
            str_slots.append(True);
            real_args.append(ctypes.c_void_p);
            real_args.append(ctypes.c_void_p);
            real_args.append(ctypes.c_int64);
        } else {
            str_slots.append(False);
            real_args.append(a);
        }
    }
    raw = ctypes.CFUNCTYPE(real_res, *real_args)(addr);
    sn_addr = 0;
    for sn in ("jac_str_new", "__jac_str_new") {
        try {
            sn_addr = native_address(eng, sn);
        } except Exception {
            sn_addr = 0;
        }
        if sn_addr {
            break;
        }
    }
    mkstr = (
        ctypes.CFUNCTYPE(ctypes.c_void_p, ctypes.c_char_p, ctypes.c_int64)(sn_addr)
            if sn_addr
            else None
    );
    def _call(*args: any) -> any {
        c_args: list[any] = [];
        _keep: list[any] = [];
        for (a, is_str) in zip(args, str_slots) {
            if is_str {
                b = a.encode("utf-8") if isinstance(a, str) else a;
                if mkstr is not None {
                    p = mkstr(b, len(b));
                } else {
                    _buf = ctypes.create_string_buffer(b);
                    _keep.append(_buf);
                    p = ctypes.cast(_buf, ctypes.c_void_p).value;
                }
                c_args.append(p);
                c_args.append(p);
                c_args.append(len(b));
            } else {
                c_args.append(a);
            }
        }
        r = raw(*c_args);
        if real_res is JacStrABI {
            if not r.data {
                return b"";
            }
            return ctypes.string_at(r.data);
        }
        return r;
    }
    return _call;
}


"""Fetch an object's persisted state by id from a compiled Jac program.

Runs under the system context (no user root), so access checks always pass.
Previously lived in `tests/conftest.py`, which existed only for pytest.
"""
def get_object(filename: str, id: str, main: bool = True) -> dict[(str, any)] {
    import from jaclang.cli.commands.cli_helpers { proc_file }
    import from jaclang.runtime.runtime { JacRuntime as Jac }
    (base, mod, mach) = proc_file(filename);
    try {
        Jac.jac_import(
            target=mod, base_path=base, override_name=("__main__" if main else None)
        );
        found = Jac.get_object(id);
        if not found {
            raise ValueError(f"Object with id {id} not found.");
        }
        return found.__jac__.__getstate__();
    } finally {
        mach.close();
    }
}


# The native pass fixtures directory: the default corpus for `compile_native`.
glob NATIVE_FIXTURES: str = str(
         Path(__file__).resolve().parent
             / "compiler"
             / "backends"
             / "native"
             / "fixtures"
     );

"""The native identity of archetype `name` declared in `source`.

Structs, method symbols, vtables and layout keys are spelled with it
(`codeinfo.native_arch_name`: the name scoped by its defining module). A
relative `source` names a file in the native fixtures directory.
"""
def native_arch(source: str, name: str) -> str {
    import from jaclang.compiler.frontend.codeinfo { native_arch_name }
    path = Path(source);
    if not path.is_absolute() {
        path = Path(NATIVE_FIXTURES) / source;
    }
    return native_arch_name(str(path), name);
}

"""`text` (IR, a symbol, a layout key) with archetype identities spelled by
source name, for assertions about everything but the scoping itself."""
def source_spelled(text: str) -> str {
    import from jaclang.compiler.frontend.codeinfo { native_display_text }
    return native_display_text(text);
}

"""`mapping` re-keyed by source name (layout registries, exported layouts)."""
def by_source_name(mapping: dict[str, any]) -> any {
    return {source_spelled(key): value for (key, value) in mapping.items()};
}

"""The link symbol `iface` exports for `name`. A record names the unit's own
archetypes by source name; an export whose name involves another module's
archetype (a specialization over it) keeps that archetype's scope, and is
found here by its source spelling too."""
def iface_symbol(iface: any, name: str) -> (str | None) {
    if iface is None {
        return None;
    }
    found = iface.symbol_of(name);
    if found is not None {
        return found;
    }
    for (key, ex) in iface.exports.items() {
        if source_spelled(key) == name {
            return ex.symbol;
        }
    }
    return None;
}

"""The absolute path of `fixture`: a file in `fixture_dir`, which defaults to
the native pass fixtures directory."""
def fixture_path(fixture: str, fixture_dir: str = "") -> str {
    return str(Path(fixture_dir or NATIVE_FIXTURES) / fixture);
}

"""Compile `path` through the kernel's compile entry, as `jac run` and the
import hook do, and return the kernel's result untouched: units, errors and
warnings as `KernelDiagnostic` records. `products` defaults to bytecode; name
"mir" to get each unit's MIR and its demoted set."""
def kernel_compile_file(
    path: str,
    options: (CompileOptions | None) = None,
    products: (list[str] | None) = None,
    sources: (dict[str, str] | None) = None
) -> CompileResult {
    import from jaclang.compiler.driver.compile_options { CompileOptions }
    import from jaclang.project.kernel_call { call_compile }
    import from jaclang.project.kernel_compile { compile_request_for }
    return call_compile(
        compile_request_for(
            [path],
            options if options is not None else CompileOptions(),
            sources or {},
            products if products is not None else ["bytecode"]
        )
    );
}

"""Write `source` to a fresh directory as `name` and compile it through the
kernel. The directory outlives the call, so diagnostics keep a real path."""
def kernel_compile_source(
    source: str,
    name: str = "main.jac",
    options: (CompileOptions | None) = None,
    products: (list[str] | None) = None
) -> CompileResult {
    return kernel_compile_file(write_case(source, name), options, products);
}

"""Check `path` through the kernel's check entry (`jac check`)."""
def kernel_check_file(
    path: str,
    options: (CompileOptions | None) = None,
    native_coverage: bool = False,
    placements: bool = False,
    closure: bool = False,
    sources: (dict[str, str] | None) = None
) -> CheckResult {
    import from jaclang.compiler.driver.compile_options { CompileOptions }
    import from jaclang.project.kernel_call { call_check }
    import from jaclang.project.kernel_compile { check_request_for }
    request = check_request_for(
        [path],
        options if options is not None else CompileOptions(),
        native_coverage,
        placements,
        closure
    );
    request.sources = {
        str(Path(key).resolve()): text
        for (key, text) in (sources or {}).items()
    };
    return call_check(request);
}

"""Write `source` to a fresh directory as `name` and check it through the
kernel."""
def kernel_check_source(
    source: str, name: str = "main.jac", options: (CompileOptions | None) = None
) -> CheckResult {
    return kernel_check_file(write_case(source, name), options);
}

"""Write `source` as `name` in a fresh directory; return its path."""
def write_case(source: str, name: str = "main.jac") -> str {
    import tempfile;
    path = Path(tempfile.mkdtemp(prefix="jac-case-")) / name;
    path.parent.mkdir(parents=True, exist_ok=True);
    path.write_text(source, encoding="utf-8");
    return str(path);
}

"""The codes of a kernel result's errors, in order."""
def error_codes(result: (CompileResult | CheckResult)) -> list[str] {
    return [diag.code for diag in result.errors];
}

"""The codes of a kernel result's warnings, in order."""
def warning_codes(result: (CompileResult | CheckResult)) -> list[str] {
    return [diag.code for diag in result.warnings];
}

"""A kernel result's diagnostics, one per line, for assertion messages."""
def diagnostics_text(result: (CompileResult | CheckResult)) -> str {
    return "\n".join(
        f"{diag.severity} {diag.code} {Path(diag.span.path).name}:{diag.span.line}:{diag.span.col}: {diag.message}"
        for diag in list(result.errors) + list(result.warnings)
    );
}

"""What the kernel made of one fixture: the whole compile result, the
fixture's own unit, and views over its native products. `llvm_ir()` is the
LLVM IR the kernel emitted for the unit; `mir()` is its MIR, and `demoted()`
the functions the decision step refused, by link symbol, with their reasons
(both present when the compile named the "mir" product)."""
obj KernelFixture {
    has path: str,
        result: CompileResult,
        unit: CompiledUnit;

    def llvm_ir -> str {
        return self.unit.native_ir;
    }

    def mir -> str {
        return self.unit.native_mir;
    }

    def demoted -> dict[str, str] {
        return {demotion.symbol: demotion.reason for demotion in self.unit.demoted};
    }

    def iface -> any {
        import from jaclang.compiler.driver.native_iface { NativeIface }
        if not self.unit.native_iface {
            return None;
        }
        return NativeIface.from_bytes(self.unit.native_iface.encode("utf-8"));
    }

    def symbol(name: str) -> str {
        return unit_symbol(self, name);
    }

    def is_demoted(name: str) -> bool {
        return self.symbol(name) in self.demoted();
    }

    def reason(name: str) -> str {
        found = self.demoted().get(self.symbol(name));
        assert found is not None , f"{name} was not demoted in {Path(self.path).name}: {self.demoted()}";
        return found;
    }
}

"""Compile a native fixture through the kernel and return what it made.

Compile errors fail the calling test with the kernel's diagnostics. The
default options force the fixture into the native codespace (see
`native_force_opts`)."""
def compile_native_unit(
    fixture: str,
    fixture_dir: str = "",
    options: (CompileOptions | None) = None,
    products: (list[str] | None) = None,
    sources: (dict[str, str] | None) = None
) -> KernelFixture {
    path = str(Path(fixture_path(fixture, fixture_dir)).resolve());
    result = kernel_compile_file(
        path,
        options if options is not None else native_force_opts(),
        products if products is not None else ["bytecode", "mir"],
        sources
    );
    assert result.ok() , f"Compilation errors in {fixture}:\n{diagnostics_text(result)}";
    return KernelFixture(path=path, result=result, unit=result.unit(path));
}

"""Hand the native units of a kernel result to `prog`'s native unit registry,
dependencies first, exactly as the compile entry adopts them for `jac run`."""
def adopt_native_units(prog: any, result: CompileResult, options: CompileOptions) {
    import from jaclang.compiler.driver.compiler { native_first }
    import from jaclang.compiler.driver.jir { SEC_CTDEPS }
    compiler = prog._get_compiler();
    for unit in native_first(result.units) {
        if unit.native_ir {
            compiler._adopt_native_unit(
                unit, prog, options, unit.sections.get(SEC_CTDEPS, b"")
            );
        }
    }
}

"""Compile a .jac fixture into the native codespace through the kernel and
JIT it in this process; return (engine, fixture).

`fixture_dir` defaults to the native pass fixtures directory, which is where
all but one caller looks; pass it explicitly for a fixture that lives
elsewhere. `options` defaults to `native_force_opts()`; `sources` overlays
unsaved text by path. The fixture carries the unit's MIR and demoted set, so
a JIT test can also assert a lowering decision. The engine is NOT cached across calls -- a JIT engine owns the
module's mutable globals, so handing the same one to two tests would let the
first test's writes reach the second. Tests that want a fixture compiled once
should assert against it once, in a single test.
"""
def compile_native(
    fixture: str,
    fixture_dir: str = "",
    options: (CompileOptions | None) = None,
    sources: (dict[str, str] | None) = None
) -> tuple[ExecutionEngine, KernelFixture] {
    import json;
    import from jaclang.compiler.driver.program { JacProgram }
    options = options if options is not None else native_force_opts();
    fx = compile_native_unit(
        fixture, fixture_dir, options, ["bytecode", "mir"], sources
    );
    prog = JacProgram();
    prog.options = options;
    adopt_native_units(prog, fx.result, options);
    prog._get_compiler()._load_native_from_cache(
        fx.path, prog, json.loads(fx.unit.interop) if fx.unit.interop else None
    );
    carrier = prog.hub.artifacts.get(fx.path);
    eng = carrier.native_engine if carrier is not None else None;
    assert eng is not None , f"No JIT engine produced for {fixture}";
    remember_native_unit(eng, fx);
    return (eng, fx);
}

"""The whole-program LLVM IR of `fixture` linked for `triple`: its unit
bitcode merged with the link glue that defines `jac_entry`, the way an
executable's object is assembled before the platform linker sees it. Tests
that hand a single relocatable object to a linker start from this text."""
def program_ir(fixture: str, triple: str, static_musl: bool = False) -> str {
    import from jaclang.compiler.driver.program { JacProgram }
    import from jaclang.compiler.driver.compile_options {
        CompileOptions,
        NATIVE_LINK_MODE_BITCODE,
        push_native_target,
        pop_native_target
    }
    import from jaclang.compiler.backends.native.link_plan {
        ArtifactKind,
        build_link_plan,
        whole_program_module
    }
    prev = push_native_target(triple);
    try {
        opts = CompileOptions(
            aot_mode=True,
            native_link_mode=NATIVE_LINK_MODE_BITCODE,
            native_target=triple
        );
        fx = compile_native_unit(fixture, "", opts, ["mir"]);
        prog = JacProgram();
        prog.options = opts;
        adopt_native_units(prog, fx.result, opts);
        plan = build_link_plan(
            prog, [fx.path], options=opts, mode=NATIVE_LINK_MODE_BITCODE
        );
        tl = triple.lower();
        platform = "elf";
        if "darwin" in tl or "apple" in tl {
            platform = "macho";
        } elif "windows" in tl or "msvc" in tl or "mingw" in tl {
            platform = "pe";
        } elif "wasm" in tl {
            platform = "wasm";
        }
        spec = plan.glue_spec(ArtifactKind.EXECUTABLE, platform, static_musl);
        (merged, _exports) = whole_program_module(plan, spec);
        return str(merged);
    } finally {
        pop_native_target(prev);
    }
}

"""Pin the compiled fixture's unit path and native interface on its engine,
so `native_address` can map a Jac-level name to the unit's link symbol."""
def remember_native_unit(eng: any, fx: KernelFixture) {
    setattr(eng, "_jac_unit_path", fx.path);
    setattr(eng, "_jac_native_iface", fx.iface());
}

"""The link symbol of a Jac-level name in the engine's root unit.

Every external symbol that is not `:pub` is module-qualified
(`<unit prefix>.<name>`, methods `<prefix>.Class.method`); `:pub` symbols,
the glue's `jac_entry` and the runtime's `__jac_*` / `__rc_*` / `jac_*`
helpers keep bare names. Already qualified symbols retain their spelling.
A name the interface does not list resolves to the root-qualified form;
address lookup never retries an unrelated bare symbol.
"""
def native_symbol(eng: any, name: str) -> str {
    path = getattr(eng, "_jac_unit_path", "") or "";
    if name == "__jac_glob_init" and path {
        import from jaclang.compiler.frontend.codeinfo { native_glob_init_name }
        return native_glob_init_name(path);
    }
    if name == "jac_entry" {
        return name;
    }
    interfaces = list(eng?._jac_unit_ifaces or []);
    iface = eng?._jac_native_iface;
    if iface is not None {
        interfaces.insert(0, iface);
    }
    for unit_iface in interfaces {
        found = iface_symbol(unit_iface, name);
        if found is not None {
            return found;
        }
        if unit_iface.prefix and name.startswith(unit_iface.prefix + ".") {
            return name;
        }
    }
    if name.startswith(("__jac_", "__rc_", "jac_", "__osp", "__mt_")) {
        return name;
    }
    if not path {
        return name;
    }
    import from jaclang.compiler.frontend.codeinfo {
        native_symbol_name,
        native_unit_prefix
    }
    return native_symbol_name(native_unit_prefix(path), name);
}

"""The link symbol a compiled fixture gives a Jac-level name: the unit's
interface record first, the mangling rule second. Tests that read a demoted
set or an emitted symbol build their key from this."""
def unit_symbol(fx: KernelFixture, name: str) -> str {
    found = iface_symbol(fx.iface(), name);
    if found is not None {
        return found;
    }
    path = fx.path;
    if not path {
        return name;
    }
    import from jaclang.compiler.frontend.codeinfo {
        native_symbol_name,
        native_unit_prefix
    }
    return native_symbol_name(native_unit_prefix(path), name);
}

"""Whether `line` names the function `name` under either spelling: bare
(`@name(` / `@"name"(`, a `:pub` or runtime symbol) or module-qualified
(`@"<prefix>.name"(`)."""
def names_function(line: str, name: str) -> bool {
    return (
        ('@"' + name + '"(') in line
        or ("@" + name + "(") in line
        or ("." + name + '"(') in line
    );
}

"""Whether `text` defines or declares the global `name` under either spelling."""
def names_global(text: str, name: str) -> bool {
    return ('@"' + name + '"') in text
        or ("@" + name + " ") in text
        or ("." + name + '"') in text;
}

"""Resolve exactly the symbol selected by the native interface or mangling rule."""
def native_address(eng: any, name: str) -> int {
    symbol = native_symbol(eng, name);
    return eng.get_function_address(symbol);
}

"""Compile a fixture through the kernel without a JIT engine and return what
it made, for tests that read the unit's MIR, its demoted set or its emitted
IR."""
def compile_native_ir(
    fixture: str, fixture_dir: str = "", options: (CompileOptions | None) = None
) -> KernelFixture {
    options = options or native_force_opts();
    options.skip_native_engine = True;
    options.no_ir_cache = True;
    return compile_native_unit(fixture, fixture_dir, options, ["mir"]);
}

"""The decision step's verdict on a fixture: its MIR and demoted set, with no
bytecode and no JIT."""
def compile_mir(
    fixture: str, fixture_dir: str = "", options: (CompileOptions | None) = None
) -> KernelFixture {
    return compile_native_ir(fixture, fixture_dir, options);
}

"""Compile a fixture expecting the kernel to refuse it; return the result so
the caller can pin the diagnostic (E5092 names the refused construct)."""
def compile_native_refused(
    fixture: str, fixture_dir: str = "", options: (CompileOptions | None) = None
) -> CompileResult {
    import from jaclang.compiler.driver.compile_options { CompileOptions }
    opts = options or CompileOptions(force_codespace="native", native_required=True);
    opts.skip_native_engine = True;
    result = kernel_compile_file(
        str(Path(fixture_path(fixture, fixture_dir)).resolve()), opts, ["mir"]
    );
    assert not result.ok() , f"{fixture} compiled although native was required";
    return result;
}

"""`jac check --native-coverage` on one file: the decision step's coverage
row for every module the check reached."""
def native_coverage_rows(path: str) -> dict[str, any] {
    result = kernel_check_file(path, native_coverage=True);
    return {row.path: row for row in result.coverage};
}

"""Get a ctypes-callable function from a JIT engine."""
def get_func(eng: any, name: str, restype: type | None, *argtypes: type) -> any {
    addr = native_address(eng, name);
    assert addr != 0 , f"Function '{name}' not found in JIT engine";
    functype = ctypes.CFUNCTYPE(restype, *argtypes);
    return functype(addr);
}

"""Return True if a kernel result, or a program that adopted one, carries at
least one error with the given code."""
def has_error_code(target: any, code: str) -> bool {
    if hasattr(target, "errors") {
        return code in error_codes(target);
    }
    for alrt in target.errors_had {
        if alrt.code is not None and alrt.code.code == code {
            return True;
        }
    }
    return False;
}

"""Return True if a kernel result carries at least one warning with the code."""
def has_warning_code(result: (CompileResult | CheckResult), code: str) -> bool {
    return code in warning_codes(result);
}

"""Every test case compiled into the loaded kernel."""
def kernel_cases -> list[KernelTestCase] {
    import from jaclang.project.kernel_call { kernel_tests }
    return kernel_tests();
}

"""Run one kernel test case inside the kernel; fail with its message."""
def run_kernel_case(case: KernelTestCase) {
    import tempfile;
    import from jaclang.project.kernel_call { call_kernel_tests }
    with tempfile.TemporaryDirectory(prefix="jac-kernel-case-") as scratch {
        outcomes = call_kernel_tests(case.suite, scratch, [case.name]);
    }
    assert len(outcomes) == 1 , f"the kernel ran {len(outcomes)} cases for {case.name}";
    outcome = outcomes[0];
    if not outcome.passed {
        raise AssertionError(f"{case.suite}: {case.name}: {outcome.message}");
    }
}

"""Memory profiles a native test can build under.

`nogc` is the headerless endpoint (zero-RC enforcement, no runtime, the
RC-free IR scan on); `rc` and `managed` are the reference-counted runtimes
without and with the cycle collector. The CLI spelling of each profile lives
here and nowhere else in the test tree, so a flag rename is a one-line
change.
"""
glob NATIVE_MEMORY_PROFILES: list[str] = ["nogc", "rc", "managed"];

def native_memory_flags(memory: str) -> list[str] {
    if memory in ("nogc", "rc", "managed") {
        return ["--memory", memory];
    }
    raise ValueError(f"unknown native memory profile: {memory}");
}

"""Build `src` into the native binary `out_bin` through the CLI.

Runs the compiler in a subprocess exactly as a developer would, under the
given memory profile, and asserts the build succeeded. Returns the build's
combined stdout/stderr so a caller can grep a build-time line (rc-stats,
assert-no-rc) without a second compile.
"""
def native_build(
    src: str,
    out_bin: str,
    memory: str = "managed",
    extra: list[str] | None = None,
    timeout: int = 300
) -> str {
    import os;
    import subprocess;
    import sys;
    assert os.path.exists(src) , f"fixture missing: {src}";
    cmd = (
        jac_command("build", src, "--native")
        + native_memory_flags(memory)
        + list(extra or [])
        + ["-o", out_bin]
    );
    comp = subprocess.run(cmd, capture_output=True, text=True, timeout=timeout);
    assert comp.returncode == 0 , (
        f"native build ({memory}) failed for {os.path.basename(src)}:"
        f" exit={comp.returncode}\n"
        f"stdout: {comp.stdout[-800:] if comp.stdout else '(empty)'}\n"
        f"stderr: {comp.stderr[-800:] if comp.stderr else '(empty)'}"
    );
    assert os.path.exists(out_bin) , f"binary not produced at {out_bin}";
    return (comp.stdout or "") + (comp.stderr or "");
}

"""Build `src` natively expecting the compile to fail; return combined output.

The counterpart to `native_build` for refusal-path tests: asserts the build
did not succeed and hands back stdout+stderr so the caller can pin the
diagnostic naming the offending construct.
"""
def native_build_fails(src: str, timeout: int = 900) -> str {
    import os;
    import subprocess;
    import tempfile;
    assert os.path.exists(src) , f"fixture missing: {src}";
    out_bin = os.path.join(tempfile.mkdtemp(), "nope.bin");
    comp = subprocess.run(
        jac_command("build", "--native", src, "-o", out_bin),
        capture_output=True,
        text=True,
        timeout=timeout
    );
    combined = (comp.stdout or "") + (comp.stderr or "");
    assert comp.returncode != 0 , (
        f"expected a refused native build for {os.path.basename(src)},"
        f" but it compiled cleanly: {combined[-600:]}"
    );
    return combined;
}

"""Run a built native binary and return its stdout; assert a clean exit."""
def native_run(
    out_bin: str,
    args: list[str] | None = None,
    timeout: int = 120,
    env: dict[str, str] | None = None
) -> str {
    import os;
    import subprocess;
    run_env: dict[str, str] = dict(os.environ);
    if env {
        run_env.update(env);
    }
    proc = subprocess.run(
        [out_bin] + list(args or []),
        capture_output=True,
        text=True,
        timeout=timeout,
        env=run_env
    );
    assert proc.returncode == 0 , (
        f"{os.path.basename(out_bin)} exited {proc.returncode}"
        f" (a segfault or abort here is a codegen regression)\n"
        f"stdout: {proc.stdout[-400:] if proc.stdout else '(empty)'}\n"
        f"stderr: {proc.stderr[-400:] if proc.stderr else '(empty)'}"
    );
    return proc.stdout;
}

"""Run `src` directly on the Python bytecode backend and return its stdout."""
def python_run(src: str, args: list[str] | None = None, timeout: int = 120) -> str {
    import os;
    import subprocess;
    import sys;
    proc = subprocess.run(
        jac_command("run", "--backend", "python", src) + list(args or []),
        capture_output=True,
        text=True,
        timeout=timeout
    );
    assert proc.returncode == 0 , (
        f"Python backend failed for {os.path.basename(src)}: exit={proc.returncode}\n"
        f"stderr: {proc.stderr[-800:] if proc.stderr else '(empty)'}"
    );
    return proc.stdout;
}

"""Build and run `src` under every memory profile and on the Python backend.

Returns {profile: stdout}. The identity contract of the ownership design is
that these agree byte for byte: annotations erase, and a headerless build
must behave exactly like the managed ones. A caller asserts that agreement
with `assert_native_identity`.
"""
def native_outputs(
    src: str, args: list[str] | None = None, profiles: list[str] | None = None
) -> dict[str, str] {
    import os;
    import tempfile;
    outs: dict[str, str] = {};
    with tempfile.TemporaryDirectory() as tmp {
        for memory in (profiles or NATIVE_MEMORY_PROFILES) {
            out_bin = os.path.join(tmp, f"{Path(src).stem}.{memory}");
            native_build(src, out_bin, memory=memory);
            outs[memory] = native_run(out_bin, args);
        }
    }
    outs["python"] = python_run(src, args);
    return outs;
}

"""Assert every backend produced the same stdout for `src`; return that stdout."""
def assert_native_identity(
    src: str, args: list[str] | None = None, profiles: list[str] | None = None
) -> str {
    outs = native_outputs(src, args, profiles);
    reference = outs["python"];
    for (memory, out) in outs.items() {
        assert out == reference , (
            f"{Path(src).name}: {memory} output differs from the Python backend\n"
            f"--- {memory} ---\n{out}\n--- python ---\n{reference}"
        );
    }
    return reference;
}

"""Run `src` on the sv lane (CPython is the oracle); return (stdout, stderr).

On this lane `import <mod>` binds CPython's own stdlib module, so sv output is
the reference every bundled-stdlib congruence probe compares against. Bare
`jac run` is used deliberately: the explicit `--backend python` route installs
jac's own logging config (INFO level, a `LEVEL - msg` format), which changes
what a probe that touches `logging` observes.
"""
def sv_run(src: str, timeout: int = 900) -> tuple[(str, str)] {
    import subprocess;
    proc = subprocess.run(
        jac_command("run", src), capture_output=True, text=True, timeout=timeout
    );
    assert proc.returncode == 0 , f"sv run failed for {src}: {proc.stderr[-800:]
        if proc.stderr
        else '(empty)'}";
    return (proc.stdout, proc.stderr);
}

"""Compile `src` to a native binary, run it, and return (stdout, stderr).

On this lane `import <mod>` binds the bundled na_stdlib module, so comparing
na output to `sv_run` output pins the sv<->na congruence contract.
"""
def na_run(src: str, timeout: int = 900) -> tuple[(str, str)] {
    import os;
    import subprocess;
    import tempfile;
    with tempfile.TemporaryDirectory() as tmp {
        out_bin = os.path.join(tmp, "probe.bin");
        native_build(src, out_bin, timeout=timeout);
        proc = subprocess.run([out_bin], capture_output=True, text=True, timeout=120);
        assert proc.returncode == 0 , f"binary failed for {src}: {proc.stderr[-400:]
            if proc.stderr
            else '(empty)'}";
        return (proc.stdout, proc.stderr);
    }
}

"""Assert two captured outputs agree non-blank line for non-blank line."""
def same_lines(sv_text: str, na_text: str, what: str) {
    sv = [
        _l
        for _l in sv_text.split("\n")
        if _l.strip()
    ];
    na = [
        _l
        for _l in na_text.split("\n")
        if _l.strip()
    ];
    assert sv , f"{what}: sv pathway produced no output";
    assert len(sv) == len(na) , f"{what} line count: sv {len(sv)} vs na {len(na)}";
    for idx in range(len(sv)) {
        assert sv[idx] == na[idx] , f"{what} line {idx}: sv {sv[idx]!r} vs na {na[
            idx
        ]!r}";
    }
}

"""A module's source together with its impl annexes, the unit the compiler
weaves, so a source-contract check reads a body wherever it lives."""
def unit_source(path: Path | str) -> str {
    import from jaclang.compiler.driver.bccache { discover_annex_files }

    files = [str(path)] + discover_annex_files(str(path), ".impl.jac");
    return "\n".join(Path(f).read_text() for f in files);
}
