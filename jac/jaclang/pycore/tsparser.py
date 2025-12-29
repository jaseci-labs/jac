"""TypeScript/JavaScript parser for Jac Lang."""

# ruff: noqa: ANN001, ANN201, ANN202, ANN204

from __future__ import annotations

import os
import sys
from collections.abc import Callable
from dataclasses import dataclass
from threading import Event
from typing import TYPE_CHECKING, Protocol, TypeAlias, TypeVar, cast

import jaclang.pycore.lark_ts_parser as ts_lark
import jaclang.pycore.unitree as uni
from jaclang.pycore.constant import TsTokens as Tok
from jaclang.pycore.passes import BaseTransform, Transform
from jaclang.vendor.lark.lexer import Token as LarkToken

if TYPE_CHECKING:
    from jaclang.pycore.program import JacProgram

T = TypeVar("T", bound=uni.UniNode)
TL = TypeVar("TL", bound=(uni.UniNode | list))


class _InteractiveParser(Protocol):
    def accepts(self) -> set[str]: ...

    def feed_token(self, token: object) -> None: ...


@dataclass
class TsLarkParseInput:
    """Input for TypeScript Lark parser transform."""

    ir_value: str
    on_error: Callable[[object], bool]


@dataclass
class TsLarkParseOutput:
    """Output from TypeScript Lark parser transform."""

    tree: object  # Lark Tree
    comments: list[object]  # Lark Tokens


class TsLarkParseTransform(BaseTransform[TsLarkParseInput, TsLarkParseOutput]):
    """Transform for TypeScript Lark parsing step."""

    comment_cache: list[object] = []

    def __init__(self, ir_in: TsLarkParseInput, prog: JacProgram) -> None:
        """Initialize TypeScript Lark parser transform."""
        super().__init__(ir_in=ir_in, prog=prog)

    def transform(self, ir_in: TsLarkParseInput) -> TsLarkParseOutput:
        """Transform input IR by parsing with LALR parser."""
        TsLarkParseTransform.comment_cache = []
        parser = ts_lark.Lark_StandAlone()
        try:
            tree = parser.parse(ir_in.ir_value, on_error=ir_in.on_error)
        except Exception as e:
            # Call error handler if provided
            if ir_in.on_error is not None:
                ir_in.on_error(e)
            raise
        return TsLarkParseOutput(
            tree=tree,
            comments=TsLarkParseTransform.comment_cache.copy(),
        )


