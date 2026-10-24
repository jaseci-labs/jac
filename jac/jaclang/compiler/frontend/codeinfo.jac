import hashlib;
import from collections.abc { Sequence }
import from contextvars { ContextVar }

obj ClientManifest {
    has exports: list[str] = [],
        globals: list[str] = [],
        params: dict[str, list[str]] = {},
        globals_values: dict[(str, any)] = {},
        has_client: bool = False,
        imports: dict[(str, str)] = {},
        runtime_imports: dict[str, list[str]] = {},
        endpoint_effects: dict[(str, dict[str, any])] = {},
        tests: list[dict[(str, str)]] = [],
        server_imports: list[str] = [],
        server_import_routes: dict[(str, dict[(str, str)])] = {},
        page_export: (str | None) = None,
        layout_export: (str | None) = None,
        linkable: list[str] = [],
        components: list[str] = [],
        forwards: dict[str, list[str]] = {};
}

obj ClientArtifact {
    has js: str,
        manifest: ClientManifest,
        native_import_sources: list[str] = [],
        source_map: list[tuple[int, int, int, int, str]] = [],
        dep_digests: dict[str, str] = {},
        boundary_contracts: dict[str, any] = {},
        framework: str = "",
        pulled: list[int] = [];
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
     STR_ASCII_TAG_BIT: int = -9223372036854775808,
     STR_LEN_PAYLOAD_MASK: int = 9223372036854775807,
     STR_LEN_TAG_SHIFT: int = 1;

glob JACSTR_DESC_FIELDS: dict[(str, tuple[str, ...])] = {
         'jacstr3': ('root', 'data', 'len'),
         'jacstr2': ('data', 'len')
     };

def str_len_tag(length: int, is_ascii: bool = False) -> int;

obj NativeFieldInfo {
    has name: str,
        llvm_type: str,
        index: int,
        enum_type: (str | None) = None,
        is_func_ptr: bool = False,
        func_param_types: (list[str] | None) = None,
        func_ret_type: (str | None) = None,
        elem_keys: (list[str | None] | None) = None,
        foreign: bool = False;
}

obj NativeStructLayout {
    has name: str,
        fields: list[NativeFieldInfo] = [],
        has_vtable: bool = False,
        accessors: dict[(str, dict[(str, str)])] = {};
}

obj NativeEnumLayout {
    has name: str,
        is_string_valued: bool = False,
        members: list[tuple[str, any, int]] = [];
}

obj NativeTupleLayout {
    has key: str,
        element_types: list[str] = [],
        element_struct_hints: list[str | None] = [];
}

obj NativeFuncLayout {
    has name: str,
        param_types: list[str] = [],
        param_names: list[str] = [],
        ret_type: str = "i64",
        ret_struct_name: (str | None) = None,
        ret_tuple_layout: (NativeTupleLayout | None) = None,
        ret_enum_type: (str | None) = None,
        ret_elem_keys: (list[str | None] | None) = None;
}

obj NativeTestLayout {
    has name: str,
        symbol: str,
        description: str = "",
        line: int = 0;
}

def native_safe_sym(src: str) -> str;

def _reserved_c_symbols -> frozenset[str];

glob NATIVE_RESERVED_C_SYMBOLS: frozenset[str] = _reserved_c_symbols();

glob NATIVE_ARCH_SCOPE_SEP: str = "$",
     _native_arch_scope_memo: dict[str, str] = {},
     _native_arch_scope_gen: list[int] = [-1],
     _native_unit_identity_memo: dict[str, str] = {};

def native_arch_scope(mod_path: str) -> str;

def native_arch_name(mod_path: str, name: str) -> str;

def _is_word_char(ch: str) -> bool;

def native_unit_spelling(text: str, mod_path: str) -> str;

def native_arch_display(native_name: str) -> str;

def _scope_suffix_end(text: str, start: int) -> int;

def native_display_text(text: str) -> str;


def native_def_symbol(name: str) -> str;

def module_dotted_name(mod_path: str, mod_name: str = "") -> str;

def native_unit_root(directory: str) -> (str | None);

def native_unit_identity(path: str) -> str;

def native_module_key(path: str) -> str;

def native_unit_prefix(path: str) -> str;

def native_symbol_name(prefix: str, name: str) -> str;

def native_glob_init_name(path: str) -> str;

def native_entry_name(path: str) -> str;

def native_runtime_probe_name(path: str) -> str;

def native_test_symbol(name: str, line: int, prefix: str = "") -> str;

glob JAC_ENTRY_SYMBOL: str = "jac_entry",
     JAC_SHARED_INIT_SYMBOL: str = "__jac_shared_init";

glob KERNEL_UNIT_REL: tuple[str, ...] = (
         "runtime/osp_kernel.jac",
         "runtime/osp_graph.jac",
         "runtime/region_native.jac",
         "compiler/backends/common/fmt_kernel.jac"
     ),
     OSP_KERNEL_REL: str = "runtime/osp_kernel.jac",
     OSP_GRAPH_REL: str = "runtime/osp_graph.jac",
     REGION_KERNEL_REL: str = "runtime/region_native.jac",
     FMT_KERNEL_REL: str = "compiler/backends/common/fmt_kernel.jac";

glob _PKG_REAL: list[str] = [];

def jaclang_pkg_root -> str;

def is_compiler_source_path(source_path: str) -> bool;

def kernel_unit_rels -> list[str];

def is_package_keyed_path(source_path: str) -> bool;

def kernel_unit_path(rel: str) -> str;

def kernel_unit_paths -> list[str];

glob _REAL_PATHS: dict[str, str] = {};

def real_path(path: str) -> str;

def forget_real_paths;

def is_kernel_unit_path(path: str) -> bool;

glob NATIVE_STDLIB_EXTENSIONS: dict[str, str] = {"os": "_os_native"},
     NOGC_NATIVE_STDLIB: set[str] = {
         "time",
         "_time_native",
         "_time_common",
         "_errno_native",
         "_errno_platform"
     };

glob NATIVE_SUPPORTED_STDLIB: set[str] = {
         "copy",
         "sys",
         "os",
         "random",
         "struct",
         "enum",
         "collections.abc"
     },
     _effective_codespace_ctx: ContextVar[str] = ContextVar(
         "jac_effective_default_codespace"
     ),
     _native_unit_ctx: ContextVar[bool] = ContextVar("jac_native_unit_compile"),
     _native_target_ctx: ContextVar[str | None] = ContextVar("jac_native_target");

glob NATIVE_ERASED_ABC_BASES: frozenset[str] = frozenset({"ABC"});

glob NATIVE_ERASED_BASES: frozenset[str] = NATIVE_ERASED_ABC_BASES;

glob NATIVE_ERASED_IDENTITY_CALLS: frozenset[str] = frozenset({"cast"});

glob NATIVE_ERASED_FIELD_MARKERS: frozenset[str] = frozenset({"ObjectField"});

glob NATIVE_ERASED_IMPORTS: dict[str, frozenset[str]] = {
         "abc": NATIVE_ERASED_ABC_BASES,
         "contextlib": frozenset({"contextmanager"}),
         "jaclang.runtime.object_model": NATIVE_ERASED_FIELD_MARKERS,
         "typing": TYPE_PARAM_CONSTRUCTORS
             | NATIVE_ERASED_IDENTITY_CALLS
             | NATIVE_ERASED_TYPE_MARKERS
             | NATIVE_ERASED_ANNOTATIONS
     };

def native_erased_import_names(module_name: str, names: list[str]) -> bool;

def set_effective_default_codespace(value: str);

def get_effective_default_codespace_override -> str;

def effective_default_codespace -> str;

def set_native_unit_compile(value: bool) -> bool;

def reset_native_unit_compile(prev: bool);

def native_unit_compile_active -> bool;

def native_stdlib_root -> (str | None);

def bundled_pkg_roots -> list[str];

def is_toolchain_unit(file_path: str) -> bool;

def bundled_native_module_names -> list[str];

def is_native_by_location(file_path: str) -> bool;

def bundled_stdlib_module_of(file_path: str) -> (str | None);

glob SHARED_RUNTIME_MODULES: tuple[str, ...] = (
         "jaclang.runtime.graph_fragment",

     ),
     CLIENT_RUNTIME_SOURCE_PATHS: list[str] = [
         "client/client_runtime.jac",
         "client/client_runtime_core.jac",
         "client/solid_runtime.jac",
         "client/pwa_runtime.jac",
         "client/wasm_host.jac",
         "client/webgl.jac",
         "client/endpoint_cache.jac",
         "client/auth_contract.jac",
         "client/client_mobui.jac",
         "client/client_react_core.jac",
         "client/client_runtime_native.jac",
         "client/targets/desktop/plugin/desktop_api.jac"
     ];


def is_client_by_location(file_path: str) -> bool;

def is_shared_runtime_module(file_path: str) -> bool;

def is_bundled_native_module(module_name: str) -> bool;

def set_native_target_override(triple: str | None) -> (str | None);

def effective_native_target -> str;

def native_target_os -> str;

def native_target_arch -> str;

def _native_variant_path(base_no_ext: str) -> (str | None);

glob NATIVE_VARIANT_OSES: frozenset[str] = frozenset(
         {"darwin", "linux", "windows"}
     ),
     NATIVE_VARIANT_ARCHES: frozenset[str] = frozenset(
         {"x86_64", "aarch64", "arm64", "i686", "riscv64", "wasm32"}
     );

def is_selected_native_variant(path: str) -> bool;

def is_native_variant_path(path: str) -> bool;

def native_variant_of(module_path: str) -> str;

def _inferred_native_path(candidate: (str | None)) -> (str | None);

def resolve_native_module(
    module_name: str, base_dir: str, allow_inferred: bool = True
) -> tuple[(str | None, str | None)];

def native_wasm_stem(path: str) -> str;

glob NATIVE_ABI_VERSION: int = 3;

obj NativeModuleLayout {
    has abi_version: int = NATIVE_ABI_VERSION,
        structs: dict[(str, NativeStructLayout)] = {},
        enums: dict[(str, NativeEnumLayout)] = {},
        functions: dict[(str, NativeFuncLayout)] = {},
        methods: dict[(str, NativeFuncLayout)] = {},
        list_elem_types: dict[(str, str)] = {},
        tuples: dict[(str, NativeTupleLayout)] = {},
        tests: list[NativeTestLayout] = [],
        str_headerless: (bool | None) = None;
}

obj BoundaryTypeInfo {
    has name: str,
        kind: str,
        type_id: str = '',
        type_scope: str = '',
        fields: list[tuple[(str, str)]] = [],
        field_defaults: dict[(str, any)] = {},
        enum_members: list[tuple[(str, any)]] = [],
        nested_types: list[str] = [];
}


obj InteropBinding {
    has name: str,
        source_context: InteropContext,
        callers: set[InteropContext] = set(),
        ret_type: str = 'int',
        param_types: list[str] = [],
        param_names: list[str] = [],
        ast_node: (UniNode | None) = None,
        source_module: (str | None) = None,
        type_scope: str = '',
        kind: str = 'function',
        provider_app: str = '',
        native_contract: dict[str, any] = {},
        endpoint_id: str = '';

    has is_cross_module: bool { getter; }
}

obj InteropManifest {
    has native_host_imports: dict[str, dict[str, any]] = {},
        bindings: dict[(str, InteropBinding)] = {},
        boundary_types: dict[(str, BoundaryTypeInfo)] = {},
        boundary_type_names: dict[str, dict[str, str]] = {},
        endpoint_effects: dict[(str, dict[str, any])] = {},
        surface: dict[(str, SurfaceEntry)] = {},
        app_edges: list[tuple[(str, str)]] = [],
        provider_routes: dict[(str, str)] = {};

    has native_imports: list[InteropBinding] { getter; }
    has callable_native_imports: list[InteropBinding] { getter; }
    has native_exports: list[InteropBinding] { getter; }
    has native_cross_module_imports: list[InteropBinding] { getter; }
    has client_native_imports: list[InteropBinding] { getter; }
    has server_exports_to_client: list[InteropBinding] { getter; }
    has server_exports_to_server: list[InteropBinding] { getter; }

    def boundary_types_for(scope: str) -> dict[str, BoundaryTypeInfo];
}

obj NodeComments {
    has leading: list[CommentToken] = [],
        trailing_inline: list[CommentToken] = [],
        trailing_own: list[CommentToken] = [],
        indent_trailing_own: bool = False;
}

obj CodeGenTarget {
    has py_text: (str | None) = None,
        jac: str = '',
        _doc_ir: (Doc | None) = None,
        js: str = '',
        css: str = '',
        _client_manifest: (ClientManifest | None) = None,
        py_ast: list[any] = [],
        py_bytecode: (bytes | None) = None,
        jcir: (bytes | None) = None,
        es_ast: EsNode | Sequence[EsNode] | SliceInfo | IndexInfo | None = None,
        llvm_ir: any = None,
        ir_module: (IRModule | None) = None,
        native_engine: (ExecutionEngine | SharedNativeEngine | None) = None,
        native_bitcode: (bytes | None) = None,
        native_object: (bytes | None) = None,
        native_iface: (NativeIface | None) = None,
        native_deps: list[str] = [],
        native_codespace: bool = False,
        native_refusal: str = "",
        native_fallbacks: (NativeFallbacks | None) = None,
        native_refusal_code: str = "",
        placement_mode: str = "",
        native_undecided: bool = False,
        native_closed_why: str = "",
        _interop_manifest: (InteropManifest | None) = None,
        interop_py_funcs: dict[(str, any)] = {},
        _interop_callbacks: list[any] = [],
        native_layout: (NativeModuleLayout | None) = None,
        osp_model: (OspModel | None) = None,
        native_osp_model: (OspModel | None) = None,
        component_call_abi: str = "",
        jc_layout: (str | None) = None,
        has_root_access: (bool | None) = None,
        nogc_enforced: bool = False,
        nogc_provenance: str = '',
        layout_registry: (LayoutRegistry | None) = None,
        _clib_paths: list[str] = [],
        _clib_symbol_lib: dict[(str, str)] = {},
        _exported_symbols: list[str] = [],
        callable_effects: dict[str, dict[str, any]] = {},
        doc_comments: (NodeComments | None) = None;

    has doc_ir: Doc { getter; setter(value: Doc); }
    has client_manifest: ClientManifest { getter; setter(value: ClientManifest); }
    has interop_manifest: InteropManifest { getter; setter(value: InteropManifest); }

    def has_native_ir -> bool;
    def drop_native_ir;
}

def endpoint_descriptor(module: Module, kind: str, name: str) -> dict[str, str];

def endpoint_key(module: Module, kind: str, name: str) -> str;
