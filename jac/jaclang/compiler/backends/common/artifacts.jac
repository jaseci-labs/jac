import from jaclang.compiler.ir.enums { CodeContext }
import hashlib;
import from collections.abc { Sequence }
import from contextvars { ContextVar }
import from jaclang.runtime.object_model { field }
import type from jaclang.compiler.lowering.layout_pass { LayoutRegistry }
import from jaclang.compiler.ir.enums {
    NATIVE_ERASED_ANNOTATIONS,
    NATIVE_ERASED_TYPE_MARKERS,
    TYPE_PARAM_CONSTRUCTORS
}
import from jaclang.compiler.frontend.source_locations { CodeLocInfo }
import type from jaclang.compiler.backends.es.estree { IndexInfo, SliceInfo }
import type from jaclang.compiler.backends.es.estree { Node as EsNode }
import type from jaclang.compiler.ir.schema { CommentToken }
import type from jaclang.compiler.tools.doc_ir { Doc }
import type from jaclang.compiler.ir.schema { Source, Token }
import type from jaclang.compiler.analysis.binding.osp_facts { OspModel }
import type from jaclang.compiler.backends.native.llvm.ir { Module as IRModule }
import type from jaclang.compiler.backends.native.llvm.binding {
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
        runtime_imports: dict[str, list[str]] = field(default_factory=`dict),
        endpoint_effects: dict[(str, dict)] = field(default_factory=`dict),
        tests: list[dict[(str, str)]] = field(default_factory=`list),
        server_imports: list[str] = field(default_factory=`list),
        server_import_routes: dict[(str, dict[(str, str)])] = field(
            default_factory=`dict
        ),
        page_export: (str | None) = None,
        layout_export: (str | None) = None;
}

obj ClientArtifact {
    has js: str,
        manifest: ClientManifest,
        native_import_sources: list[str] = field(default_factory=`list),
        source_map: list[tuple[int, int, int, int, str]] = field(default_factory=`list),
        dep_digests: dict[str, str] = field(default_factory=`dict),
        boundary_contracts: dict = field(default_factory=`dict),
        framework: str = "";

    def to_bytes -> bytes;
    static def from_bytes(raw: bytes) -> (ClientArtifact | None);
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
        type_id: str = '',
        type_scope: str = '',
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
        type_scope: str = '',
        kind: str = 'function',
        provider_app: str = '',
        native_contract: dict = field(default_factory=`dict),
        endpoint_id: str = '';

    has is_cross_module: bool { getter; }
}

obj InteropManifest {
    has native_host_imports: dict[str, dict] = field(default_factory=`dict),
        bindings: dict[(str, InteropBinding)] = field(default_factory=`dict),
        boundary_types: dict[(str, BoundaryTypeInfo)] = field(default_factory=`dict),
        boundary_type_names: dict[str, dict[str, str]] = field(default_factory=`dict),
        endpoint_effects: dict[(str, dict)] = field(default_factory=`dict),
        func_access: dict[(str, bool)] = field(default_factory=`dict),
        walker_access: dict[(str, bool)] = field(default_factory=`dict),
        app_edges: list[tuple[(str, str)]] = field(default_factory=`list),
        provider_routes: dict[(str, str)] = field(default_factory=`dict),
        native_module_imports: dict[(str, NativeModuleInfo)] = field(
            default_factory=`dict
        ),
        native_transitive_sources: list[str] = field(default_factory=`list),
        native_transitive_keys: list[str] = field(default_factory=`list);

    has native_imports: list[InteropBinding] { getter; }
    has native_exports: list[InteropBinding] { getter; }
    has native_cross_module_imports: list[InteropBinding] { getter; }
    has native_dependency_sources: list[str] { getter; }
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

obj NodeArtifacts {
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
        llvm_ir: (ModuleRef | IRModule | None) = None,
        native_engine: (ExecutionEngine | None) = None,
        native_bitcode: (bytes | None) = None,
        native_linked_ir: (str | None) = None,
        _interop_manifest: (InteropManifest | None) = None,
        interop_py_funcs: dict[(str, any)] = field(default_factory=`dict),
        _interop_callbacks: list[any] = field(default_factory=`list),
        native_layout: (NativeModuleLayout | None) = None,
        osp_models: dict[CodeContext | None, OspModel] = {},
        jc_layout: (str | None) = None,
        has_root_access: (bool | None) = None,
        nogc_enforced: bool = False,
        nogc_provenance: str = '',
        layout_registry: LayoutRegistry | None = None,
        _clib_paths: list[str] = field(default_factory=`list),
        _clib_symbol_lib: dict[(str, str)] = field(default_factory=`dict),
        _exported_symbols: list[str] = field(default_factory=`list),
        doc_comments: (NodeComments | None) = None;

    has doc_ir: Doc { getter; setter(value: Doc); }
    has client_manifest: ClientManifest { getter; setter(value: ClientManifest); }
    has interop_manifest: InteropManifest { getter; setter(value: InteropManifest); }

    def peek_interop -> InteropManifest | None {
        return self._interop_manifest;
    }
}
