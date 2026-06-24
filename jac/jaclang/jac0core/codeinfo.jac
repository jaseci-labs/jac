"""Code location info for AST nodes."""
import ast as ast3;
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

"""Client-side rendering manifest metadata."""
obj ClientManifest {
    has exports: list = [],
        globals: list = [],
        params: dict[(str, list)] = field(default_factory=`dict),
        globals_values: dict[(str, Any)] = field(default_factory=`dict),
        has_client: bool = False,
        imports: dict[(str, str)] = field(default_factory=`dict),
        endpoint_effects: dict[(str, dict)] = field(default_factory=`dict),
        tests: list[dict[(str, str)]] = field(default_factory=`list),
        # Absolute paths of server (`sv import`) modules this client file binds
        # to. A full-stack cl test boots these directly instead of guessing the
        # backend by filename.
        server_imports: list[str] = field(default_factory=`list);
}

"""Codespace context for interop bindings."""
enum InteropContext {
    SERVER = 'server',
    NATIVE = 'native',
    CLIENT = 'client'
}

"""Metadata for an exported native function."""
obj NativeFunctionInfo {
    has name: str,
        ret_type: str = 'int',
        param_types: list = [],
        param_names: list = [];
}

"""Metadata for a compiled .na.jac module."""
obj NativeModuleInfo {
    has mod_path: str,
        llvm_module: (ModuleRef | None) = None,
        native_engine: (ExecutionEngine | None) = None,
        exported_functions: dict[(str, NativeFunctionInfo)] = field(
            default_factory=`dict
        );
}

"""Layout info for a single struct field (for native ctypes marshalling)."""
obj NativeFieldInfo {
    has name: str,
        llvm_type: str,
        index: int,
        enum_type: (str | None) = None,
        is_func_ptr: bool = False,
        func_param_types: (list[str] | None) = None,
        func_ret_type: (str | None) = None;
}

"""Layout info for a native struct (for ctypes auto-generation)."""
obj NativeStructLayout {
    has name: str,
        fields: list[NativeFieldInfo] = field(default_factory=`list),
        has_vtable: bool = False;
}

