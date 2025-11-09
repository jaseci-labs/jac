"""Code location info for AST nodes."""

from __future__ import annotations

import ast as ast3
from dataclasses import dataclass, field
from typing import Any, Optional, TYPE_CHECKING, TypeAlias

if TYPE_CHECKING:
    from jaclang.compiler.passes.ecmascript.estree import Node as EsNode
    from jaclang.compiler.unitree import Source, Token

    try:
        from llvmlite import ir as _ir

        LlvmModule: TypeAlias = _ir.Module
    except ImportError:
        LlvmModule: TypeAlias = Any  # type: ignore


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


class CodeGenTarget:
    """Code generation target.

    This class stores generated code in various target formats including
    Python, JavaScript, and LLVM IR.
    """

    def __init__(self) -> None:
        """Initialize code generation target."""
        import jaclang.compiler.passes.tool.doc_ir as doc

        # Python code generation
        self.py: str = ""
        self.py_ast: list[ast3.AST] = []
        self.py_bytecode: Optional[bytes] = None

        # Jac code generation
        self.jac: str = ""

        # Documentation generation
        self.doc_ir: doc.DocType = doc.Text("")

        # JavaScript/ECMAScript generation
        self.js: str = ""
        self.es_ast: Optional[EsNode] = None
        self.client_manifest: ClientManifest = ClientManifest()

        # LLVM IR generation (type-safe with proper annotations)
        self.llvm_module: LlvmModule | None = None  # LLVM Module object
        self.llvm_ir: str = ""  # LLVM IR text representation
        self.llvm_metadata: dict[str, dict[str, Any]] = {}  # Function signatures
        self.llvm_triple: str = ""  # Target triple (e.g., "x86_64-unknown-linux-gnu")
        self.llvm_data_layout: str = ""  # Data layout string


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
