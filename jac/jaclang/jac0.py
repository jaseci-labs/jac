"""jac0 - Bootstrap Jac-to-Python transpiler.

A single-file compiler that reads the Jac subset used in jac0core
and emits equivalent Python source code. Called in-memory by
meta_importer._exec_bootstrap() at import time — no disk I/O needed.
"""

from __future__ import annotations

import enum
import os
from dataclasses import dataclass, field

# =============================================================================
# Token Types
# =============================================================================


class TT(enum.Enum):
    """Token types for the Jac0 lexer."""

    NAME = "NAME"
    NUMBER = "NUMBER"
    STRING = "STRING"
    EOF = "EOF"
    LBRACE = "LBRACE"
    RBRACE = "RBRACE"
    LPAREN = "LPAREN"
    RPAREN = "RPAREN"
    LBRACKET = "LBRACKET"
    RBRACKET = "RBRACKET"
    SEMI = "SEMI"
    COLON = "COLON"
    COMMA = "COMMA"
    DOT = "DOT"
    QDOT = "QDOT"
    AT = "AT"
    ARROW = "ARROW"
    ELLIPSIS = "ELLIPSIS"
    OP = "OP"


@dataclass
class Token:
    """A lexer token."""

    type: TT
    value: str
    line: int = 0
    col: int = 0
    backtick: bool = False


KEYWORDS = {
    "import",
    "from",
    "class",
    "obj",
    "node",
    "edge",
    "walker",
    "def",
    "can",
    "static",
    "has",
    "glob",
    "impl",
    "with",
    "entry",
    "if",
    "elif",
    "else",
    "for",
    "while",
    "try",
    "except",
    "finally",
    "return",
    "raise",
    "assert",
    "break",
    "continue",
    "del",
    "global",
    "nonlocal",
    "yield",
    "as",
    "in",
    "not",
    "and",
    "or",
    "is",
    "None",
    "True",
    "False",
    "lambda",
    "pass",
    "enum",
    "async",
    "await",
    "by",
    "postinit",
}


# =============================================================================
# Lexer
# =============================================================================


class Lexer:
    """Tokenize Jac source code."""

    def __init__(self, source: str, filename: str = "<unknown>") -> None:
        self.source = source
        self._source_len = len(source)
        self.filename = filename
        self.pos = 0
        self.line = 1
        self.col = 1
        self.tokens: list[Token] = []
        self._tokenize()

    def _ch(self) -> str:
        return self.source[self.pos] if self.pos < self._source_len else ""

    def _peek(self, offset: int = 0) -> str:
        p = self.pos + offset
        return self.source[p] if p < self._source_len else ""

    def _advance(self, n: int = 1) -> str:
        result = self.source[self.pos : self.pos + n]
        for c in result:
            if c == "\n":
                self.line += 1
                self.col = 1
            else:
                self.col += 1
        self.pos += n
        return result

    def _emit(self, tt: TT, value: str, line: int, col: int) -> None:
        self.tokens.append(Token(tt, value, line, col))

    def _skip_ws_and_comments(self) -> None:
        while self.pos < self._source_len:
            c = self._ch()
            if c in " \t\r\n":
                self._advance()
            elif c == "#":
                if self._peek(1) == "*":
                    # Block comment #* ... *#
                    self._advance(2)
                    while self.pos < self._source_len:
                        if self._ch() == "*" and self._peek(1) == "#":
                            self._advance(2)
                            break
                        self._advance()
                else:
                    # Line comment
                    while self.pos < self._source_len and self._ch() != "\n":
                        self._advance()
            else:
                break

    def _is_string_prefix(self) -> bool:
        """Check if current position starts a string (with optional prefix)."""
        save = self.pos
        while self.pos < self._source_len and self.source[self.pos] in "fFrRbBuU":
            self.pos += 1
        result = self.pos < self._source_len and self.source[self.pos] in "\"'"
        self.pos = save
        return result

    def _read_string(self) -> None:
        line, col = self.line, self.col
        start = self.pos
        # Read prefix
        while self.pos < self._source_len and self.source[self.pos] in "fFrRbBuU":
            self._advance()
        # Read quote
        q = self._ch()
        self._advance()
        # Triple quote?
        triple = False
        if self._ch() == q and self._peek(1) == q:
            triple = True
            self._advance(2)
        # Read body
        while self.pos < self._source_len:
            c = self._ch()
            if c == "\\":
                self._advance(2)
                continue
            if triple:
                if c == q and self._peek(1) == q and self._peek(2) == q:
                    self._advance(3)
                    break
                self._advance()
            else:
                if c == q:
                    self._advance()
                    break
                self._advance()
        value = self.source[start : self.pos]
        # Collapse newlines in non-triple-quoted strings (py2jac line wrapping)
        if not triple and "\n" in value:
            # Find the opening quote position in the value
            qi = len(value) - len(value.lstrip("fFrRbBuU")) + 1
            inner = value[qi:-1]  # strip prefix+quote and closing quote
            inner = " ".join(inner.split())  # collapse whitespace
            value = value[:qi] + inner + value[-1]
        self._emit(TT.STRING, value, line, col)

    def _read_number(self) -> None:
        line, col = self.line, self.col
        start = self.pos
        if self._ch() == "0" and self._peek(1) in "xXoObB":
            self._advance(2)
            while self.pos < self._source_len and (
                self._ch().isalnum() or self._ch() == "_"
            ):
                self._advance()
        else:
            while self.pos < self._source_len and (
                self._ch().isdigit() or self._ch() == "_"
            ):
                self._advance()
            if self._ch() == "." and self._peek(1) != ".":
                self._advance()
                while self.pos < self._source_len and (
                    self._ch().isdigit() or self._ch() == "_"
                ):
                    self._advance()
            if self._ch() in "eE":
                self._advance()
                if self._ch() in "+-":
                    self._advance()
                while self.pos < self._source_len and (
                    self._ch().isdigit() or self._ch() == "_"
                ):
                    self._advance()
        if self._ch() in "jJ":
            self._advance()
        self._emit(TT.NUMBER, self.source[start : self.pos], line, col)

    def _read_name(self) -> None:
        line, col = self.line, self.col
        start = self.pos
        while self.pos < self._source_len and (
            self._ch().isalnum() or self._ch() == "_"
        ):
            self._advance()
        self._emit(TT.NAME, self.source[start : self.pos], line, col)

    def _read_backtick_name(self) -> None:
        """Read `name and emit as NAME with backtick flag (strip backtick char)."""
        line, col = self.line, self.col
        self._advance()  # skip backtick
        start = self.pos
        while self.pos < self._source_len and (
            self._ch().isalnum() or self._ch() == "_"
        ):
            self._advance()
        tok = Token(TT.NAME, self.source[start : self.pos], line, col, backtick=True)
        self.tokens.append(tok)

    def _tokenize(self) -> None:
        two_char_ops = {
            "==",
            "!=",
            "<=",
            ">=",
            "**",
            "//",
            "<<",
            ">>",
            "+=",
            "-=",
            "*=",
            "/=",
            "%=",
            "&=",
            "|=",
            "^=",
            ":=",
            "@=",
        }
        three_char_ops = {"**=", "//=", ">>=", "<<="}

        while True:
            self._skip_ws_and_comments()
            if self.pos >= self._source_len:
                break
            line, col = self.line, self.col
            c = self._ch()

            # Strings
            if c in "\"'" or (c in "fFrRbBuU" and self._is_string_prefix()):
                self._read_string()
                continue

            # Numbers
            if c.isdigit() or (c == "." and self._peek(1).isdigit()):
                self._read_number()
                continue

            # Backtick names
            if c == "`":
                self._read_backtick_name()
                continue

            # Names / keywords
            if c.isalpha() or c == "_":
                self._read_name()
                continue

            # Three-char tokens
            three = self.source[self.pos : self.pos + 3]
            if three == "...":
                self._advance(3)
                self._emit(TT.ELLIPSIS, "...", line, col)
                continue
            if three in three_char_ops:
                self._advance(3)
                self._emit(TT.OP, three, line, col)
                continue

            # Two-char tokens
            two = self.source[self.pos : self.pos + 2]
            if two == "->":
                self._advance(2)
                self._emit(TT.ARROW, "->", line, col)
                continue
            if two == "?.":
                # Null-safe access: emit QDOT, handled in transform_tokens
                self._advance(2)
                self._emit(TT.QDOT, "?.", line, col)
                continue
            if two in two_char_ops:
                self._advance(2)
                self._emit(TT.OP, two, line, col)
                continue

            # Single-char tokens
            single = {
                "{": TT.LBRACE,
                "}": TT.RBRACE,
                "(": TT.LPAREN,
                ")": TT.RPAREN,
                "[": TT.LBRACKET,
                "]": TT.RBRACKET,
                ";": TT.SEMI,
                ":": TT.COLON,
                ",": TT.COMMA,
                ".": TT.DOT,
                "@": TT.AT,
            }
            if c in single:
                self._advance()
                self._emit(single[c], c, line, col)
                continue

            # Operators
            if c in "=+-*/%&|^~<>!":
                self._advance()
                self._emit(TT.OP, c, line, col)
                continue

            # Unknown character - skip
            self._advance()

        self._emit(TT.EOF, "", self.line, self.col)


