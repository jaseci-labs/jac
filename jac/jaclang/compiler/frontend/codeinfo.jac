import hashlib;
import from collections.abc { Sequence }
import from contextvars { ContextVar }
import from dataclasses { field }
import from jaclang.compiler.frontend.constant {
    NATIVE_ERASED_ANNOTATIONS,
    NATIVE_ERASED_TYPE_MARKERS,
    TYPE_PARAM_CONSTRUCTORS
}
import from jaclang.compiler.frontend.srcloc { CodeLocInfo }
import type from jaclang.compiler.backends.es.estree { IndexInfo, SliceInfo }
import type from jaclang.compiler.backends.es.estree { Node as EsNode }
import type from jaclang.compiler.frontend.unitree { CommentToken }
import type from jaclang.compiler.tools.doc_ir { Doc }
import type from jaclang.compiler.frontend.unitree { Source, Token }
import type from jaclang.runtime.osp_model { OspModel }
import type from jaclang.compiler.backends.native.llvm.binding {
    ModuleRef,
    ExecutionEngine
}
import type from jaclang.compiler.driver.native_iface { NativeIface }

obj ClientManifest {
    has exports: list = [],
        globals: list = [],
        params: dict[(str, list)] = field(default_factory=`dict),
        globals_values: dict[(str, any)] = field(default_factory=`dict),
        has_client: bool = False,
        imports: dict[(str, str)] = field(default_factory=`dict),
        endpoint_effects: dict[(str, dict)] = field(default_factory=`dict),
        tests: list[dict[(str, str)]] = field(default_factory=`list),
        server_imports: list[str] = field(default_factory=`list),
        page_export: (str | None) = None,
        layout_export: (str | None) = None;
}

obj ClientArtifact {
    has js: str,
        manifest: ClientManifest,
        native_import_sources: list[str] = field(default_factory=`list),
        source_map: list[tuple[int, int, int, int, str]] = field(default_factory=`list),
        dep_digests: dict[str, str] = field(default_factory=`dict),
        framework: str = "";

    def to_bytes -> bytes;
    static def from_bytes(raw: bytes) -> (ClientArtifact | None);
}

enum InteropContext { SERVER = 'server', NATIVE = 'native', CLIENT = 'client' }

glob HDR_ALLOC_ID_OFF: int = -32,
     HDR_TAG_OFF: int = -24,
     HDR_RC_OFF: int = -16,
     HDR_DTOR_OFF: int = -8,
     HDR_TOTAL: int = 32;

glob HDR_MAGIC: int = 44061,
     HDR_MAGIC_SHIFT_BASE: int = 44061 * 4294967296,
     RC_SENTINEL: int = 0x7FFFFFFFFFFFFFFF;

glob STR_LEN_TAG_BIT: int = 1,
     STR_LEN_TAG_SHIFT: int = 1;

glob JACSTR_DESC_FIELDS: dict[(str, tuple)] = {
         'jacstr3': ('root', 'data', 'len'),
         'jacstr2': ('data', 'len')
     };

def str_len_tag(length: int) -> int {
    return (length << STR_LEN_TAG_SHIFT) | STR_LEN_TAG_BIT;
}

obj NativeFieldInfo {
    has name: str,
        llvm_type: str,
        index: int,
        enum_type: (str | None) = None,
        is_func_ptr: bool = False,
        func_param_types: (list[str] | None) = None,
        func_ret_type: (str | None) = None,
        elem_keys: (list | None) = None,
        foreign: bool = False;
}

obj NativeStructLayout {
    has name: str,
        fields: list[NativeFieldInfo] = field(default_factory=`list),
        has_vtable: bool = False,
        accessors: dict[(str, dict[(str, str)])] = field(default_factory=`dict);
}

obj NativeEnumLayout {
    has name: str,
        is_string_valued: bool = False,
        members: list = field(default_factory=`list);
}

obj NativeTupleLayout {
    has key: str,
        element_types: list[str] = field(default_factory=`list),
        element_struct_hints: list = field(default_factory=`list);
}

