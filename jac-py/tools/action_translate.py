"""Structured translation of CPython grammar actions to Jac parser code.

Replaces the ordered-regex ActionLowerer with a typed C-expression parser and
family-based emitters. Unknown action forms raise ActionTranslationError.
"""

from __future__ import annotations

import os
import re
import sys
from dataclasses import dataclass
from enum import Enum, auto
from typing import Callable

_HERE = os.path.dirname(os.path.abspath(__file__))
_REPO = os.path.dirname(os.path.dirname(_HERE))
_CPY_PARSER = os.path.join(_REPO, "reference", "cpython", "Parser")
sys.path.insert(0, _CPY_PARSER)

import asdl  # noqa: E402

ASDL_PATH = os.path.join(_CPY_PARSER, "Python.asdl")

BINOP_OPS = {
    "Add": "Add",
    "Sub": "Sub",
    "Mult": "Mult",
    "Div": "Div",
    "FloorDiv": "FloorDiv",
    "Mod": "Mod",
    "MatMult": "MatMult",
    "Pow": "Pow",
    "LShift": "LShift",
    "RShift": "RShift",
    "BitOr": "BitOr",
    "BitXor": "BitXor",
    "BitAnd": "BitAnd",
}

UNARY_OPS = {"UAdd": "UAdd", "USub": "USub", "Invert": "Invert", "Not": "Not"}
BOOL_OPS = {"And": "And", "Or": "Or"}
CMP_OPS = {
    "Eq": "Eq",
    "NotEq": "NotEq",
    "Lt": "Lt",
    "LtE": "LtE",
    "Gt": "Gt",
    "GtE": "GtE",
    "Is": "Is",
    "IsNot": "IsNot",
    "In": "In",
    "NotIn": "NotIn",
}

OP_CONSTANTS = {**BINOP_OPS, **UNARY_OPS, **BOOL_OPS, **CMP_OPS}
EXPR_CONTEXTS = {"Load": "Load", "Store": "Store", "Del": "Del"}

LOC = "start_lineno, start_col_offset, end_lineno, end_col_offset"


class ActionTranslationError(ValueError):
  """Raised when a grammar action cannot be translated structurally."""


class TokKind(Enum):
    EOF = auto()
    IDENT = auto()
    NUMBER = auto()
    STRING = auto()
    LPAREN = auto()
    RPAREN = auto()
    COMMA = auto()
    ARROW = auto()
    DOT = auto()
    QMARK = auto()
    COLON = auto()
    STAR = auto()


@dataclass
class Tok:
    kind: TokKind
    value: str = ""
    pos: int = 0


class Lexer:
    def __init__(self, text: str) -> None:
        self.text = text
        self.pos = 0

    def _peek(self, n: int = 1) -> str:
        return self.text[self.pos : self.pos + n]

    def _advance(self, n: int = 1) -> None:
        self.pos += n

    def next(self) -> Tok:
        while self.pos < len(self.text) and self.text[self.pos].isspace():
            self.pos += 1
        if self.pos >= len(self.text):
            return Tok(TokKind.EOF, "", self.pos)
        ch = self.text[self.pos]
        if ch in "()":
            kind = TokKind.LPAREN if ch == "(" else TokKind.RPAREN
            self._advance()
            return Tok(kind, ch, self.pos - 1)
        if ch == ",":
            self._advance()
            return Tok(TokKind.COMMA, ch, self.pos - 1)
        if ch == "?":
            self._advance()
            return Tok(TokKind.QMARK, ch, self.pos - 1)
        if ch == ":":
            self._advance()
            return Tok(TokKind.COLON, ch, self.pos - 1)
        if ch == "*":
            self._advance()
            return Tok(TokKind.STAR, ch, self.pos - 1)
        if ch == ".":
            self._advance()
            return Tok(TokKind.DOT, ch, self.pos - 1)
        if self._peek(2) == "->":
            self._advance(2)
            return Tok(TokKind.ARROW, "->", self.pos - 2)
        if ch in "\"'":
            quote = ch
            self._advance()
            start = self.pos
            while self.pos < len(self.text) and self.text[self.pos] != quote:
                if self.text[self.pos] == "\\":
                    self.pos += 2
                    continue
                self.pos += 1
            val = self.text[start : self.pos]
            self._advance()
            return Tok(TokKind.STRING, val, start)
        if ch.isdigit():
            start = self.pos
            while self.pos < len(self.text) and self.text[self.pos].isdigit():
                self.pos += 1
            return Tok(TokKind.NUMBER, self.text[start : self.pos], start)
        if ch.isalpha() or ch == "_":
            start = self.pos
            while self.pos < len(self.text) and (
                self.text[self.pos].isalnum() or self.text[self.pos] == "_"
            ):
                self.pos += 1
            return Tok(TokKind.IDENT, self.text[start : self.pos], start)
        raise ActionTranslationError(f"unexpected character {ch!r} at {self.pos}")


