"""Code location info for AST nodes."""

from __future__ import annotations

import ast as ast3
from collections.abc import Sequence
from dataclasses import dataclass, field
from typing import TYPE_CHECKING, Any

if TYPE_CHECKING:
    from jaclang.compiler.passes.ecmascript.estree import (
        IndexInfo,
        SliceInfo,
    )
    from jaclang.compiler.passes.ecmascript.estree import (
        Node as EsNode,
    )
    from jaclang.compiler.unitree import Source, Token


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
    """Code generation target."""

    def __init__(self) -> None:
        """Initialize code generation target."""
        import jaclang.compiler.passes.tool.doc_ir as doc

        self.py: str = ""
        self.jac: str = ""
        self.doc_ir: doc.DocType = doc.Text("")
        self.js: str = ""
        self.client_manifest: ClientManifest = ClientManifest()
        self.py_ast: list[ast3.AST] = []
        self.py_bytecode: bytes | None = None
        self.es_ast: EsNode | Sequence[EsNode] | SliceInfo | IndexInfo | None = None


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