"""Layout info for a native enum."""
obj NativeEnumLayout {
    has name: str,
        is_string_valued: bool = False,
        members: list = field(default_factory=`list);
}

"""Layout info for a native tuple return type."""
obj NativeTupleLayout {
    has key: str,
        element_types: list[str] = field(default_factory=`list),
        element_struct_hints: list = field(default_factory=`list);
}

"""Layout info for a native function."""
obj NativeFuncLayout {
    has name: str,
        param_types: list[str] = field(default_factory=`list),
        param_names: list[str] = field(default_factory=`list),
        ret_type: str = "i64",
        ret_struct_name: (str | None) = None,
        ret_tuple_layout: (NativeTupleLayout | None) = None,
        # Enum type name when the function returns an enum (lowered to i64), so
        # the marshaller can map the ordinal back to the Python enum member
        # instead of leaking a raw int to Python callers.
        ret_enum_type: (str | None) = None;
}

"""Layout info for a native test block.

A `test` block in native context lowers to a zero-argument native function
returning `i8*`: null means the test passed, a non-null pointer is a static
failure message (the uncaught exception's message).
"""
obj NativeTestLayout {
    has name: str,
        symbol: str,
        description: str = "",
        line: int = 0;
}

"""Native symbol name for a test block.

Single naming contract shared by NaIRGenPass (which defines the function)
and PyastGenPass (whose host-side shim looks the address up by name). The
line number keeps symbols unique when two descriptions derive the same
identifier.
"""
def native_test_symbol(name: str, line: int) -> str {
    return f"__jac_test_{name}_{line}";
}

"""Unique LLVM-safe suffix for a native module's per-module symbols.

`source_module_str` is the value stored in `InteropBinding.source_module`
and `InteropManifest.native_transitive_sources` (e.g. `math_utils.na` for a
flat import or `math/utils.na` for a dotted `math.utils` import — see
`resolve_native_module`). The legacy transform `re.sub(r'[^a-zA-Z0-9_]',
'_', src)` collapses both spellings to `math_utils_na`, so two distinct
transitive native deps can collide on `__jac_glob_init_<safe>` /
`__jac_entry_<safe>`, and LLVM's first-seen-wins silently drops the second
module's initializer/entry. We keep the human-readable slug (so `nm`/crash
traces stay legible) and append a short sha1 of the *original* string —
which differs between `math_utils.na` and `math/utils.na` — to guarantee
uniqueness without dragging absolute paths (which the runtime/JIT call
sites in nacompile.impl/native_marshal.jac do not have) into the contract.

Single naming contract shared by NaIRGenPass (defines the renamed
`__jac_glob_init_<safe>` / `__jac_entry_<safe>`), NativeCompilePass (renames
imported IR), nacompile (emits `__jac_shared_init` calls), and
native_marshal.init_native_globals (looks the address up by name). All four
must agree or the JIT lookup silently no-ops.

`osp_kernel` is a singleton SENTINEL (not a real per-module source path): the
portable OSP kernel is linked under a fixed, hash-free symbol by
`_link_osp_kernel` / `_emit_osp_setup` and probed by name in
`_references_undefined_osp_kernel`, so it must map to the bare `osp_kernel`
slug. Appending the disambiguating hash here would leave the entry's
`__jac_glob_init_osp_kernel_<hash>` call dangling against the kernel's
hash-free definition (undefined symbol at load — issue #6669).
"""
def native_safe_sym(src: str) -> str {
    if src == "osp_kernel" {
        return "osp_kernel";
    }
    safe = re.sub(r'[^a-zA-Z0-9_]', '_', src);
    return f"{safe}_{hashlib.sha1(src.encode()).hexdigest()[:8]}";
}

"""Resolve a module name to a .na.jac file path.

Shared resolver used by both BoundaryAnalysisPass and NaIRGenPass to
ensure consistent native module path resolution across the compiler.

Returns (source_module_str, full_path) or (None, None) if not found.
source_module_str mirrors the value stored in InteropBinding.source_module.
"""
def resolve_native_module(
    module_name: str, base_dir: str
) -> tuple[(str | None, str | None)] {
    import os;
    clean = module_name.lstrip('.');
    # Fast path: flat filename (e.g. 'tokens' → 'tokens.na.jac')
    na_jac = os.path.join(base_dir, f"{clean}.na.jac");
    if os.path.exists(na_jac) {
        return (f"{clean}.na", na_jac);
    }
    # Slow path: dotted name → directory hierarchy, walk up to project root.
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
    return (None, None);
}

"""Complete layout metadata for a native module (auto-generated by NaIRGenPass)."""
obj NativeModuleLayout {
    has structs: dict[(str, NativeStructLayout)] = field(default_factory=`dict),
        enums: dict[(str, NativeEnumLayout)] = field(default_factory=`dict),
        functions: dict[(str, NativeFuncLayout)] = field(default_factory=`dict),
        methods: dict[(str, NativeFuncLayout)] = field(default_factory=`dict),
        list_elem_types: dict[(str, str)] = field(default_factory=`dict),
        tuples: dict[(str, NativeTupleLayout)] = field(default_factory=`dict),
        tests: list[NativeTestLayout] = field(default_factory=`list);
}

"""Metadata for a type (obj, node, enum) that crosses a codespace boundary.

    Collected by BoundaryAnalysisPass, consumed by EsastGenPass to emit
    JS class stubs with __from_wire/__to_wire methods.
    """