# =============================================================================
# AST Nodes
# =============================================================================


@dataclass
class Module:
    body: list = field(default_factory=list)
    filename: str = ""


@dataclass
class Import:
    module: str = ""
    names: list = field(default_factory=list)
    alias: str = ""
    is_from: bool = False


@dataclass
class ClassDef:
    name: str = ""
    bases: str = ""
    body: list = field(default_factory=list)
    decorators: list = field(default_factory=list)
    is_dataclass: bool = False


@dataclass
class EnumDef:
    name: str = ""
    bases: str = ""
    body: list = field(default_factory=list)
    decorators: list = field(default_factory=list)


@dataclass
class FuncDef:
    name: str = ""
    params: list = field(default_factory=list)
    return_type: str = ""
    body: list = field(default_factory=list)
    decorators: list = field(default_factory=list)
    is_static: bool = False
    is_async: bool = False


@dataclass
class Param:
    name: str = ""
    type_ann: str = ""
    default: str = ""
    is_star: bool = False
    is_dstar: bool = False
    star_sep: bool = False


@dataclass
class HasVar:
    name: str = ""
    type_ann: str = ""
    default: str = ""
    by_postinit: bool = False


@dataclass
class HasDecl:
    vars: list = field(default_factory=list)


@dataclass
class GlobDecl:
    assignments: list = field(default_factory=list)


@dataclass
class ImplDef:
    target: str = ""
    params: list = field(default_factory=list)
    return_type: str = ""
    body: list = field(default_factory=list)
    decorators: list = field(default_factory=list)
    is_static: bool = False
    is_async: bool = False


@dataclass
class WithEntry:
    body: list = field(default_factory=list)


@dataclass
class IfStmt:
    condition: str = ""
    body: list = field(default_factory=list)
    elifs: list = field(default_factory=list)
    else_body: list = field(default_factory=list)


@dataclass
class ForStmt:
    target: str = ""
    iter_expr: str = ""
    body: list = field(default_factory=list)
    is_async: bool = False


@dataclass
class WhileStmt:
    condition: str = ""
    body: list = field(default_factory=list)


@dataclass
class TryStmt:
    body: list = field(default_factory=list)
    excepts: list = field(default_factory=list)
    else_body: list = field(default_factory=list)
    finally_body: list = field(default_factory=list)


@dataclass
class WithStmt:
    items: str = ""
    body: list = field(default_factory=list)
    is_async: bool = False


@dataclass
class ReturnStmt:
    expr: str = ""


@dataclass
class YieldStmt:
    expr: str = ""


@dataclass
class RaiseStmt:
    expr: str = ""


@dataclass
class AssertStmt:
    expr: str = ""


@dataclass
class MatchStmt:
    subject: str = ""
    cases: list = field(default_factory=list)  # list of (pattern, body)


@dataclass
class DeleteStmt:
    expr: str = ""


@dataclass
class GlobalStmt:
    names: list = field(default_factory=list)


@dataclass
class NonlocalStmt:
    names: list = field(default_factory=list)


@dataclass
class ExprStmt:
    expr: str = ""


@dataclass
class PassStmt:
    pass


@dataclass
class BreakStmt:
    pass


@dataclass
class ContinueStmt:
    pass


# =============================================================================
# Token Transformations
# =============================================================================

_NO_SPACE_BEFORE = {".", ")", "]", ",", ":", ";"}
_NO_SPACE_AFTER = {".", "(", "[", "~"}


def _join_tokens(tokens: list[Token]) -> str:
    """Join tokens into a Python expression string with appropriate spacing."""
    if not tokens:
        return ""
    parts = [tokens[0].value]
    for i in range(1, len(tokens)):
        prev = tokens[i - 1]
        cur = tokens[i]
        pv, cv = prev.value, cur.value
        need_space = True
        if (
            cv in _NO_SPACE_BEFORE
            or pv in _NO_SPACE_AFTER
            or prev.type == TT.NAME
            and cv in ("(", "[")
            or prev.type == TT.STRING
            and cv in (".", "(", "[")
            or prev.type == TT.NUMBER
            and cv == "."
            or pv in (")", "]")
            and cv in (".", "(", "[")
            or pv == ")"
            and cv == ")"
            or pv == "]"
            and cv == "]"
        ):
            need_space = False
        if need_space:
            parts.append(" ")
        parts.append(cv)
    return "".join(parts)


def _pop_primary_expr(out: list[Token]) -> list[Token]:
    """Pop tokens forming the trailing primary expression from out.

    Handles: NAME, dotted names (a.b.c), function calls f(...), subscripts x[...].
    Used by the ?. (QDOT) transform to extract the object expression.
    """
    if not out:
        return []
    result: list[Token] = []
    while out:
        last = out[-1]
        if last.type == TT.NAME or last.type == TT.NUMBER or last.type == TT.STRING:
            result.append(out.pop())
            # If preceded by DOT, continue collecting the chain
            if out and out[-1].type == TT.DOT:
                result.append(out.pop())
                continue
            break
        elif last.type in (TT.RPAREN, TT.RBRACKET):
            # Match back to the corresponding opening delimiter
            close_t = last.type
            open_t = TT.LPAREN if close_t == TT.RPAREN else TT.LBRACKET
            depth = 0
            while out:
                t = out.pop()
                result.append(t)
                if t.type == close_t:
                    depth += 1
                elif t.type == open_t:
                    depth -= 1
                    if depth == 0:
                        break
            # After matched delimiters, check for preceding name or dot chain
            if out and out[-1].type == TT.NAME:
                result.append(out.pop())
                if out and out[-1].type == TT.DOT:
                    result.append(out.pop())
                    continue
            elif out and out[-1].type == TT.DOT:
                result.append(out.pop())
                continue
            break
        else:
            break
    result.reverse()
    return result