# ---- IR ---------------------------------------------------------------------

@dataclass
class Expr:
    pass


@dataclass
class Ident(Expr):
    name: str


@dataclass
class Null(Expr):
    pass


@dataclass
class PyNone(Expr):
    pass


@dataclass
class PyBool(Expr):
    value: bool


@dataclass
class StringLit(Expr):
    value: str


@dataclass
class IntLit(Expr):
    value: int


@dataclass
class Extra(Expr):
    pass


@dataclass
class OpConst(Expr):
    name: str


@dataclass
class Cast(Expr):
    type_name: str
    expr: Expr


@dataclass
class Member(Expr):
    base: Expr
    field: str


@dataclass
class Call(Expr):
    func: str
    args: list[Expr]


@dataclass
class Ternary(Expr):
    cond: Expr
    then: Expr
    else_: Expr


@dataclass
class TypeStar(Expr):
    name: str


@dataclass
class Arena(Expr):
    pass


class Parser:
    def __init__(self, text: str) -> None:
        self.lexer = Lexer(text)
        self.tok = self.lexer.next()

    def _eat(self, kind: TokKind) -> Tok:
        if self.tok.kind != kind:
            raise ActionTranslationError(
                f"expected {kind.name}, got {self.tok.kind.name} ({self.tok.value!r})"
            )
        tok = self.tok
        self.tok = self.lexer.next()
        return tok

    def _match(self, kind: TokKind) -> bool:
        if self.tok.kind == kind:
            self.tok = self.lexer.next()
            return True
        return False

    def parse(self) -> Expr:
        expr = self._ternary()
        if self.tok.kind != TokKind.EOF:
            raise ActionTranslationError(
                f"trailing tokens after action: {self.tok.value!r}"
            )
        return expr

    def _ternary(self) -> Expr:
        cond = self._postfix()
        if self._match(TokKind.QMARK):
            then = self._ternary()
            self._eat(TokKind.COLON)
            else_ = self._ternary()
            return Ternary(cond, then, else_)
        return cond

    def _postfix(self) -> Expr:
        expr = self._primary()
        while True:
            if self._match(TokKind.ARROW):
                field = self._eat(TokKind.IDENT).value
                if isinstance(expr, Ident) and expr.name == "p" and field == "arena":
                    expr = Arena()
                    continue
                expr = Member(expr, field)
                continue
            if self._match(TokKind.DOT):
                field = self._eat(TokKind.IDENT).value
                expr = Member(expr, field)
                continue
            if self._match(TokKind.LPAREN):
                args: list[Expr] = []
                if not self._match(TokKind.RPAREN):
                    while True:
                        args.append(self._ternary())
                        if self._match(TokKind.RPAREN):
                            break
                        self._eat(TokKind.COMMA)
                expr = Call(self._func_name(expr), args)
                continue
            break
        return expr

    def _func_name(self, expr: Expr) -> str:
        if isinstance(expr, Ident):
            return expr.name
        if isinstance(expr, Member):
            return self._member_path(expr)
        raise ActionTranslationError(f"invalid call target: {expr!r}")

    def _member_path(self, expr: Member) -> str:
        parts: list[str] = [expr.field]
        base: Expr = expr.base
        while isinstance(base, Member):
            parts.append(base.field)
            base = base.base
        if isinstance(base, Ident):
            parts.append(base.name)
            return ".".join(reversed(parts))
        raise ActionTranslationError(f"invalid member path: {expr!r}")

    def _looks_like_cast_type(self, name: str) -> bool:
        return (
            name.endswith("_ty")
            or name.startswith("asdl_")
            or name == "AugOperator"
            or name == "void"
        )

    def _primary(self) -> Expr:
        if self._match(TokKind.LPAREN):
            if self.tok.kind == TokKind.IDENT and self._looks_like_cast_type(
                self.tok.value
            ):
                type_name = self._eat(TokKind.IDENT).value
                if self._match(TokKind.STAR):
                    type_name = f"{type_name}*"
                self._eat(TokKind.RPAREN)
                return Cast(type_name, self._ternary())
            expr = self._ternary()
            self._eat(TokKind.RPAREN)
            return expr
        if self.tok.kind == TokKind.IDENT:
            name = self.tok.value
            self.tok = self.lexer.next()
            if name == "NULL":
                return Null()
            if name == "Py_None":
                return PyNone()
            if name == "Py_True":
                return PyBool(True)
            if name == "Py_False":
                return PyBool(False)
            if name == "Py_Ellipsis":
                return PyNone()
            if name == "EXTRA":
                return Extra()
            if name == "void" and self._match(TokKind.STAR):
                return TypeStar("void")
            if self._looks_like_cast_type(name) and self._match(TokKind.STAR):
                return TypeStar(name)
            if name in OP_CONSTANTS or name in EXPR_CONTEXTS:
                return OpConst(name)
            return Ident(name)
        if self.tok.kind == TokKind.STRING:
            val = self.tok.value
            self.tok = self.lexer.next()
            return StringLit(val)
        if self.tok.kind == TokKind.NUMBER:
            val = int(self.tok.value)
            self.tok = self.lexer.next()
            return IntLit(val)
        raise ActionTranslationError(f"unexpected token {self.tok.kind.name}")