obj NativeFuncLayout {
    has name: str,
        param_types: list[str] = field(default_factory=`list),
        param_names: list[str] = field(default_factory=`list),
        ret_type: str = "i64",
        ret_struct_name: (str | None) = None,
        ret_tuple_layout: (NativeTupleLayout | None) = None,
        ret_enum_type: (str | None) = None,
        ret_elem_keys: (list | None) = None;
}

obj NativeTestLayout {
    has name: str,
        symbol: str,
        description: str = "",
        line: int = 0;
}

def native_safe_sym(src: str) -> str {
    safe = '';
    for ch in src {
        if ((ch >= 'a') and (ch <= 'z'))
            or ((ch >= 'A') and (ch <= 'Z'))
            or ((ch >= '0') and (ch <= '9'))
            or (ch == '_') {
            safe += ch;
        } else {
            safe += '_';
        }
    }
    return f"{safe}_{hashlib.sha1(src.encode()).hexdigest()[:8]}";
}

def module_dotted_name(mod_path: str, mod_name: str = "") -> str {
    import os;
    path = mod_path.replace("\\", "/");
    if not path {
        return mod_name;
    }
    idx = path.rfind("/jaclang/");
    stem = path[idx + 1:] if idx >= 0 else os.path.basename(path);
    for ext in (".impl.jac", ".test.jac", ".jac", ".py") {
        if stem.endswith(ext) {
            stem = stem[:-len(ext)];
            break;
        }
    }
    if stem.endswith("/__init__") {
        stem = stem[:-len("/__init__")];
    }
    return stem.replace("/", ".");
}

def native_module_key(path: str) -> str {
    import os;
    rp = os.path.realpath(path);
    base = os.path.basename(rp);
    dot = base.rfind(".");
    stem = base[0:dot] if dot > 0 else base;
    return f"{stem}:{hashlib.sha1(rp.encode()).hexdigest()[:12]}";
}

"""The symbol prefix of one native unit: the safe form of its module key.

Every external symbol a unit defines that is not `:pub` lives under this
prefix, so two units defining the same Jac name never collide at link time.
The prefix is a pure function of the unit's resolved path, which is what lets
a consumer name a dependency's symbols without the dependency's object.
"""
def native_unit_prefix(path: str) -> str {
    return native_safe_sym(native_module_key(path));
}

"""The module-qualified external symbol for `name` defined by the unit with
`prefix`. Methods pass `Class.method`; static fields pass `Class.field`."""
def native_symbol_name(prefix: str, name: str) -> str {
    return f"{prefix}.{name}";
}

"""The unit's module-level initializer. Idempotent: every unit's initializer
guards itself, so the link plan may call it from any number of roots."""
def native_glob_init_name(path: str) -> str {
    return f"__jac_glob_init_{native_unit_prefix(path)}";
}

"""The unit's `with entry` body. The synthesized `jac_entry` of an artifact
calls the root unit's entry after every unit's initializer has run."""
def native_entry_name(path: str) -> str {
    return f"__jac_entry_{native_unit_prefix(path)}";
}

"""The unit's runtime-mode probe (`JAC_NO_GC`, `JAC_GC_CYCLES`), called by the
synthesized `jac_entry` before any initializer."""
def native_runtime_probe_name(path: str) -> str {
    return f"__jac_rt_probe_{native_unit_prefix(path)}";
}

def native_test_symbol(name: str, line: int, prefix: str = "") -> str {
    bare = f"__jac_test_{name}_{line}";
    return native_symbol_name(prefix, bare) if prefix else bare;
}

glob JAC_ENTRY_SYMBOL: str = "jac_entry",
     JAC_SHARED_INIT_SYMBOL: str = "__jac_shared_init";

"""Arm an execution engine with the ordered initializers of a link plan.

`init_symbols` is the plan's topological initializer order (dependencies
first, the root last); `jac_entry` runs them itself, so handing out its
address must not run them a second time.
"""
def install_native_static_init(engine: any, init_symbols: list[str]) -> None {
    if engine is None {
        return;
    }
    engine.static_init_symbols = list(init_symbols);
    engine.static_init_chained = {JAC_ENTRY_SYMBOL};
}

