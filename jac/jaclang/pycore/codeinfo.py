"""Code location info for AST nodes."""

from __future__ import annotations

import ast as ast3
from collections.abc import Sequence
from dataclasses import dataclass, field
from enum import Enum
from typing import TYPE_CHECKING, Any

if TYPE_CHECKING:
    from jaclang.compiler.passes.ecmascript.estree import (
        IndexInfo,
        SliceInfo,
    )
    from jaclang.compiler.passes.ecmascript.estree import (
        Node as EsNode,
    )
    from jaclang.compiler.passes.tool.doc_ir import Doc
    from jaclang.pycore.unitree import Source, Token


@dataclass
class ClientManifest:
    """Client-side rendering manifest metadata."""

    exports: list[str] = field(default_factory=list)
    globals: list[str] = field(default_factory=list)
    params: dict[str, list[str]] = field(default_factory=dict)
    globals_values: dict[str, Any] = field(default_factory=dict)
    has_client: bool = False
    imports: dict[str, str] = field(
        default_factory=dict
    )  # module_name -> resolved_path


class InteropContext(Enum):
    """Codespace context for interop bindings."""

    SERVER = "server"
    NATIVE = "native"
    CLIENT = "client"


@dataclass
class NativeFunctionInfo:
    """Metadata for an exported native function."""

    name: str
    ret_type: str = "int"
    param_types: list[str] = field(default_factory=list)
    param_names: list[str] = field(default_factory=list)


@dataclass
class NativeModuleInfo:
    """Metadata for a compiled .na.jac module."""

    mod_path: str
    llvm_module: Any = None  # llvmlite Module (before JIT)
    native_engine: Any = None  # MCJIT engine (after JIT)
    exported_functions: dict[str, NativeFunctionInfo] = field(default_factory=dict)


@dataclass
class InteropBinding:
    """A function callable across codespace boundaries.

    Records that a function defined in `source_context` is called from
    one or more other codespace contexts listed in `callers`.
    """

    name: str
    source_context: InteropContext
    callers: set[InteropContext] = field(default_factory=set)
    ret_type: str = "int"  # Jac-level type name
    param_types: list[str] = field(default_factory=list)
    param_names: list[str] = field(default_factory=list)
    ast_node: Any = None  # Reference to the Ability AST node
    route: list[InteropContext] = field(default_factory=list)
    source_module: str | None = None  # Path to source module (for cross-module imports)

    @property
    def is_direct(self) -> bool:
        """True if the bridge is a single hop (e.g. sv↔na)."""
        return len(self.route) == 2

    @property
    def is_composed(self) -> bool:
        """True if the bridge requires multiple hops (e.g. cl→sv→na)."""
        return len(self.route) > 2

    @property
    def is_cross_module(self) -> bool:
        """True if the function is imported from another module."""
        return self.source_module is not None


@dataclass
class InteropManifest:
    """All cross-boundary function bindings for a module.

    Built by InteropAnalysisPass, consumed by codegen passes.
    """

    bindings: dict[str, InteropBinding] = field(default_factory=dict)
    native_module_imports: dict[str, NativeModuleInfo] = field(default_factory=dict)

    @property
    def native_imports(self) -> list[InteropBinding]:
        """Server (Python) functions that native code calls."""
        return [
            b
            for b in self.bindings.values()
            if b.source_context == InteropContext.SERVER
            and InteropContext.NATIVE in b.callers
        ]

    @property
    def native_exports(self) -> list[InteropBinding]:
        """Native functions that server (Python) code calls."""
        return [
            b
            for b in self.bindings.values()
            if b.source_context == InteropContext.NATIVE
            and InteropContext.SERVER in b.callers
        ]

    @property
    def native_cross_module_imports(self) -> list[InteropBinding]:
        """Native functions imported from other .na.jac modules."""
        return [
            b
            for b in self.bindings.values()
            if b.source_context == InteropContext.NATIVE
            and InteropContext.NATIVE in b.callers
            and b.source_module is not None
        ]

    @property
    def server_exports_to_client(self) -> list[InteropBinding]:
        """Server functions that client (JS) code calls."""
        return [
            b
            for b in self.bindings.values()
            if b.source_context == InteropContext.SERVER
            and InteropContext.CLIENT in b.callers
        ]

    # Jac type → ctypes type name mapping for sv↔na bridges
    JAC_TO_CTYPES: dict[str, str] = field(
        default_factory=lambda: {
            "int": "ctypes.c_int64",
            "float": "ctypes.c_double",
            "bool": "ctypes.c_bool",
            "str": "ctypes.c_char_p",
        }
    )


class CodeGenTarget:
    """Code generation target."""

    def __init__(self) -> None:
        """Initialize code generation target."""
        self.py: str = ""
        self.jac: str = ""
        self._doc_ir: Doc | None = (
            None  # Lazily initialized to allow doc_ir.jac conversion
        )
        self.js: str = ""
        self.client_manifest: ClientManifest = ClientManifest()
        self.py_ast: list[ast3.AST] = []
        self.py_bytecode: bytes | None = None
        self.es_ast: EsNode | Sequence[EsNode] | SliceInfo | IndexInfo | None = None
        self.llvm_ir: Any = None
        self.native_engine: Any = None
        self.interop_manifest: InteropManifest = InteropManifest()
        self.interop_py_funcs: dict[str, Any] = {}  # Python funcs for native callbacks
        self._interop_callbacks: list[Any] = []  # Prevent callback garbage collection

    @property
    def doc_ir(self) -> Doc:
        """Lazy initialization of doc_ir to allow doc_ir.jac conversion."""
        if self._doc_ir is None:
            import jaclang.compiler.passes.tool.doc_ir as doc

            self._doc_ir = doc.Text("")
        return self._doc_ir

    @doc_ir.setter
    def doc_ir(self, value: Doc) -> None:
        """Set doc_ir value."""
        self._doc_ir = value


class CodeLocInfo:
    """Code location info."""

    def __init__(
        self,
        first_tok: Token,
        last_tok: Token,
    ) -> None:
        """Initialize code location info."""
        self.first_tok = first_tok
        self.last_tok = last_tok

    @property
    def orig_src(self) -> Source:
        """Get file source."""
        return self.first_tok.orig_src

    @property
    def mod_path(self) -> str:
        return self.first_tok.orig_src.file_path

    @property
    def first_line(self) -> int:
        return self.first_tok.line_no

    @property
    def last_line(self) -> int:
        return self.last_tok.end_line

    @property
    def col_start(self) -> int:
        return self.first_tok.c_start

    @property
    def col_end(self) -> int:
        return self.last_tok.c_end

    @property
    def pos_start(self) -> int:
        return self.first_tok.pos_start

    @property
    def pos_end(self) -> int:
        return self.last_tok.pos_end

    @property
    def tok_range(self) -> tuple[Token, Token]:
        return (self.first_tok, self.last_tok)

    @property
    def first_token(self) -> Token:
        return self.first_tok

    @property
    def last_token(self) -> Token:
        return self.last_tok

    def update_token_range(self, first_tok: Token, last_tok: Token) -> None:
        self.first_tok = first_tok
        self.last_tok = last_tok

    def update_first_token(self, first_tok: Token) -> None:
        self.first_tok = first_tok

    def update_last_token(self, last_tok: Token) -> None:
        self.last_tok = last_tok

    def __str__(self) -> str:
        return f"{self.first_line}:{self.col_start} - {self.last_line}:{self.col_end}"
