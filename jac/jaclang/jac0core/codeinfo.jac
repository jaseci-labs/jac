import hashlib;
import from collections.abc { Sequence }
import from contextvars { ContextVar }
import from dataclasses { field }
import from jaclang.jac0core.constant {
    NATIVE_ERASED_ANNOTATIONS,
    NATIVE_ERASED_TYPE_MARKERS,
    TYPE_PARAM_CONSTRUCTORS
}
import from jaclang.jac0core.srcloc { CodeLocInfo }
import type from jaclang.jac0core.constant { GraphBreakKind, GraphMendHelper }
import type from jaclang.compiler.passes.ecmascript.estree { IndexInfo, SliceInfo }
import type from jaclang.compiler.passes.ecmascript.estree { Node as EsNode }
import type from jaclang.jac0core.unitree { Ability, CommentToken, UniNode }
import type from jaclang.compiler.passes.tool.doc_ir { Doc }
import type from jaclang.jac0core.unitree { Source, Token }
import type from jaclang.jac0core.osp_model { OspModel }
import type from jaclang.compiler.passes.native.llvm.binding {
    ModuleRef,
    ExecutionEngine
}

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

enum InteropContext { SERVER = 'server', NATIVE = 'native', CLIENT = 'client' }

obj NativeFunctionInfo {
    has name: str,
        ret_type: str = 'int',
        param_types: list = [],
        param_names: list = [];
}

obj NativeModuleInfo {
    has mod_path: str,
        llvm_module: (ModuleRef | None) = None,
        native_engine: (ExecutionEngine | None) = None,
        exported_functions: dict[(str, NativeFunctionInfo)] = field(
            default_factory=`dict
        );
}

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

def native_test_symbol(name: str, line: int) -> str {
    return f"__jac_test_{name}_{line}";
}

def native_safe_sym(src: str) -> str {
    if src in ("osp_kernel", "fmt_kernel") {
        return src;
    }
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

def native_glob_init_symbols(manifest: (InteropManifest | None)) -> list[str] {
    syms: list[str] = [];
    sources: list[str] = [];
    if manifest is not None {
        sources = manifest.native_transitive_sources;
    }
    for src in sources {
        if not src {
            continue;
        }
        sym = f"__jac_glob_init_{native_safe_sym(src)}";
        if sym not in syms {
            syms.append(sym);
        }
    }
    syms.append("__jac_glob_init");
    return syms;
}

def install_native_static_init(
    engine: any, manifest: (InteropManifest | None)
) -> None {
    if engine is None {
        return;
    }
    engine.static_init_symbols = native_glob_init_symbols(manifest);
    engine.static_init_chained = {"jac_entry"};
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
     _closure_cap_ctx: ContextVar[int] = ContextVar("jac_native_closure_cap");

glob NATIVE_ERASED_ABC_BASES: frozenset = frozenset({"ABC"});

glob NATIVE_ERASED_RIM_BASES: frozenset = frozenset({"PassRim"});

glob NATIVE_ERASED_BASES: frozenset = (
         NATIVE_ERASED_ABC_BASES | NATIVE_ERASED_RIM_BASES
     );

glob NATIVE_ERASED_IDENTITY_CALLS: frozenset = frozenset({"cast"});

glob NATIVE_ERASED_FIELD_MARKERS: frozenset = frozenset({"field"});

glob PASS_RIM_MODULE: str = "jaclang.jac0core.passes.pass_rim";

glob NATIVE_ERASED_IMPORTS: dict[str, frozenset] = {
         "abc": NATIVE_ERASED_ABC_BASES,
         "dataclasses": NATIVE_ERASED_FIELD_MARKERS,
         PASS_RIM_MODULE: NATIVE_ERASED_RIM_BASES,
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
        os.path.dirname(jaclang.__file__), "runtimelib", "na_stdlib"
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
    return ap.startswith(os.path.join(pkg, "runtimelib", "na_stdlib") + os.sep);
}

glob CLIENT_RUNTIME_SOURCE_PATHS: list[str] = [
         "runtimelib/client_runtime.jac",
         "runtimelib/client_runtime_core.jac",
         "runtimelib/solid_runtime.jac",
         "runtimelib/pwa_runtime.jac",
         "runtimelib/wasm_host.jac",
         "runtimelib/client/client_mobui.jac",
         "runtimelib/client/client_runtime_core.jac",
         "runtimelib/client/client_runtime_native.jac",
         "runtimelib/client/targets/desktop/plugin/desktop_api.jac"
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
    import from jaclang.jac0core.placement_solver { native_default_path_ok }
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
        walker_access: dict[(str, bool)] = field(default_factory=`dict),
        native_module_imports: dict[(str, NativeModuleInfo)] = field(
            default_factory=`dict
        ),
        native_transitive_sources: list[str] = field(default_factory=`list);

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

obj GraphMendFacts {
    has breaks: dict[(UniNode, GraphBreakKind)] = field(default_factory=`dict),
        boundary: dict[(Ability, Ability)] = field(default_factory=`dict),
        helpers: set[GraphMendHelper] = field(default_factory=`set),
        noop: bool = False,
        wrapped_keys: set[str] = field(default_factory=`set),
        covered_by: dict[(str, str)] = field(default_factory=`dict);
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
        doc_comments: (NodeComments | None) = None,
        graphmend_facts: (GraphMendFacts | None) = None;

    has doc_ir: Doc { getter; setter(value: Doc); }
    has client_manifest: ClientManifest { getter; setter(value: ClientManifest); }
    has interop_manifest: InteropManifest { getter; setter(value: InteropManifest); }
}