"""Toolchain units every native artifact may pull in by dependency edge:
the OSP runtime, the format kernel and the region arena. They are ordinary
native units; the IR generator records an edge to whichever one a module
uses, and the link plan pulls it like any other dependency."""
glob KERNEL_UNIT_REL: tuple[str, ...] = (
         "runtime/osp_kernel.jac",
         "runtime/osp_graph.jac",
         "runtime/region_native.jac",
         "compiler/backends/fmt_kernel.jac"
     ),
     OSP_KERNEL_REL: str = "runtime/osp_kernel.jac",
     OSP_GRAPH_REL: str = "runtime/osp_graph.jac",
     REGION_KERNEL_REL: str = "runtime/region_native.jac",
     FMT_KERNEL_REL: str = "compiler/backends/fmt_kernel.jac";

def jaclang_pkg_root -> str {
    import os;
    import jaclang;
    return os.path.dirname(os.path.abspath(str(jaclang.__file__)));
}

def kernel_unit_path(rel: str) -> str {
    import os;
    return os.path.join(jaclang_pkg_root(), rel.replace("/", os.sep));
}

def kernel_unit_paths -> list[str] {
    return [kernel_unit_path(rel) for rel in KERNEL_UNIT_REL];
}

def is_kernel_unit_path(path: str) -> bool {
    import os;
    if not path {
        return False;
    }
    rp = os.path.realpath(path);
    for rel in KERNEL_UNIT_REL {
        if rp == os.path.realpath(kernel_unit_path(rel)) {
            return True;
        }
    }
    return False;
}

glob NATIVE_SUPPORTED_STDLIB: set[str] = {
         "sys",
         "math",
         "time",
         "os",
         "random",
         "struct",
         "enum",
         "collections.abc"
     },
     _effective_codespace_ctx: ContextVar[str] = ContextVar(
         "jac_effective_default_codespace"
     ),
     _closure_cap_ctx: ContextVar[int] = ContextVar("jac_native_closure_cap"),
     _native_unit_ctx: ContextVar[bool] = ContextVar("jac_native_unit_compile");

glob NATIVE_ERASED_ABC_BASES: frozenset = frozenset({"ABC"});

glob NATIVE_ERASED_BASES: frozenset = NATIVE_ERASED_ABC_BASES;

glob NATIVE_ERASED_IDENTITY_CALLS: frozenset = frozenset({"cast"});

glob NATIVE_ERASED_FIELD_MARKERS: frozenset = frozenset({"field"});

glob NATIVE_ERASED_IMPORTS: dict[str, frozenset] = {
         "abc": NATIVE_ERASED_ABC_BASES,
         "dataclasses": NATIVE_ERASED_FIELD_MARKERS,
         "typing": TYPE_PARAM_CONSTRUCTORS
             | NATIVE_ERASED_IDENTITY_CALLS
             | NATIVE_ERASED_TYPE_MARKERS
             | NATIVE_ERASED_ANNOTATIONS
     };

def native_erased_import_names(module_name: str, names: list[str]) -> bool {
    allowed = NATIVE_ERASED_IMPORTS.get(module_name.lstrip('.'));
    if allowed is None or not names {
        return False;
    }
    for n in names {
        if n not in allowed {
            return False;
        }
    }
    return True;
}

def set_effective_default_codespace(value: str) {
    _effective_codespace_ctx.set(value);
}

def get_effective_default_codespace_override -> str {
    return _effective_codespace_ctx.get('');
}

def effective_default_codespace -> str {
    cur = _effective_codespace_ctx.get('');
    if cur {
        return cur;
    }
    try {
        import from jaclang.project.config { get_config, BuildConfig }
        cfg = get_config();
        if cfg is not None {
            return cfg.build.default_codespace;
        }
        return BuildConfig().default_codespace;
    } except Exception {
        return "server";
    }
}

"""Whether the enclosing compile was requested with `CompileOptions.native_unit`.

Set by the driver for the span of one compile, exactly as the effective
default codespace is; it is the option's value, reachable from the resolver
sites that have no options handle, and never a flag a caller toggles.
"""
def set_native_unit_compile(value: bool) -> any {
    return _native_unit_ctx.set(value);
}

def reset_native_unit_compile(token: any) {
    _native_unit_ctx.reset(token);
}

def native_unit_compile_active -> bool {
    return _native_unit_ctx.get(False);
}