def parse_action(text: str) -> Expr:
    normalized = " ".join(text.split())
    if re.fullmatch(r"[a-zA-Z_]\w*", normalized):
        return Ident(normalized)
    return Parser(normalized).parse()


# ---- ASDL-backed AST constructor metadata -----------------------------------

LOC_FIELDS = frozenset({"lineno", "col_offset", "end_lineno", "end_col_offset"})


def _load_asdl_constructors() -> dict[str, list[str]]:
    mod = asdl.parse(ASDL_PATH)
    out: dict[str, list[str]] = {}
    for name, typ in mod.types.items():
        if isinstance(typ, asdl.Sum):
            for ctor in typ.types:
                fields = [f.name for f in ctor.fields]
                if typ.attributes:
                    fields.extend(f.name for f in typ.attributes)
                out[ctor.name] = fields
                out[f"{ctor.name}__values"] = [f for f in fields if f not in LOC_FIELDS]
                out[f"{ctor.name}__has_loc"] = any(f in LOC_FIELDS for f in fields)
        elif isinstance(typ, asdl.Product):
            fields = [f.name for f in typ.fields]
            if typ.attributes:
                fields.extend(f.name for f in typ.attributes)
            out[name] = fields
            out[f"{name}__values"] = [f for f in fields if f not in LOC_FIELDS]
            out[f"{name}__has_loc"] = any(f in LOC_FIELDS for f in fields)
    return out


ASDL_CONSTRUCTORS = _load_asdl_constructors()

