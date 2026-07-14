import hashlib;
import re;
import from collections.abc { Sequence }
import from dataclasses { field }
import from typing { Any }
import type from jaclang.compiler.passes.ecmascript.estree { IndexInfo, SliceInfo }
import type from jaclang.compiler.passes.ecmascript.estree { Node as EsNode }
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
        globals_values: dict[(str, Any)] = field(default_factory=`dict),
        has_client: bool = False,
        imports: dict[(str, str)] = field(default_factory=`dict),
        endpoint_effects: dict[(str, dict)] = field(default_factory=`dict),
        tests: list[dict[(str, str)]] = field(default_factory=`list),
        server_imports: list[str] = field(default_factory=`list);
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

obj NativeFieldInfo {
    has name: str,
        llvm_type: str,
        index: int,
        enum_type: (str | None) = None,
        is_func_ptr: bool = False,
        func_param_types: (list[str] | None) = None,
        func_ret_type: (str | None) = None;
}

obj NativeStructLayout {
    has name: str,
        fields: list[NativeFieldInfo] = field(default_factory=`list),
        has_vtable: bool = False;
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
        ret_enum_type: (str | None) = None;
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
    if src == "osp_kernel" {
        return "osp_kernel";
    }
    safe = re.sub(r'[^a-zA-Z0-9_]', '_', src);
    return f"{safe}_{hashlib.sha1(src.encode()).hexdigest()[:8]}";
}

def native_stdlib_root -> (str | None) {
    import os;
    import jaclang;
    if not jaclang?.__file__ {
        return None;
    }
    root = os.path.join(os.path.dirname(jaclang.__file__), "runtimelib", "na_stdlib");
    return root if os.path.isdir(root) else None;
}

def is_bundled_native_module(module_name: str) -> bool {
    import os;
    root = native_stdlib_root();
    if root is None or not module_name {
        return False;
    }
    path_name = module_name.lstrip('.').replace('.', os.sep);
    return os.path.exists(os.path.join(root, f"{path_name}.na.jac"));
}

def resolve_native_module(
    module_name: str, base_dir: str
) -> tuple[(str | None, str | None)] {
    import os;
    clean = module_name.lstrip('.');

    na_jac = os.path.join(base_dir, f"{clean}.na.jac");
    if os.path.exists(na_jac) {
        return (f"{clean}.na", na_jac);
    }

    path_name = clean.replace('.', os.sep);
    if path_name != clean {
        search = os.path.abspath(base_dir);
        while True {
            cand = os.path.join(search, f"{path_name}.na.jac");
            if os.path.exists(cand) {
                rel = os.path.relpath(cand[:-4], os.path.abspath(base_dir));
                return (rel, cand);
            }
            parent = os.path.dirname(search);
            if parent == search {
                break;
            }
            search = parent;
        }
    }

    bundled_root = native_stdlib_root();
    if bundled_root is not None {
        bundled = os.path.join(bundled_root, f"{path_name}.na.jac");
        if os.path.exists(bundled) {
            return (f"{path_name}.na", bundled);
        }
    }
    return (None, None);
}

obj NativeModuleLayout {
    has structs: dict[(str, NativeStructLayout)] = field(default_factory=`dict),
        enums: dict[(str, NativeEnumLayout)] = field(default_factory=`dict),
        functions: dict[(str, NativeFuncLayout)] = field(default_factory=`dict),
        methods: dict[(str, NativeFuncLayout)] = field(default_factory=`dict),
        list_elem_types: dict[(str, str)] = field(default_factory=`dict),
        tuples: dict[(str, NativeTupleLayout)] = field(default_factory=`dict),
        tests: list[NativeTestLayout] = field(default_factory=`list);
}

obj BoundaryTypeInfo {
    has name: str,
        kind: str,
        fields: list[tuple[(str, str)]] = field(default_factory=`list),
        enum_members: list[tuple[(str, Any)]] = field(default_factory=`list),
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
        route: list[InteropContext] = [],
        source_module: (str | None) = None,
        kind: str = 'function';

    has is_direct: bool { getter; }
    has is_composed: bool { getter; }
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
        native_transitive_sources: list[str] = field(default_factory=`list),
        JAC_TO_CTYPES: dict[(str, str)] = field(
            default_factory=lambda { return {
                'int': 'ctypes.c_int64',
                'float': 'ctypes.c_double',
                'bool': 'ctypes.c_bool',
                'str': 'ctypes.c_char_p'
            }; }
        );

    has native_imports: list[InteropBinding] { getter; }
    has native_exports: list[InteropBinding] { getter; }
    has native_cross_module_imports: list[InteropBinding] { getter; }
    has server_exports_to_client: list[InteropBinding] { getter; }
    has server_exports_to_server: list[InteropBinding] { getter; }
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
        es_ast: EsNode | Sequence[EsNode] | SliceInfo | IndexInfo | None = None,
        llvm_ir: (ModuleRef | None) = None,
        native_engine: (ExecutionEngine | None) = None,
        native_bitcode: (bytes | None) = None,
        _interop_manifest: (InteropManifest | None) = None,
        interop_py_funcs: dict[(str, Any)] = field(default_factory=`dict),
        _interop_callbacks: list[any] = field(default_factory=`list),
        native_layout: (NativeModuleLayout | None) = None,
        osp_model: (OspModel | None) = None,
        native_compat: bool = False,
        layout_registry: any = None,
        _clib_paths: list[str] = field(default_factory=`list),
        _clib_symbol_lib: dict[(str, str)] = field(default_factory=`dict),
        _exported_symbols: list[str] = field(default_factory=`list);

    has doc_ir: Doc { getter; setter(value: Doc); }
    has client_manifest: ClientManifest { getter; setter(value: ClientManifest); }
    has interop_manifest: InteropManifest { getter; setter(value: InteropManifest); }
}

obj CodeLocInfo {
    has first_tok: Token,
        last_tok: Token;

    has orig_src: Source { getter; }
    has mod_path: str { getter; }
    has first_line: int { getter; }
    has last_line: int { getter; }
    has col_start: int { getter; }
    has col_end: int { getter; }
    has pos_start: int { getter; }
    has pos_end: int { getter; }

    def update_token_range(first_tok: Token, last_tok: Token) {
        self.first_tok = first_tok;
        self.last_tok = last_tok;
    }

    def update_first_token(first_tok: Token) {
        self.first_tok = first_tok;
    }

    def update_last_token(last_tok: Token) {
        self.last_tok = last_tok;
    }

    def __str__ -> str {
        return f"{self.first_line}:{self.col_start} - {self.last_line}:{self.col_end}";
    }
}