def transform_tokens(tokens: list[Token]) -> list[Token]:
    """Apply Jac→Python transformations on a token list.

    1. super.method → super().method
    2. NAME[( ... )] → NAME[ ... ] (Jac generic syntax)
    3. lambda(args): → lambda args: (Jac lambda syntax)
    """
    out: list[Token] = []
    i = 0
    bracket_stack: list[int] = []
    bracket_depth = 0

    while i < len(tokens):
        tok = tokens[i]

        # === lambda NAME: TYPE : body → lambda NAME: body (no parens) ===
        if (
            tok.type == TT.NAME
            and tok.value == "lambda"
            and i + 1 < len(tokens)
            and tokens[i + 1].type != TT.LPAREN
        ):
            # Find the first two colons at depth 0 to detect type annotation
            j = i + 1
            d = 0
            colon_positions: list[int] = []
            while j < len(tokens) and len(colon_positions) < 2:
                t = tokens[j]
                if t.type in (TT.LPAREN, TT.LBRACKET, TT.LBRACE):
                    d += 1
                elif t.type in (TT.RPAREN, TT.RBRACKET, TT.RBRACE):
                    d -= 1
                    if d < 0:
                        break
                if t.type == TT.COLON and d == 0:
                    colon_positions.append(j)
                j += 1
            if len(colon_positions) == 2:
                # Two colons: first is type annotation, second is body sep
                # Emit lambda + params up to first colon, skip type, continue from second colon
                out.append(tok)  # emit 'lambda'
                for k in range(i + 1, colon_positions[0]):
                    out.append(tokens[k])
                i = colon_positions[1]  # next iteration emits the body separator ':'
                continue
            # else: single colon or none — pass through normally

        # === super.x → super().x  (with init → __init__, postinit → __post_init__) ===
        if (
            tok.type == TT.NAME
            and tok.value == "super"
            and i + 1 < len(tokens)
            and tokens[i + 1].type == TT.DOT
        ):
            out.append(Token(TT.NAME, "super()", tok.line, tok.col))
            # Check if method name after DOT needs dunder conversion
            if i + 2 < len(tokens) and tokens[i + 2].type == TT.NAME:
                mname = tokens[i + 2].value
                dunder_map = {
                    "init": "__init__",
                    "postinit": "__post_init__",
                    "init_subclass": "__init_subclass__",
                }
                if mname in dunder_map:
                    out.append(tokens[i + 1])  # DOT
                    out.append(
                        Token(
                            TT.NAME,
                            dunder_map[mname],
                            tokens[i + 2].line,
                            tokens[i + 2].col,
                        )
                    )
                    i += 3
                    continue
            i += 1
            continue

        # === lambda(args): → lambda args: (strip type annotations) ===
        if (
            tok.type == TT.NAME
            and tok.value == "lambda"
            and i + 1 < len(tokens)
            and tokens[i + 1].type == TT.LPAREN
        ):
            out.append(tok)  # emit 'lambda'
            i += 2  # skip 'lambda' and '('
            depth = 1
            skip_type = False
            type_depth = 0
            while i < len(tokens) and depth > 0:
                t = tokens[i]
                if t.type == TT.LPAREN:
                    if skip_type:
                        type_depth += 1
                        i += 1
                        continue
                    depth += 1
                elif t.type == TT.RPAREN:
                    if skip_type and type_depth > 0:
                        type_depth -= 1
                        i += 1
                        continue
                    depth -= 1
                    if depth == 0:
                        i += 1  # skip closing )
                        break
                # At param level, ':' starts type annotation → skip it
                if depth == 1 and not skip_type and t.type == TT.COLON:
                    skip_type = True
                    type_depth = 0
                    i += 1
                    continue
                # ',' or '=' at param level ends type skip
                if (
                    skip_type
                    and type_depth == 0
                    and (t.type == TT.COMMA or (t.type == TT.OP and t.value == "="))
                ):
                    skip_type = False
                if skip_type:
                    i += 1
                    continue
                if depth > 0:
                    out.append(t)
                i += 1
            continue

        # === NAME[( → NAME[, skip ( ===
        if (
            tok.type == TT.LBRACKET
            and i + 1 < len(tokens)
            and tokens[i + 1].type == TT.LPAREN
            and out
            and out[-1].type == TT.NAME
        ):
            bracket_depth += 1
            bracket_stack.append(bracket_depth)
            out.append(tok)  # emit [
            i += 2  # skip [ and (
            continue

        # Track bracket depth
        if tok.type == TT.LBRACKET:
            bracket_depth += 1
        elif tok.type == TT.RBRACKET:
            bracket_depth -= 1

        # === )] at generic depth → ] ===
        if (
            tok.type == TT.RPAREN
            and bracket_stack
            and i + 1 < len(tokens)
            and tokens[i + 1].type == TT.RBRACKET
            and bracket_stack[-1] == bracket_depth
        ):
            bracket_stack.pop()
            bracket_depth -= 1
            out.append(Token(TT.RBRACKET, "]", tok.line, tok.col))
            i += 2  # skip ) and ]
            continue

        # === .init → .__init__  (general dunder method name conversion) ===
        if tok.type == TT.NAME and out and out[-1].type == TT.DOT:
            dunder_map = {
                "init": "__init__",
                "postinit": "__post_init__",
                "init_subclass": "__init_subclass__",
            }
            if tok.value in dunder_map:
                out.append(Token(TT.NAME, dunder_map[tok.value], tok.line, tok.col))
                i += 1
                continue

        # === x?.attr → getattr(x, "attr", None) (null-safe access) ===
        if (
            tok.type == TT.QDOT
            and i + 1 < len(tokens)
            and tokens[i + 1].type == TT.NAME
        ):
            attr_name = tokens[i + 1].value
            # Pop preceding primary expression from out
            obj_toks = _pop_primary_expr(out)
            # Emit: getattr(obj_expr, "attr_name", None)
            out.append(Token(TT.NAME, "getattr", tok.line, tok.col))
            out.append(Token(TT.LPAREN, "(", tok.line, tok.col))
            out.extend(obj_toks)
            out.append(Token(TT.COMMA, ",", tok.line, tok.col))
            out.append(Token(TT.STRING, f'"{attr_name}"', tok.line, tok.col))
            out.append(Token(TT.COMMA, ",", tok.line, tok.col))
            out.append(Token(TT.NAME, "None", tok.line, tok.col))
            out.append(Token(TT.RPAREN, ")", tok.line, tok.col))
            i += 2  # skip QDOT and NAME
            continue

        out.append(tok)
        i += 1

    return out


def tokens_to_str(tokens: list[Token]) -> str:
    """Transform and join tokens into a Python expression string."""
    return _join_tokens(transform_tokens(tokens))


# =============================================================================
# Parser
# =============================================================================


class ParseError(Exception):
    pass


