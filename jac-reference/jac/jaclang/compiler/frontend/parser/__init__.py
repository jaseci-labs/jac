"""Jac Parser - Hand-written recursive descent parser.

This package provides the lexer, parser, and token definitions for Jac.
All modules are compiled by jac0 during bootstrap.
"""

from jaclang.compiler.frontend.parser.frontend import parse
from jaclang.compiler.frontend.parser.lexer import Lexer
from jaclang.compiler.frontend.parser.parser import Parser
from jaclang.compiler.frontend.parser.tokens import (
    LexToken,
    SourceLoc,
    TokenKind,
    lookup_keyword,
)
from jaclang.compiler.frontend.parser.tokens import LexToken as Token

__all__ = [
    "Token",
    "LexToken",
    "TokenKind",
    "SourceLoc",
    "lookup_keyword",
    "Lexer",
    "Parser",
    "parse",
]