obj BoundaryTypeInfo {
    has name: str,
        kind: str,  # "obj", "node", "walker", "enum"
        fields: list[tuple[(str, str)]] = field(default_factory=`list),
        enum_members: list[tuple[(str, Any)]] = field(default_factory=`list),
        nested_types: list[str] = field(default_factory=`list);
}

"""A function callable across codespace boundaries.

    Records that a function defined in `source_context` is called from
    one or more other codespace contexts listed in `callers`.
    """
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
        # Kind of provider symbol this binding stubs out: 'function' for
        # `def:pub` functions (POST /function/<name>), 'walker' for
        # `walker:pub` archetypes (POST /walker/<name>). Drives stub
        # codegen and runtime dispatch for sv-to-sv imports.
        kind: str = 'function';

    has is_direct: bool { getter; }
    has is_composed: bool { getter; }
    has is_cross_module: bool { getter; }
}

"""All cross-boundary function bindings for a module.

    Built by BoundaryAnalysisPass (front-end), consumed by codegen + serve.
    """
obj InteropManifest {
    has bindings: dict[(str, InteropBinding)] = field(default_factory=`dict),
        boundary_types: dict[(str, BoundaryTypeInfo)] = field(default_factory=`dict),
        # Graph-effect contract per RPC endpoint, keyed `walker:<name>` /
        # `func:<name>` -> {is_writer, touches}. Produced by the boundary
        # analysis pass (formerly WalkerEffectsPass -> client_manifest).
        endpoint_effects: dict[(str, dict)] = field(default_factory=`dict),
        # Per-symbol auth requirement (True = auth required, secure-by-default),
        # computed at compile time so the serve runtime never re-walks ASTs.
        func_access: dict[(str, bool)] = field(default_factory=`dict),
        walker_access: dict[(str, bool)] = field(default_factory=`dict),
        native_module_imports: dict[(str, NativeModuleInfo)] = field(
            default_factory=`dict
        ),
        # Transitive closure of native module source strings (e.g. "foo.na").
        # Populated by NaIRGenPass._register_imported_struct_types via DFS,
        # consumed by _codegen_entry to emit __jac_glob_init_<safe_name>() calls.
        native_transitive_sources: list[str] = field(default_factory=`list),
        JAC_TO_CTYPES: dict[(str, str)] = field(
            default_factory=lambda() :
                {
                    'int': 'ctypes.c_int64',
                    'float': 'ctypes.c_double',
                    'bool': 'ctypes.c_bool',
                    'str': 'ctypes.c_char_p'
                }
        );

    has native_imports: list[InteropBinding] { getter; }
    has native_exports: list[InteropBinding] { getter; }
    has native_cross_module_imports: list[InteropBinding] { getter; }
    has server_exports_to_client: list[InteropBinding] { getter; }
    has server_exports_to_server: list[InteropBinding] { getter; }
}

"""Code generation target."""
obj CodeGenTarget {
    has py: str = '',
        jac: str = '',
        _doc_ir: (Doc | None) = None,
        js: str = '',
        css: str = '',
        client_manifest: ClientManifest = field(default_factory=ClientManifest),
        py_ast: list = field(default_factory=`list),
        py_bytecode: (bytes | None) = None,
        es_ast: EsNode | Sequence[EsNode] | SliceInfo | IndexInfo | None = None,
        llvm_ir: (ModuleRef | None) = None,
        native_engine: (ExecutionEngine | None) = None,
        native_bitcode: (bytes | None) = None,
        interop_manifest: InteropManifest = field(default_factory=InteropManifest),
        interop_py_funcs: dict[(str, Any)] = field(default_factory=`dict),
        _interop_callbacks: list[any] = field(default_factory=`list),
        native_layout: (NativeModuleLayout | None) = None,
        # The one OSP-fact store (kinds/tags/is_a/slots/uses), derived once per
        # compile by OspAnalysis.compute and read by every backend; no backend
        # keeps its own OSP tag/kind/slot state. None until a backend computes it.
        osp_model: (OspModel | None) = None,
        native_compat: bool = False,
        layout_registry: any = None,
        # Paths to C shared libraries discovered during native compilation.
        # Set by NaIRGenPass._process_clib_imports, consumed by NativeCompilePass
        # and nacompile CLI for transitive .so loading and AOT linking.
        _clib_paths: list[str] = field(default_factory=`list),
        # Maps each clib function's C name to the library it was imported from
        # (e.g. "InitWindow" -> "libraylib.dylib"). Set by the same pass and
        # consumed by the nacompile CLI to drive Mach-O two-level dylib ordinals.
        _clib_symbol_lib: dict[(str, str)] = field(default_factory=`dict),
        # Names of `:pub` functions/globals to export across the C ABI when
        # building a shared library (jac nacompile --shared). Recorded by
        # NaIRGenPass, propagated across AOT-linked imports by NativeCompilePass,
        # and consumed by the nacompile CLI + platform linkers to build the
        # export table (ELF .dynsym / Mach-O export trie / PE export directory).
        _exported_symbols: list[str] = field(default_factory=`list);

    has doc_ir: Doc { getter; setter(value: Doc); }
}

"""Code location info."""
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
    has tok_range: tuple[(Token, Token)] { getter; }
    has first_token: Token { getter; }
    has last_token: Token { getter; }

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