class Parser:
    """Recursive descent parser for Jac0 subset."""

    def __init__(
        self, tokens: list[Token], source: str = "", filename: str = ""
    ) -> None:
        self.tokens = tokens
        self._tokens_len = len(tokens)
        self.pos = 0
        self.source = source
        self.filename = filename

    def _peek(self, offset: int = 0) -> Token:
        p = self.pos + offset
        if p < self._tokens_len:
            return self.tokens[p]
        return self.tokens[-1]  # EOF

    def _advance(self) -> Token:
        tok = self.tokens[self.pos]
        if tok.type != TT.EOF:
            self.pos += 1
        return tok

    def _at(self, tt: TT, value: str | None = None) -> bool:
        tok = self._peek()
        return tok.type == tt and (value is None or tok.value == value)

    def _match(self, tt: TT, value: str | None = None) -> Token | None:
        if self._at(tt, value):
            return self._advance()
        return None

    def _expect(self, tt: TT, value: str | None = None) -> Token:
        tok = self._advance()
        if tok.type != tt or (value is not None and tok.value != value):
            exp = f"{tt.value}" + (f" {value!r}" if value else "")
            raise ParseError(
                f"{self.filename}:{tok.line}:{tok.col}: "
                f"expected {exp}, got {tok.type.value} {tok.value!r}"
            )
        return tok

    def _at_op(self, value: str) -> bool:
        return self._at(TT.OP, value)

    def _match_op(self, value: str) -> Token | None:
        return self._match(TT.OP, value)

    # ── Expression Collection ─────────────────────────────────────────────

    def _collect_until(self, *stop: TT, stop_values: set | None = None) -> str:
        """Collect tokens until a stop token at depth 0, return as Python str."""
        toks: list[Token] = []
        depth = 0
        sv = stop_values or set()
        while True:
            tok = self._peek()
            if tok.type == TT.EOF:
                break
            if depth == 0:
                if tok.type in stop:
                    break
                if tok.type == TT.OP and tok.value in sv:
                    break
            if tok.type in (TT.LPAREN, TT.LBRACKET, TT.LBRACE):
                depth += 1
            elif tok.type in (TT.RPAREN, TT.RBRACKET, TT.RBRACE):
                depth -= 1
                if depth < 0:
                    break
            toks.append(self._advance())
        return tokens_to_str(toks)

    def _collect_type(self, *extra_stop: TT, stop_vals: set | None = None) -> str:
        """Collect type annotation tokens."""
        stops = {TT.LBRACE, TT.SEMI, TT.COMMA, *extra_stop}
        return self._collect_until(*stops, stop_values=stop_vals or {"="})

    def _collect_dotted(self) -> str:
        # Handle leading dots for relative imports (e.g., .tokens, ..utils)
        prefix = ""
        while self._at(TT.DOT):
            prefix += "."
            self._advance()
        if self._at(TT.NAME):
            parts = [self._expect(TT.NAME).value]
            while self._match(TT.DOT):
                parts.append(self._expect(TT.NAME).value)
            return prefix + ".".join(parts)
        return prefix

    # ── Decorators ────────────────────────────────────────────────────────

    def _parse_decorators(self) -> list[str]:
        decorators: list[str] = []
        while self._at(TT.AT):
            self._advance()  # skip @
            toks: list[Token] = []
            depth = 0
            while True:
                tok = self._peek()
                if tok.type == TT.EOF:
                    break
                if (
                    depth == 0
                    and tok.type == TT.NAME
                    and tok.value
                    in (
                        "def",
                        "class",
                        "obj",
                        "node",
                        "edge",
                        "walker",
                        "enum",
                        "static",
                        "async",
                        "has",
                        "impl",
                        "can",
                    )
                ):
                    break
                if depth == 0 and tok.type == TT.AT:
                    break
                if tok.type == TT.LPAREN:
                    depth += 1
                elif tok.type == TT.RPAREN:
                    depth -= 1
                toks.append(self._advance())
                if depth == 0 and tok.type == TT.RPAREN:
                    break
            decorators.append(tokens_to_str(toks))
        return decorators

    # ── Top-Level Parsing ─────────────────────────────────────────────────

    def parse(self) -> Module:
        body: list = []
        while not self._at(TT.EOF):
            node = self._parse_item()
            if node is not None:
                body.append(node)
        return Module(body=body, filename=self.filename)

    def _parse_item(self) -> object:
        """Parse a single item (works for module, class, or function body)."""
        # Decorators
        if self._at(TT.AT):
            decorators = self._parse_decorators()
            return self._parse_decorated(decorators)

        tok = self._peek()
        if tok.type == TT.NAME and not tok.backtick:
            v = tok.value
            if v == "import":
                return self._parse_import()
            if v in ("class", "obj", "node", "edge", "walker"):
                return self._parse_class([])
            if v == "enum":
                return self._parse_enum([])
            if v == "def" or v == "can":
                return self._parse_funcdef([])
            if v == "static":
                return self._parse_funcdef([])
            if v == "async":
                nxt = self._peek(1)
                if nxt.value in ("def", "can", "static"):
                    return self._parse_funcdef([])
                if nxt.value == "for":
                    return self._parse_for(is_async=True)
                if nxt.value == "with":
                    return self._parse_with_stmt(is_async=True)
            if v == "has":
                return self._parse_has()
            if v == "glob":
                return self._parse_glob()
            if v == "impl":
                return self._parse_impl([])
            if v == "with":
                if self._peek(1).value == "entry":
                    return self._parse_with_entry()
                return self._parse_with_stmt()
            if v == "match":
                return self._parse_match()
            if v == "if":
                return self._parse_if()
            if v == "for":
                return self._parse_for()
            if v == "while":
                return self._parse_while()
            if v == "try":
                return self._parse_try()
            if v == "return":
                return self._parse_return()
            if v == "yield":
                return self._parse_yield()
            if v == "raise":
                return self._parse_raise()
            if v == "assert":
                return self._parse_assert()
            if v == "del":
                return self._parse_delete()
            if v == "global":
                return self._parse_global_stmt()
            if v == "nonlocal":
                return self._parse_nonlocal_stmt()
            if v == "break":
                self._advance()
                self._match(TT.SEMI)
                return BreakStmt()
            if v == "continue":
                self._advance()
                self._match(TT.SEMI)
                return ContinueStmt()
            if v == "pass":
                self._advance()
                self._match(TT.SEMI)
                return PassStmt()

        # Standalone string literal (docstring — no semicolon required)
        if self._peek().type == TT.STRING:
            nxt = self._peek(1)
            if nxt.type not in (TT.DOT, TT.LBRACKET, TT.LPAREN, TT.OP, TT.COMMA):
                tok = self._advance()
                self._match(TT.SEMI)
                return ExprStmt(expr=tok.value)

        # Bare semicolon → pass
        if self._at(TT.SEMI):
            self._advance()
            return PassStmt()

        # Expression statement
        return self._parse_expr_stmt()

    def _parse_decorated(self, decorators: list[str]) -> object:
        tok = self._peek()
        v = tok.value if tok.type == TT.NAME else ""
        if v in ("class", "obj", "node", "edge", "walker"):
            return self._parse_class(decorators)
        if v == "enum":
            return self._parse_enum(decorators)
        if v in ("def", "static", "async", "can"):
            return self._parse_funcdef(decorators)
        if v == "impl":
            return self._parse_impl(decorators)
        raise ParseError(
            f"{self.filename}:{tok.line}:{tok.col}: "
            f"expected class/def/impl after decorator, got {tok.value!r}"
        )

    # ── Imports ───────────────────────────────────────────────────────────

    def _parse_import(self) -> Import:
        self._expect(TT.NAME, "import")
        if self._at(TT.NAME, "from"):
            self._advance()  # consume 'from'
            module = self._collect_dotted()
            self._expect(TT.LBRACE)
            names: list[str] = []
            while not self._at(TT.RBRACE):
                name_toks: list[Token] = []
                # Collect possibly dotted/complex name
                depth = 0
                while True:
                    t = self._peek()
                    if t.type == TT.EOF:
                        break
                    if depth == 0 and t.type in (TT.COMMA, TT.RBRACE):
                        break
                    if depth == 0 and t.type == TT.NAME and t.value == "as":
                        break
                    if t.type in (TT.LPAREN, TT.LBRACKET):
                        depth += 1
                    elif t.type in (TT.RPAREN, TT.RBRACKET):
                        depth -= 1
                    name_toks.append(self._advance())
                n = tokens_to_str(name_toks)
                if self._match(TT.NAME, "as"):
                    alias = self._expect(TT.NAME).value
                    n = f"{n} as {alias}"
                names.append(n)
                self._match(TT.COMMA)
            self._expect(TT.RBRACE)
            self._match(TT.SEMI)
            return Import(module=module, names=names, is_from=True)
        else:
            module = self._collect_dotted()
            alias = ""
            if self._match(TT.NAME, "as"):
                alias = self._expect(TT.NAME).value
            self._match(TT.SEMI)
            return Import(module=module, alias=alias, is_from=False)

    # ── Classes ───────────────────────────────────────────────────────────

    def _parse_class(self, decorators: list[str]) -> ClassDef:
        kw = self._advance()  # class/obj/node/edge/walker
        is_dc = kw.value in ("obj", "node", "edge", "walker")
        name = self._expect(TT.NAME).value
        bases = ""
        if self._match(TT.LPAREN):
            bases = self._collect_until(TT.RPAREN)
            self._expect(TT.RPAREN)
        self._expect(TT.LBRACE)
        body = self._parse_body()
        self._expect(TT.RBRACE)
        return ClassDef(
            name=name,
            bases=bases,
            body=body,
            decorators=decorators,
            is_dataclass=is_dc,
        )

    def _parse_enum(self, decorators: list[str]) -> EnumDef:
        self._expect(TT.NAME, "enum")
        name = self._expect(TT.NAME).value
        bases = ""
        if self._match(TT.LPAREN):
            bases = self._collect_until(TT.RPAREN)
            self._expect(TT.RPAREN)
        self._expect(TT.LBRACE)
        body = self._parse_enum_body()
        self._expect(TT.RBRACE)
        return EnumDef(name=name, bases=bases, body=body, decorators=decorators)

    def _parse_enum_body(self) -> list:
        """Parse enum body — handles comma OR semicolon separated members."""
        body: list = []
        while not self._at(TT.RBRACE) and not self._at(TT.EOF):
            # Check for nested constructs (def, has, etc.)
            tok = self._peek()
            if tok.type == TT.NAME and not tok.backtick:
                v = tok.value
                if v in ("def", "static", "async", "can"):
                    body.append(self._parse_funcdef([]))
                    continue
                if v == "has":
                    body.append(self._parse_has())
                    continue
                if v == "with" and self._peek(1).value == "entry":
                    body.append(self._parse_with_entry())
                    continue
            if self._at(TT.AT):
                decs = self._parse_decorators()
                body.append(self._parse_decorated(decs))
                continue
            # Collect expression (enum member) until comma, semi, or closing brace
            expr = self._collect_until(TT.SEMI, TT.COMMA)
            self._match(TT.SEMI)
            self._match(TT.COMMA)
            if expr.strip():
                body.append(ExprStmt(expr=expr))
        return body

    # ── Functions ─────────────────────────────────────────────────────────

    def _parse_funcdef(self, decorators: list[str]) -> FuncDef:
        is_static = False
        is_async = False
        # Handle both orders: static async def / async static def
        if self._match(TT.NAME, "static"):
            is_static = True
        if self._match(TT.NAME, "async"):
            is_async = True
        if not is_static and self._match(TT.NAME, "static"):
            is_static = True
        # consume 'def' or 'can'
        self._advance()
        name = self._expect(TT.NAME).value
        params: list[Param] = []
        if self._match(TT.LPAREN):
            params = self._parse_params()
            self._expect(TT.RPAREN)
        return_type = ""
        if self._match(TT.ARROW):
            return_type = self._collect_type()
        if self._match(TT.SEMI):
            body = [PassStmt()]
        else:
            self._expect(TT.LBRACE)
            body = self._parse_body()
            self._expect(TT.RBRACE)
        return FuncDef(
            name=name,
            params=params,
            return_type=return_type,
            body=body,
            decorators=decorators,
            is_static=is_static,
            is_async=is_async,
        )

    def _parse_params(self) -> list[Param]:
        params: list[Param] = []
        while not self._at(TT.RPAREN):
            is_star = False
            is_dstar = False

            if self._at_op("**"):
                self._advance()
                is_dstar = True
            elif self._at_op("*"):
                self._advance()
                if self._at(TT.COMMA) or self._at(TT.RPAREN):
                    params.append(Param(star_sep=True))
                    self._match(TT.COMMA)
                    continue
                is_star = True

            name = self._expect(TT.NAME).value
            type_ann = ""
            default = ""

            if self._match(TT.COLON):
                type_ann = self._collect_type(TT.RPAREN, stop_vals={"="})

            if self._match_op("="):
                default = self._collect_until(TT.COMMA, TT.RPAREN)

            params.append(
                Param(
                    name=name,
                    type_ann=type_ann,
                    default=default,
                    is_star=is_star,
                    is_dstar=is_dstar,
                )
            )
            self._match(TT.COMMA)
        return params

    # ── Has Declarations ──────────────────────────────────────────────────

    def _parse_has(self) -> HasDecl:
        self._expect(TT.NAME, "has")
        # Optional access modifier :pub, :priv, :prot
        if (
            self._at(TT.COLON)
            and self._peek(1).type == TT.NAME
            and self._peek(1).value in ("pub", "priv", "prot", "protect")
        ):
            self._advance()  # skip :
            self._advance()  # consume access modifier
        vars_list: list[HasVar] = []
        while True:
            name = self._expect(TT.NAME).value
            self._expect(TT.COLON)
            type_ann = self._collect_type(stop_vals={"="})
            default = ""
            by_postinit = False
            if self._match_op("="):
                default = self._collect_until(TT.COMMA, TT.SEMI)
            elif self._at(TT.NAME, "by"):
                self._advance()
                self._expect(TT.NAME, "postinit")
                by_postinit = True
            vars_list.append(
                HasVar(
                    name=name,
                    type_ann=type_ann,
                    default=default,
                    by_postinit=by_postinit,
                )
            )
            if self._match(TT.SEMI):
                break
            self._expect(TT.COMMA)
            # Check for access modifier on next var
            if (
                self._at(TT.COLON)
                and self._peek(1).type == TT.NAME
                and self._peek(1).value in ("pub", "priv", "prot", "protect")
            ):
                self._advance()
                self._advance()
        return HasDecl(vars=vars_list)

    # ── Glob Declarations ─────────────────────────────────────────────────

    def _parse_glob(self) -> GlobDecl:
        self._expect(TT.NAME, "glob")
        assignments: list[tuple[str, str]] = []
        while True:
            name = self._expect(TT.NAME).value
            # Optional type annotation: glob X: Type = expr
            type_ann = ""
            if self._match(TT.COLON):
                type_ann = self._collect_type(stop_vals={"="})
            self._expect(TT.OP, "=")
            expr = self._collect_until(TT.COMMA, TT.SEMI)
            if type_ann:
                assignments.append((f"{name}: {type_ann}", expr))
            else:
                assignments.append((name, expr))
            if self._match(TT.SEMI):
                break
            self._expect(TT.COMMA)
        return GlobDecl(assignments=assignments)

    # ── Impl Definitions ──────────────────────────────────────────────────

    def _parse_impl(self, decorators: list[str]) -> ImplDef:
        self._expect(TT.NAME, "impl")
        is_static = False
        is_async = False
        target = self._collect_dotted()
        params: list[Param] = []
        if self._at(TT.LPAREN):
            self._advance()
            params = self._parse_params()
            self._expect(TT.RPAREN)
        return_type = ""
        if self._match(TT.ARROW):
            return_type = self._collect_type()
        self._expect(TT.LBRACE)
        body = self._parse_body()
        self._expect(TT.RBRACE)
        return ImplDef(
            target=target,
            params=params,
            return_type=return_type,
            body=body,
            decorators=decorators,
            is_static=is_static,
            is_async=is_async,
        )

    # ── With Entry ────────────────────────────────────────────────────────

    def _parse_with_entry(self) -> WithEntry:
        self._expect(TT.NAME, "with")
        self._expect(TT.NAME, "entry")
        self._expect(TT.LBRACE)
        body = self._parse_body()
        self._expect(TT.RBRACE)
        return WithEntry(body=body)

    # ── Control Flow ──────────────────────────────────────────────────────

    def _parse_if(self) -> IfStmt:
        self._expect(TT.NAME, "if")
        cond = self._collect_until(TT.LBRACE)
        self._expect(TT.LBRACE)
        body = self._parse_body()
        self._expect(TT.RBRACE)
        elifs: list[tuple[str, list]] = []
        while self._match(TT.NAME, "elif"):
            econd = self._collect_until(TT.LBRACE)
            self._expect(TT.LBRACE)
            ebody = self._parse_body()
            self._expect(TT.RBRACE)
            elifs.append((econd, ebody))
        else_body: list = []
        if self._match(TT.NAME, "else"):
            self._expect(TT.LBRACE)
            else_body = self._parse_body()
            self._expect(TT.RBRACE)
        return IfStmt(condition=cond, body=body, elifs=elifs, else_body=else_body)

    def _parse_for(self, is_async: bool = False) -> ForStmt:
        if is_async:
            self._expect(TT.NAME, "async")
        self._expect(TT.NAME, "for")
        # Collect target (before 'in')
        target_toks: list[Token] = []
        depth = 0
        while True:
            tok = self._peek()
            if tok.type == TT.EOF:
                break
            if depth == 0 and tok.type == TT.NAME and tok.value == "in":
                break
            if tok.type in (TT.LPAREN, TT.LBRACKET, TT.LBRACE):
                depth += 1
            elif tok.type in (TT.RPAREN, TT.RBRACKET, TT.RBRACE):
                depth -= 1
            target_toks.append(self._advance())
        self._expect(TT.NAME, "in")
        iter_expr = self._collect_until(TT.LBRACE)
        self._expect(TT.LBRACE)
        body = self._parse_body()
        self._expect(TT.RBRACE)
        return ForStmt(
            target=tokens_to_str(target_toks),
            iter_expr=iter_expr,
            body=body,
            is_async=is_async,
        )

    def _parse_match(self) -> MatchStmt:
        self._expect(TT.NAME, "match")
        subject = self._collect_until(TT.LBRACE)
        self._expect(TT.LBRACE)
        cases: list[tuple[str, list]] = []
        while self._match(TT.NAME, "case"):
            # Collect pattern until : (colon after pattern)
            pattern = self._collect_until(TT.COLON)
            self._expect(TT.COLON)
            # Collect body until next 'case' or closing '}'
            body: list = []
            while (
                not self._at(TT.RBRACE)
                and not self._at(TT.EOF)
                and not (self._peek().type == TT.NAME and self._peek().value == "case")
            ):
                node = self._parse_item()
                if node is not None:
                    body.append(node)
            cases.append((pattern, body))
        self._expect(TT.RBRACE)
        return MatchStmt(subject=subject, cases=cases)

    def _parse_while(self) -> WhileStmt:
        self._expect(TT.NAME, "while")
        cond = self._collect_until(TT.LBRACE)
        self._expect(TT.LBRACE)
        body = self._parse_body()
        self._expect(TT.RBRACE)
        return WhileStmt(condition=cond, body=body)

    def _parse_try(self) -> TryStmt:
        self._expect(TT.NAME, "try")
        self._expect(TT.LBRACE)
        body = self._parse_body()
        self._expect(TT.RBRACE)
        excepts: list[tuple[str, str, list]] = []
        while self._match(TT.NAME, "except"):
            exc_type = ""
            exc_name = ""
            if not self._at(TT.LBRACE):
                exc_str = self._collect_until(TT.LBRACE)
                if " as " in exc_str:
                    parts = exc_str.rsplit(" as ", 1)
                    exc_type = parts[0].strip()
                    exc_name = parts[1].strip()
                else:
                    exc_type = exc_str.strip()
            self._expect(TT.LBRACE)
            exc_body = self._parse_body()
            self._expect(TT.RBRACE)
            excepts.append((exc_type, exc_name, exc_body))
        else_body: list = []
        if self._match(TT.NAME, "else"):
            self._expect(TT.LBRACE)
            else_body = self._parse_body()
            self._expect(TT.RBRACE)
        finally_body: list = []
        if self._match(TT.NAME, "finally"):
            self._expect(TT.LBRACE)
            finally_body = self._parse_body()
            self._expect(TT.RBRACE)
        return TryStmt(
            body=body,
            excepts=excepts,
            else_body=else_body,
            finally_body=finally_body,
        )

    def _parse_with_stmt(self, is_async: bool = False) -> WithStmt:
        if is_async:
            self._expect(TT.NAME, "async")
        self._expect(TT.NAME, "with")
        items = self._collect_until(TT.LBRACE)
        self._expect(TT.LBRACE)
        body = self._parse_body()
        self._expect(TT.RBRACE)
        return WithStmt(items=items, body=body, is_async=is_async)

    # ── Simple Statements ─────────────────────────────────────────────────

    def _parse_return(self) -> ReturnStmt:
        self._expect(TT.NAME, "return")
        if self._at(TT.SEMI):
            self._advance()
            return ReturnStmt()
        expr = self._collect_until(TT.SEMI)
        self._match(TT.SEMI)
        return ReturnStmt(expr=expr)

    def _parse_yield(self) -> YieldStmt:
        self._expect(TT.NAME, "yield")
        if self._at(TT.SEMI):
            self._advance()
            return YieldStmt()
        expr = self._collect_until(TT.SEMI)
        self._match(TT.SEMI)
        return YieldStmt(expr=expr)

    def _parse_raise(self) -> RaiseStmt:
        self._expect(TT.NAME, "raise")
        if self._at(TT.SEMI):
            self._advance()
            return RaiseStmt()
        expr = self._collect_until(TT.SEMI)
        self._match(TT.SEMI)
        return RaiseStmt(expr=expr)

    def _parse_assert(self) -> AssertStmt:
        self._expect(TT.NAME, "assert")
        expr = self._collect_until(TT.SEMI)
        self._match(TT.SEMI)
        return AssertStmt(expr=expr)

    def _parse_delete(self) -> DeleteStmt:
        self._expect(TT.NAME, "del")
        expr = self._collect_until(TT.SEMI)
        self._match(TT.SEMI)
        return DeleteStmt(expr=expr)

    def _parse_global_stmt(self) -> GlobalStmt:
        self._expect(TT.NAME, "global")
        names: list[str] = []
        names.append(self._expect(TT.NAME).value)
        while self._match(TT.COMMA):
            names.append(self._expect(TT.NAME).value)
        self._match(TT.SEMI)
        return GlobalStmt(names=names)

    def _parse_nonlocal_stmt(self) -> NonlocalStmt:
        self._expect(TT.NAME, "nonlocal")
        names: list[str] = []
        names.append(self._expect(TT.NAME).value)
        while self._match(TT.COMMA):
            names.append(self._expect(TT.NAME).value)
        self._match(TT.SEMI)
        return NonlocalStmt(names=names)

    def _parse_expr_stmt(self) -> ExprStmt:
        expr = self._collect_until(TT.SEMI)
        self._match(TT.SEMI)
        return ExprStmt(expr=expr)

    # ── Body Parsing ──────────────────────────────────────────────────────

    def _parse_body(self) -> list:
        body: list = []
        while not self._at(TT.RBRACE) and not self._at(TT.EOF):
            node = self._parse_item()
            if node is not None:
                body.append(node)
        return body


