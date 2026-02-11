"""Code location info for AST nodes."""
import ast as ast3;
import from collections.abc { Sequence }
import from dataclasses { dataclass, field }
import from enum { Enum }
import from typing { TYPE_CHECKING, Any }

with entry {
    if TYPE_CHECKING {
        import from jaclang.compiler.passes.ecmascript.estree { IndexInfo, SliceInfo }
        import from jaclang.compiler.passes.ecmascript.estree { Node as EsNode }
        import from jaclang.compiler.passes.tool.doc_ir { Doc }
        import from jaclang.jac0core.unitree { Source, Token }
    }
}

"""Client-side rendering manifest metadata."""
@dataclass
class ClientManifest {
    with entry {
        exports: list = field(default_factory=`list);
        globals: list = field(default_factory=`list);
        params: dict[(str, list)] = field(default_factory=`dict);
        globals_values: dict[(str, Any)] = field(default_factory=`dict);
        has_client: bool = False;
        imports: dict[(str, str)] = field(default_factory=`dict);
    }
}

"""Codespace context for interop bindings."""
class InteropContext(Enum) {
    with entry {
        SERVER = 'server';
        NATIVE = 'native';
        CLIENT = 'client';
    }
}

"""Metadata for an exported native function."""
@dataclass
class NativeFunctionInfo {
    with entry {
        name: str;
        ret_type: str = 'int';
        param_types: list = field(default_factory=`list);
        param_names: list = field(default_factory=`list);
    }
}

"""Metadata for a compiled .na.jac module."""
@dataclass
class NativeModuleInfo {
    with entry {
        mod_path: str;
        llvm_module: Any = None;
        native_engine: Any = None;
        exported_functions: dict[(str, NativeFunctionInfo)] = field(
            default_factory=`dict
        );
    }
}

"""A function callable across codespace boundaries.

    Records that a function defined in `source_context` is called from
    one or more other codespace contexts listed in `callers`.
    """
@dataclass
class InteropBinding {
    with entry {
        name: str;
        source_context: InteropContext;
        callers: set[InteropContext] = field(default_factory=`set);
        ret_type: str = 'int';
        param_types: list = field(default_factory=`list);
        param_names: list = field(default_factory=`list);
        ast_node: Any = None;
        route: list[InteropContext] = field(default_factory=`list);
        source_module: (str | None) = None;
    }

    """True if the bridge is a single hop (e.g. svâna)."""
    @property
    def is_direct(self: InteropBinding) -> bool {
        return (len(self.route) == 2);
    }

    """True if the bridge requires multiple hops (e.g. clâsvâna)."""
    @property
    def is_composed(self: InteropBinding) -> bool {
        return (len(self.route) > 2);
    }

    """True if the function is imported from another module."""
    @property
    def is_cross_module(self: InteropBinding) -> bool {
        return (self.source_module is not None);
    }
}

"""All cross-boundary function bindings for a module.

    Built by InteropAnalysisPass, consumed by codegen passes.
    """
@dataclass
class InteropManifest {
    with entry {
        bindings: dict[(str, InteropBinding)] = field(default_factory=`dict);
        native_module_imports: dict[(str, NativeModuleInfo)] = field(
            default_factory=`dict
        );
    }

    """Server (Python) functions that native code calls."""
    @property
    def native_imports(self: InteropManifest) -> list[InteropBinding] {
        return [
            b
            for b in self.bindings.values()
            if (
                (b.source_context == InteropContext.SERVER)
                and (InteropContext.NATIVE in b.callers)
            )
        ];
    }

    """Native functions that server (Python) code calls."""
    @property
    def native_exports(self: InteropManifest) -> list[InteropBinding] {
        return [
            b
            for b in self.bindings.values()
            if (
                (b.source_context == InteropContext.NATIVE)
                and (InteropContext.SERVER in b.callers)
            )
        ];
    }

    """Native functions imported from other .na.jac modules."""
    @property
    def native_cross_module_imports(self: InteropManifest) -> list[InteropBinding] {
        return [
            b
            for b in self.bindings.values()
            if (
                (b.source_context == InteropContext.NATIVE)
                and (InteropContext.NATIVE in b.callers)
                and (b.source_module is not None)
            )
        ];
    }