def set_native_closure_cap(value: int) {
    _closure_cap_ctx.set(value);
}

def get_native_closure_cap_override -> int {
    return _closure_cap_ctx.get(0);
}

def effective_native_closure_cap -> int {
    cur = _closure_cap_ctx.get(0);
    if cur > 0 {
        return cur;
    }
    try {
        import from jaclang.project.config { get_config, BuildConfig }
        cfg = get_config();
        if cfg is not None {
            return cfg.build.native_closure_cap;
        }
        return BuildConfig().native_closure_cap;
    } except Exception {
        return 256;
    }
}

def native_stdlib_root -> (str | None) {
    import os;
    import jaclang;
    if not jaclang?.__file__ {
        return None;
    }
    stdlib_dir = os.path.join(
        os.path.dirname(jaclang.__file__), "runtime", "na_stdlib"
    );
    return stdlib_dir if os.path.isdir(stdlib_dir) else None;
}

def is_native_by_location(file_path: str) -> bool {
    import os;
    import jaclang;
    if not file_path or not jaclang?.__file__ {
        return False;
    }
    ap = os.path.abspath(file_path);
    pkg = os.path.dirname(os.path.abspath(str(jaclang.__file__)));
    return ap.startswith(os.path.join(pkg, "runtime", "na_stdlib") + os.sep);
}

def bundled_stdlib_module_of(file_path: str) -> (str | None) {
    import os;
    import jaclang;
    if not file_path or not jaclang?.__file__ {
        return None;
    }
    ap = os.path.abspath(file_path);
    pkg = os.path.dirname(os.path.abspath(str(jaclang.__file__)));
    native_root = os.path.join(pkg, "runtime", "na_stdlib") + os.sep;
    stub_root = os.path.join(pkg, "vendor", "typeshed", "stdlib") + os.sep;
    if ap.startswith(native_root) and ap.endswith(".jac") {
        rel = ap[len(native_root):-len(".jac")];
        parts = rel.split(os.sep);

        parts[-1] = parts[-1].split(".")[0];
        return ".".join(parts);
    }
    if ap.startswith(stub_root) and ap.endswith(".pyi") {
        rel = ap[len(stub_root):-len(".pyi")];
        parts = rel.split(os.sep);
        if parts[-1] == "__init__" {
            parts = parts[:-1];
        }
        return ".".join(parts) if parts else None;
    }
    return None;
}

glob CLIENT_RUNTIME_SOURCE_PATHS: list[str] = [
         "client/client_runtime.jac",
         "client/client_runtime_core.jac",
         "client/solid_runtime.jac",
         "client/pwa_runtime.jac",
         "client/wasm_host.jac",
         "client/client_mobui.jac",
         "client/client_react_core.jac",
         "client/client_runtime_native.jac",
         "client/targets/desktop/plugin/desktop_api.jac"
     ];


def is_client_by_location(file_path: str) -> bool {
    import os;
    import jaclang;
    if not file_path or not jaclang?.__file__ {
        return False;
    }
    ap = os.path.abspath(file_path);
    pkg = os.path.dirname(os.path.abspath(str(jaclang.__file__)));
    for rel in CLIENT_RUNTIME_SOURCE_PATHS {
        if ap == os.path.join(pkg, rel.replace("/", os.sep)) {
            return True;
        }
    }
    return False;
}

def is_bundled_native_module(module_name: str) -> bool {
    import os;
    stdlib_dir = native_stdlib_root();
    if stdlib_dir is None or not module_name {
        return False;
    }
    path_name = module_name.lstrip('.').replace('.', os.sep);
    return _native_variant_path(os.path.join(stdlib_dir, path_name)) is not None;
}

def native_target_os -> str {
    import os;
    import sys;
    _t = os.environ.get("JAC_NATIVE_TARGET", "");
    if _t {
        if ("darwin" in _t) or ("apple" in _t) {
            return "darwin";
        }
        if ("windows" in _t) or ("msvc" in _t) {
            return "windows";
        }
        return "linux";
    }
    _s = sys.platform;
    if _s == "darwin" {
        return "darwin";
    }
    if _s == "win32" {
        return "windows";
    }
    return "linux";
}