class TypeScriptParser(Transform[uni.Source, uni.Module]):
    """TypeScript/JavaScript Parser."""

    def __init__(
        self,
        root_ir: uni.Source,
        prog: JacProgram,
        cancel_token: Event | None = None,
    ) -> None:
        """Initialize parser."""
        self.mod_path = root_ir.loc.mod_path
        self.node_list: list[uni.UniNode] = []
        self._node_ids: set[int] = set()

        if cancel_token and cancel_token.is_set():
            return
        Transform.__init__(self, ir_in=root_ir, prog=prog, cancel_token=cancel_token)

    def transform(self, ir_in: uni.Source) -> uni.Module:
        """Transform input IR."""
        try:
            lark_input = TsLarkParseInput(
                ir_value=ir_in.value,
                on_error=self.error_callback,
            )
            lark_transform = TsLarkParseTransform(ir_in=lark_input, prog=self.prog)
            parse_output = lark_transform.ir_out
            mod = TypeScriptParser.TreeToAST(parser=self).transform(parse_output.tree)
            ir_in.comments = [self.proc_comment(i, mod) for i in parse_output.comments]
            if not isinstance(mod, uni.Module):
                raise self.ice()
            if len(self.errors_had) != 0:
                mod.has_syntax_errors = True
                self.report_errors()
            self.ir_out = mod
            return mod
        except Exception as e:
            if hasattr(e, "line"):
                catch_error = self.error_to_token(e)
                error_msg = self.error_to_message(e)
                self.log_error(error_msg, node_override=catch_error)
            else:
                raise e

        self.report_errors()
        mod = uni.Module.make_stub(inject_src=ir_in)
        mod.has_syntax_errors = True
        return mod

    @staticmethod
    def proc_comment(token: object, mod: uni.UniNode) -> uni.CommentToken:
        """Process comment token."""
        return uni.CommentToken(
            orig_src=mod.loc.orig_src,
            name=getattr(token, "type", "COMMENT"),
            value=getattr(token, "value", str(token)),
            line=getattr(token, "line", 0) or 0,
            end_line=getattr(token, "end_line", 0) or 0,
            col_start=getattr(token, "column", 0) or 0,
            col_end=getattr(token, "end_column", 0) or 0,
            pos_start=getattr(token, "start_pos", 0) or 0,
            pos_end=getattr(token, "end_pos", 0) or 0,
            kid=[],
        )

    _MISSING_TOKENS = [
        Tok.SEMI,
        Tok.COMMA,
        Tok.COLON,
        Tok.RPAREN,
        Tok.RBRACE,
        Tok.RSQUARE,
    ]

    def error_callback(self, e: object) -> bool:
        """Handle parse error with recovery."""
        iparser = getattr(e, "interactive_parser", None)
        if iparser is None:
            return False
        iparser = cast(_InteractiveParser, iparser)

        def try_feed_missing_token(iparser: _InteractiveParser) -> Tok | None:
            """Try to feed a missing token to recover."""
            accepts = iparser.accepts()
            for tok in TypeScriptParser._MISSING_TOKENS:
                if tok.name in accepts:
                    iparser.feed_token(LarkToken(tok.name, tok.value))
                    return tok
            return None

        def feed_current_token(iparser: _InteractiveParser, tok: LarkToken) -> bool:
            """Feed current token after recovery."""
            max_attempts = 100
            attempts = 0
            while tok.type not in iparser.accepts():
                if attempts >= max_attempts:
                    return False
                if not try_feed_missing_token(iparser):
                    return False
                attempts += 1
            iparser.feed_token(tok)
            return True

        if hasattr(e, "token"):
            e_token = cast(LarkToken, e.token)
            if tk := try_feed_missing_token(iparser):
                self.log_error(f"Missing {tk.name}", self.error_to_token(e))
                return feed_current_token(iparser, e_token)

            self.log_error(
                f"Unexpected token '{e_token}'",
                self.error_to_token(e),
            )
            return True

        return False

    def error_to_message(self, e: object) -> str:
        """Convert error to message."""
        if hasattr(e, "token"):
            return f"Unexpected token '{cast(LarkToken, e.token)}'"
        return "Syntax Error"

    def error_to_token(self, e: object) -> uni.Token:
        """Convert error to token for location info."""
        catch_error = uni.EmptyToken()
        catch_error.orig_src = self.ir_in
        catch_error.line_no = getattr(e, "line", 1)
        catch_error.end_line = getattr(e, "line", 1)
        catch_error.c_start = getattr(e, "column", 0)
        catch_error.pos_start = getattr(e, "pos_in_stream", 0) or 0
        if hasattr(e, "token") and e.token:
            catch_error.c_end = getattr(e.token, "end_column", catch_error.c_start + 1)
            catch_error.pos_end = getattr(e.token, "end_pos", catch_error.pos_start + 1)
        else:
            catch_error.c_end = catch_error.c_start + 1
            catch_error.pos_end = catch_error.pos_start + 1
        return catch_error

    def report_errors(self, *, colors: bool = True) -> None:
        """Report errors to user."""
        from jaclang.pycore.helpers import ANSIColors

        if not sys.stderr.isatty():
            colors = False
        for alrt in self.errors_had:
            error_label = (
                "Error:" if not colors else f"{ANSIColors.RED}Error:{ANSIColors.END}"
            )
            print(error_label, end=" ", file=sys.stderr)
            print(alrt.pretty_print(colors=colors), file=sys.stderr)

    TsTransformer: TypeAlias = object  # Will be Lark Transformer

    class TreeToAST:
        """Transform TypeScript parse tree to AST."""

        def __init__(self, parser: TypeScriptParser) -> None:
            """Initialize transformer."""
            self.parse_ref = parser
            self.terminals: list[uni.Token] = []
            self.node_idx = 0
            self.cur_nodes: list[uni.UniNode] = []

        def transform(self, tree: object) -> uni.Module:
            """Transform the parse tree to AST."""
            lark_module = ts_lark
            transformer_base = lark_module.Transformer
            outer_ref = self

            # Dynamic class inheritance from Lark Transformer requires type: ignore
            # since Python's type system doesn't support runtime base classes
            class _InnerTransformer(transformer_base):  # type: ignore[misc, valid-type]
                """Inner Lark transformer."""

                def __init__(self) -> None:
                    super().__init__()
                    self.outer = outer_ref

                def _get_token(self, token: LarkToken) -> uni.Token:
                    """Convert Lark token to uni.Token."""
                    tok_type = token.type
                    tok_value = str(token)
                    tok_line = token.line or 1
                    tok_end_line = token.end_line or tok_line
                    tok_column = token.column or 0
                    tok_end_column = token.end_column or (tok_column + len(tok_value))
                    tok_start_pos = token.start_pos or 0
                    tok_end_pos = token.end_pos or (tok_start_pos + len(tok_value))
                    return uni.Token(
                        orig_src=self.outer.parse_ref.ir_in,
                        name=tok_type,
                        value=tok_value,
                        line=tok_line,
                        end_line=tok_end_line,
                        col_start=tok_column,
                        col_end=tok_end_column,
                        pos_start=tok_start_pos,
                        pos_end=tok_end_pos,
                    )

                def _make_name(self, token: LarkToken) -> uni.Name:
                    """Create a Name node from token."""
                    return uni.Name(
                        orig_src=self.outer.parse_ref.ir_in,
                        name=Tok.NAME.name,
                        value=str(token),
                        line=token.line or 1,
                        end_line=token.end_line or (token.line or 1),
                        col_start=token.column or 0,
                        col_end=token.end_column or (token.column or 0),
                        pos_start=token.start_pos or 0,
                        pos_end=token.end_pos or (token.start_pos or 0),
                    )

                def __default_token__(self, token: LarkToken) -> uni.Token:
                    """Default token handler."""
                    return self._get_token(token)

                def start(self, items: list[object]) -> uni.Module:
                    """start: source_file"""
                    if items and isinstance(items[0], uni.Module):
                        items[0]._in_mod_nodes = self.outer.parse_ref.node_list
                        return items[0]
                    return self.outer._make_module([])

                def source_file(self, items):
                    """source_file: statement*"""
                    stmts = [i for i in items if isinstance(i, uni.UniNode)]
                    return self.outer._make_module(stmts)

                def statement(self, items):
                    """statement: declaration | ..."""
                    return items[0] if items else None

                def declaration(self, items):
                    """declaration: var_decl | func_decl | ..."""
                    return items[0] if items else None

                # Variable Declarations
                def var_decl(self, items):
                    """var_decl: (KW_VAR | KW_LET | KW_CONST) binding_list semi"""
                    kids = [i for i in items if i is not None]
                    keyword = kids[0] if kids else None
                    is_frozen = False
                    if isinstance(keyword, uni.Token):
                        is_frozen = keyword.name in (Tok.KW_CONST.name, "KW_CONST")

                    bindings = []
                    for item in kids[1:]:
                        if isinstance(item, list):
                            bindings.extend(item)
                        elif isinstance(item, uni.Assignment):
                            bindings.append(item)

                    return uni.GlobalVars(
                        access=None,
                        assignments=bindings,
                        is_frozen=is_frozen,
                        kid=kids,
                    )

                def binding_list(self, items):
                    """binding_list: binding (COMMA binding)*"""
                    return [i for i in items if isinstance(i, uni.Assignment)]

                def binding(self, items):
                    """binding: binding_pattern type_annotation? initializer?"""
                    kids = [i for i in items if i is not None]
                    name = None
                    type_tag = None
                    value = None

                    for item in kids:
                        if isinstance(item, (uni.Name, uni.Token)) and name is None:
                            if (
                                isinstance(item, uni.Token)
                                and item.name == Tok.NAME.name
                            ):
                                name = uni.Name(
                                    orig_src=item.orig_src,
                                    name=item.name,
                                    value=item.value,
                                    line=item.line_no,
                                    end_line=item.end_line,
                                    col_start=item.c_start,
                                    col_end=item.c_end,
                                    pos_start=item.pos_start,
                                    pos_end=item.pos_end,
                                )
                            elif isinstance(item, uni.Name):
                                name = item
                        elif isinstance(item, uni.SubTag):
                            type_tag = item
                        elif isinstance(item, uni.Expr):
                            value = item

                    if name is None:
                        return None

                    return uni.Assignment(
                        target=uni.AtomTrailer(
                            target=name,
                            right=None,
                            is_null_ok=False,
                            is_attr=False,
                            kid=[name],
                        ),
                        type_tag=type_tag,
                        value=value,
                        kid=kids,
                    )

                def binding_pattern(self, items):
                    """binding_pattern: NAME | array_binding | object_binding"""
                    if items:
                        item = items[0]
                        if hasattr(item, "value"):
                            return self._make_name(item)
                        return item
                    return None

                def type_annotation(self, items):
                    """type_annotation: COLON type"""
                    kids = [i for i in items if i is not None]
                    if len(kids) >= 2:
                        type_expr = kids[1] if isinstance(kids[1], uni.Expr) else None
                        if type_expr:
                            return uni.SubTag[uni.Expr](tag=type_expr, kid=kids)
                    return None

                def initializer(self, items):
                    """initializer: EQ assignment_expr"""
                    if len(items) >= 2:
                        return items[1]
                    return items[0] if items else None

                # Function Declarations
                def func_decl(self, items):
                    """func_decl: KW_ASYNC? KW_FUNCTION STAR? NAME? ..."""
                    kids = [i for i in items if i is not None]
                    is_async = False
                    name = None
                    params = []
                    return_type = None
                    body = []

                    for item in kids:
                        if isinstance(item, uni.Token):
                            if item.name in (Tok.KW_ASYNC.name, "KW_ASYNC"):
                                is_async = True
                            elif item.name in (Tok.NAME.name, "NAME") and name is None:
                                name = self._make_name(item)
                        elif isinstance(item, uni.Name) and name is None:
                            name = item
                        elif isinstance(item, list):
                            if not params:
                                params = [
                                    p for p in item if isinstance(p, uni.ParamVar)
                                ]
                            else:
                                body = [
                                    s for s in item if isinstance(s, uni.CodeBlockStmt)
                                ]
                        elif isinstance(item, uni.SubTag):
                            return_type = item

                    if name is None:
                        name = uni.Name.gen_stub_from_node(
                            self.outer.parse_ref.ir_in, "[anonymous]"
                        )

                    sig = uni.FuncSignature(
                        params=params,
                        return_type=return_type.tag if return_type else None,
                        kid=kids,
                    )

                    return uni.Ability(
                        name_ref=name,
                        is_func=True,
                        is_async=is_async,
                        is_override=False,
                        is_static=False,
                        is_abstract=False,
                        access=None,
                        signature=sig,
                        body=body,
                        decorators=None,
                        doc=None,
                        kid=kids,
                    )

                def param_list(self, items):
                    """param_list: param (COMMA param)*"""
                    return [i for i in items if isinstance(i, uni.ParamVar)]

                def param(self, items):
                    """param: binding_pattern QUESTION? type_annotation? initializer?"""
                    kids = [i for i in items if i is not None]
                    name = None
                    type_tag = None
                    default_val = None

                    for item in kids:
                        if isinstance(item, uni.Name) and name is None:
                            name = item
                        elif isinstance(item, uni.Token):
                            if item.name in (Tok.NAME.name, "NAME") and name is None:
                                name = self._make_name(item)
                            # QUESTION token indicates optional param (currently unused)
                        elif isinstance(item, uni.SubTag):
                            type_tag = item
                        elif isinstance(item, uni.Expr) and default_val is None:
                            default_val = item

                    if name is None:
                        return None

                    return uni.ParamVar(
                        name=name,
                        unpack=None,
                        type_tag=type_tag,
                        value=default_val,
                        kid=kids,
                    )

                def func_body(self, items):
                    """func_body: block_stmt"""
                    return items[0] if items else []

                # Class Declarations
                def class_decl(self, items):
                    """class_decl: decorators? KW_ABSTRACT? KW_CLASS NAME? ..."""
                    kids = [i for i in items if i is not None]
                    name = None
                    base_classes = []
                    body = []
                    decorators = []

                    for item in kids:
                        if isinstance(item, uni.Token):
                            # KW_ABSTRACT token indicates abstract class (currently unused)
                            if item.name in (Tok.NAME.name, "NAME") and name is None:
                                name = self._make_name(item)
                        elif isinstance(item, uni.Name) and name is None:
                            name = item
                        elif isinstance(item, list):
                            if all(isinstance(i, uni.Expr) for i in item):
                                decorators = item
                            elif all(isinstance(i, uni.ArchBlockStmt) for i in item):
                                body = item
                            else:
                                body = [
                                    i for i in item if isinstance(i, uni.ArchBlockStmt)
                                ]

                    if name is None:
                        name = uni.Name.gen_stub_from_node(
                            self.outer.parse_ref.ir_in, "[anonymous]"
                        )

                    return uni.Archetype(
                        name=name,
                        arch_type=uni.Token(
                            orig_src=self.outer.parse_ref.ir_in,
                            name="KW_CLASS",
                            value="class",
                            line=1,
                            end_line=1,
                            col_start=0,
                            col_end=5,
                            pos_start=0,
                            pos_end=5,
                        ),
                        access=None,
                        base_classes=base_classes,
                        body=body,
                        decorators=decorators if decorators else None,
                        doc=None,
                        kid=kids,
                    )

                def class_body(self, items):
                    """class_body: LBRACE class_element* RBRACE"""
                    return [i for i in items if isinstance(i, uni.ArchBlockStmt)]

                def class_element(self, items):
                    """class_element: decorators? class_element_modifiers? class_member"""
                    if items:
                        for item in items:
                            if isinstance(item, uni.ArchBlockStmt):
                                return item
                    return None

                def class_member(self, items):
                    """class_member: property_definition | method_definition | ..."""
                    return items[0] if items else None

                def property_definition(self, items):
                    """property_definition: property_name ...? type_annotation? initializer?"""
                    kids = [i for i in items if i is not None]
                    name = None
                    type_tag = None
                    value = None

                    for item in kids:
                        if isinstance(item, uni.Name) and name is None:
                            name = item
                        elif isinstance(item, uni.Token) and name is None:
                            if item.name in (Tok.NAME.name, "NAME"):
                                name = self._make_name(item)
                        elif isinstance(item, uni.SubTag):
                            type_tag = item
                        elif isinstance(item, uni.Expr):
                            value = item

                    if name is None:
                        return None

                    return uni.HasVar(
                        name=name,
                        type_tag=type_tag,
                        value=value,
                        is_static=False,
                        is_frozen=False,
                        access=None,
                        doc=None,
                        kid=kids,
                    )

                def method_definition(self, items):
                    """method_definition: KW_ASYNC? STAR? property_name ..."""
                    kids = [i for i in items if i is not None]
                    is_async = False
                    name = None
                    params = []
                    return_type = None
                    body = []

                    for item in kids:
                        if isinstance(item, uni.Token):
                            if item.name in (Tok.KW_ASYNC.name, "KW_ASYNC"):
                                is_async = True
                            # STAR token indicates generator (currently unused)
                            elif item.name in (Tok.NAME.name, "NAME") and name is None:
                                name = self._make_name(item)
                        elif isinstance(item, uni.Name) and name is None:
                            name = item
                        elif isinstance(item, list):
                            if all(isinstance(p, uni.ParamVar) for p in item if p):
                                params = [
                                    p for p in item if isinstance(p, uni.ParamVar)
                                ]
                            else:
                                body = [
                                    s for s in item if isinstance(s, uni.CodeBlockStmt)
                                ]
                        elif isinstance(item, uni.SubTag):
                            return_type = item

                    if name is None:
                        return None

                    sig = uni.FuncSignature(
                        params=params,
                        return_type=return_type.tag if return_type else None,
                        kid=kids,
                    )

                    return uni.Ability(
                        name_ref=name,
                        is_func=True,
                        is_async=is_async,
                        is_override=False,
                        is_static=False,
                        is_abstract=False,
                        access=None,
                        signature=sig,
                        body=body,
                        decorators=None,
                        doc=None,
                        kid=kids,
                    )

                # Interface Declarations
                def interface_decl(self, items):
                    """interface_decl: KW_INTERFACE NAME type_params? ..."""
                    kids = [i for i in items if i is not None]
                    name = None
                    body = []

                    for item in kids:
                        if isinstance(item, uni.Token):
                            if item.name in (Tok.NAME.name, "NAME") and name is None:
                                name = self._make_name(item)
                        elif isinstance(item, uni.Name) and name is None:
                            name = item
                        elif isinstance(item, list):
                            body = [i for i in item if isinstance(i, uni.ArchBlockStmt)]

                    if name is None:
                        name = uni.Name.gen_stub_from_node(
                            self.outer.parse_ref.ir_in, "[anonymous]"
                        )

                    return uni.Archetype(
                        name=name,
                        arch_type=uni.Token(
                            orig_src=self.outer.parse_ref.ir_in,
                            name="KW_INTERFACE",
                            value="interface",
                            line=1,
                            end_line=1,
                            col_start=0,
                            col_end=9,
                            pos_start=0,
                            pos_end=9,
                        ),
                        access=None,
                        base_classes=[],
                        body=body,
                        decorators=None,
                        doc=None,
                        kid=kids,
                    )

                # Type Alias
                def type_alias_decl(self, items):
                    """type_alias_decl: KW_TYPE NAME type_params? EQ type semi"""
                    kids = [i for i in items if i is not None]
                    name = None
                    type_val = None

                    for item in kids:
                        if isinstance(item, uni.Token):
                            if item.name in (Tok.NAME.name, "NAME") and name is None:
                                name = self._make_name(item)
                        elif isinstance(item, uni.Name) and name is None:
                            name = item
                        elif isinstance(item, uni.Expr):
                            type_val = item

                    if name is None:
                        return None

                    # Use Assignment to represent type alias
                    return uni.Assignment(
                        target=uni.AtomTrailer(
                            target=name,
                            right=None,
                            is_null_ok=False,
                            is_attr=False,
                            kid=[name],
                        ),
                        type_tag=None,
                        value=type_val,
                        kid=kids,
                    )

                # Enum Declarations
                def enum_decl(self, items):
                    """enum_decl: KW_CONST? KW_ENUM NAME LBRACE enum_member_list? RBRACE"""
                    kids = [i for i in items if i is not None]
                    name = None
                    members = []

                    for item in kids:
                        if isinstance(item, uni.Token):
                            if item.name in (Tok.NAME.name, "NAME") and name is None:
                                name = self._make_name(item)
                        elif isinstance(item, uni.Name) and name is None:
                            name = item
                        elif isinstance(item, list):
                            members = [m for m in item if isinstance(m, uni.Assignment)]

                    if name is None:
                        name = uni.Name.gen_stub_from_node(
                            self.outer.parse_ref.ir_in, "[anonymous]"
                        )

                    return uni.Enum(
                        name=name,
                        access=None,
                        base_classes=[],
                        body=members,
                        decorators=None,
                        doc=None,
                        kid=kids,
                    )

                def enum_member_list(self, items):
                    """enum_member_list: enum_member (COMMA enum_member)*"""
                    return [i for i in items if isinstance(i, uni.Assignment)]

                def enum_member(self, items):
                    """enum_member: property_name (EQ assignment_expr)?"""
                    kids = [i for i in items if i is not None]
                    name = None
                    value = None

                    for item in kids:
                        if isinstance(item, uni.Name) and name is None:
                            name = item
                        elif isinstance(item, uni.Token):
                            if item.name in (Tok.NAME.name, "NAME") and name is None:
                                name = self._make_name(item)
                        elif isinstance(item, uni.Expr):
                            value = item

                    if name is None:
                        return None

                    return uni.Assignment(
                        target=uni.AtomTrailer(
                            target=name,
                            right=None,
                            is_null_ok=False,
                            is_attr=False,
                            kid=[name],
                        ),
                        type_tag=None,
                        value=value,
                        kid=kids,
                    )

                # Import/Export
                def import_decl(self, items):
                    """import_decl: KW_IMPORT ..."""
                    kids = [i for i in items if i is not None]
                    from_loc = None
                    import_items = []

                    for item in kids:
                        if isinstance(item, uni.Token):
                            pass  # KW_TYPE token indicates type-only import (currently unused)
                        elif isinstance(item, uni.ModulePath):
                            from_loc = item
                        elif isinstance(item, list):
                            import_items = [
                                i for i in item if isinstance(i, uni.ModuleItem)
                            ]
                        elif isinstance(item, uni.ModuleItem):
                            import_items.append(item)

                    return uni.Import(
                        from_loc=from_loc,
                        items=import_items
                        if import_items
                        else [from_loc]
                        if from_loc
                        else [],
                        is_absorb=False,
                        kid=kids,
                    )

                def from_clause(self, items):
                    """from_clause: KW_FROM module_specifier"""
                    for item in items:
                        if isinstance(item, uni.ModulePath):
                            return item
                        if isinstance(item, uni.Token) and item.name in (
                            "STRING",
                            Tok.STRING.name,
                        ):
                            path_val = item.value.strip("'\"")
                            return uni.ModulePath(
                                path=[
                                    uni.Name(
                                        orig_src=item.orig_src,
                                        name="NAME",
                                        value=path_val,
                                        line=item.line_no,
                                        end_line=item.end_line,
                                        col_start=item.c_start,
                                        col_end=item.c_end,
                                        pos_start=item.pos_start,
                                        pos_end=item.pos_end,
                                    )
                                ],
                                level=0,
                                alias=None,
                                kid=[item],
                            )
                    return None

                def module_specifier(self, items):
                    """module_specifier: STRING"""
                    if items:
                        item = items[0]
                        if isinstance(item, uni.Token):
                            path_val = item.value.strip("'\"")
                            return uni.ModulePath(
                                path=[
                                    uni.Name(
                                        orig_src=item.orig_src,
                                        name="NAME",
                                        value=path_val,
                                        line=item.line_no,
                                        end_line=item.end_line,
                                        col_start=item.c_start,
                                        col_end=item.c_end,
                                        pos_start=item.pos_start,
                                        pos_end=item.pos_end,
                                    )
                                ],
                                level=0,
                                alias=None,
                                kid=[item],
                            )
                    return None

                def named_imports(self, items):
                    """named_imports: LBRACE import_specifier_list? RBRACE"""
                    result = []
                    for item in items:
                        if isinstance(item, list):
                            result.extend(
                                [i for i in item if isinstance(i, uni.ModuleItem)]
                            )
                        elif isinstance(item, uni.ModuleItem):
                            result.append(item)
                    return result

                def import_specifier_list(self, items):
                    """import_specifier_list: import_specifier (COMMA import_specifier)*"""
                    return [i for i in items if isinstance(i, uni.ModuleItem)]

                def import_specifier(self, items):
                    """import_specifier: NAME (KW_AS NAME)?"""
                    kids = [i for i in items if i is not None]
                    name = None
                    alias = None

                    for item in kids:
                        if isinstance(item, uni.Token) and item.name in (
                            Tok.NAME.name,
                            "NAME",
                        ):
                            if name is None:
                                name = self._make_name(item)
                            else:
                                alias = self._make_name(item)

                    if name is None:
                        return None

                    return uni.ModuleItem(
                        name=name,
                        alias=alias,
                        kid=kids,
                    )

                def export_decl(self, items):
                    """export_decl: KW_EXPORT ..."""
                    # For simplicity, return the inner declaration
                    for item in items:
                        if isinstance(item, uni.UniNode) and not isinstance(
                            item, uni.Token
                        ):
                            return item
                    return None

                # Control Flow
                def block_stmt(self, items):
                    """block_stmt: LBRACE statement* RBRACE"""
                    return [i for i in items if isinstance(i, uni.CodeBlockStmt)]

                def if_stmt(self, items):
                    """if_stmt: KW_IF LPAREN expression RPAREN statement (KW_ELSE statement)?"""
                    kids = [i for i in items if i is not None]
                    condition = None
                    body = []
                    else_body = None

                    for item in kids:
                        if isinstance(item, uni.Expr) and condition is None:
                            condition = item
                        elif isinstance(item, uni.CodeBlockStmt):
                            if not body:
                                body = [item]
                            else:
                                else_body = uni.ElseStmt(body=[item], kid=[item])
                        elif isinstance(item, list):
                            if not body:
                                body = [
                                    i for i in item if isinstance(i, uni.CodeBlockStmt)
                                ]
                            else:
                                else_stmts = [
                                    i for i in item if isinstance(i, uni.CodeBlockStmt)
                                ]
                                if else_stmts:
                                    else_body = uni.ElseStmt(
                                        body=else_stmts, kid=else_stmts
                                    )

                    return uni.IfStmt(
                        condition=condition,
                        body=body,
                        else_body=else_body,
                        kid=kids,
                    )

                def while_stmt(self, items):
                    """while_stmt: KW_WHILE LPAREN expression RPAREN statement"""
                    kids = [i for i in items if i is not None]
                    condition = None
                    body = []

                    for item in kids:
                        if isinstance(item, uni.Expr) and condition is None:
                            condition = item
                        elif isinstance(item, uni.CodeBlockStmt):
                            body = [item]
                        elif isinstance(item, list):
                            body = [i for i in item if isinstance(i, uni.CodeBlockStmt)]

                    return uni.WhileStmt(
                        condition=condition,
                        body=body,
                        kid=kids,
                    )

                def for_stmt(self, items):
                    """for_stmt: KW_FOR LPAREN for_init? SEMI expression? SEMI expression? RPAREN statement"""
                    kids = [i for i in items if i is not None]
                    body = []

                    for item in kids:
                        if isinstance(item, list):
                            body = [i for i in item if isinstance(i, uni.CodeBlockStmt)]
                        elif isinstance(item, uni.CodeBlockStmt):
                            body = [item]

                    # Create an IterForStmt as approximation
                    return uni.IterForStmt(
                        iter=None,
                        condition=None,
                        count_by=None,
                        body=body,
                        else_body=None,
                        is_async=False,
                        kid=kids,
                    )

                def for_in_stmt(self, items):
                    """for_in_stmt: KW_FOR ..."""
                    return self.for_stmt(items)

                def for_of_stmt(self, items):
                    """for_of_stmt: KW_FOR ..."""
                    return self.for_stmt(items)

                def return_stmt(self, items):
                    """return_stmt: KW_RETURN expression? semi"""
                    kids = [i for i in items if i is not None]
                    expr = None
                    for item in kids:
                        if isinstance(item, uni.Expr):
                            expr = item
                            break

                    return uni.ReturnStmt(expr=expr, kid=kids)

                def try_stmt(self, items):
                    """try_stmt: KW_TRY block_stmt catch_clause? finally_clause?"""
                    kids = [i for i in items if i is not None]
                    body = []
                    excepts = []
                    finally_body = None

                    for item in kids:
                        if isinstance(item, list):
                            if not body:
                                body = [
                                    i for i in item if isinstance(i, uni.CodeBlockStmt)
                                ]
                        elif isinstance(item, uni.Except):
                            excepts.append(item)
                        elif isinstance(item, uni.FinallyStmt):
                            finally_body = item

                    return uni.TryStmt(
                        body=body,
                        excepts=excepts,
                        finally_body=finally_body,
                        kid=kids,
                    )

                def catch_clause(self, items):
                    """catch_clause: KW_CATCH (LPAREN binding_pattern type_annotation? RPAREN)? block_stmt"""
                    kids = [i for i in items if i is not None]
                    name = None
                    body = []

                    for item in kids:
                        if isinstance(item, uni.Name) and name is None:
                            name = item
                        elif isinstance(item, uni.Token) and name is None:
                            if item.name in (Tok.NAME.name, "NAME"):
                                name = self._make_name(item)
                        elif isinstance(item, list):
                            body = [i for i in item if isinstance(i, uni.CodeBlockStmt)]

                    return uni.Except(
                        ex_type=None,
                        name=name,
                        body=body,
                        kid=kids,
                    )

                def finally_clause(self, items):
                    """finally_clause: KW_FINALLY block_stmt"""
                    kids = [i for i in items if i is not None]
                    body = []
                    for item in kids:
                        if isinstance(item, list):
                            body = [i for i in item if isinstance(i, uni.CodeBlockStmt)]

                    return uni.FinallyStmt(body=body, kid=kids)

                def throw_stmt(self, items):
                    """throw_stmt: KW_THROW expression semi"""
                    kids = [i for i in items if i is not None]
                    expr = None
                    for item in kids:
                        if isinstance(item, uni.Expr):
                            expr = item
                            break

                    return uni.RaiseStmt(cause=expr, from_target=None, kid=kids)

                def break_stmt(self, items):
                    """break_stmt: KW_BREAK NAME? semi"""
                    return uni.CtrlStmt(
                        ctrl=uni.Token(
                            orig_src=self.outer.parse_ref.ir_in,
                            name="KW_BREAK",
                            value="break",
                            line=1,
                            end_line=1,
                            col_start=0,
                            col_end=5,
                            pos_start=0,
                            pos_end=5,
                        ),
                        kid=[i for i in items if i is not None],
                    )

                def continue_stmt(self, items):
                    """continue_stmt: KW_CONTINUE NAME? semi"""
                    return uni.CtrlStmt(
                        ctrl=uni.Token(
                            orig_src=self.outer.parse_ref.ir_in,
                            name="KW_CONTINUE",
                            value="continue",
                            line=1,
                            end_line=1,
                            col_start=0,
                            col_end=8,
                            pos_start=0,
                            pos_end=8,
                        ),
                        kid=[i for i in items if i is not None],
                    )

                def empty_stmt(self, items):
                    """empty_stmt: SEMI"""
                    return None

                def expr_stmt(self, items):
                    """expr_stmt: expression semi"""
                    kids = [i for i in items if i is not None]
                    for item in kids:
                        if isinstance(item, uni.Expr):
                            return uni.ExprStmt(expr=item, kid=kids)
                    return None

                # Expressions
                def expression(self, items):
                    """expression: assignment_expr (COMMA assignment_expr)*"""
                    exprs = [i for i in items if isinstance(i, uni.Expr)]
                    if len(exprs) == 1:
                        return exprs[0]
                    elif len(exprs) > 1:
                        return uni.TupleVal(values=exprs, kid=list(items))
                    return None

                def assignment_expr(self, items):
                    """assignment_expr: conditional_expr | left_hand_side_expr assignment_op assignment_expr"""
                    kids = [i for i in items if i is not None]
                    if len(kids) == 1:
                        return kids[0] if isinstance(kids[0], uni.Expr) else None

                    # Assignment case
                    if len(kids) >= 3:
                        target = kids[0]
                        # kids[1] is the assignment operator (unused)
                        value = kids[2]
                        if isinstance(target, uni.Expr) and isinstance(value, uni.Expr):
                            return uni.Assignment(
                                target=target,
                                type_tag=None,
                                value=value,
                                kid=kids,
                            )
                    return kids[0] if kids and isinstance(kids[0], uni.Expr) else None

                def conditional_expr(self, items):
                    """conditional_expr: nullish_coalescing_expr (QUESTION assignment_expr COLON assignment_expr)?"""
                    kids = [i for i in items if i is not None]
                    exprs = [i for i in kids if isinstance(i, uni.Expr)]

                    if len(exprs) == 1:
                        return exprs[0]
                    elif len(exprs) == 3:
                        return uni.IfElseExpr(
                            condition=exprs[0],
                            value=exprs[1],
                            else_value=exprs[2],
                            kid=kids,
                        )
                    return exprs[0] if exprs else None

                def _binary_expr(self, items, op_name: str = "OP"):
                    """Helper for binary expressions."""
                    kids = [i for i in items if i is not None]
                    exprs = [i for i in kids if isinstance(i, uni.Expr)]
                    ops = [i for i in kids if isinstance(i, uni.Token)]

                    if len(exprs) == 1:
                        return exprs[0]
                    elif len(exprs) >= 2 and ops:
                        return uni.BinaryExpr(
                            left=exprs[0],
                            op=ops[0],
                            right=exprs[1],
                            kid=kids,
                        )
                    return exprs[0] if exprs else None

                def nullish_coalescing_expr(self, items):
                    return self._binary_expr(items, "NULLISH_COALESCE")

                def logical_or_expr(self, items):
                    return self._binary_expr(items, "OR")

                def logical_and_expr(self, items):
                    return self._binary_expr(items, "AND")

                def bitwise_or_expr(self, items):
                    return self._binary_expr(items, "BW_OR")

                def bitwise_xor_expr(self, items):
                    return self._binary_expr(items, "BW_XOR")

                def bitwise_and_expr(self, items):
                    return self._binary_expr(items, "BW_AND")

                def equality_expr(self, items):
                    return self._binary_expr(items, "EQ")

                def relational_expr(self, items):
                    return self._binary_expr(items, "CMP")

                def shift_expr(self, items):
                    return self._binary_expr(items, "SHIFT")

                def additive_expr(self, items):
                    return self._binary_expr(items, "ADD")

                def multiplicative_expr(self, items):
                    return self._binary_expr(items, "MUL")

                def exponentiation_expr(self, items):
                    return self._binary_expr(items, "EXP")

                def unary_expr(self, items):
                    """unary_expr: postfix_expr | (op) unary_expr"""
                    kids = [i for i in items if i is not None]
                    if len(kids) == 1:
                        return kids[0] if isinstance(kids[0], uni.Expr) else None

                    # Unary operation
                    op = None
                    operand = None
                    for item in kids:
                        if isinstance(item, uni.Token) and op is None:
                            op = item
                        elif isinstance(item, uni.Expr):
                            operand = item

                    if op and operand:
                        return uni.UnaryExpr(op=op, operand=operand, kid=kids)
                    return operand

                def postfix_expr(self, items):
                    """postfix_expr: left_hand_side_expr (PLUS_PLUS | MINUS_MINUS)?"""
                    kids = [i for i in items if i is not None]
                    expr = None
                    op = None
                    for item in kids:
                        if isinstance(item, uni.Expr) and expr is None:
                            expr = item
                        elif isinstance(item, uni.Token):
                            op = item

                    if op and expr:
                        return uni.UnaryExpr(op=op, operand=expr, kid=kids)
                    return expr

                def left_hand_side_expr(self, items):
                    """left_hand_side_expr: call_expr | new_expr"""
                    return items[0] if items else None

                def new_expr(self, items):
                    """new_expr: member_expr | KW_NEW new_expr"""
                    return items[-1] if items else None

                def call_expr(self, items):
                    """call_expr: member_expr arguments | ..."""
                    kids = [i for i in items if i is not None]
                    target = None
                    args = []

                    for item in kids:
                        if isinstance(item, uni.Expr) and target is None:
                            target = item
                        elif isinstance(item, list):
                            args = [a for a in item if isinstance(a, uni.Expr)]

                    if target:
                        if args or any(isinstance(k, list) for k in kids):
                            return uni.FuncCall(
                                target=target,
                                params=args,
                                kid=kids,
                            )
                        return target
                    return None

                def member_expr(self, items):
                    """member_expr: primary_expr | member_expr DOT NAME | member_expr LSQUARE expression RSQUARE"""
                    kids = [i for i in items if i is not None]
                    if len(kids) == 1:
                        return kids[0] if isinstance(kids[0], uni.Expr) else None

                    # Member access
                    target = None
                    accessor = None
                    for item in kids:
                        if isinstance(item, uni.Expr) and target is None:
                            target = item
                        elif isinstance(item, (uni.Name, uni.Token)):
                            if isinstance(item, uni.Token) and item.name in (
                                Tok.NAME.name,
                                "NAME",
                            ):
                                accessor = self._make_name(item)
                            elif isinstance(item, uni.Name):
                                accessor = item
                        elif isinstance(item, uni.Expr) and target is not None:
                            accessor = item

                    if target and accessor:
                        return uni.AtomTrailer(
                            target=target,
                            right=accessor,
                            is_null_ok=False,
                            is_attr=isinstance(accessor, uni.Name),
                            kid=kids,
                        )
                    return target

                def arguments(self, items):
                    """arguments: type_args? LPAREN argument_list? RPAREN"""
                    for item in items:
                        if isinstance(item, list):
                            return item
                    return []

                def argument_list(self, items):
                    """argument_list: argument (COMMA argument)*"""
                    return [i for i in items if isinstance(i, uni.Expr)]

                def argument(self, items):
                    """argument: ELLIPSIS? assignment_expr"""
                    for item in items:
                        if isinstance(item, uni.Expr):
                            return item
                    return None

                def primary_expr(self, items):
                    """primary_expr: KW_THIS | NAME | literal | ..."""
                    if items:
                        item = items[0]
                        if isinstance(item, uni.Token):
                            if item.name in (Tok.NAME.name, "NAME"):
                                return self._make_name(item)
                            elif item.name in (
                                Tok.KW_THIS.name,
                                "KW_THIS",
                            ) or item.name in (Tok.KW_SUPER.name, "KW_SUPER"):
                                return uni.SpecialVarRef(
                                    var=item,
                                    kid=[item],
                                )
                        return item if isinstance(item, uni.Expr) else None
                    return None

                def paren_expr(self, items):
                    """paren_expr: LPAREN expression RPAREN"""
                    for item in items:
                        if isinstance(item, uni.Expr):
                            return item
                    return None

                # Literals
                def literal(self, items):
                    """literal: NULL | TRUE | FALSE | NUMBER | STRING | REGEX"""
                    if items:
                        item = items[0]
                        if isinstance(item, uni.Token):
                            if item.name in ("NULL", Tok.NULL.name):
                                return uni.Null(kid=[item])
                            elif item.name in (
                                "TRUE",
                                "FALSE",
                                Tok.TRUE.name,
                                Tok.FALSE.name,
                            ):
                                return uni.Bool(
                                    value=item.value.lower() == "true",
                                    kid=[item],
                                )
                            elif item.name in ("NUMBER", Tok.NUMBER.name):
                                if "." in item.value or "e" in item.value.lower():
                                    return uni.Float(
                                        value=item.value,
                                        kid=[item],
                                    )
                                else:
                                    return uni.Int(
                                        value=item.value,
                                        kid=[item],
                                    )
                            elif item.name in (
                                "STRING",
                                Tok.STRING.name,
                            ) or item.name in ("REGEX", Tok.REGEX.name):
                                return uni.String(
                                    value=item.value,
                                    kid=[item],
                                )
                        return item if isinstance(item, uni.Expr) else None
                    return None

                def array_literal(self, items):
                    """array_literal: LSQUARE element_list? RSQUARE"""
                    elements = []
                    for item in items:
                        if isinstance(item, list):
                            elements = [e for e in item if isinstance(e, uni.Expr)]
                        elif isinstance(item, uni.Expr):
                            elements.append(item)
                    return uni.ListVal(values=elements, kid=list(items))

                def element_list(self, items):
                    """element_list: array_element (COMMA array_element)*"""
                    return [i for i in items if isinstance(i, uni.Expr)]

                def array_element(self, items):
                    """array_element: ELLIPSIS? assignment_expr | COMMA"""
                    for item in items:
                        if isinstance(item, uni.Expr):
                            return item
                    return None

                def object_literal(self, items):
                    """object_literal: LBRACE property_list? RBRACE"""
                    props = []
                    for item in items:
                        if isinstance(item, list):
                            props = [p for p in item if isinstance(p, uni.KVPair)]
                    return uni.DictVal(kv_pairs=props, kid=list(items))

                def property_list(self, items):
                    """property_list: property_definition_expr (COMMA property_definition_expr)*"""
                    return [i for i in items if isinstance(i, uni.KVPair)]

                def property_definition_expr(self, items):
                    """property_definition_expr: property_name COLON assignment_expr | ..."""
                    kids = [i for i in items if i is not None]
                    key = None
                    value = None

                    for item in kids:
                        if isinstance(item, uni.Name) and key is None:
                            key = item
                        elif isinstance(item, uni.Token) and key is None:
                            if item.name in (Tok.NAME.name, "NAME"):
                                key = self._make_name(item)
                        elif isinstance(item, uni.Expr):
                            if key is None:
                                key = item
                            else:
                                value = item

                    if key:
                        if value is None:
                            value = key
                        return uni.KVPair(key=key, value=value, kid=kids)
                    return None

                def property_name(self, items):
                    """property_name: NAME | STRING | NUMBER | computed_property_name"""
                    if items:
                        item = items[0]
                        if isinstance(item, uni.Token):
                            if item.name in (Tok.NAME.name, "NAME"):
                                return self._make_name(item)
                            elif item.name in (Tok.STRING.name, "STRING"):
                                return uni.String(value=item.value, kid=[item])
                            elif item.name in (Tok.NUMBER.name, "NUMBER"):
                                return uni.Int(value=item.value, kid=[item])
                        return item if isinstance(item, uni.Expr) else None
                    return None

                # Arrow Functions
                def arrow_func(self, items):
                    """arrow_func: KW_ASYNC? type_params? arrow_params type_annotation? ARROW arrow_body"""
                    kids = [i for i in items if i is not None]
                    is_async = False
                    params = []
                    return_type = None
                    body = []

                    for item in kids:
                        if isinstance(item, uni.Token):
                            if item.name in (Tok.KW_ASYNC.name, "KW_ASYNC"):
                                is_async = True
                            elif item.name in (Tok.NAME.name, "NAME"):
                                # Single parameter shorthand
                                params = [
                                    uni.ParamVar(
                                        name=self._make_name(item),
                                        unpack=None,
                                        type_tag=None,
                                        value=None,
                                        kid=[item],
                                    )
                                ]
                        elif isinstance(item, list):
                            if all(isinstance(p, uni.ParamVar) for p in item if p):
                                params = [
                                    p for p in item if isinstance(p, uni.ParamVar)
                                ]
                            else:
                                body = [
                                    s for s in item if isinstance(s, uni.CodeBlockStmt)
                                ]
                        elif isinstance(item, uni.SubTag):
                            return_type = item
                        elif isinstance(item, uni.Expr):
                            # Expression body - wrap in implicit return
                            body = [uni.ReturnStmt(expr=item, kid=[item])]

                    name = uni.Name.gen_stub_from_node(
                        self.outer.parse_ref.ir_in, "[arrow]"
                    )

                    sig = uni.FuncSignature(
                        params=params,
                        return_type=return_type.tag if return_type else None,
                        kid=kids,
                    )

                    return uni.Ability(
                        name_ref=name,
                        is_func=True,
                        is_async=is_async,
                        is_override=False,
                        is_static=False,
                        is_abstract=False,
                        access=None,
                        signature=sig,
                        body=body,
                        decorators=None,
                        doc=None,
                        kid=kids,
                    )

                def arrow_params(self, items):
                    """arrow_params: NAME | LPAREN param_list? RPAREN"""
                    if items:
                        item = items[0]
                        if isinstance(item, uni.Token) and item.name in (
                            Tok.NAME.name,
                            "NAME",
                        ):
                            return [
                                uni.ParamVar(
                                    name=self._make_name(item),
                                    unpack=None,
                                    type_tag=None,
                                    value=None,
                                    kid=[item],
                                )
                            ]
                        elif isinstance(item, list):
                            return [p for p in item if isinstance(p, uni.ParamVar)]
                    return []

                def arrow_body(self, items):
                    """arrow_body: assignment_expr | block_stmt"""
                    if items:
                        item = items[0]
                        if isinstance(item, uni.Expr):
                            return [item]
                        elif isinstance(item, list):
                            return item
                    return []

                # Template Literals
                def template_literal(self, items):
                    """template_literal: TEMPLATE_STRING | template_head template_spans"""
                    if items:
                        item = items[0]
                        if isinstance(item, uni.Token):
                            return uni.String(value=item.value, kid=[item])
                        return item if isinstance(item, uni.Expr) else None
                    return None

                # Types
                def type(self, items):
                    """type: union_type | intersection_type | primary_type | ..."""
                    return (
                        items[0] if items and isinstance(items[0], uni.Expr) else None
                    )

                def union_type(self, items):
                    """union_type: type (BW_OR type)+"""
                    types = [i for i in items if isinstance(i, uni.Expr)]
                    if len(types) == 1:
                        return types[0]
                    # Return as tuple for union representation
                    return uni.TupleVal(values=types, kid=list(items))

                def intersection_type(self, items):
                    """intersection_type: type (BW_AND type)+"""
                    types = [i for i in items if isinstance(i, uni.Expr)]
                    if len(types) == 1:
                        return types[0]
                    return uni.TupleVal(values=types, kid=list(items))

                def primary_type(self, items):
                    """primary_type: predefined_type | type_reference | ..."""
                    return (
                        items[0] if items and isinstance(items[0], uni.Expr) else None
                    )

                def predefined_type(self, items):
                    """predefined_type: KW_ANY | KW_STRING_TYPE | ..."""
                    if items:
                        item = items[0]
                        if isinstance(item, uni.Token):
                            return uni.BuiltinType(
                                typ=item,
                                kid=[item],
                            )
                    return None

                def type_reference(self, items):
                    """type_reference: type_name type_args?"""
                    if items:
                        item = items[0]
                        if isinstance(item, uni.Name):
                            return item
                        elif isinstance(item, uni.Token) and item.name in (
                            Tok.NAME.name,
                            "NAME",
                        ):
                            return self._make_name(item)
                    return None

                def type_name(self, items):
                    """type_name: NAME (DOT NAME)*"""
                    names = []
                    for item in items:
                        if isinstance(item, uni.Token) and item.name in (
                            Tok.NAME.name,
                            "NAME",
                        ):
                            names.append(self._make_name(item))
                        elif isinstance(item, uni.Name):
                            names.append(item)
                    return names[0] if names else None

                # JSX
                def jsx_element(self, items):
                    """jsx_element: jsx_self_closing | jsx_opening_closing | jsx_fragment"""
                    return items[0] if items else None

                def jsx_self_closing(self, items):
                    """jsx_self_closing: JSX_OPEN_START jsx_element_name jsx_attributes? JSX_SELF_CLOSE"""
                    return uni.JsxElement(
                        tag=items[1] if len(items) > 1 else None,
                        props=[],
                        children=[],
                        kid=list(items),
                    )

                def jsx_opening_closing(self, items):
                    """jsx_opening_closing: jsx_opening_element jsx_children? jsx_closing_element"""
                    return uni.JsxElement(
                        tag=items[0] if items else None,
                        props=[],
                        children=[],
                        kid=list(items),
                    )

                def jsx_fragment(self, items):
                    """jsx_fragment: JSX_FRAG_OPEN jsx_children? JSX_FRAG_CLOSE"""
                    return uni.JsxElement(
                        tag=None,
                        props=[],
                        children=[],
                        kid=list(items),
                    )

                def jsx_element_name(self, items):
                    """jsx_element_name: NAME (DOT NAME)*"""
                    if items:
                        item = items[0]
                        if isinstance(item, uni.Token):
                            return self._make_name(item)
                        return item
                    return None

                # Decorators
                def decorators(self, items):
                    """decorators: decorator+"""
                    return [i for i in items if isinstance(i, uni.Expr)]

                def decorator(self, items):
                    """decorator: AT decorator_expr"""
                    for item in items:
                        if isinstance(item, uni.Expr):
                            return item
                    return None

                def decorator_expr(self, items):
                    """decorator_expr: NAME | decorator_expr DOT NAME | decorator_expr arguments"""
                    if items:
                        item = items[0]
                        if isinstance(item, uni.Token) and item.name in (
                            Tok.NAME.name,
                            "NAME",
                        ):
                            return self._make_name(item)
                        return item if isinstance(item, uni.Expr) else None
                    return None

                # Default handler
                def __default__(self, data, children, meta):
                    """Default handler for unhandled rules."""
                    if children:
                        # Return first non-None child
                        for child in children:
                            if child is not None:
                                return child
                    return None

            transformer = _InnerTransformer()
            return transformer.transform(tree)

        def _make_module(self, body: list[uni.UniNode]) -> uni.Module:
            """Create a Module node."""
            stmts = [
                s for s in body if isinstance(s, (uni.ElementStmt, uni.CodeBlockStmt))
            ]
            mod_name = os.path.basename(self.parse_ref.mod_path)
            if mod_name.endswith(".ts"):
                mod_name = mod_name[:-3]
            elif mod_name.endswith(".tsx"):
                mod_name = mod_name[:-4]
            elif mod_name.endswith(".js"):
                mod_name = mod_name[:-3]
            elif mod_name.endswith(".jsx"):
                mod_name = mod_name[:-4]

            # Cast stmts since TypeScript parser produces CodeBlockStmt which
            # is not in the standard Module.body type but works at runtime
            return uni.Module(
                name=mod_name,
                source=self.parse_ref.ir_in,
                doc=None,
                body=cast(list[uni.ElementStmt | uni.String | uni.EmptyToken], stmts),
                terminals=self.terminals,
                kid=body or [uni.EmptyToken(self.parse_ref.ir_in)],
            )

        def ice(self) -> Exception:
            """Raise internal compiler error."""
            self.parse_ref.log_error("Internal Compiler Error, Invalid Parse Tree!")
            return RuntimeError(
                f"{self.parse_ref.__class__.__name__} - Internal Compiler Error!"
            )
