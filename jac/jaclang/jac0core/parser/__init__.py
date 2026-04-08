"""Jac Parser - Hand-written recursive descent parser.

This package provides the lexer, parser, and token definitions for Jac.
All modules are compiled by jac0 during bootstrap.
"""

from jaclang.jac0core.parser.lexer import Lexer
from jaclang.jac0core.parser.parser import Parser, parse
from jaclang.jac0core.parser.tokens import SourceLoc, Token, TokenKind, lookup_keyword

__all__ = [
    "Token",
    "TokenKind",
    "SourceLoc",
    "lookup_keyword",
    "Lexer",
    "Parser",
    "parse",
]

# After all bootstrap .na.jac modules are imported, load cached native
# bitcode into a shared MCJIT engine and install native wrappers.
try:
    from jaclang.meta_importer import JacMetaImporter

    JacMetaImporter.finalize_bootstrap_native()
except Exception:
    pass