def _native_variant_path(base_no_ext: str) -> (str | None) {
    import os;
    _osv = os.path.join(f"{base_no_ext}.{native_target_os()}.jac");
    if os.path.exists(_osv) {
        return _osv;
    }
    _plain = f"{base_no_ext}.jac";
    if os.path.exists(_plain) {
        return _plain;
    }
    return None;
}

def _inferred_native_path(candidate: (str | None)) -> (str | None) {
    if candidate is None {
        return None;
    }
    import from jaclang.compiler.placement.placement_solver { native_default_path_ok }
    return candidate if native_default_path_ok(candidate) else None;
}

def resolve_native_module(
    module_name: str, base_dir: str, allow_inferred: bool = True
) -> tuple[(str | None, str | None)] {
    import os;
    clean = module_name.lstrip('.');
    path_name = clean.replace('.', os.sep);

    if allow_inferred {
        local = _inferred_native_path(
            _native_variant_path(os.path.join(base_dir, clean))
        );
        if local is not None {
            return (f"{clean}.jac", local);
        }
        if path_name != clean {
            search = os.path.abspath(base_dir);
            while True {
                cand = _inferred_native_path(
                    _native_variant_path(os.path.join(search, path_name))
                );
                if cand is not None {
                    rel = str(os.path.relpath(cand, os.path.abspath(base_dir)));
                    return (rel, cand);
                }
                parent = os.path.dirname(search);
                if parent == search {
                    break;
                }
                search = parent;
            }
        }
    }

    if clean.startswith('jaclang.') {
        import from jaclang.compiler.native_scope { in_native_scope_path }
        if native_unit_compile_active() {
            _parts = clean.split('.')[1:];
            _cand = os.path.join(jaclang_pkg_root(), *_parts) + '.jac';
            if in_native_scope_path(_cand) and os.path.isfile(_cand) {
                return (path_name, _cand);
            }
        }
    }

    bundled_root = native_stdlib_root();
    if bundled_root is not None {
        bundled = _native_variant_path(os.path.join(bundled_root, path_name));
        if bundled is not None {
            return (path_name, bundled);
        }
    }
    return (None, None);
}

def native_wasm_stem(path: str) -> str {
    import os;
    stem = os.path.splitext(os.path.basename(path))[0];
    for marker in ('.cl', ) {
        if stem.endswith(marker) {
            stem = stem[0:-len(marker)];
        }
    }
    return stem;
}

glob NATIVE_ABI_VERSION: int = 1;