_SPECIAL_ACTIONS: dict[str, str] = {
    "asdl_seq_LEN ( patterns ) == 1 ? asdl_seq_GET ( patterns , 0 ) : _PyAST_MatchOr ( patterns , EXTRA )": (
        "pa_or_pattern_singleton(patterns, start_lineno, start_col_offset, end_lineno, end_col_offset)"
    ),
    "_PyPegen_check_legacy_stmt ( p , a ) ? NULL : p -> tokens [p -> mark - 1] -> level == 0 ? NULL : RAISE_SYNTAX_ERROR_KNOWN_RANGE ( a , b , \"invalid syntax. Perhaps you forgot a comma?\" )": (
        "pa_check_legacy_stmt_or_raise(p, a, b)"
    ),
    '_PyPegen_check_legacy_stmt ( p , a ) ? RAISE_SYNTAX_ERROR_KNOWN_RANGE ( a , b , "Missing parentheses in call to \'%U\'. Did you mean %U(...)?" , a -> v . Name . id , a -> v . Name . id ) : NULL': (
        'pa_raise_syntax_known_range(p, False, a, b, "Missing parentheses in call to \'%U\'. Did you mean %U(...)?") if pa_check_legacy_stmt(p, a) else None'
    ),
    'RAISE_SYNTAX_ERROR_STARTING_FROM ( colon , e -> kind == Tuple_kind ? "cannot use constraints with TypeVarTuple" : "cannot use bound with TypeVarTuple" )': (
        "pa_raise_type_param_error(colon, e, True)"
    ),
    'RAISE_SYNTAX_ERROR_STARTING_FROM ( colon , e -> kind == Tuple_kind ? "cannot use constraints with ParamSpec" : "cannot use bound with ParamSpec" )': (
        "pa_raise_type_param_error(colon, e, False)"
    ),
    "RAISE_ERROR_KNOWN_LOCATION ( p , PyExc_SyntaxError , a -> lineno , a -> end_col_offset - 1 , a -> end_lineno , - 1 , \"':' expected after dictionary key\" )": (
        "pa_raise_kvpair_error(p, a)"
    ),
}


# ---- Translator -------------------------------------------------------------