# =============================================================================
# Code Generator
# =============================================================================


class CodeGen:
    """Generate Python source code from jac0 AST."""

    def __init__(self) -> None:
        self.lines: list[str] = []
        self.indent = 0
        self.needs_dataclass_import = False
        self.needs_enum_import = False
        self.impl_registry: dict[str, list[ImplDef]] = {}
        self._in_class = False

    def _line(self, text: str = "") -> None:
        if text:
            self.lines.append("    " * self.indent + text)
        else:
            self.lines.append("")

    def _strip_parens(self, s: str) -> str:
        """Strip wrapping parens from condition: (x > 0) → x > 0."""
        s = s.strip()
        if s.startswith("(") and s.endswith(")"):
            depth = 0
            for i, c in enumerate(s):
                if c == "(":
                    depth += 1
                elif c == ")":
                    depth -= 1
                if depth == 0 and i < len(s) - 1:
                    return s  # Parens don't fully wrap
            return s[1:-1].strip()
        return s

    def generate(self, module: Module) -> str:
        self._scan_needs(module.body)
        self._line("from __future__ import annotations")
        if self.needs_dataclass_import:
            self._line("from dataclasses import dataclass, field")
        if self.needs_enum_import:
            self._line("import enum")
        self._line()
        for node in module.body:
            self._emit(node)
        return "\n".join(self.lines) + "\n"

    def _scan_needs(self, body: list) -> None:
        for node in body:
            if isinstance(node, ClassDef):
                if node.is_dataclass:
                    has_dc = any("dataclass" in d for d in node.decorators)
                    if not has_dc:
                        self.needs_dataclass_import = True
                self._scan_needs(node.body)
            elif isinstance(node, EnumDef):
                if not node.bases:
                    self.needs_enum_import = True
            elif isinstance(node, WithEntry):
                self._scan_needs(node.body)

    def _emit(self, node: object) -> None:
        if isinstance(node, Import):
            self._emit_import(node)
        elif isinstance(node, ClassDef):
            self._emit_class(node)
        elif isinstance(node, EnumDef):
            self._emit_enum(node)
        elif isinstance(node, FuncDef):
            self._emit_func(node)
        elif isinstance(node, HasDecl):
            self._emit_has(node)
        elif isinstance(node, GlobDecl):
            self._emit_glob(node)
        elif isinstance(node, ImplDef):
            pass  # Stitched into classes
        elif isinstance(node, WithEntry):
            self._emit_with_entry(node)
        elif isinstance(node, IfStmt):
            self._emit_if(node)
        elif isinstance(node, ForStmt):
            self._emit_for(node)
        elif isinstance(node, WhileStmt):
            self._emit_while(node)
        elif isinstance(node, TryStmt):
            self._emit_try(node)
        elif isinstance(node, MatchStmt):
            self._emit_match(node)
        elif isinstance(node, WithStmt):
            self._emit_with(node)
        elif isinstance(node, ReturnStmt):
            self._line(f"return {node.expr}" if node.expr else "return")
        elif isinstance(node, YieldStmt):
            self._line(f"yield {node.expr}" if node.expr else "yield")
        elif isinstance(node, RaiseStmt):
            self._line(f"raise {node.expr}" if node.expr else "raise")
        elif isinstance(node, AssertStmt):
            self._line(f"assert {node.expr}")
        elif isinstance(node, DeleteStmt):
            self._line(f"del {node.expr}")
        elif isinstance(node, GlobalStmt):
            self._line(f"global {', '.join(node.names)}")
        elif isinstance(node, NonlocalStmt):
            self._line(f"nonlocal {', '.join(node.names)}")
        elif isinstance(node, ExprStmt):
            if node.expr:
                self._line(node.expr)
        elif isinstance(node, PassStmt):
            self._line("pass")
        elif isinstance(node, BreakStmt):
            self._line("break")
        elif isinstance(node, ContinueStmt):
            self._line("continue")

    def _emit_body(self, body: list) -> None:
        if not body:
            self._line("pass")
        else:
            for item in body:
                self._emit(item)

    # ── Imports ───────────────────────────────────────────────────────────

    def _emit_import(self, node: Import) -> None:
        if node.is_from:
            names = ", ".join(node.names)
            self._line(f"from {node.module} import {names}")
        elif node.alias:
            self._line(f"import {node.module} as {node.alias}")
        else:
            self._line(f"import {node.module}")

    # ── Classes ───────────────────────────────────────────────────────────

    def _emit_class(self, node: ClassDef) -> None:
        for dec in node.decorators:
            self._line(f"@{dec}")
        if node.is_dataclass:
            has_dc = any("dataclass" in d for d in node.decorators)
            if not has_dc:
                self._line("@dataclass")
        base_str = f"({node.bases})" if node.bases else ""
        self._line(f"class {node.name}{base_str}:")
        self.indent += 1
        body = node.body
        # Stitch impls
        impls = self.impl_registry.get(node.name, [])
        if not body and not impls:
            self._line("pass")
        else:
            prev_in_class = self._in_class
            self._in_class = True
            self._emit_body(body)
            for impl in impls:
                self._emit_impl_as_method(impl)
            self._in_class = prev_in_class
        self.indent -= 1
        self._line()

    def _emit_enum(self, node: EnumDef) -> None:
        for dec in node.decorators:
            self._line(f"@{dec}")
        if node.bases:
            bases = node.bases
        else:
            bases = "enum.Enum"
            self.needs_enum_import = True
        self._line(f"class {node.name}({bases}):")
        self.indent += 1
        if not node.body:
            self._line("pass")
        else:
            self._emit_body(node.body)
        self.indent -= 1
        self._line()

    # ── Functions ─────────────────────────────────────────────────────────

    def _emit_func(self, node: FuncDef) -> None:
        for dec in node.decorators:
            self._line(f"@{dec}")
        if node.is_static:
            self._line("@staticmethod")
        name = "__init__" if node.name == "init" else node.name
        func_params = list(node.params)
        # Auto-add self for instance methods inside a class
        if (
            self._in_class
            and not node.is_static
            and (not func_params or func_params[0].name not in ("self", "cls"))
        ):
            func_params.insert(0, Param(name="self"))
        params = self._format_params(func_params)
        ap = "async " if node.is_async else ""
        ret = f" -> {node.return_type}" if node.return_type else ""
        self._line(f"{ap}def {name}({params}){ret}:")
        self.indent += 1
        prev_in_class = self._in_class
        self._in_class = False  # nested functions are not methods
        self._emit_body(node.body)
        self._in_class = prev_in_class
        self.indent -= 1
        self._line()

    def _format_params(self, params: list[Param]) -> str:
        parts: list[str] = []
        for p in params:
            if p.star_sep:
                parts.append("*")
                continue
            prefix = "**" if p.is_dstar else ("*" if p.is_star else "")
            s = f"{prefix}{p.name}"
            # Strip type annotation from self/cls
            if p.type_ann and p.name not in ("self", "cls"):
                s += f": {p.type_ann}"
            if p.default:
                s += f" = {p.default}"
            parts.append(s)
        return ", ".join(parts)

    # ── Has ───────────────────────────────────────────────────────────────

    def _emit_has(self, node: HasDecl) -> None:
        for var in node.vars:
            if var.by_postinit:
                self._line(f"{var.name}: {var.type_ann} = field(init=False)")
            elif var.default:
                d = var.default.strip()
                if d == "[]":
                    self._line(
                        f"{var.name}: {var.type_ann} = field(default_factory=list)"
                    )
                elif d == "{}":
                    self._line(
                        f"{var.name}: {var.type_ann} = field(default_factory=dict)"
                    )
                else:
                    self._line(f"{var.name}: {var.type_ann} = {var.default}")
            else:
                self._line(f"{var.name}: {var.type_ann}")

    # ── Glob ──────────────────────────────────────────────────────────────

    def _emit_glob(self, node: GlobDecl) -> None:
        for name, expr in node.assignments:
            self._line(f"{name} = {expr}")

    # ── WithEntry ─────────────────────────────────────────────────────────

    def _emit_with_entry(self, node: WithEntry) -> None:
        for item in node.body:
            self._emit(item)

    # ── Impl as Method ────────────────────────────────────────────────────

    def _emit_impl_as_method(self, impl: ImplDef) -> None:
        parts = impl.target.split(".")
        method_name = parts[-1] if len(parts) > 1 else parts[0]
        if method_name == "init":
            method_name = "__init__"
        for dec in impl.decorators:
            self._line(f"@{dec}")
        if impl.is_static:
            self._line("@staticmethod")
        func_params = list(impl.params)
        # Auto-add self for instance methods
        if not impl.is_static and (
            not func_params or func_params[0].name not in ("self", "cls")
        ):
            func_params.insert(0, Param(name="self"))
        params = self._format_params(func_params)
        ap = "async " if impl.is_async else ""
        ret = f" -> {impl.return_type}" if impl.return_type else ""
        self._line(f"{ap}def {method_name}({params}){ret}:")
        self.indent += 1
        prev_in_class = self._in_class
        self._in_class = False  # nested functions are not methods
        self._emit_body(impl.body)
        self._in_class = prev_in_class
        self.indent -= 1
        self._line()

    # ── Control Flow ──────────────────────────────────────────────────────

    def _emit_if(self, node: IfStmt) -> None:
        self._line(f"if {self._strip_parens(node.condition)}:")
        self.indent += 1
        self._emit_body(node.body)
        self.indent -= 1
        for cond, body in node.elifs:
            self._line(f"elif {self._strip_parens(cond)}:")
            self.indent += 1
            self._emit_body(body)
            self.indent -= 1
        if node.else_body:
            self._line("else:")
            self.indent += 1
            self._emit_body(node.else_body)
            self.indent -= 1

    def _emit_for(self, node: ForStmt) -> None:
        ap = "async " if node.is_async else ""
        self._line(f"{ap}for {node.target} in {node.iter_expr}:")
        self.indent += 1
        self._emit_body(node.body)
        self.indent -= 1

    def _emit_while(self, node: WhileStmt) -> None:
        self._line(f"while {self._strip_parens(node.condition)}:")
        self.indent += 1
        self._emit_body(node.body)
        self.indent -= 1

    def _emit_try(self, node: TryStmt) -> None:
        self._line("try:")
        self.indent += 1
        self._emit_body(node.body)
        self.indent -= 1
        for exc_type, exc_name, exc_body in node.excepts:
            if exc_type and exc_name:
                self._line(f"except {exc_type} as {exc_name}:")
            elif exc_type:
                self._line(f"except {exc_type}:")
            else:
                self._line("except:")
            self.indent += 1
            self._emit_body(exc_body)
            self.indent -= 1
        if node.else_body:
            self._line("else:")
            self.indent += 1
            self._emit_body(node.else_body)
            self.indent -= 1
        if node.finally_body:
            self._line("finally:")
            self.indent += 1
            self._emit_body(node.finally_body)
            self.indent -= 1

    def _emit_with(self, node: WithStmt) -> None:
        ap = "async " if node.is_async else ""
        self._line(f"{ap}with {node.items}:")
        self.indent += 1
        self._emit_body(node.body)
        self.indent -= 1

    def _emit_match(self, node: MatchStmt) -> None:
        self._line(f"match {self._strip_parens(node.subject)}:")
        self.indent += 1
        for pattern, body in node.cases:
            self._line(f"case {pattern}:")
            self.indent += 1
            self._emit_body(body)
            self.indent -= 1
        self.indent -= 1