obj NativeModuleLayout {
    has abi_version: int = NATIVE_ABI_VERSION,
        structs: dict[(str, NativeStructLayout)] = field(default_factory=`dict),
        enums: dict[(str, NativeEnumLayout)] = field(default_factory=`dict),
        functions: dict[(str, NativeFuncLayout)] = field(default_factory=`dict),
        methods: dict[(str, NativeFuncLayout)] = field(default_factory=`dict),
        list_elem_types: dict[(str, str)] = field(default_factory=`dict),
        tuples: dict[(str, NativeTupleLayout)] = field(default_factory=`dict),
        tests: list[NativeTestLayout] = field(default_factory=`list),
        str_headerless: (bool | None) = None;
}

def _tuple_layout_to_dict(t: (NativeTupleLayout | None)) -> (dict | None) {
    if t is None {
        return None;
    }
    return {
        "key": t.key,
        "element_types": list(t.element_types),
        "element_struct_hints": list(t.element_struct_hints)
    };
}

def _func_layout_to_dict(f: NativeFuncLayout) -> dict {
    return {
        "name": f.name,
        "param_types": list(f.param_types),
        "param_names": list(f.param_names),
        "ret_type": f.ret_type,
        "ret_struct_name": f.ret_struct_name,
        "ret_tuple_layout": _tuple_layout_to_dict(f.ret_tuple_layout),
        "ret_enum_type": f.ret_enum_type,
        "ret_elem_keys": (
            list(f.ret_elem_keys) if f.ret_elem_keys is not None else None
        )
    };
}

def native_layout_to_dict(layout: NativeModuleLayout) -> dict {
    return {
        "abi_version": layout.abi_version,
        "structs": {
            name: {
                "name": s.name,
                "has_vtable": s.has_vtable,
                "accessors": {
                    fname: dict(kinds) for (fname, kinds) in s.accessors.items()
                },
                "fields": [
                    {
                        "name": fld.name,
                        "llvm_type": fld.llvm_type,
                        "index": fld.index,
                        "enum_type": fld.enum_type,
                        "is_func_ptr": fld.is_func_ptr,
                        "func_param_types": (
                            list(fld.func_param_types)
                                if fld.func_param_types is not None
                                else None
                        ),
                        "func_ret_type": fld.func_ret_type,
                        "elem_keys": (
                            list(fld.elem_keys) if fld.elem_keys is not None else None
                        ),
                        "foreign": fld.foreign
                    } for fld in s.fields
                ]
            } for (name, s) in layout.structs.items()
        },
        "enums": {
            name: {
                "name": e.name,
                "is_string_valued": e.is_string_valued,
                "members": list(e.members)
            } for (name, e) in layout.enums.items()
        },
        "functions": {
            name: _func_layout_to_dict(f) for (name, f) in layout.functions.items()
        },
        "methods": {
            name: _func_layout_to_dict(f) for (name, f) in layout.methods.items()
        },
        "list_elem_types": dict(layout.list_elem_types),
        "tuples": {key: _tuple_layout_to_dict(t) for (key, t) in layout.tuples.items()},
        "str_headerless": layout.str_headerless
    };
}

def _tuple_layout_from_dict(d: (dict | None)) -> (NativeTupleLayout | None) {
    if not isinstance(d, dict) {
        return None;
    }
    return NativeTupleLayout(
        key=str(d.get("key", "")),
        element_types=[str(x) for x in d.get("element_types", [])],
        element_struct_hints=list(d.get("element_struct_hints") or [])
    );
}

def _func_layout_from_dict(d: dict) -> NativeFuncLayout {
    keys = d.get("ret_elem_keys");
    return NativeFuncLayout(
        name=str(d.get("name", "")),
        param_types=[str(x) for x in d.get("param_types", [])],
        param_names=[str(x) for x in d.get("param_names", [])],
        ret_type=str(d.get("ret_type", "i64")),
        ret_struct_name=d.get("ret_struct_name"),
        ret_tuple_layout=_tuple_layout_from_dict(d.get("ret_tuple_layout")),
        ret_enum_type=d.get("ret_enum_type"),
        ret_elem_keys=list(keys) if keys is not None else None
    );
}

"""The inverse of `native_layout_to_dict`: rehydrate a layout from its JSON
form, as carried inside a unit's native interface record."""
def native_layout_from_dict(d: dict) -> NativeModuleLayout {
    layout = NativeModuleLayout(
        abi_version=int(d.get("abi_version", NATIVE_ABI_VERSION)),
        str_headerless=d.get("str_headerless")
    );
    for (name, sd) in (d.get("structs") or {}).items() {
        fields: list[NativeFieldInfo] = [];
        for fd in sd.get("fields") or [] {
            fpt = fd.get("func_param_types");
            ek = fd.get("elem_keys");
            fields.append(
                NativeFieldInfo(
                    name=str(fd.get("name", "")),
                    llvm_type=str(fd.get("llvm_type", "i64")),
                    index=int(fd.get("index", 0)),
                    enum_type=fd.get("enum_type"),
                    is_func_ptr=bool(fd.get("is_func_ptr", False)),
                    func_param_types=list(fpt) if fpt is not None else None,
                    func_ret_type=fd.get("func_ret_type"),
                    elem_keys=list(ek) if ek is not None else None,
                    foreign=bool(fd.get("foreign", False))
                )
            );
        }
        layout.structs[str(name)] = NativeStructLayout(
            name=str(sd.get("name", name)),
            fields=fields,
            has_vtable=bool(sd.get("has_vtable", False)),
            accessors={
                str(fn): {str(k): str(v) for (k, v) in kinds.items()}
                for (fn, kinds) in (sd.get("accessors") or {}).items()
            }
        );
    }
    for (name, ed) in (d.get("enums") or {}).items() {
        layout.enums[str(name)] = NativeEnumLayout(
            name=str(ed.get("name", name)),
            is_string_valued=bool(ed.get("is_string_valued", False)),
            members=list(ed.get("members") or [])
        );
    }
    for (name, fd) in (d.get("functions") or {}).items() {
        layout.functions[str(name)] = _func_layout_from_dict(fd);
    }
    for (name, fd) in (d.get("methods") or {}).items() {
        layout.methods[str(name)] = _func_layout_from_dict(fd);
    }
    layout.list_elem_types = {
        str(k): str(v) for (k, v) in (d.get("list_elem_types") or {}).items()
    };
    for (key, td) in (d.get("tuples") or {}).items() {
        t = _tuple_layout_from_dict(td);
        if t is not None {
            layout.tuples[str(key)] = t;
        }
    }
    return layout;
}

obj BoundaryTypeInfo {
    has name: str,
        kind: str,
        fields: list[tuple[(str, str)]] = field(default_factory=`list),
        field_defaults: dict[(str, any)] = field(default_factory=`dict),
        enum_members: list[tuple[(str, any)]] = field(default_factory=`list),
        nested_types: list[str] = field(default_factory=`list);
}

obj InteropBinding {
    has name: str,
        source_context: InteropContext,
        callers: set[InteropContext] = field(default_factory=`set),
        ret_type: str = 'int',
        param_types: list[str] = [],
        param_names: list[str] = [],
        ast_node: any = None,
        source_module: (str | None) = None,
        kind: str = 'function';

    has is_cross_module: bool { getter; }
}