class ActionTranslator:
    """Translate parsed grammar actions into Jac expressions."""

    def __init__(self) -> None:
        self._pegen_handlers = self._build_pegen_handlers()
        self._raise_handlers = self._build_raise_handlers()
        self._ast_handlers = self._build_ast_handlers()

    def translate(self, action: str) -> str:
        normalized = " ".join(action.split())
        special = _SPECIAL_ACTIONS.get(normalized)
        if special is not None:
            return special
        ir = parse_action(action)
        return self._emit(ir)

    def _emit(self, node: Expr) -> str:
        if isinstance(node, Ident):
            return node.name
        if isinstance(node, Null):
            return "None"
        if isinstance(node, PyNone):
            return "None"
        if isinstance(node, PyBool):
            return "True" if node.value else "False"
        if isinstance(node, StringLit):
            esc = node.value.replace("\\", "\\\\").replace('"', '\\"')
            return f'"{esc}"'
        if isinstance(node, IntLit):
            return str(node.value)
        if isinstance(node, Extra):
            return LOC
        if isinstance(node, Arena):
            return "None"
        if isinstance(node, TypeStar):
            return node.name
        if isinstance(node, OpConst):
            return f"{node.name}()"
        if isinstance(node, Cast):
            return self._emit(node.expr)
        if isinstance(node, Member):
            return self._emit_member(node)
        if isinstance(node, Ternary):
            cond = self._emit(node.cond)
            then = self._emit(node.then)
            else_ = self._emit(node.else_)
            if else_ == "None" and cond.startswith("pa_check_legacy_stmt("):
                return f"({then} if {cond} else None)"
            return f"({then} if {cond} is not None else {else_})"
        if isinstance(node, Call):
            return self._emit_call(node)
        raise ActionTranslationError(f"unsupported IR node: {node!r}")

    def _member_base(self, node: Expr) -> str:
        if isinstance(node, Cast):
            return self._emit(node.expr)
        return self._emit(node)

    def _emit_member(self, node: Member) -> str:
        path: list[str] = []
        cur: Expr = node
        while isinstance(cur, Member):
            path.append(cur.field)
            cur = cur.base
        if isinstance(cur, (Ident, Cast)):
            base = self._member_base(cur)
            full = ".".join(reversed(path))
            if full == "v.Name.id" or full.endswith(".v.Name.id"):
                return f"pa_name_id({base})"
            if full == "kind" or full.endswith(".kind"):
                return f"pa_aug_op({base})"
            if full == "v.Call.args" or full.endswith(".v.Call.args"):
                return f"pa_call_args({base})"
            if full == "v.Call.keywords" or full.endswith(".v.Call.keywords"):
                return f"pa_call_keywords({base})"
            if full.endswith(".key") or full == "key":
                return f"pa_comp_field({base}, \"key\")"
            if full.endswith(".value") or full == "value":
                return f"pa_comp_field({base}, \"value\")"
            if full == "lineno":
                return f"pa_expr_lineno({base})"
            if full == "end_col_offset":
                return f"pa_expr_end_col_offset({base})"
            if full == "end_lineno":
                return f"pa_expr_end_lineno({base})"
            raise ActionTranslationError(f"unsupported member access: {full}")
        raise ActionTranslationError(f"unsupported member base: {node!r}")

    def _pegen_args(self, args: list[Expr]) -> list[Expr]:
        if args and isinstance(args[0], Ident) and args[0].name == "p":
            return args[1:]
        return args

    def _emit_call(self, node: Call) -> str:
        func = node.func
        args = node.args
        if func.startswith("_PyPegen_"):
            args = self._pegen_args(args)
        if func == "CHECK":
            return f"pa_check({self._emit(node.args[1])})"
        if func == "CHECK_NULL_ALLOWED":
            return f"pa_check({self._emit(node.args[1])})"
        if func == "CHECK_VERSION":
            return self._emit(node.args[3])
        if func == "NEW_TYPE_COMMENT":
            return "None"
        if func.startswith("RAISE_"):
            handler = self._raise_handlers.get(func)
            if handler is None:
                raise ActionTranslationError(f"unknown raise macro: {func}")
            return handler(self, node.args)
        if func.startswith("_PyPegen_"):
            handler = self._pegen_handlers.get(func)
            if handler is None:
                raise ActionTranslationError(f"unknown pegen helper: {func}")
            return handler(self, args)
        if func.startswith("_PyAST_"):
            handler = self._ast_handlers.get(func)
            if handler is None:
                return self._emit_ast_generic(func, args)
            return handler(self, args)
        if func == "PyErr_Occurred":
            return "pa_err_occurred(p)"
        if func in ("PyPegen_first_item", "PyPegen_last_item"):
            which = "first" if func.endswith("first_item") else "last"
            return f"pa_seq_{which}({self._emit(args[0])})"
        if func == "asdl_seq_LEN":
            return f"pa_seq_len({self._emit(args[0])})"
        if func == "asdl_seq_GET":
            return f"pa_seq_get({self._emit(args[0])}, {self._emit(args[1])})"
        raise ActionTranslationError(f"unknown action call: {func}")

    def _loc_kw(self) -> str:
        return (
            f"lineno=start_lineno, col_offset=start_col_offset, "
            f"end_lineno=end_lineno, end_col_offset=end_col_offset"
        )

    def _emit_ast_generic(self, func: str, args: list[Expr]) -> str:
        ctor = func[len("_PyAST_") :]
        value_fields_key = f"{ctor}__values"
        has_loc_key = f"{ctor}__has_loc"
        if value_fields_key not in ASDL_CONSTRUCTORS:
            raise ActionTranslationError(f"unknown AST constructor: {ctor}")
        value_fields = ASDL_CONSTRUCTORS[value_fields_key]
        has_loc = ASDL_CONSTRUCTORS.get(has_loc_key, False)
        translated = [self._emit(a) for a in args]
        cleaned: list[str] = []
        for val in translated:
            if val in ("p -> arena", "p->arena"):
                continue
            cleaned.append(val)
        if cleaned and cleaned[-1] == LOC:
            cleaned = cleaned[:-1]
        while cleaned and cleaned[-1] == "None" and len(cleaned) > len(value_fields):
            cleaned.pop()
        if ctor == "comprehension" and len(cleaned) == len(value_fields) + 1:
            cleaned = cleaned[: len(value_fields)]
        if len(cleaned) != len(value_fields):
            raise ActionTranslationError(
                f"arg count mismatch for {ctor}: {len(cleaned)} vs {len(value_fields)} ({cleaned})"
            )
        pairs = []
        for i in range(len(value_fields)):
            val = cleaned[i]
            field = value_fields[i]
            if field == "orelse":
                val = f"pa_stmt_list_or_empty({val})"
            pairs.append(f"{field}={val}")
        if has_loc:
            pairs.append(self._loc_kw())
        return f"{ctor}({', '.join(pairs)})"

    def _build_raise_handlers(
        self,
    ) -> dict[str, Callable[["ActionTranslator", list[Expr]], str]]:
        def simple(msg_idx: int, on_next: bool = False):
            def emit(self: ActionTranslator, args: list[Expr]) -> str:
                msg = self._emit(args[msg_idx])
                on_next_lit = "True" if on_next else "False"
                return f"pa_raise_syntax(p, {on_next_lit}, {msg})"

            return emit

        return {
            "RAISE_SYNTAX_ERROR": simple(0),
            "RAISE_SYNTAX_ERROR_ON_NEXT_TOKEN": simple(0, True),
            "RAISE_INDENTATION_ERROR": simple(0),
            "RAISE_SYNTAX_ERROR_KNOWN_LOCATION": lambda self, args: (
                f"pa_raise_syntax_known_expr(p, False, {self._emit(args[0])}, {self._emit(args[1])})"
            ),
            "RAISE_SYNTAX_ERROR_KNOWN_RANGE": lambda self, args: (
                f"pa_raise_syntax_known_range(p, False, {self._emit(args[0])}, {self._emit(args[1])}, {self._emit(args[2])})"
            ),
            "RAISE_SYNTAX_ERROR_STARTING_FROM": lambda self, args: (
                f"pa_raise_syntax_known_expr(p, False, {self._emit(args[0])}, {self._emit(args[1])})"
            ),
            "RAISE_SYNTAX_ERROR_INVALID_TARGET": lambda self, args: (
                f"pa_raise_invalid_target(p, {self._emit(args[0])}, {self._emit(args[1])})"
            ),
            "RAISE_ERROR_KNOWN_LOCATION": lambda self, args: (
                f"pa_raise_syntax_known_expr(p, False, {self._emit(args[0])}, {self._emit(args[1])})"
            ),
        }

    def _build_pegen_handlers(
        self,
    ) -> dict[str, Callable[["ActionTranslator", list[Expr]], str]]:
        loc = LOC

        def unary(pa: str, arg_idx: int = 0):
            return lambda self, args: f"{pa}({self._emit(args[arg_idx])})"

        def binary(pa: str):
            return lambda self, args: f"{pa}({self._emit(args[0])}, {self._emit(args[1])})"

        def ternary(pa: str):
            return lambda self, args: (
                f"{pa}({self._emit(args[0])}, {self._emit(args[1])}, {self._emit(args[2])})"
            )

        handlers: dict[str, Callable[[ActionTranslator, list[Expr]], str]] = {
            "_PyPegen_singleton_seq": unary("pa_singleton_seq"),
            "_PyPegen_seq_insert_in_front": binary("pa_seq_insert_front"),
            "_PyPegen_seq_append_to_end": lambda self, args: (
                f"pa_seq_append_to_end({', '.join(self._emit(a) for a in args)})"
            ),
            "_PyPegen_seq_flatten": unary("pa_seq_flatten"),
            "_PyPegen_get_cmpops": unary("pa_get_cmpops"),
            "_PyPegen_get_exprs": unary("pa_get_exprs"),
            "_PyPegen_get_keys": unary("pa_get_keys"),
            "_PyPegen_get_values": unary("pa_get_values"),
            "_PyPegen_get_patterns": unary("pa_get_patterns"),
            "_PyPegen_get_pattern_keys": unary("pa_get_pattern_keys"),
            "_PyPegen_map_names_to_ids": unary("pa_map_names_to_ids"),
            "_PyPegen_seq_count_dots": unary("pa_seq_count_dots"),
            "_PyPegen_empty_arguments": lambda self, args: "pa_empty_arguments()",
            "_PyPegen_dummy_name": lambda self, args: f"pa_dummy_name({loc})",
            "_PyPegen_interactive_exit": lambda self, args: "pa_interactive_exit(p)",
            "_PyPegen_make_module": unary("pa_make_module"),
            "_PyPegen_register_stmts": lambda self, args: self._emit(args[0]),
            "_PyPegen_checked_future_import": lambda self, args: (
                f"pa_checked_future_import({self._emit(args[0])}, {self._emit(args[1])}, {self._emit(args[2])}, {loc})"
            ),
            "_PyPegen_nonparen_genexp_in_call": binary("pa_nonparen_genexp_in_call"),
            "_PyPegen_arguments_parsing_error": unary("pa_arguments_parsing_error"),
            "_PyPegen_check_legacy_stmt": lambda self, args: (
                f"pa_check_legacy_stmt(p, {self._emit(args[0])})"
            ),
            "_PyPegen_concatenate_strings": unary("pa_concatenate_strings"),
            "_PyPegen_concatenate_tstrings": unary("pa_concatenate_tstrings"),
            "_PyPegen_constant_from_string": unary("pa_constant_from_string"),
            "_PyPegen_constant_from_token": unary("pa_constant_from_token"),
            "_PyPegen_decoded_constant_from_token": unary("pa_decoded_constant_from_token"),
            "_PyPegen_ensure_imaginary": unary("pa_ensure_imaginary"),
            "_PyPegen_ensure_real": unary("pa_ensure_real"),
            "_PyPegen_get_expr_name": lambda self, args: (
                "pa_get_expr_name()"
                if not args
                else f"pa_get_expr_name({self._emit(args[0])})"
            ),
            "_PyPegen_get_last_comprehension_item": unary("pa_get_last_comprehension_item"),
            "_PyPegen_join_names_with_dot": binary("pa_join_names_with_dot"),
            "_PyPegen_join_sequences": binary("pa_join_sequences"),
            "_PyPegen_alias_for_star": unary("pa_alias_for_star"),
            "_PyPegen_add_type_comment_to_arg": binary("pa_add_type_comment_to_arg"),
            "_PyPegen_seq_delete_starred_exprs": unary("pa_seq_delete_starred_exprs"),
            "_PyPegen_seq_extract_starred_exprs": unary("pa_seq_extract_starred_exprs"),
            "_PyPegen_setup_full_format_spec": unary("pa_setup_full_format_spec"),
            "_PyPegen_check_fstring_conversion": binary("pa_check_fstring_conversion"),
            "_PyPegen_function_def_decorators": binary("pa_function_def_decorators"),
            "_PyPegen_class_def_decorators": binary("pa_class_def_decorators"),
            "_PyPegen_cmpop_expr_pair": lambda self, args: (
                f"pa_make_cmpop_pair({self._emit(args[0])}, {self._emit(args[1])})"
            ),
            "_PyPegen_augoperator": lambda self, args: self._emit(args[0]),
            "_PyPegen_set_expr_context": lambda self, args: (
                f"pa_set_context({self._emit(args[0])}, {self._emit(args[1])})"
            ),
            "_PyPegen_collect_call_seqs": lambda self, args: (
                f"pa_collect_call_seqs({self._emit(args[0])}, {self._emit(args[1])}, {loc})"
            ),
            "_PyPegen_key_value_pair": lambda self, args: (
                f"pa_key_value_pair({self._emit(args[0])}, {self._emit(args[1])}, {loc})"
            ),
            "_PyPegen_key_pattern_pair": lambda self, args: (
                f"pa_key_pattern_pair({self._emit(args[0])}, {self._emit(args[1])}, {loc})"
            ),
            "_PyPegen_name_default_pair": lambda self, args: (
                f"pa_name_default_pair({self._emit(args[0])}, {self._emit(args[1])}, {loc})"
            ),
            "_PyPegen_keyword_or_starred": lambda self, args: (
                f"pa_keyword_or_starred({', '.join(self._emit(a) for a in args)}, {loc})"
            ),
            "_PyPegen_make_arguments": lambda self, args: (
                f"pa_make_arguments({', '.join(self._emit(a) for a in args)}, {loc})"
            ),
            "_PyPegen_star_etc": lambda self, args: (
                f"pa_star_etc({', '.join(self._emit(a) for a in args)}, {loc})"
            ),
            "_PyPegen_slash_with_default": lambda self, args: (
                f"pa_slash_with_default({', '.join(self._emit(a) for a in args)}, {loc})"
            ),
            "_PyPegen_joined_str": lambda self, args: (
                f"pa_joined_str({', '.join(self._emit(a) for a in args)}, {loc})"
            ),
            "_PyPegen_template_str": lambda self, args: (
                f"pa_template_str({', '.join(self._emit(a) for a in args)}, {loc})"
            ),
            "_PyPegen_formatted_value": lambda self, args: (
                f"pa_formatted_value({', '.join(self._emit(a) for a in args)}, {loc})"
            ),
            "_PyPegen_interpolation": lambda self, args: (
                f"pa_interpolation({', '.join(self._emit(a) for a in args)}, {loc})"
            ),
        }
        return handlers

    def _build_ast_handlers(
        self,
    ) -> dict[str, Callable[["ActionTranslator", list[Expr]], str]]:
        loc = LOC

        def with_loc(pa: str, *arg_indices: int):
            def emit(self: ActionTranslator, args: list[Expr]) -> str:
                parts = [self._emit(args[i]) for i in arg_indices]
                parts.append(loc)
                return f"{pa}({', '.join(parts)})"

            return emit

        handlers: dict[str, Callable[[ActionTranslator, list[Expr]], str]] = {
            "_PyAST_Expression": lambda self, args: f"pa_ast_expression({self._emit(args[0])})",
            "_PyAST_Interactive": lambda self, args: f"Interactive(body={self._emit(args[0])})",
            "_PyAST_FunctionType": lambda self, args: (
                f"FunctionType(argtypes={self._emit(args[0])}, returns={self._emit(args[1])})"
            ),
            "_PyAST_BinOp": with_loc("pa_ast_binop", 0, 1, 2),
            "_PyAST_UnaryOp": with_loc("pa_ast_unaryop", 0, 1),
            "_PyAST_BoolOp": with_loc("pa_ast_boolop", 0, 1),
            "_PyAST_Compare": with_loc("pa_ast_compare", 0, 1, 2),
            "_PyAST_IfExp": with_loc("pa_ast_ifexp", 0, 1, 2),
            "_PyAST_Call": lambda self, args: (
                f"pa_ast_call({self._emit(args[0])}, {self._emit(args[1])}, {self._emit(args[2])}, {loc})"
                if len(args) >= 3
                else f"pa_call_from_optional_args({self._emit(args[0])}, b, {loc})"
            ),
            "_PyAST_Starred": with_loc("pa_ast_starred", 0),
            "_PyAST_Constant": lambda self, args: (
                f"pa_constant_bool(True, {loc})"
                if isinstance(args[0], PyBool) and args[0].value
                else f"pa_constant_bool(False, {loc})"
                if isinstance(args[0], PyBool)
                else f"pa_constant_none({loc})"
                if isinstance(args[0], (PyNone, Null))
                else f"pa_constant_from_expr({self._emit(args[0])}, {loc})"
            ),
            "_PyAST_Expr": with_loc("pa_ast_expr_stmt", 0),
            "_PyAST_Assign": with_loc("pa_ast_assign", 0, 1),
            "_PyAST_AnnAssign": lambda self, args: (
                f"pa_ast_annassign({self._emit(args[0])}, {self._emit(args[1])}, {self._emit(args[2])}, {self._emit(args[3])}, {loc})"
            ),
            "_PyAST_Return": with_loc("pa_ast_return", 0),
            "_PyAST_Pass": lambda self, args: f"pa_ast_pass({loc})",
            "_PyAST_Break": lambda self, args: f"pa_ast_break({loc})",
            "_PyAST_Continue": lambda self, args: f"pa_ast_continue({loc})",
            "_PyAST_Tuple": with_loc("pa_ast_tuple", 0, 1),
            "_PyAST_Attribute": with_loc("pa_ast_attribute", 0, 1, 2),
            "_PyAST_Subscript": with_loc("pa_ast_subscript", 0, 1, 2),
            "_PyAST_Slice": with_loc("pa_ast_slice", 0, 1, 2),
            "_PyAST_AugAssign": with_loc("pa_ast_augassign", 0, 1, 2),
            "_PyAST_Delete": with_loc("pa_ast_delete", 0),
        }
        return handlers