# =============================================================================
# Orchestrator
# =============================================================================


def discover_impl_files(jac_path: str) -> list[str]:
    """Discover .impl.jac files for a given .jac file."""
    impls: list[str] = []
    base = jac_path[:-4]  # strip .jac
    dir_path = os.path.dirname(jac_path) or "."
    base_name = os.path.basename(base)

    # Same directory: foo.impl.jac
    impl_file = f"{base}.impl.jac"
    if os.path.isfile(impl_file):
        impls.append(impl_file)

    # Module folder: foo.impl/*.impl.jac
    impl_dir = f"{base}.impl"
    if os.path.isdir(impl_dir):
        for f in sorted(os.listdir(impl_dir)):
            if f.endswith(".impl.jac"):
                impls.append(os.path.join(impl_dir, f))

    # Shared folder: impl/foo.impl.jac
    shared_impl = os.path.join(dir_path, "impl", f"{base_name}.impl.jac")
    if os.path.isfile(shared_impl):
        impls.append(shared_impl)

    return impls


def compile_jac(
    source: str,
    filename: str = "<unknown>",
    impl_sources: list[tuple[str, str]] | None = None,
) -> str:
    """Compile Jac source to Python source."""
    lexer = Lexer(source, filename)
    parser = Parser(lexer.tokens, source, filename)
    module = parser.parse()

    codegen = CodeGen()

    # Register impls from main module
    for node in module.body:
        if isinstance(node, ImplDef):
            cls = node.target.split(".")[0]
            codegen.impl_registry.setdefault(cls, []).append(node)

    # Parse and register impls from impl files
    if impl_sources:
        for impl_src, impl_file in impl_sources:
            impl_lexer = Lexer(impl_src, impl_file)
            impl_parser = Parser(impl_lexer.tokens, impl_src, impl_file)
            impl_module = impl_parser.parse()
            for node in impl_module.body:
                if isinstance(node, ImplDef):
                    cls = node.target.split(".")[0]
                    codegen.impl_registry.setdefault(cls, []).append(node)

    return codegen.generate(module)