obj InteropManifest {
    has bindings: dict[(str, InteropBinding)] = field(default_factory=`dict),
        boundary_types: dict[(str, BoundaryTypeInfo)] = field(default_factory=`dict),
        endpoint_effects: dict[(str, dict)] = field(default_factory=`dict),
        func_access: dict[(str, bool)] = field(default_factory=`dict),
        walker_access: dict[(str, bool)] = field(default_factory=`dict);

    has native_imports: list[InteropBinding] { getter; }
    has native_exports: list[InteropBinding] { getter; }
    has native_cross_module_imports: list[InteropBinding] { getter; }
    has client_native_imports: list[InteropBinding] { getter; }
    has server_exports_to_client: list[InteropBinding] { getter; }
    has server_exports_to_server: list[InteropBinding] { getter; }
}

obj NodeComments {
    has leading: list[CommentToken] = [],
        trailing_inline: list[CommentToken] = [],
        trailing_own: list[CommentToken] = [],
        indent_trailing_own: bool = False;
}

obj CodeGenTarget {
    has py: str = '',
        jac: str = '',
        _doc_ir: (Doc | None) = None,
        js: str = '',
        css: str = '',
        _client_manifest: (ClientManifest | None) = None,
        py_ast: list = field(default_factory=`list),
        py_bytecode: (bytes | None) = None,
        jcir: (bytes | None) = None,
        es_ast: EsNode | Sequence[EsNode] | SliceInfo | IndexInfo | None = None,
        llvm_ir: (ModuleRef | None) = None,
        native_engine: (ExecutionEngine | None) = None,
        native_bitcode: (bytes | None) = None,
        native_object: (bytes | None) = None,
        native_iface: (NativeIface | None) = None,
        native_deps: list[str] = field(default_factory=`list),
        _interop_manifest: (InteropManifest | None) = None,
        interop_py_funcs: dict[(str, any)] = field(default_factory=`dict),
        _interop_callbacks: list[any] = field(default_factory=`list),
        native_layout: (NativeModuleLayout | None) = None,
        osp_model: (OspModel | None) = None,
        has_root_access: (bool | None) = None,
        nogc_enforced: bool = False,
        nogc_provenance: str = '',
        layout_registry: any = None,
        _clib_paths: list[str] = field(default_factory=`list),
        _clib_symbol_lib: dict[(str, str)] = field(default_factory=`dict),
        _exported_symbols: list[str] = field(default_factory=`list),
        doc_comments: (NodeComments | None) = None;

    has doc_ir: Doc { getter; setter(value: Doc); }
    has client_manifest: ClientManifest { getter; setter(value: ClientManifest); }
    has interop_manifest: InteropManifest { getter; setter(value: InteropManifest); }
}