    """Server functions that client (JS) code calls."""
    @property
    def server_exports_to_client(self: InteropManifest) -> list[InteropBinding] {
        return [
            b
            for b in self.bindings.values()
            if (
                (b.source_context == InteropContext.SERVER)
                and (InteropContext.CLIENT in b.callers)
            )
        ];
    }

    with entry {
        JAC_TO_CTYPES: dict[(str, str)] = field(
            default_factory=lambda() :
                {
                    'int': 'ctypes.c_int64',
                    'float': 'ctypes.c_double',
                    'bool': 'ctypes.c_bool',
                    'str': 'ctypes.c_char_p'
                }
        );
    }
}

"""Code generation target."""
class CodeGenTarget {
    """Initialize code generation target."""
    def init(self: CodeGenTarget) -> None {
        self.py: str = '';
        self.jac: str = '';
        self._doc_ir: (Doc | None) = None;
        self.js: str = '';
        self.client_manifest: ClientManifest = ClientManifest();
        self.py_ast: list = [];
        self.py_bytecode: (bytes | None) = None;
        self.es_ast: EsNode | Sequence[EsNode] | SliceInfo | IndexInfo | None = None;
        self.llvm_ir: Any = None;
        self.native_engine: Any = None;
        self.interop_manifest: InteropManifest = InteropManifest();
        self.interop_py_funcs: dict[(str, Any)] = {};
        self._interop_callbacks: list[Any] = [];
    }

    """Lazy initialization of doc_ir to allow doc_ir.jac conversion."""
    @property
    def doc_ir(self: CodeGenTarget) -> Doc {
        if (self._doc_ir is None) {
            import jaclang.compiler.passes.tool.doc_ir as doc;
            self._doc_ir = doc.Text('');
        }
        return self._doc_ir;
    }

    """Set doc_ir value."""
    @doc_ir.setter
    def doc_ir(self: CodeGenTarget, value: Doc) -> None {
        self._doc_ir = value;
    }
}

"""Code location info."""
class CodeLocInfo {
    """Initialize code location info."""
    def init(self: CodeLocInfo, first_tok: Token, last_tok: Token) -> None {
        self.first_tok = first_tok;
        self.last_tok = last_tok;
    }

    """Get file source."""
    @property
    def orig_src(self: CodeLocInfo) -> Source {
        return self.first_tok.orig_src;
    }

    @property
    def mod_path(self: CodeLocInfo) -> str {
        return self.first_tok.orig_src.file_path;
    }

    @property
    def first_line(self: CodeLocInfo) -> int {
        return self.first_tok.line_no;
    }

    @property
    def last_line(self: CodeLocInfo) -> int {
        return self.last_tok.end_line;
    }

    @property
    def col_start(self: CodeLocInfo) -> int {
        return self.first_tok.c_start;
    }

    @property
    def col_end(self: CodeLocInfo) -> int {
        return self.last_tok.c_end;
    }

    @property
    def pos_start(self: CodeLocInfo) -> int {
        return self.first_tok.pos_start;
    }

    @property
    def pos_end(self: CodeLocInfo) -> int {
        return self.last_tok.pos_end;
    }

    @property
    def tok_range(self: CodeLocInfo) -> tuple[(Token, Token)] {
        return (self.first_tok, self.last_tok);
    }

    @property
    def first_token(self: CodeLocInfo) -> Token {
        return self.first_tok;
    }

    @property
    def last_token(self: CodeLocInfo) -> Token {
        return self.last_tok;
    }

    def update_token_range(
        self: CodeLocInfo, first_tok: Token, last_tok: Token
    ) -> None {
        self.first_tok = first_tok;
        self.last_tok = last_tok;
    }

    def update_first_token(self: CodeLocInfo, first_tok: Token) -> None {
        self.first_tok = first_tok;
    }

    def update_last_token(self: CodeLocInfo, last_tok: Token) -> None {
        self.last_tok = last_tok;
    }

    def __str__(self: CodeLocInfo) -> str {
        return f"{self.first_line}:{self.col_start} - {self.last_line}:{self.col_end}";
    }
}
