"""Lark parser for Jac Lang."""

from __future__ import annotations

import keyword
import os
from collections.abc import Callable, Sequence
from dataclasses import dataclass
from threading import Event
from typing import TYPE_CHECKING, TypeAlias, TypeVar, cast

import jaclang.pycore.lark_jac_parser as jl
import jaclang.pycore.unitree as uni
from jaclang.pycore.constant import CodeContext, EdgeDir
from jaclang.pycore.constant import Tokens as Tok
from jaclang.pycore.passes import BaseTransform, Transform

if TYPE_CHECKING:
    from jaclang.pycore.program import JacProgram

T = TypeVar("T", bound=uni.UniNode)
TL = TypeVar("TL", bound=(uni.UniNode | list))

# Build TOKEN_MAP from the lark parser
TOKEN_MAP = {
    x.name: x.pattern.value for x in jl.Lark_StandAlone().parser.lexer_conf.terminals
}
# fmt: off
TOKEN_MAP.update({
    "CARROW_L": "<++", "CARROW_R": "++>", "GLOBAL_OP": "global", "NONLOCAL_OP": "nonlocal",
    "WALKER_OP": ":walker:", "NODE_OP": ":node:", "EDGE_OP": ":edge:", "CLASS_OP": ":class:",
    "OBJECT_OP": ":obj:", "TYPE_OP": "`", "ABILITY_OP": ":can:", "NULL_OK": "?", "KW_OR": "|",
    "ARROW_BI": "<-->", "ARROW_L": "<--", "ARROW_R": "-->", "ARROW_L_P1": "<-:", "ARROW_R_P2": ":->",
    "ARROW_L_P2": ":<-", "ARROW_R_P1": "->:", "CARROW_BI": "<++>", "CARROW_L_P1": "<+:",
    "RSHIFT_EQ": ">>=", "ELLIPSIS": "...", "CARROW_R_P2": ":+>", "CARROW_L_P2": ":<+",
    "CARROW_R_P1": "+>:", "PIPE_FWD": "|>", "PIPE_BKWD": "<|", "A_PIPE_FWD": ":>", "A_PIPE_BKWD": "<:",
    "DOT_FWD": ".>", "STAR_POW": "**", "STAR_MUL": "*", "FLOOR_DIV": "//", "DIV": "/",
    "PYNLINE": "::py::", "ADD_EQ": "+=", "SUB_EQ": "-=", "STAR_POW_EQ": "**=", "MUL_EQ": "*=",
    "FLOOR_DIV_EQ": "//=", "DIV_EQ": "/=", "MOD_EQ": "%=", "BW_AND_EQ": "&=", "BW_OR_EQ": "|=",
    "BW_XOR_EQ": "^=", "BW_NOT_EQ": "~=", "LSHIFT_EQ": "<<=",
})
# fmt: on


def _extract_jac_keywords() -> set[str]:
    """Extract Jac keywords from TOKEN_MAP."""
    keywords = set()

    # Iterate through all KW_* tokens
    for tok_name in dir(Tok):
        if (
            not (
                tok_name.startswith("KW_")
                or (tok_name.endswith("_OP"))
                or tok_name in ("NULL", "NOT")
            )
            or tok_name not in TOKEN_MAP
        ):
            continue
        else:
            keywords.add(TOKEN_MAP[tok_name])
    keywords.update(["or", "and", "False", "True"])

    return keywords


JAC_KEYWORDS = _extract_jac_keywords()
# Python keywords that should NOT be used as names in Jac
PYTHON_ONLY_KEYWORDS = set(keyword.kwlist) - JAC_KEYWORDS


@dataclass
class LarkParseInput:
    """Input for Lark parser transform."""

    ir_value: str
    on_error: Callable[[jl.UnexpectedInput], bool]


@dataclass
class LarkParseOutput:
    """Output from Lark parser transform."""

    tree: jl.Tree[jl.Tree[str]]
    comments: list[jl.Token]


class LarkParseTransform(BaseTransform[LarkParseInput, LarkParseOutput]):
    """Transform for Lark parsing step."""

    comment_cache: list[jl.Token] = []
    parser = jl.Lark_StandAlone(
        lexer_callbacks={
            "COMMENT": lambda comment: LarkParseTransform.comment_cache.append(comment)
        }  # type: ignore
    )

    def __init__(self, ir_in: LarkParseInput, prog: JacProgram) -> None:
        """Initialize Lark parser transform."""
        super().__init__(ir_in=ir_in, prog=prog)

    def transform(self, ir_in: LarkParseInput) -> LarkParseOutput:
        """Transform input IR by parsing with Lark."""
        LarkParseTransform.comment_cache = []
        tree = LarkParseTransform.parser.parse(ir_in.ir_value, on_error=ir_in.on_error)
        return LarkParseOutput(
            tree=tree,
            comments=LarkParseTransform.comment_cache.copy(),
        )


class JacParser(Transform[uni.Source, uni.Module]):
    """Jac Parser."""

    @staticmethod
    def _recalculate_parents(node: uni.UniNode) -> None:
        """Recalculate `.parent` pointers after mutating node children."""
        for child in node.kid:
            child.parent = node
            JacParser._recalculate_parents(child)

    def _log_python_only_keyword_error(
        self, keyword: str, node: uni.Token | None = None
    ) -> None:
        """Log error for Python-only keywords that are not valid in Jac."""
        self.log_error(
            f"'{keyword}' keyword is not allowed in Jac",
            node_override=node,
        )
        self.log_error(
            "Jac does not allow this keyword in any syntactic position",
            node_override=node,
        )

    @classmethod
    def _coerce_client_module(cls, module: uni.Module) -> None:
        """Treat a `.cl.jac` file as client code, except for explicit sv blocks.

        This allows authoring client-only modules without sprinkling `cl` in front
        of every statement. Explicit sv{} blocks can override to include server code.
        """
        elements: list[uni.ElementStmt] = []
        for stmt in module.body:
            if isinstance(stmt, uni.ClientBlock):
                elements.extend(stmt.body)
            elif isinstance(stmt, uni.ServerBlock):
                # Skip ServerBlocks - they remain server-side even in .cl.jac
                elements.append(stmt)
            elif isinstance(stmt, uni.ElementStmt):
                elements.append(stmt)

        # Mark all top-level statements as CLIENT context,
        # except for ServerBlocks and explicit sv statements which keep their SERVER context.
        # Propagate one level into `with entry` blocks.
        for elem in elements:
            if isinstance(elem, uni.ServerBlock):
                continue  # Keep as SERVER
            if isinstance(elem, uni.ContextAwareNode):
                # Skip elements that have explicit sv token (not just default SERVER context)
                context_token = elem._source_context_token()
                if context_token is not None and context_token.name == Tok.KW_SERVER:
                    continue  # Keep explicit sv as SERVER
                elem.code_context = CodeContext.CLIENT
                if isinstance(elem, uni.ModuleCode) and elem.body:
                    for inner in elem.body:
                        if isinstance(inner, uni.ContextAwareNode):
                            inner.code_context = CodeContext.CLIENT

        # Keep elements as direct module children (no ClientBlock wrapper)
        module.body = elements
        module.normalize(deep=False)
        cls._recalculate_parents(module)

    @classmethod
    def _coerce_server_module(cls, module: uni.Module) -> None:
        """Treat a `.sv.jac` file as server code (explicit marking).

        This is mostly for symmetry with .cl.jac. Since .jac files default to
        server context, .sv.jac provides explicit documentation of intent.
        Explicit cl{} blocks can override to include client code.
        """
        elements: list[uni.ElementStmt] = []
        for stmt in module.body:
            if isinstance(stmt, uni.ServerBlock):
                elements.extend(stmt.body)
            elif isinstance(stmt, uni.ClientBlock):
                # Keep ClientBlocks - they remain client-side even in .sv.jac
                elements.append(stmt)
            elif isinstance(stmt, uni.ElementStmt):
                elements.append(stmt)

        # Mark all top-level statements as SERVER context,
        # except for ClientBlocks which keep their CLIENT context.
        for elem in elements:
            if isinstance(elem, uni.ClientBlock):
                continue  # Keep as CLIENT
            if isinstance(elem, uni.ContextAwareNode):
                elem.code_context = CodeContext.SERVER
                if isinstance(elem, uni.ModuleCode) and elem.body:
                    for inner in elem.body:
                        if isinstance(inner, uni.ContextAwareNode):
                            inner.code_context = CodeContext.SERVER

        # Keep elements as direct module children (no ServerBlock wrapper)
        module.body = elements
        module.normalize(deep=False)
        cls._recalculate_parents(module)

    @classmethod
    def _coerce_native_module(cls, module: uni.Module) -> None:
        """Treat a `.na.jac` file as native code.

        All top-level statements default to NATIVE context.
        Explicit sv{} or cl{} blocks can override to include server/client code.
        """
        elements: list[uni.ElementStmt] = []
        for stmt in module.body:
            if isinstance(stmt, uni.NativeBlock):
                elements.extend(stmt.body)
            elif isinstance(stmt, (uni.ServerBlock, uni.ClientBlock)):
                # Keep ServerBlocks/ClientBlocks - they retain their context
                elements.append(stmt)
            elif isinstance(stmt, uni.ElementStmt):
                elements.append(stmt)

        # Mark all top-level statements as NATIVE context,
        # except for ServerBlocks and ClientBlocks which keep their context.
        for elem in elements:
            if isinstance(elem, (uni.ServerBlock, uni.ClientBlock)):
                continue
            if isinstance(elem, uni.ContextAwareNode):
                elem.code_context = CodeContext.NATIVE
                if isinstance(elem, uni.ModuleCode) and elem.body:
                    for inner in elem.body:
                        if isinstance(inner, uni.ContextAwareNode):
                            inner.code_context = CodeContext.NATIVE

        # Keep elements as direct module children (no NativeBlock wrapper)
        module.body = elements
        module.normalize(deep=False)
        cls._recalculate_parents(module)

    def __init__(
        self, root_ir: uni.Source, prog: JacProgram, cancel_token: Event | None = None
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
            # Create input for Lark parser transform
            lark_input = LarkParseInput(
                ir_value=ir_in.value,
                on_error=self.error_callback,
            )
            # Use LarkParseTransform instead of direct parser call
            lark_transform = LarkParseTransform(ir_in=lark_input, prog=self.prog)
            parse_output = lark_transform.ir_out
            # Transform parse tree to AST
            mod = JacParser.TreeToAST(parser=self).transform(parse_output.tree)
            ir_in.comments = [self.proc_comment(i, mod) for i in parse_output.comments]
            if not isinstance(mod, uni.Module):
                raise self.ice()
            if len(self.errors_had) != 0:
                mod.has_syntax_errors = True
            if ir_in.file_path.endswith(".cl.jac"):
                self._coerce_client_module(mod)
            elif ir_in.file_path.endswith(".sv.jac"):
                self._coerce_server_module(mod)
            elif ir_in.file_path.endswith(".na.jac"):
                self._coerce_native_module(mod)
            self.ir_out = mod
            return mod
        except jl.UnexpectedInput as e:
            catch_error = self.error_to_token(e)
            error_msg = self.error_to_message(e)

            if len(e.args) >= 1 and isinstance(e.args[0], str):
                error_msg += e.args[0]
            self.log_error(error_msg, node_override=catch_error)

        except Exception as e:
            raise e

        # If we reach here, there was a syntax error, mark the module as such
        # and report errors.
        mod = uni.Module.make_stub(inject_src=ir_in)
        mod.has_syntax_errors = True
        return mod

    @staticmethod
    def proc_comment(token: jl.Token, mod: uni.UniNode) -> uni.CommentToken:
        """Process comment."""
        return uni.CommentToken(
            orig_src=mod.loc.orig_src,
            name=token.type,
            value=token.value,
            line=token.line or 0,
            end_line=token.end_line or 0,
            col_start=token.column or 0,
            col_end=token.end_column or 0,
            pos_start=token.start_pos or 0,
            pos_end=token.end_pos or 0,
            kid=[],
        )

    _MISSING_TOKENS = [
        Tok.SEMI,
        Tok.COMMA,
        Tok.COLON,
        Tok.RPAREN,
        Tok.RBRACE,
        Tok.RSQUARE,
        Tok.RETURN_HINT,
    ]

    def error_callback(self, e: jl.UnexpectedInput) -> bool:
        """Handle error."""
        iparser = e.interactive_parser

        def try_feed_missing_token(iparser: jl.InteractiveParser) -> Tok | None:
            """Feed a missing token to the parser."""
            # If any of the below token is missing, insert them and continue parsing.
            accepts = iparser.accepts()
            for tok in JacParser._MISSING_TOKENS:
                if tok.name in accepts:
                    iparser.feed_token(jl.Token(tok.name, TOKEN_MAP[tok.name]))
                    return tok
            return None

        def feed_current_token(iparser: jl.InteractiveParser, tok: jl.Token) -> bool:
            """Feed the current token to the parser."""
            max_attempts = 100  # Prevent infinite loops
            attempts = 0
            while tok.type not in iparser.accepts():
                if attempts >= max_attempts:
                    return False  # Give up after too many attempts
                if not try_feed_missing_token(iparser):
                    return False
                attempts += 1
            iparser.feed_token(tok)
            return True

        if isinstance(e, jl.UnexpectedToken):
            last_tok: jl.Token | None = (
                e.token_history[-1]
                if e.token_history and len(e.token_history) >= 1
                else None
            )

            # Check for unsupported python keywords in code blocks
            if (
                e.token
                and e.token.value in PYTHON_ONLY_KEYWORDS
                and (Tok.RBRACE.name in e.accepts or Tok.SEMI.name in e.accepts)
            ):
                self._log_python_only_keyword_error(
                    e.token.value, self.error_to_token(e)
                )
                return True

            # If last token is DOT and we expect a NAME, insert a NAME token
            if (
                last_tok
                and last_tok.type == Tok.DOT.name
                and (Tok.NAME.name in e.accepts)
            ):
                self.log_error("Incomplete member access", self.error_to_token(e))
                iparser.feed_token(jl.Token(Tok.NAME.name, "recover_name_token"))
                return feed_current_token(iparser, e.token)

            # Check for 'new' keyword pattern (e.g., "new ClassName(...)")
            if (
                last_tok
                and last_tok.value == "new"
                and e.token.type in (Tok.NAME.name, Tok.JSX_NAME.name)
            ):
                self.log_error(
                    "The 'new' keyword is not supported in Jac",
                    self.error_to_token(e),
                )
                self.log_error(
                    "Use `Reflect.construct(target, argumentsList)` method to create new instances",
                    self.error_to_token(e),
                )
                return True

            # We're calling try_feed_missing_token twice here because the first missing
            # will be reported as such and we don't for the consequent missing token.
            if tk := try_feed_missing_token(iparser):
                self.log_error(f"Missing {tk.name}", self.error_to_token(e))
                return feed_current_token(iparser, e.token)

            # Ignore unexpected tokens and continue parsing till we reach a known state.
            self.log_error(
                f"Unexpected token '{e.token.value}'", self.error_to_token(e)
            )
            return True

        return False

    def error_to_message(self, e: jl.UnexpectedInput) -> str:
        """Return an error message based on the exception."""
        # TODO: Match more specific errors with lark's example based matching.
        # Reference: https://github.com/lark-parser/lark/blob/master/examples/advanced/error_reporting_lalr.py
        # e.match_examples()
        if isinstance(e, jl.UnexpectedToken):
            return f"Unexpected token '{e.token.value}'"
        return "Syntax Error"

    def error_to_token(self, e: jl.UnexpectedInput) -> uni.Token:
        """Convert error to token."""
        catch_error = uni.EmptyToken()
        catch_error.orig_src = self.ir_in
        catch_error.line_no = e.line
        catch_error.end_line = e.line
        catch_error.c_start = e.column
        catch_error.pos_start = e.pos_in_stream or 0
        if isinstance(e, jl.UnexpectedToken) and e.token:
            catch_error.c_end = e.token.end_column or (e.column + 1)
            catch_error.pos_end = e.token.end_pos or (catch_error.pos_start + 1)
        else:
            catch_error.c_end = e.column + 1
            catch_error.pos_end = catch_error.pos_start + 1
        return catch_error

    JacTransformer: TypeAlias = jl.Transformer[jl.Tree[str], uni.UniNode]

    class TreeToAST(JacTransformer):
        """Transform parse tree to AST."""

        def __init__(self, parser: JacParser, *args: bool, **kwargs: bool) -> None:
            """Initialize transformer."""
            super().__init__(*args, **kwargs)
            self.parse_ref = parser
            self.terminals: list[uni.Token] = []
            # TODO: Once the kid is removed from the ast, we can get rid of this
            # node_idx and directly pop(0) kid as we process the nodes.
            self.node_idx = 0
            self.cur_nodes: list[uni.UniNode] = []

        def ice(self) -> Exception:
            """Raise internal compiler error."""
            self.parse_ref.log_error("Internal Compiler Error, Invalid Parse Tree!")
            return RuntimeError(
                f"{self.parse_ref.__class__.__name__} - Internal Compiler Error, Invalid Parse Tree!"
            )

        def _node_update(self, node: T) -> T:
            self.parse_ref.cur_node = node
            node_id = id(node)
            if node_id not in self.parse_ref._node_ids:
                self.parse_ref._node_ids.add(node_id)
                self.parse_ref.node_list.append(node)
            return node

        def _call_userfunc(
            self, tree: jl.Tree, new_children: None | list[uni.UniNode] = None
        ) -> uni.UniNode:
            self.cur_nodes = new_children or tree.children  # type: ignore[assignment]
            if self.parse_ref.is_canceled():
                raise StopIteration
            try:
                return self._node_update(super()._call_userfunc(tree, new_children))
            finally:
                self.cur_nodes = []
                self.node_idx = 0

        def _call_userfunc_token(self, token: jl.Token) -> uni.UniNode:
            return self._node_update(super()._call_userfunc_token(token))

        def _binary_expr_unwind(self, kid: list[uni.UniNode]) -> uni.Expr:
            """Binary expression helper."""
            if len(kid) > 1:
                if (
                    isinstance(kid[0], uni.Expr)
                    and isinstance(
                        kid[1],
                        (uni.Token, uni.DisconnectOp, uni.ConnectOp),
                    )
                    and isinstance(kid[2], uni.Expr)
                ):
                    return uni.BinaryExpr(
                        left=kid[0],
                        op=kid[1],
                        right=kid[2],
                        kid=kid,
                    )
                else:
                    raise self.ice()
            elif isinstance(kid[0], uni.Expr):
                return kid[0]
            else:
                raise self.ice()

        # ******************************************************************* #
        # Parser Helper functions.                                            #
        # ******************************************************************* #

        def extract_from_list(
            self, nd_list: list[uni.UniNode], ty: type[T] | tuple[type[T], ...]
        ) -> list[T]:
            """Extract a list of nodes of type 'ty' from the current nodes."""
            return cast(list[T], [node for node in nd_list if isinstance(node, ty)])

        def match(self, ty: type[TL]) -> TL | None:
            """Return a node matching type 'ty' if possible from the current nodes."""
            if (self.node_idx < len(self.cur_nodes)) and isinstance(
                self.cur_nodes[self.node_idx], ty
            ):
                self.node_idx += 1
                return self.cur_nodes[self.node_idx - 1]  # type: ignore[return-value]
            return None

        def consume(self, ty: type[TL]) -> TL:
            """Consume and return the specified type, if it's not exists, will be an internal compiler error."""
            if node := self.match(ty):
                return node
            raise self.ice()

        def match_token(self, tok: Tok) -> uni.Token | None:
            """Match a token with the given type and return it."""
            if token := self.match(uni.Token):
                if token.name == tok.name:
                    return token
                self.node_idx -= (
                    1  # We're already matched but wrong token so undo matching it.
                )
            return None

        def consume_token(self, tok: Tok) -> uni.Token:
            """Consume a token with the given type and return it."""
            if token := self.match_token(tok):
                return token
            raise self.ice()

        def match_many(self, ty: type[T]) -> list[T]:
            """Match 0 or more of the given type and return the list."""
            nodes: list[uni.UniNode] = []
            while node := self.match(ty):
                nodes.append(node)
            return nodes  # type: ignore[return-value]

        def consume_many(self, ty: type[T]) -> list[T]:
            """Match 1 or more of the given type and return the list."""
            nodes: list[uni.UniNode] = [self.consume(ty)]
            while node := self.match(ty):
                nodes.append(node)
            return nodes  # type: ignore[return-value]

        @property
        def flat_cur_nodes(self) -> list[uni.UniNode]:
            """Flatten the current nodes."""
            flat_nodes: list[uni.UniNode] = []
            for node in self.cur_nodes:
                if isinstance(node, list):
                    flat_nodes.extend(node)
                else:
                    flat_nodes.append(node)
            return flat_nodes

        # ******************************************************************* #
        # Parsing Rules                                                       #
        # ******************************************************************* #

        def start(self, _: None) -> uni.Module:
            """Grammar rule.

            start: module
            """
            module = self.consume(uni.Module)
            module._in_mod_nodes = self.parse_ref.node_list
            return module

        def module(self, _: None) -> uni.Module:
            """Grammar rule.

            module: (toplevel_stmt (tl_stmt_with_doc | toplevel_stmt)*)?
                | STRING (tl_stmt_with_doc | toplevel_stmt)*
            """
            doc = self.match(uni.String)
            # Collect all statements, flattening lists from cl { ... } blocks
            body: list[uni.ElementStmt] = []
            flat_kids: list[uni.UniNode] = []

            for node in self.cur_nodes:
                if isinstance(node, list):
                    # This is a list from cl { } block
                    body.extend(node)
                    flat_kids.extend(node)
                elif isinstance(node, uni.ElementStmt):
                    body.append(node)
                    flat_kids.append(node)
                else:
                    flat_kids.append(node)

            mod = uni.Module(
                name=self.parse_ref.mod_path.split(os.path.sep)[-1].removesuffix(
                    ".jac"
                ),
                source=self.parse_ref.ir_in,
                doc=doc,
                body=body,
                terminals=self.terminals,
                kid=flat_kids
                or [uni.EmptyToken(uni.Source("", self.parse_ref.mod_path))],
            )
            return mod

        def tl_stmt_with_doc(self, _: None) -> uni.ElementStmt:
            """Grammar rule.

            tl_stmt_with_doc: STRING toplevel_stmt
            """
            doc = self.consume(uni.String)
            element = self.consume(uni.ElementStmt)
            element.doc = doc
            element.add_kids_left([doc])
            return element

        def onelang_stmt(self, _: None) -> uni.ElementStmt:
            """Grammar rule.

            onelang_stmt: import_stmt
                | archetype
                | ability
                | global_var
                | free_code
                | test
                | impl_def
                | sem_def
            """
            return self.consume(uni.ElementStmt)

        def toplevel_stmt(self, _: None) -> uni.ElementStmt | list[uni.ElementStmt]:
            """Grammar rule.

            toplevel_stmt: (KW_CLIENT | KW_SERVER | KW_NATIVE)? onelang_stmt
                | (KW_CLIENT | KW_SERVER | KW_NATIVE) LBRACE onelang_stmt* RBRACE
                | py_code_block
            """
            # Check for context keywords (mutually exclusive)
            client_tok = self.match_token(Tok.KW_CLIENT)
            server_tok = self.match_token(Tok.KW_SERVER) if not client_tok else None
            native_tok = (
                self.match_token(Tok.KW_NATIVE)
                if not client_tok and not server_tok
                else None
            )

            if client_tok or server_tok or native_tok:
                # Determine context
                if client_tok:
                    context = CodeContext.CLIENT
                    context_tok = client_tok
                elif server_tok:
                    context = CodeContext.SERVER
                    context_tok = server_tok
                else:
                    context = CodeContext.NATIVE
                    assert native_tok is not None
                    context_tok = native_tok

                lbrace = self.match_token(Tok.LBRACE)
                if lbrace:
                    # Create a ClientBlock, ServerBlock, or NativeBlock
                    elements: list[uni.ElementStmt] = []
                    while elem := self.match(uni.ElementStmt):
                        # VALIDATION: Prevent nested context blocks
                        if isinstance(
                            elem,
                            (uni.ClientBlock, uni.ServerBlock, uni.NativeBlock),
                        ):
                            if isinstance(elem, uni.ClientBlock):
                                opposite = "cl"
                            elif isinstance(elem, uni.ServerBlock):
                                opposite = "sv"
                            else:
                                opposite = "na"
                            current = (
                                "cl" if client_tok else "sv" if server_tok else "na"
                            )
                            self.error(
                                elem,
                                f"Cannot nest {opposite} blocks inside {current} blocks. "
                                f"Code context keywords are mutually exclusive.",
                            )

                        if isinstance(elem, uni.ContextAwareNode):
                            elem.code_context = context
                            # Propagate to ModuleCode children (with entry blocks)
                            if isinstance(elem, uni.ModuleCode) and elem.body:
                                for stmt in elem.body:
                                    if isinstance(stmt, uni.ContextAwareNode):
                                        stmt.code_context = context
                        elements.append(elem)
                    self.consume(uni.Token)  # RBRACE

                    if client_tok:
                        return uni.ClientBlock(
                            body=elements,
                            kid=self.flat_cur_nodes,
                        )
                    elif server_tok:
                        return uni.ServerBlock(
                            body=elements,
                            kid=self.flat_cur_nodes,
                        )
                    else:  # native_tok
                        return uni.NativeBlock(
                            body=elements,
                            kid=self.flat_cur_nodes,
                        )
                else:
                    # Single statement: cl/sv/na import foo;
                    element = self.consume(uni.ElementStmt)
                    if isinstance(element, uni.ContextAwareNode):
                        element.code_context = context
                        # Propagate to ModuleCode children (with entry blocks)
                        if isinstance(element, uni.ModuleCode) and element.body:
                            for stmt in element.body:
                                if isinstance(stmt, uni.ContextAwareNode):
                                    stmt.code_context = context
                        element.add_kids_left([context_tok])
                    return element
            else:
                return self.consume(uni.ElementStmt)

        def global_var(self, _: None) -> uni.GlobalVars:
            """Grammar rule.

            global_var: KW_GLOBAL access_tag? assignment_list SEMI
            """
            self.consume(uni.Token)  # KW_GLOBAL
            access_tag = self.match(uni.SubTag)
            assignments_list = self.consume(list)
            return uni.GlobalVars(
                access=access_tag,
                assignments=self.extract_from_list(assignments_list, uni.Assignment),
                is_frozen=False,
                kid=self.flat_cur_nodes,
            )

        def access_tag(self, _: None) -> uni.SubTag[uni.Token]:
            """Grammar rule.

            access_tag: COLON ( KW_PROT | KW_PUB | KW_PRIV )
            """
            self.consume_token(Tok.COLON)
            access = self.consume(uni.Token)
            return uni.SubTag[uni.Token](tag=access, kid=self.cur_nodes)

        def test(self, _: None) -> uni.Test:
            """Grammar rule.

            test: KW_TEST NAME? code_block
            """
            # Q(thakee): Why the name should be KW_TEST if no name present?
            test_tok = self.consume_token(Tok.KW_TEST)
            name = self.match(uni.Name) or test_tok
            codeblock = self.consume(list)
            return uni.Test(
                name=name,
                body=self.extract_from_list(codeblock, uni.CodeBlockStmt),
                kid=self.flat_cur_nodes,
            )

        def free_code(self, _: None) -> uni.ModuleCode:
            """Grammar rule.

            free_code: KW_WITH KW_ENTRY (COLON NAME)? code_block
            """
            self.consume_token(Tok.KW_WITH)
            self.consume_token(Tok.KW_ENTRY)
            name = None
            if self.match_token(Tok.COLON):
                name = self.consume(uni.Name)
            codeblock = self.consume(list)
            return uni.ModuleCode(
                name=name,
                body=self.extract_from_list(codeblock, uni.CodeBlockStmt),
                kid=self.flat_cur_nodes,
            )

        def py_code_block(self, _: None) -> uni.PyInlineCode:
            """Grammar rule.

            py_code_block: PYNLINE
            """
            pyinline = self.consume_token(Tok.PYNLINE)
            return uni.PyInlineCode(
                code=pyinline,
                kid=self.cur_nodes,
            )

        def import_stmt(self, _: None) -> uni.Import:
            """Grammar rule.

            import_stmt: KW_IMPORT KW_FROM from_path LBRACE import_items RBRACE
                    | KW_IMPORT import_path (COMMA import_path)* SEMI
                    | KW_INCLUDE import_path SEMI
            """
            if self.match_token(Tok.KW_INCLUDE):
                # Handle include statement
                import_path_obj = self.consume(uni.ModulePath)
                return uni.Import(
                    from_loc=None,
                    items=[import_path_obj],
                    is_absorb=True,
                    kid=self.cur_nodes,
                )

            from_path: uni.ModulePath | None = None
            self.consume_token(Tok.KW_IMPORT)

            if self.match_token(Tok.KW_FROM):
                from_path = self.consume(uni.ModulePath)
                self.consume(uni.Token)  # LBRACE or COMMA
                items = self.extract_from_list(self.consume(list), uni.ModuleItem)
                self.consume(uni.Token)
                return uni.Import(
                    from_loc=from_path,
                    items=items,
                    is_absorb=False,
                    kid=self.flat_cur_nodes,
                )
            else:
                paths = [self.consume(uni.ModulePath)]
                while self.match_token(Tok.COMMA):
                    paths.append(self.consume(uni.ModulePath))
                self.consume_token(Tok.SEMI)
                return uni.Import(
                    from_loc=from_path,
                    items=paths,
                    is_absorb=False,
                    kid=self.flat_cur_nodes,
                )

        def from_path(self, _: None) -> uni.ModulePath:
            """Grammar rule.

            from_path: (DOT | ELLIPSIS)* import_path
                     | (DOT | ELLIPSIS)+
            """
            level = 0
            while True:
                if self.match_token(Tok.DOT):
                    level += 1
                elif self.match_token(Tok.ELLIPSIS):
                    level += 3
                else:
                    break
            if import_path := self.match(uni.ModulePath):
                kids = [i for i in self.cur_nodes if isinstance(i, uni.Token)]
                import_path.level = level
                import_path.add_kids_left(kids)
                return import_path

            return uni.ModulePath(
                path=None,
                level=level,
                alias=None,
                kid=self.cur_nodes,
            )

        def import_path(self, _: None) -> uni.ModulePath:
            """Grammar rule.

            import_path: (dotted_name | STRING) (KW_AS NAME)?
            """
            # The grammar can produce: [list, KW_AS, NAME]
            # or just: [list]
            # or: [String, KW_AS, NAME]
            # or: [String]

            # Consume either String or dotted_name list
            valid_path: list[uni.Name | uni.String]
            if self.cur_nodes and isinstance(self.cur_nodes[0], uni.String):
                # Handle string literal import path (e.g., "@jac/runtime")
                string_node = self.consume(uni.String)
                valid_path = [string_node]
            else:
                # Handle dotted_name list
                valid_path = self.extract_from_list(self.consume(list), uni.Name)

            # Check for optional alias
            alias = self.consume(uni.Name) if self.match_token(Tok.KW_AS) else None

            return uni.ModulePath(
                path=valid_path,
                level=0,
                alias=alias,
                kid=self.flat_cur_nodes,
            )

        def dotted_name(self, _: None) -> list[uni.UniNode]:
            """Grammar rule.

            dotted_name: named_ref (DOT named_ref)*
            """
            return self.cur_nodes

        def import_items(self, _: None) -> list[uni.UniNode]:
            """Grammar rule.

            import_items: (import_item COMMA)* import_item COMMA?
            """
            return self.flat_cur_nodes

        def import_item(self, _: None) -> uni.ModuleItem:
            """Grammar rule.

            import_item: (KW_DEFAULT | STAR_MUL | named_ref) (KW_AS NAME)?
            """
            # The first node in cur_nodes is the name (either Token for default/*, or Name for regular)
            # Check if it's a special token or regular name
            name: uni.Name | uni.Token
            first_node = (
                self.cur_nodes[self.node_idx]
                if self.node_idx < len(self.cur_nodes)
                else None
            )

            if isinstance(first_node, uni.Token) and first_node.name in [
                Tok.KW_DEFAULT.name,
                Tok.STAR_MUL.name,
            ]:
                name = self.consume(uni.Token)
            else:
                name = self.consume(uni.Name)

            alias = self.consume(uni.Name) if self.match_token(Tok.KW_AS) else None
            return uni.ModuleItem(
                name=name,
                alias=alias,
                kid=self.cur_nodes,
            )

        def archetype(self, _: None) -> uni.ArchSpec | uni.Enum:
            """Grammar rule.

            archetype: decorators? archetype_decl
                    | archetype_def
                    | enum
            """
            archspec: uni.ArchSpec | uni.Enum | None = None

            decorators_node = self.match(list)
            is_async = self.match_token(Tok.KW_ASYNC)
            if decorators_node is not None:
                archspec = self.consume(uni.ArchSpec)
                decorators = self.extract_from_list(decorators_node, uni.Expr)
                archspec.decorators = decorators
                archspec.add_kids_left(decorators_node)
            else:
                archspec = self.match(uni.ArchSpec) or self.consume(uni.Enum)
            if is_async and isinstance(archspec, uni.ArchSpec):
                archspec.is_async = True
                archspec.add_kids_left([is_async])
                assert isinstance(archspec, uni.Archetype)
                if archspec.arch_type.name != Tok.KW_WALKER:
                    self.parse_ref.log_error(
                        f"Expected async archetype to be walker, but got {archspec.arch_type.value}"
                    )
            return archspec

        def impl_def(self, _: None) -> uni.ImplDef:
            """Grammar rule.

            impl_def: decorators? KW_IMPL dotted_name impl_spec? impl_tail
            """
            decorators_node = self.match(list)
            self.consume_token(Tok.KW_IMPL)
            target = self.extract_from_list(self.consume(list), uni.NameAtom)
            spec = (
                self.match(list)
                or self.match(uni.FuncSignature)
                or self.match(uni.EventSignature)
            )
            tail = self.match(list) or self.match(uni.Expr)
            valid_tail = spec if tail is None else tail
            valid_spec = None if tail is None else spec
            impl = uni.ImplDef(
                body=(
                    self.extract_from_list(
                        valid_tail,
                        (uni.EnumBlockStmt, uni.CodeBlockStmt),  # type: ignore[arg-type]
                    )
                    if isinstance(valid_tail, list)
                    else valid_tail
                ),
                target=target,
                decorators=(
                    self.extract_from_list(decorators_node, uni.Expr)
                    if decorators_node
                    else None
                ),
                spec=valid_spec,
                kid=self.flat_cur_nodes,
            )
            return impl

        def sem_def(self, _: None) -> uni.SemDef:
            """Grammar rule.

            sem_def: KW_SEM dotted_name (EQ | KW_IS) STRING SEMI
            """
            self.consume_token(Tok.KW_SEM)
            target = self.extract_from_list(self.consume(list), uni.NameAtom)
            if not self.match_token(Tok.KW_IS):
                self.consume_token(Tok.EQ)
            value = self.consume(uni.String)
            self.consume_token(Tok.SEMI)
            return uni.SemDef(
                target=target,
                value=value,
                kid=self.flat_cur_nodes,
            )

        def impl_spec(
            self, _: None
        ) -> Sequence[uni.Expr] | uni.FuncSignature | uni.EventSignature:
            """Grammar rule.

            impl_spec: inherited_archs | func_decl | event_clause
            """
            spec = (
                self.match(list)  # inherited_archs
                or self.match(uni.FuncSignature)  # func_decl
                or self.consume(uni.EventSignature)  # event_clause
            )
            return spec

        def impl_tail(
            self, _: None
        ) -> Sequence[uni.EnumBlockStmt] | list[uni.CodeBlockStmt] | uni.Expr:
            """Grammar rule.

            impl_tail: enum_block | block_tail
            """
            tail = self.match(list) or self.consume(uni.Expr)
            return tail

        def archetype_decl(self, _: None) -> uni.ArchSpec:
            """Grammar rule.

            archetype_decl: arch_type access_tag? NAME inherited_archs? (member_block | SEMI)
            """
            arch_type = self.consume(uni.Token)
            access = self.match(uni.SubTag)
            name = self.consume(uni.Name)
            inh_sn = self.match(list)
            body_list = self.match(list)
            body: list[uni.ArchBlockStmt] | None
            if body_list is None and self.match_token(Tok.SEMI):
                body = None
            elif body_list is None:
                body = self.extract_from_list(inh_sn or [], uni.ArchBlockStmt)
                inh_sn = None
            else:
                body = self.extract_from_list(body_list or [], uni.ArchBlockStmt)
            return uni.Archetype(
                arch_type=arch_type,
                name=name,
                access=access,
                base_classes=self.extract_from_list(inh_sn or [], uni.Expr) or [],
                body=body,
                kid=self.flat_cur_nodes,
            )

        def arch_type(self, _: None) -> uni.Token:
            """Grammar rule.

            arch_type: KW_WALKER
                    | KW_OBJECT
                    | KW_EDGE
                    | KW_NODE
            """
            return self.consume(uni.Token)

        def decorators(self, _: None) -> list[uni.UniNode]:
            """Grammar rule.

            decorators: (DECOR_OP atomic_chain)+
            """
            return self.cur_nodes

        def inherited_archs(self, kid: list[uni.UniNode]) -> list[uni.UniNode]:
            """Grammar rule.

            inherited_archs: LPAREN (atomic_chain COMMA)* atomic_chain RPAREN
            """
            return self.flat_cur_nodes

        def named_ref(self, _: None) -> uni.NameAtom:
            """Grammar rule.

            named_ref: special_ref
                    | KWESC_NAME
                    | NAME
            """
            return self.consume(uni.NameAtom)

        def special_ref(self, _: None) -> uni.SpecialVarRef:
            """Grammar rule.

            special_ref: KW_INIT
                        | KW_POST_INIT
                        | KW_ROOT
                        | KW_SUPER
                        | KW_SELF
                        | KW_PROPS
                        | KW_HERE
                        | KW_VISITOR
            """
            return uni.SpecialVarRef(var=self.consume(uni.Name))

        def enum(self, _: None) -> uni.Enum:
            """Grammar rule.

            enum: decorators? enum_decl
                | enum_def
            """
            if decorator := self.match(list):
                enum_decl = self.consume(uni.Enum)
                enum_decl.decorators = self.extract_from_list(decorator, uni.Expr)
                enum_decl.add_kids_left(decorator)
                return enum_decl
            return self.consume(uni.Enum)

        def enum_decl(self, _: None) -> uni.Enum:
            """Grammar rule.

            enum_decl: KW_ENUM access_tag? STRING? NAME inherited_archs? (enum_block | SEMI)
            """
            self.consume_token(Tok.KW_ENUM)
            access = self.match(uni.SubTag)
            name = self.consume(uni.Name)
            sub_list1 = self.match(list)
            enum_body = self.match(list)
            body: list[uni.UniNode] | None = None
            if enum_body is None and self.match_token(Tok.SEMI):
                inh, body = sub_list1, None
            elif enum_body is None:
                body = self.extract_from_list(sub_list1 or [], uni.EnumBlockStmt)
                inh = None
            else:
                body = enum_body
                inh = sub_list1
            return uni.Enum(
                name=name,
                access=access,
                base_classes=self.extract_from_list(inh or [], uni.Expr) or [],
                body=self.extract_from_list(body, uni.EnumBlockStmt) if body else None,
                kid=self.flat_cur_nodes,
            )

        def enum_block(self, _: None) -> list[uni.UniNode]:
            """Grammar rule.

            enum_block: LBRACE assignment_list COMMA? (py_code_block | free_code)* RBRACE
            """
            left_enc = self.consume_token(Tok.LBRACE)
            assignments = self.consume(list)
            self.match_token(Tok.COMMA)
            while item := self.match(uni.EnumBlockStmt):
                item.is_enum_stmt = True
                assignments.append(item)
            right_enc = self.consume_token(Tok.RBRACE)
            for i in assignments:
                if isinstance(i, uni.Assignment):
                    i.is_enum_stmt = True
            return [left_enc, *assignments, right_enc]

        def ability(self, _: None) -> uni.Ability | uni.FuncCall:
            """Grammar rule.

            ability: decorators? KW_ASYNC? (ability_decl | function_decl)
            """
            decorators_node = self.match(list)
            is_async = self.match_token(Tok.KW_ASYNC)

            # Try to match ability_decl or function_decl
            ability = self.consume(uni.Ability)
            if is_async and ability and isinstance(ability, uni.Ability):
                ability.is_async = True
                ability.add_kids_left([is_async])

            if decorators_node:
                decorators = self.extract_from_list(decorators_node, uni.Expr)
                # Note: @staticmethod to static conversion is handled by JacAutoLintPass
                if decorators:
                    ability.decorators = decorators
                    ability.add_kids_left(decorators_node)

            return ability

        def ability_decl(self, _: None) -> uni.Ability:
            """Grammar rule.

            ability_decl: KW_OVERRIDE? KW_STATIC? KW_CAN access_tag? named_ref?
                event_clause (block_tail | KW_ABSTRACT? SEMI)
            """
            is_override = self.match_token(Tok.KW_OVERRIDE) is not None
            is_static = self.match_token(Tok.KW_STATIC) is not None
            self.consume_token(Tok.KW_CAN)
            access = self.match(uni.SubTag)
            name = self.match(uni.NameAtom)
            signature = self.consume(uni.EventSignature)

            # Handle block_tail
            body_sn_or_call = self.match(list) or self.match(uni.Expr)
            if body_sn_or_call is None:
                is_abstract = self.match_token(Tok.KW_ABSTRACT) is not None
                self.consume_token(Tok.SEMI)
                body = None
            else:
                is_abstract = False
                body = (
                    self.extract_from_list(body_sn_or_call, uni.CodeBlockStmt)
                    if isinstance(body_sn_or_call, list)
                    else body_sn_or_call
                )

            return uni.Ability(
                name_ref=name,
                is_async=False,
                is_override=is_override,
                is_static=is_static,
                is_abstract=is_abstract,
                access=access,
                signature=signature,
                body=body,
                kid=self.flat_cur_nodes,
            )

        def function_decl(self, _: None) -> uni.Ability:
            """Grammar rule.

            function_decl: KW_OVERRIDE? KW_STATIC? KW_DEF access_tag? named_ref
                func_decl? (block_tail | KW_ABSTRACT? SEMI)
            """
            # Save original kids to track tokens
            is_override = self.match_token(Tok.KW_OVERRIDE) is not None
            is_static = self.match_token(Tok.KW_STATIC) is not None
            self.consume_token(Tok.KW_DEF)
            access = self.match(uni.SubTag)
            name = self.consume(uni.NameAtom)
            signature = self.match(uni.FuncSignature)

            # Handle block_tail
            body_sn_or_call = self.match(list) or self.match(uni.Expr)
            if body_sn_or_call is None:
                is_abstract = self.match_token(Tok.KW_ABSTRACT) is not None
                self.consume_token(Tok.SEMI)
                body = None
            else:
                is_abstract = False
                body = (
                    self.extract_from_list(body_sn_or_call, uni.CodeBlockStmt)
                    if isinstance(body_sn_or_call, list)
                    else body_sn_or_call
                )

            return uni.Ability(
                name_ref=name,
                is_async=False,
                is_override=is_override,
                is_static=is_static,
                is_abstract=is_abstract,
                access=access,
                signature=signature,
                body=body,
                kid=self.flat_cur_nodes,
            )

        def func_decl(self, _: None) -> uni.FuncSignature:
            """Grammar rule.

            func_decl: (LPAREN func_decl_params? RPAREN) (RETURN_HINT expression)?
                    | (RETURN_HINT expression)
            """
            return_spec: uni.Expr | None = None

            # Check if starting with RETURN_HINT
            if return_hint := self.match_token(Tok.RETURN_HINT):
                return_spec = self.consume(uni.Expr)
                kid_list: list[uni.UniNode] = [return_hint]
                if return_spec:
                    kid_list.append(return_spec)
                return uni.FuncSignature(
                    posonly_params=[],
                    params=[],
                    varargs=None,
                    kwonlyargs=[],
                    kwargs=None,
                    return_type=return_spec,
                    kid=kid_list,
                )
            # Otherwise, parse the traditional parameter list form
            else:
                lparen = self.consume_token(Tok.LPAREN)
                all_params = self.match(list) or []
                posonly_params, params, varargs, kwonlyargs, kwargs = (
                    self._parse_parameter_categories(all_params)
                )
                rparen = self.consume_token(Tok.RPAREN)
                return_hint = self.match_token(Tok.RETURN_HINT)
                if return_hint:
                    return_spec = self.consume(uni.Expr)
                # Build kid list with all tokens
                func_kid_list: list[uni.UniNode] = [lparen]
                if all_params:
                    func_kid_list.extend(all_params)
                func_kid_list.append(rparen)
                if return_hint:
                    func_kid_list.append(return_hint)
                    if return_spec:
                        func_kid_list.append(return_spec)
                return uni.FuncSignature(
                    posonly_params=posonly_params,
                    params=params,
                    varargs=varargs,
                    kwonlyargs=kwonlyargs,
                    kwargs=kwargs,
                    return_type=return_spec,
                    kid=func_kid_list,
                )

        def _parse_parameter_categories(
            self, all_params: list[uni.UniNode]
        ) -> tuple[
            list[uni.ParamVar],
            list[uni.ParamVar],
            uni.ParamVar | None,
            list[uni.ParamVar],
            uni.ParamVar | None,
        ]:
            posonly_params = []
            params = []
            varargs = None
            kwonlyargs = []
            kwargs = None

            # Initial state determination
            cur_state = "positional"
            for param in all_params:
                if isinstance(param, uni.Token) and param.name == Tok.DIV:
                    cur_state = "posonly"
                    break

            for cur_nd in all_params:
                cur_state = self._update_parameter_state(cur_nd, cur_state)
                if isinstance(cur_nd, uni.ParamVar):
                    if cur_state == "positional":
                        cur_nd.param_kind = uni.ParamKind.NORMAL
                        params.append(cur_nd)
                    elif cur_state == "posonly":
                        cur_nd.param_kind = uni.ParamKind.POSONLY
                        posonly_params.append(cur_nd)
                    elif cur_state == "varargs":
                        cur_nd.param_kind = uni.ParamKind.VARARG
                        varargs = cur_nd
                        cur_state = "keyword_only"
                    elif cur_state == "keyword_only":
                        cur_nd.param_kind = uni.ParamKind.KWONLY
                        kwonlyargs.append(cur_nd)
                    elif cur_state == "kwargs":
                        cur_nd.param_kind = uni.ParamKind.KWARG
                        kwargs = cur_nd
                    else:
                        raise self.ice()

            return posonly_params, params, varargs, kwonlyargs, kwargs

        def _update_parameter_state(self, cur_nd: uni.UniNode, cur_state: str) -> str:
            if isinstance(cur_nd, uni.Token):
                if cur_nd.name == Tok.DIV:
                    if cur_state in ["keyword_only", "kwargs", "positional"]:
                        self.parse_ref.log_error(
                            "Invalid syntax in function parameters: '/' cannot appear after '*' or '**'.",
                            node_override=cur_nd,
                        )
                    return "positional"
                elif cur_nd.name == Tok.STAR_MUL:
                    if cur_state in ["keyword_only", "kwargs"]:
                        self.parse_ref.log_error(
                            "Invalid syntax in function parameters: '*' cannot appear after '**'.",
                            node_override=cur_nd,
                        )
                    return "keyword_only"
                elif cur_nd.name == Tok.COMMA:
                    return cur_state

            elif isinstance(cur_nd, uni.ParamVar):
                if cur_nd.is_vararg:
                    return "varargs"
                if cur_nd.is_kwargs:
                    return "kwargs"
            return cur_state

        def func_decl_params(self, _: None) -> list[uni.UniNode]:
            """Grammar rule.

            func_decl_params: (param_var COMMA)* param_var COMMA?
            """
            return self.cur_nodes

        def param_var(self, _: None) -> uni.ParamVar | uni.Token:
            """Grammar rule.

            param_var: (STAR_POW | STAR_MUL)? named_ref type_tag (EQ expression)?
                    | DIV
                    | STAR_MUL
            """
            if len(self.cur_nodes) == 1 and (
                star_only := self.match_token(Tok.DIV) or self.match_token(Tok.STAR_MUL)
            ):
                return star_only
            star = self.match_token(Tok.STAR_POW) or self.match_token(Tok.STAR_MUL)
            name = self.consume(uni.Name)
            type_tag = self.consume(uni.SubTag)
            value = self.consume(uni.Expr) if self.match_token(Tok.EQ) else None

            return uni.ParamVar(
                name=name,
                type_tag=type_tag,
                value=value,
                unpack=star,
                kid=self.cur_nodes,
            )

        def member_block(self, _: None) -> list[uni.UniNode]:
            """Grammar rule.

            member_block: LBRACE member_stmt* RBRACE
            """
            return self.cur_nodes

        def member_stmt(self, _: None) -> uni.ArchBlockStmt:
            """Grammar rule.

            member_stmt: STRING? (py_code_block | ability | archetype | impl_def | has_stmt | free_code)
            """
            doc = self.match(uni.String)
            ret = self.consume(uni.ArchBlockStmt)
            if doc and isinstance(ret, uni.AstDocNode):
                ret.doc = doc
                ret.add_kids_left([doc])
            return ret

        def has_stmt(self, kid: list[uni.UniNode]) -> uni.ArchHas:
            """Grammar rule.

            has_stmt: KW_STATIC? KW_HAS access_tag? has_assign_list SEMI
            """
            chomp = [*kid]
            is_static = (
                isinstance(chomp[0], uni.Token) and chomp[0].name == Tok.KW_STATIC
            )
            chomp = chomp[1:] if is_static else chomp
            chomp = chomp[1:]  # Skip KW_HAS
            access = chomp[0] if isinstance(chomp[0], uni.SubTag) else None
            chomp = chomp[1:] if access else chomp
            assign = chomp[0]
            if isinstance(assign, list):
                assigns = self.extract_from_list(assign, uni.HasVar)
                return uni.ArchHas(
                    vars=assigns,
                    is_static=is_static,
                    is_frozen=False,
                    access=access,
                    kid=self.flat_cur_nodes,
                )
            else:
                raise self.ice()

        def has_assign_list(self, _: None) -> list[uni.UniNode]:
            """Grammar rule.

            has_assign_list: (has_assign_list COMMA)? typed_has_clause
            """
            return self.flat_cur_nodes

        def typed_has_clause(self, _: None) -> uni.HasVar:
            """Grammar rule.

            typed_has_clause: named_ref type_tag (EQ expression | KW_BY KW_POST_INIT)?
            """
            value: uni.Expr | None = None
            defer: bool = False
            name = self.consume(uni.Name)
            type_tag = self.consume(uni.SubTag)
            if self.match_token(Tok.EQ):
                value = self.consume(uni.Expr)
            elif self.match_token(Tok.KW_BY):
                defer = bool(self.consume_token(Tok.KW_POST_INIT))
            return uni.HasVar(
                name=name,
                type_tag=type_tag,
                defer=defer,
                value=value,
                kid=self.cur_nodes,
            )

        def type_tag(self, _: None) -> uni.SubTag[uni.Expr]:
            """Grammar rule.

            type_tag: COLON expression
            """
            self.consume_token(Tok.COLON)
            tag = self.consume(uni.Expr)
            return uni.SubTag[uni.Expr](tag=tag, kid=self.cur_nodes)

        def builtin_type(self, _: None) -> uni.Token:
            """Grammar rule.

            builtin_type: TYP_TYPE
                        | TYP_ANY
                        | TYP_BOOL
                        | TYP_DICT
                        | TYP_SET
                        | TYP_TUPLE
                        | TYP_LIST
                        | TYP_FLOAT
                        | TYP_INT
                        | TYP_BYTES
                        | TYP_STRING
            """
            token = self.consume(uni.Token)
            return uni.BuiltinType(
                name=token.name,
                orig_src=self.parse_ref.ir_in,
                value=token.value,
                line=token.loc.first_line,
                end_line=token.loc.last_line,
                col_start=token.loc.col_start,
                col_end=token.loc.col_end,
                pos_start=token.pos_start,
                pos_end=token.pos_end,
            )

        def code_block(self, kid: list[uni.UniNode]) -> list[uni.UniNode]:
            """Grammar rule.

            code_block: LBRACE statement* RBRACE
            """
            return self.flat_cur_nodes

        def statement(self, kid: list[uni.UniNode]) -> uni.CodeBlockStmt:
            """Grammar rule.

            statement: import_stmt
                    | ability
                    | archetype
                    | if_stmt
                    | while_stmt
                    | for_stmt
                    | try_stmt
                    | match_stmt
                    | with_stmt
                    | global_ref SEMI
                    | nonlocal_ref SEMI
                    | typed_ctx_block
                    | return_stmt SEMI
                    | (yield_expr | KW_YIELD) SEMI
                    | raise_stmt SEMI
                    | assert_stmt SEMI
                    | assignment SEMI
                    | delete_stmt SEMI
                    | report_stmt SEMI
                    | expression SEMI
                    | ctrl_stmt SEMI
                    | py_code_block
                    | spatial_stmt
                    | SEMI
            """
            if (code_block := self.match(uni.CodeBlockStmt)) and len(
                self.cur_nodes
            ) < 2:
                return code_block
            elif (token := self.match(uni.Token)) and token.name == Tok.KW_YIELD:
                return uni.ExprStmt(
                    expr=(
                        expr := uni.YieldExpr(
                            expr=None,
                            with_from=False,
                            kid=self.cur_nodes,
                        )
                    ),
                    in_fstring=False,
                    kid=[expr],
                )
            elif isinstance(kid[0], uni.Expr):
                return uni.ExprStmt(
                    expr=kid[0],
                    in_fstring=False,
                    kid=self.cur_nodes,
                )
            elif isinstance(kid[0], uni.CodeBlockStmt):
                kid[0].add_kids_right([kid[1]])
                return kid[0]
            else:
                raise self.ice()

        def typed_ctx_block(self, _: None) -> uni.TypedCtxBlock:
            """Grammar rule.

            typed_ctx_block: RETURN_HINT expression code_block
            """
            self.consume_token(Tok.RETURN_HINT)
            ctx = self.consume(uni.Expr)
            body = self.consume(list)
            return uni.TypedCtxBlock(
                type_ctx=ctx,
                body=self.extract_from_list(body, uni.CodeBlockStmt),
                kid=self.flat_cur_nodes,
            )

        def if_stmt(self, _: None) -> uni.IfStmt:
            """Grammar rule.

            if_stmt: KW_IF expression code_block (elif_stmt | else_stmt)?
            """
            self.consume_token(Tok.KW_IF)
            condition = self.consume(uni.Expr)
            body = self.consume(list)
            else_body = self.match(uni.ElseStmt) or self.match(uni.ElseIf)
            return uni.IfStmt(
                condition=condition,
                body=self.extract_from_list(body, uni.CodeBlockStmt),
                else_body=else_body,
                kid=self.flat_cur_nodes,
            )

        def elif_stmt(self, _: None) -> uni.ElseIf:
            """Grammar rule.

            elif_stmt: KW_ELIF expression code_block (elif_stmt | else_stmt)?
            """
            self.consume_token(Tok.KW_ELIF)
            condition = self.consume(uni.Expr)
            body = self.consume(list)
            else_body = self.match(uni.ElseStmt) or self.match(uni.ElseIf)
            return uni.ElseIf(
                condition=condition,
                body=self.extract_from_list(body, uni.CodeBlockStmt),
                else_body=else_body,
                kid=self.flat_cur_nodes,
            )

        def else_stmt(self, _: None) -> uni.ElseStmt:
            """Grammar rule.

            else_stmt: KW_ELSE code_block
            """
            self.consume_token(Tok.KW_ELSE)
            body = self.consume(list)
            return uni.ElseStmt(
                body=self.extract_from_list(body, uni.CodeBlockStmt),
                kid=self.flat_cur_nodes,
            )

        def try_stmt(self, _: None) -> uni.TryStmt:
            """Grammar rule.

            try_stmt: KW_TRY code_block except_list? else_stmt? finally_stmt?
            """
            self.consume_token(Tok.KW_TRY)
            block = self.consume(list)
            except_list = self.match(list)
            else_stmt = self.match(uni.ElseStmt)
            finally_stmt = self.match(uni.FinallyStmt)
            return uni.TryStmt(
                body=self.extract_from_list(block, uni.CodeBlockStmt),
                excepts=(
                    self.extract_from_list(except_list, uni.Except)
                    if except_list
                    else []
                ),
                else_body=else_stmt,
                finally_body=finally_stmt,
                kid=self.flat_cur_nodes,
            )

        def except_list(self, _: None) -> list[uni.UniNode]:
            """Grammar rule.

            except_list: except_def+
            """
            return self.flat_cur_nodes

        def except_def(self, _: None) -> uni.Except:
            """Grammar rule.

            except_def: KW_EXCEPT expression (KW_AS NAME)? code_block
            """
            name: uni.Name | None = None
            self.consume_token(Tok.KW_EXCEPT)
            ex_type = self.consume(uni.Expr)
            if self.match_token(Tok.KW_AS):
                name = self.consume(uni.Name)
            body_node = self.consume(list)
            return uni.Except(
                ex_type=ex_type,
                name=name,
                body=self.extract_from_list(body_node, uni.CodeBlockStmt),
                kid=self.flat_cur_nodes,
            )

        def finally_stmt(self, _: None) -> uni.FinallyStmt:
            """Grammar rule.

            finally_stmt: KW_FINALLY code_block
            """
            self.consume_token(Tok.KW_FINALLY)
            body = self.consume(list)
            return uni.FinallyStmt(
                body=self.extract_from_list(body, uni.CodeBlockStmt),
                kid=self.flat_cur_nodes,
            )

        def for_stmt(self, _: None) -> uni.IterForStmt | uni.InForStmt:
            """Grammar rule.

            for_stmt: KW_ASYNC? KW_FOR assignment KW_TO expression KW_BY assignment code_block else_stmt?
                    | KW_ASYNC? KW_FOR atomic_chain KW_IN expression code_block else_stmt?
            """
            is_async = bool(self.match_token(Tok.KW_ASYNC))
            self.consume_token(Tok.KW_FOR)
            if iter := self.match(uni.Assignment):
                self.consume_token(Tok.KW_TO)
                condition = self.consume(uni.Expr)
                self.consume_token(Tok.KW_BY)
                count_by = self.consume(uni.Assignment)
                body = self.consume(list)
                else_body = self.match(uni.ElseStmt)
                return uni.IterForStmt(
                    is_async=is_async,
                    iter=iter,
                    condition=condition,
                    count_by=count_by,
                    body=self.extract_from_list(body, uni.CodeBlockStmt),
                    else_body=else_body,
                    kid=self.flat_cur_nodes,
                )
            target = self.consume(uni.Expr)
            self.consume_token(Tok.KW_IN)
            collection = self.consume(uni.Expr)
            body = self.consume(list)
            else_body = self.match(uni.ElseStmt)
            return uni.InForStmt(
                is_async=is_async,
                target=target,
                collection=collection,
                body=self.extract_from_list(body, uni.CodeBlockStmt),
                else_body=else_body,
                kid=self.flat_cur_nodes,
            )

        def while_stmt(self, _: None) -> uni.WhileStmt:
            """Grammar rule.

            while_stmt: KW_WHILE expression code_block else_stmt?
            """
            self.consume_token(Tok.KW_WHILE)
            condition = self.consume(uni.Expr)
            body = self.consume(list)
            else_body = self.match(uni.ElseStmt)
            return uni.WhileStmt(
                condition=condition,
                body=self.extract_from_list(body, uni.CodeBlockStmt),
                else_body=else_body,
                kid=self.flat_cur_nodes,
            )

        def with_stmt(self, _: None) -> uni.WithStmt:
            """Grammar rule.

            with_stmt: KW_ASYNC? KW_WITH expr_as_list code_block
            """
            is_async = bool(self.match_token(Tok.KW_ASYNC))
            self.consume_token(Tok.KW_WITH)
            exprs_node = self.extract_from_list(self.consume(list), uni.ExprAsItem)
            body = self.consume(list)
            return uni.WithStmt(
                is_async=is_async,
                exprs=exprs_node,
                body=self.extract_from_list(body, uni.CodeBlockStmt),
                kid=self.flat_cur_nodes,
            )

        def expr_as_list(self, _: None) -> list[uni.UniNode]:
            """Grammar rule.

            expr_as_list: (expr_as COMMA)* expr_as
            """
            return self.cur_nodes

        def expr_as(self, _: None) -> uni.ExprAsItem:
            """Grammar rule.

            expr_as: expression (KW_AS expression)?
            """
            expr = self.consume(uni.Expr)
            alias = self.consume(uni.Expr) if self.match_token(Tok.KW_AS) else None
            return uni.ExprAsItem(
                expr=expr,
                alias=alias,
                kid=self.cur_nodes,
            )

        def raise_stmt(self, _: None) -> uni.RaiseStmt:
            """Grammar rule.

            raise_stmt: KW_RAISE (expression (KW_FROM expression)?)?
            """
            e_type: uni.Expr | None = None
            from_target: uni.Expr | None = None
            self.consume_token(Tok.KW_RAISE)
            if e_type := self.match(uni.Expr):
                from_target = (
                    self.consume(uni.Expr) if self.match_token(Tok.KW_FROM) else None
                )
            return uni.RaiseStmt(
                cause=e_type,
                from_target=from_target,
                kid=self.cur_nodes,
            )

        def assert_stmt(self, _: None) -> uni.AssertStmt:
            """Grammar rule.

            assert_stmt: KW_ASSERT expression (COMMA expression)?
            """
            error_msg: uni.Expr | None = None
            self.consume_token(Tok.KW_ASSERT)
            condition = self.consume(uni.Expr)
            if self.match_token(Tok.COMMA):
                error_msg = self.consume(uni.Expr)
            return uni.AssertStmt(
                condition=condition,
                error_msg=error_msg,
                kid=self.cur_nodes,
            )

        def ctrl_stmt(self, _: None) -> uni.CtrlStmt | uni.DisengageStmt:
            """Grammar rule.

            ctrl_stmt: KW_SKIP | KW_BREAK | KW_CONTINUE
            """
            tok = (
                self.match_token(Tok.KW_SKIP)
                or self.match_token(Tok.KW_BREAK)
                or self.consume_token(Tok.KW_CONTINUE)
            )
            return uni.CtrlStmt(
                ctrl=tok,
                kid=self.cur_nodes,
            )

        def delete_stmt(self, _: None) -> uni.DeleteStmt:
            """Grammar rule.

            delete_stmt: KW_DELETE expression
            """
            self.consume_token(Tok.KW_DELETE)
            target = self.consume(uni.Expr)
            return uni.DeleteStmt(
                target=target,
                kid=self.cur_nodes,
            )

        def report_stmt(self, _: None) -> uni.ReportStmt:
            """Grammar rule.

            report_stmt: KW_REPORT expression
            """
            self.consume_token(Tok.KW_REPORT)
            target = self.consume(uni.Expr)
            return uni.ReportStmt(
                expr=target,
                kid=self.cur_nodes,
            )

        def return_stmt(self, _: None) -> uni.ReturnStmt:
            """Grammar rule.

            return_stmt: KW_RETURN expression?
            """
            self.consume_token(Tok.KW_RETURN)
            expr = self.match(uni.Expr)

            return uni.ReturnStmt(
                expr=expr,
                kid=self.cur_nodes,
            )

        def spatial_stmt(self, _: None) -> uni.CodeBlockStmt:
            """Grammar rule.

            spatial_stmt: visit_stmt | ignore_stmt
            """
            return self.consume(uni.CodeBlockStmt)

        def disenage_stmt(self, _: None) -> uni.DisengageStmt:
            """Grammar rule.

            disenage_stmt: KW_DISENGAGE SEMI
            """
            self.consume_token(Tok.KW_DISENGAGE)
            self.consume_token(Tok.SEMI)
            return uni.DisengageStmt(
                kid=self.cur_nodes,
            )

        def visit_stmt(self, _: None) -> uni.VisitStmt:
            """Grammar rule.

            visit_stmt: KW_VISIT (COLON expression COLON)?
                expression (else_stmt | SEMI)
            """
            self.consume_token(Tok.KW_VISIT)
            insert_loc = None
            if self.match_token(Tok.COLON):
                insert_loc = self.consume(uni.Expr)
                self.consume_token(Tok.COLON)
            target = self.consume(uni.Expr)
            else_body = self.match(uni.ElseStmt)
            if else_body is None:
                self.consume_token(Tok.SEMI)
            return uni.VisitStmt(
                insert_loc=insert_loc,
                target=target,
                else_body=else_body,
                kid=self.cur_nodes,
            )

        def global_ref(self, _: None) -> uni.GlobalStmt:
            """Grammar rule.

            global_ref: GLOBAL_OP name_list
            """
            self.consume_token(Tok.GLOBAL_OP)
            target = self.consume(list)
            return uni.GlobalStmt(
                target=self.extract_from_list(target, uni.Name),
                kid=self.flat_cur_nodes,
            )

        def nonlocal_ref(self, _: None) -> uni.NonLocalStmt:
            """Grammar rule.

            nonlocal_ref: NONLOCAL_OP name_list
            """
            self.consume_token(Tok.NONLOCAL_OP)
            target = self.consume(list)
            return uni.NonLocalStmt(
                target=self.extract_from_list(target, uni.Name),
                kid=self.flat_cur_nodes,
            )

        def assignment(self, _: None) -> uni.Assignment:
            """Grammar rule.

            assignment: (atomic_chain EQ)+ (yield_expr | expression)
                      | atomic_chain type_tag (EQ (yield_expr | expression))?
                      | atomic_chain aug_op (yield_expr | expression)
            """
            assignees: list = []
            type_tag: uni.SubTag | None = None
            is_aug: uni.Token | None = None

            if first_expr := self.match(uni.Expr):
                assignees.append(first_expr)

            token = self.match(uni.Token)
            if token and (token.name == Tok.EQ):
                assignees.append(token)
                while expr := self.match(uni.Expr):
                    eq = self.match_token(Tok.EQ)
                    assignees.append(expr)
                    if eq:
                        assignees.append(eq)
                value = assignees.pop()
            elif token and (token.name not in {Tok.COLON, Tok.EQ}):
                is_aug = token
                value = self.consume(uni.Expr)
            else:
                type_tag = self.consume(uni.SubTag)
                value = self.consume(uni.Expr) if self.match_token(Tok.EQ) else None

            valid_assignees = [i for i in assignees if isinstance(i, (uni.Expr))]

            if is_aug:
                return uni.Assignment(
                    target=valid_assignees,
                    type_tag=type_tag,
                    value=value,
                    mutable=False,
                    aug_op=is_aug,
                    kid=self.flat_cur_nodes,
                )
            return uni.Assignment(
                target=valid_assignees,
                type_tag=type_tag,
                value=value,
                mutable=False,
                kid=self.flat_cur_nodes,
            )

        def expression(self, _: None) -> uni.Expr:
            """Grammar rule.

            expression: walrus_assign (KW_IF expression KW_ELSE expression)?
                      | lambda_expr
            """
            value = self.consume(uni.Expr)
            if self.match_token(Tok.KW_IF):
                condition = self.consume(uni.Expr)
                self.consume_token(Tok.KW_ELSE)
                else_value = self.consume(uni.Expr)
                return uni.IfElseExpr(
                    value=value,
                    condition=condition,
                    else_value=else_value,
                    kid=self.cur_nodes,
                )
            return value

        def concurrent_expr(self, _: None) -> uni.ConcurrentExpr | uni.Expr:
            """Grammar rule.

            concurrent: (KW_FLOW | KW_WAIT)
            """
            if (tok := self.match_token(Tok.KW_FLOW)) or (
                tok := self.match_token(Tok.KW_WAIT)
            ):
                target = self.consume(uni.Expr)
                return uni.ConcurrentExpr(
                    tok=tok,
                    target=target,
                    kid=self.cur_nodes,
                )
            else:
                return self.consume(uni.Expr)

        def walrus_assign(self, _: None) -> uni.Expr:
            """Grammar rule.

            walrus_assign: (named_ref WALRUS_EQ)? by_expr
            """
            return self._binary_expr_unwind(self.cur_nodes)

        def by_expr(self, _: None) -> uni.Expr:
            """Grammar rule.

            by_expr: (by_expr KW_BY)? pipe
            """
            return self._binary_expr_unwind(self.cur_nodes)

        def lambda_expr(self, _: None) -> uni.LambdaExpr:
            """Grammar rule.

            lambda_expr: KW_LAMBDA func_decl_params? (RETURN_HINT expression)? ( COLON expression | code_block )
            """
            return_type: uni.Expr | None = None
            return_hint_tok: uni.Token | None = None
            sig_kid: list[uni.UniNode] = []
            self.consume_token(Tok.KW_LAMBDA)
            param_nodes: list[uni.UniNode] | None = None
            signature = self.match(uni.FuncSignature)
            signature_created = False
            if not signature:
                if self.node_idx < len(self.cur_nodes) and isinstance(
                    self.cur_nodes[self.node_idx], list
                ):
                    candidate: list[uni.UniNode] = self.cur_nodes[self.node_idx]  # type: ignore[assignment]
                    first = candidate[0] if candidate else None
                    if not (
                        isinstance(first, uni.Token) and first.name == Tok.LBRACE.name
                    ):
                        param_nodes = self.consume(list)
                elif (
                    self.node_idx < len(self.cur_nodes)
                    and isinstance(cur_node := self.cur_nodes[self.node_idx], uni.Token)
                    and cur_node.name == Tok.LPAREN.name
                ):
                    self.consume_token(Tok.LPAREN)
                    param_nodes = self.match(list)
                    self.consume_token(Tok.RPAREN)
                if return_hint_tok := self.match_token(Tok.RETURN_HINT):
                    return_type = self.consume(uni.Expr)
                if param_nodes:
                    sig_kid.extend(param_nodes)
                if return_hint_tok:
                    sig_kid.append(return_hint_tok)
                if return_type:
                    sig_kid.append(return_type)
                signature = (
                    uni.FuncSignature(
                        posonly_params=[],
                        params=(
                            self.extract_from_list(param_nodes, uni.ParamVar)
                            if param_nodes
                            else []
                        ),
                        varargs=None,
                        kwonlyargs=[],
                        kwargs=None,
                        return_type=return_type,
                        kid=sig_kid,
                    )
                    if param_nodes or return_type
                    else None
                )
                signature_created = signature is not None

            # Check if body is a code block or expression
            block_nodes: list[uni.UniNode] | None = None
            if self.match_token(Tok.COLON):
                # Single-expression body
                body: uni.Expr | list[uni.CodeBlockStmt] = self.consume(uni.Expr)
            else:
                if self.node_idx < len(self.cur_nodes) and isinstance(
                    self.cur_nodes[self.node_idx], list
                ):
                    block_nodes = self.consume(list)
                    body = self.extract_from_list(block_nodes, uni.CodeBlockStmt)
                else:
                    self.consume_token(Tok.LBRACE)
                    body_stmts: list[uni.CodeBlockStmt] = []
                    while not self.match_token(Tok.RBRACE):
                        body_stmts.append(self.consume(uni.CodeBlockStmt))
                    body = body_stmts

            new_kid: list[uni.UniNode] = []
            for item in self.cur_nodes:
                if param_nodes is not None and item is param_nodes:
                    continue
                if item is return_type or item is return_hint_tok:
                    continue
                if block_nodes is not None and item is block_nodes:
                    new_kid.extend(block_nodes)
                else:
                    new_kid.append(item)
            if signature_created and signature:
                new_kid.insert(1, signature)
            return uni.LambdaExpr(
                signature=signature,
                body=body,
                kid=new_kid,
            )

        def pipe(self, _: None) -> uni.Expr:
            """Grammar rule.

            pipe: (pipe PIPE_FWD)? pipe_back
            """
            return self._binary_expr_unwind(self.cur_nodes)

        def pipe_back(self, _: None) -> uni.Expr:
            """Grammar rule.

            pipe_back: (pipe_back PIPE_BKWD)? bitwise_or
            """
            return self._binary_expr_unwind(self.cur_nodes)

        def bitwise_or(self, _: None) -> uni.Expr:
            """Grammar rule.

            bitwise_or: (bitwise_or BW_OR)? bitwise_xor
            """
            return self._binary_expr_unwind(self.cur_nodes)

        def bitwise_xor(self, _: None) -> uni.Expr:
            """Grammar rule.

            bitwise_xor: (bitwise_xor BW_XOR)? bitwise_and
            """
            return self._binary_expr_unwind(self.cur_nodes)

        def bitwise_and(self, _: None) -> uni.Expr:
            """Grammar rule.

            bitwise_and: (bitwise_and BW_AND)? shift
            """
            return self._binary_expr_unwind(self.cur_nodes)

        def shift(self, _: None) -> uni.Expr:
            """Grammar rule.

            shift: (shift (RSHIFT | LSHIFT))? logical_or
            """
            return self._binary_expr_unwind(self.cur_nodes)

        def logical_or(self, _: None) -> uni.Expr:
            """Grammar rule.

            logical_or: logical_and (KW_OR logical_and)*
            """
            value = self.consume(uni.Expr)
            if not (ops := self.match_token(Tok.KW_OR)):
                return value
            values: list = [value]
            while value := self.consume(uni.Expr):
                values.append(value)
                if not self.match_token(Tok.KW_OR):
                    break
            return uni.BoolExpr(
                op=ops,
                values=values,
                kid=self.cur_nodes,
            )

        def logical_and(self, _: None) -> uni.Expr:
            """Grammar rule.

            logical_and: logical_not (KW_AND logical_not)*
            """
            value = self.consume(uni.Expr)
            if not (ops := self.match_token(Tok.KW_AND)):
                return value
            values: list = [value]
            while value := self.consume(uni.Expr):
                values.append(value)
                if not self.match_token(Tok.KW_AND):
                    break
            return uni.BoolExpr(
                op=ops,
                values=values,
                kid=self.cur_nodes,
            )

        def logical_not(self, _: None) -> uni.Expr:
            """Grammar rule.

            logical_not: NOT logical_not | compare
            """
            if op := self.match_token(Tok.NOT):
                operand = self.consume(uni.Expr)
                return uni.UnaryExpr(
                    op=op,
                    operand=operand,
                    kid=self.cur_nodes,
                )
            return self.consume(uni.Expr)

        def compare(self, _: None) -> uni.Expr:
            """Grammar rule.

            compare: (arithmetic cmp_op)* arithmetic
            """
            ops: list = []
            rights: list = []
            left = self.consume(uni.Expr)
            while op := self.match(uni.Token):
                ops.append(op)
                rights.append(self.consume(uni.Expr))
            if not ops:
                return left
            return uni.CompareExpr(
                left=left,
                ops=ops,
                rights=rights,
                kid=self.cur_nodes,
            )

        def cmp_op(self, _: None) -> uni.Token:
            """Grammar rule.

            cmp_op: KW_ISN
                  | KW_IS
                  | KW_NIN
                  | KW_IN
                  | NE
                  | GTE
                  | LTE
                  | GT
                  | LT
                  | EE
            """
            return self.consume(uni.Token)

        def arithmetic(self, _: None) -> uni.Expr:
            """Grammar rule.

            arithmetic: (arithmetic (MINUS | PLUS))? term
            """
            return self._binary_expr_unwind(self.cur_nodes)

        def term(self, _: None) -> uni.Expr:
            """Grammar rule.

            term: (term (MOD | DIV | FLOOR_DIV | STAR_MUL | DECOR_OP))? power
            """
            return self._binary_expr_unwind(self.cur_nodes)

        def factor(self, _: None) -> uni.Expr:
            """Grammar rule.

            factor: (BW_NOT | MINUS | PLUS) factor | connect
            """
            if (
                op := self.match_token(Tok.BW_NOT)
                or self.match_token(Tok.MINUS)
                or self.match_token(Tok.PLUS)
            ):
                operand = self.consume(uni.Expr)
                return uni.UnaryExpr(
                    op=op,
                    operand=operand,
                    kid=self.cur_nodes,
                )
            return self._binary_expr_unwind(self.cur_nodes)

        def power(self, _: None) -> uni.Expr:
            """Grammar rule.

            power: (power STAR_POW)? factor
            """
            return self._binary_expr_unwind(self.cur_nodes)

        def connect(self, _: None) -> uni.Expr:
            """Grammar rule.

            connect: (connect (connect_op | disconnect_op))? atomic_pipe
            """
            return self._binary_expr_unwind(self.cur_nodes)

        def atomic_pipe(self, _: None) -> uni.Expr:
            """Grammar rule.

            atomic_pipe: (atomic_pipe A_PIPE_FWD)? atomic_pipe_back
            """
            return self._binary_expr_unwind(self.cur_nodes)

        def atomic_pipe_back(self, _: None) -> uni.Expr:
            """Grammar rule.

            atomic_pipe_back: (atomic_pipe_back A_PIPE_BKWD)? ds_spawn
            """
            return self._binary_expr_unwind(self.cur_nodes)

        def os_spawn(self, _: None) -> uni.Expr:
            """Grammar rule.

            os_spawn: (os_spawn KW_SPAWN)? unpack
            """
            return self._binary_expr_unwind(self.cur_nodes)

        def unpack(self, _: None) -> uni.Expr:
            """Grammar rule.

            unpack: STAR_MUL? ref
            """
            if op := self.match_token(Tok.STAR_MUL):
                operand = self.consume(uni.Expr)
                return uni.UnaryExpr(
                    op=op,
                    operand=operand,
                    kid=self.cur_nodes,
                )
            return self._binary_expr_unwind(self.cur_nodes)

        def ref(self, _: None) -> uni.Expr:
            """Grammar rule.

            ref: walrus_assign
               | BW_AND walrus_assign
            """
            if op := self.match_token(Tok.BW_AND):
                operand = self.consume(uni.Expr)
                return uni.UnaryExpr(
                    op=op,
                    operand=operand,
                    kid=self.cur_nodes,
                )
            return self._binary_expr_unwind(self.cur_nodes)

        def await_expr(self, _: None) -> uni.Expr:
            """Grammar rule.

            await_expr: KW_AWAIT? pipe_call
            """
            if self.match_token(Tok.KW_AWAIT):
                operand = self.consume(uni.Expr)
                return uni.AwaitExpr(
                    target=operand,
                    kid=self.cur_nodes,
                )
            return self._binary_expr_unwind(self.cur_nodes)

        def pipe_call(self, _: None) -> uni.Expr:
            """Grammar rule.

            pipe_call: (PIPE_FWD | A_PIPE_FWD | KW_SPAWN)? atomic_chain
            """
            if len(self.cur_nodes) == 2 and (op := self.match(uni.Token)):
                operand = self.consume(uni.Expr)
                return uni.UnaryExpr(
                    op=op,
                    operand=operand,
                    kid=self.cur_nodes,
                )
            return self._binary_expr_unwind(self.cur_nodes)

        def aug_op(self, _: None) -> uni.Token:
            """Grammar rule.

            aug_op: RSHIFT_EQ
                   | LSHIFT_EQ
                   | BW_XOR_EQ
                   | BW_OR_EQ
                   | BW_AND_EQ
                   | MOD_EQ
                   | DIV_EQ
                   | FLOOR_DIV_EQ
                   | MUL_EQ
                   | SUB_EQ
                   | ADD_EQ
                   | MATMUL_EQ
                   | STAR_POW_EQ
            """
            return self.consume(uni.Token)

        def atomic_chain(self, _: None) -> uni.Expr:
            """Grammar rule.

            atomic_chain: atomic_chain NULL_OK? (filter_compr | assign_compr | index_slice)
                        | atomic_chain NULL_OK? (DOT_BKWD | DOT_FWD | DOT) named_ref
                        | (atomic_call | atom | edge_ref_chain)
            """
            if len(self.cur_nodes) == 1:
                return self.consume(uni.Expr)
            target = self.consume(uni.Expr)
            is_null_ok = bool(self.match_token(Tok.NULL_OK))
            if right := self.match(uni.AtomExpr):
                return uni.AtomTrailer(
                    target=target,
                    right=right,
                    is_null_ok=is_null_ok,
                    is_attr=False,
                    kid=self.cur_nodes,
                )
            token = (
                self.match_token(Tok.DOT_BKWD)
                or self.match_token(Tok.DOT_FWD)
                or self.consume_token(Tok.DOT)
            )
            name = self.match(uni.AtomExpr) or self.consume(uni.AtomTrailer)
            return uni.AtomTrailer(
                target=(target if token.name != Tok.DOT_BKWD else name),
                right=(name if token.name != Tok.DOT_BKWD else target),
                is_null_ok=is_null_ok,
                is_attr=True,
                kid=self.cur_nodes,
            )

        def atomic_call(self, _: None) -> uni.FuncCall:
            """Grammar rule.

            atomic_call: atomic_chain LPAREN param_list? RPAREN
            """
            target = self.consume(uni.Expr)
            gencompr = self.match(uni.GenCompr)
            if gencompr:
                return uni.FuncCall(
                    target=target,
                    params=[gencompr],
                    genai_call=None,
                    kid=self.cur_nodes,
                )
            self.consume_token(Tok.LPAREN)
            params_sn = self.match(list)
            self.consume_token(Tok.RPAREN)

            return uni.FuncCall(
                target=target,
                params=(
                    self.extract_from_list(params_sn, (uni.Expr, uni.KWPair))  # type: ignore[arg-type]
                    if params_sn
                    else []
                ),
                genai_call=None,
                kid=self.flat_cur_nodes,
            )

        def index_slice(self, _: None) -> uni.IndexSlice:
            """Grammar rule.

            index_slice: LSQUARE                                                        \
                            expression? COLON expression? (COLON expression?)?          \
                            (COMMA expression? COLON expression? (COLON expression?)?)* \
                         RSQUARE
                        | list_val
            """
            if len(self.cur_nodes) == 1:
                index = self.consume(uni.ListVal)
                if len(index.values) == 1:
                    expr = index.values[0]
                    kid = self.cur_nodes
                else:
                    expr = uni.TupleVal(values=index.values, kid=index.kid)
                    kid = [expr]
                return uni.IndexSlice(
                    slices=[uni.IndexSlice.Slice(start=expr, stop=None, step=None)],
                    is_range=False,
                    kid=kid,
                )
            else:
                self.consume_token(Tok.LSQUARE)
                slices: list[uni.IndexSlice.Slice] = []
                while not self.match_token(Tok.RSQUARE):
                    expr1 = self.match(uni.Expr)
                    self.consume_token(Tok.COLON)
                    expr2 = self.match(uni.Expr)
                    expr3 = (
                        self.match(uni.Expr) if self.match_token(Tok.COLON) else None
                    )
                    self.match_token(Tok.COMMA)
                    slices.append(
                        uni.IndexSlice.Slice(start=expr1, stop=expr2, step=expr3)
                    )
                return uni.IndexSlice(
                    slices=slices,
                    is_range=True,
                    kid=self.cur_nodes,
                )

        def atom(self, _: None) -> uni.Expr:
            """Grammar rule.

            atom: named_ref
                 | LPAREN (expression | yield_expr | function_decl) RPAREN
                 | atom_collection
                 | atom_literal
                 | type_ref
                 | jsx_element
            """
            if lparen := self.match_token(Tok.LPAREN):
                # Try to match expression first, then yield_expr, then function_decl
                value: uni.Expr | uni.YieldExpr | uni.Ability
                if matched_expr := self.match(uni.Expr):
                    value = matched_expr
                elif matched_yield := self.match(uni.YieldExpr):
                    value = matched_yield
                else:
                    value = self.consume(uni.Ability)
                rparen = self.consume_token(Tok.RPAREN)
                return uni.AtomUnit(value=value, kid=[lparen, value, rparen])
            return self.consume(uni.AtomExpr)

        def yield_expr(self, _: None) -> uni.YieldExpr:
            """Grammar rule.

            yield_expr: KW_YIELD KW_FROM? expression
            """
            self.consume_token(Tok.KW_YIELD)
            is_with_from = bool(self.match_token(Tok.KW_FROM))
            expr = self.consume(uni.Expr)
            return uni.YieldExpr(
                expr=expr,
                with_from=is_with_from,
                kid=self.cur_nodes,
            )

        def atom_literal(self, _: None) -> uni.AtomExpr:
            """Grammar rule.

            atom_literal: builtin_type
                        | NULL
                        | BOOL
                        | multistring
                        | ELLIPSIS
                        | FLOAT
                        | OCT
                        | BIN
                        | HEX
                        | INT
            """
            return self.consume(uni.AtomExpr)

        def atom_collection(self, kid: list[uni.UniNode]) -> uni.AtomExpr:
            """Grammar rule.

            atom_collection: dict_compr
                           | set_compr
                           | gen_compr
                           | list_compr
                           | dict_val
                           | set_val
                           | tuple_val
                           | list_val
            """
            return self.consume(uni.AtomExpr)

        def multistring(self, _: None) -> uni.AtomExpr:
            """Grammar rule.

            multistring: (fstring | STRING)+
            """
            valid_strs = [self.match(uni.String) or self.consume(uni.FString)]
            while node := (self.match(uni.String) or self.match(uni.FString)):
                valid_strs.append(node)
            return uni.MultiString(
                strings=valid_strs,
                kid=self.cur_nodes,
            )

        def fstring(self, _: None) -> uni.FString:
            """Grammar rule.

            fstring: F_DQ_START fstr_dq_part* F_DQ_END
                    | F_SQ_START fstr_sq_part* F_SQ_END
            """
            fstring_configs = [
                ([Tok.F_DQ_START, Tok.RF_DQ_START], Tok.F_DQ_END),
                ([Tok.F_SQ_START, Tok.RF_SQ_START], Tok.F_SQ_END),
                ([Tok.F_TDQ_START, Tok.RF_TDQ_START], Tok.F_TDQ_END),
                ([Tok.F_TSQ_START, Tok.RF_TSQ_START], Tok.F_TSQ_END),
            ]

            for start_toks, end_tok in fstring_configs:
                if fstr := self._process_fstring(start_toks, end_tok):
                    return fstr

            raise self.ice()

        def _process_fstring(
            self, start_tok: list[Tok], end_tok: Tok
        ) -> uni.FString | None:
            """Process fstring nodes."""
            tok_start = self.match_token(start_tok[0]) or self.match_token(start_tok[1])
            if not tok_start:
                return None
            parts = []
            while part := self.match(uni.String) or self.match(uni.FormattedValue):
                parts.append(part)
            tok_end = self.consume_token(end_tok)
            return uni.FString(
                start=tok_start,
                parts=parts,
                end=tok_end,
                kid=self.flat_cur_nodes,
            )

        def fstr_dq_part(self, _: None) -> uni.Token | uni.FormattedValue:
            """Grammar rule.

            fstr_dq_part: F_TEXT_DQ | D_LBRACE | D_RBRACE | LBRACE expression CONV? (COLON fformat*)? RBRACE
            """
            return self._process_f_expr(Tok.F_TEXT_DQ, self.cur_nodes)

        def fstr_sq_part(self, _: None) -> uni.Token | uni.FormattedValue:
            """Grammar rule.

            fstr_sq_part: F_TEXT_SQ | D_LBRACE | D_RBRACE | LBRACE expression CONV? (COLON fformat*)? RBRACE
            """
            return self._process_f_expr(Tok.F_TEXT_SQ, self.cur_nodes)

        def fstr_tdq_part(self, _: None) -> uni.Token | uni.FormattedValue:
            """Grammar rule.

            fstr_tdq_part: F_TEXT_DQ | D_LBRACE | D_RBRACE | LBRACE expression CONV? (COLON fformat*)? RBRACE
            """
            return self._process_f_expr(Tok.F_TEXT_TDQ, self.cur_nodes)

        def fstr_tsq_part(self, _: None) -> uni.Token | uni.FormattedValue:
            """Grammar rule.

            fstr_sq_part: F_TEXT_SQ | D_LBRACE | D_RBRACE | LBRACE expression CONV? (COLON fformat*)? RBRACE
            """
            return self._process_f_expr(Tok.F_TEXT_TSQ, self.cur_nodes)

        def rfstr_dq_part(self, _: None) -> uni.Token | uni.FormattedValue:
            """Grammar rule.

            fstr_dq_part: F_TEXT_DQ | D_LBRACE | D_RBRACE | LBRACE expression CONV? (COLON fformat*)? RBRACE
            """
            return self._process_f_expr(Tok.RF_TEXT_DQ, self.cur_nodes)

        def rfstr_sq_part(self, _: None) -> uni.Token | uni.FormattedValue:
            """Grammar rule.

            fstr_sq_part: F_TEXT_SQ | D_LBRACE | D_RBRACE | LBRACE expression CONV? (COLON fformat*)? RBRACE
            """
            return self._process_f_expr(Tok.RF_TEXT_SQ, self.cur_nodes)

        def rfstr_tdq_part(self, _: None) -> uni.Token | uni.FormattedValue:
            """Grammar rule.

            fstr_tdq_part: F_TEXT_DQ | D_LBRACE | D_RBRACE | LBRACE expression CONV? (COLON fformat*)? RBRACE
            """
            return self._process_f_expr(Tok.RF_TEXT_TDQ, self.cur_nodes)

        def rfstr_tsq_part(self, _: None) -> uni.Token | uni.FormattedValue:
            """Grammar rule.

            fstr_sq_part: F_TEXT_SQ | D_LBRACE | D_RBRACE | LBRACE expression CONV? (COLON fformat*)? RBRACE
            """
            return self._process_f_expr(Tok.RF_TEXT_TSQ, self.cur_nodes)

        def fformat(self, _: None) -> uni.Token | uni.FormattedValue:
            """Grammar rule.

            fformat: F_FORMAT_TEXT | D_LBRACE | D_RBRACE | LBRACE expression CONV? (COLON fformat*)? RBRACE
            """
            return self._process_f_expr(Tok.F_FORMAT_TEXT, self.cur_nodes)

        def _process_f_expr(
            self, token: Tok, nodes: list[uni.UniNode]
        ) -> uni.Token | uni.FormattedValue:
            """Process fexpression nodes."""
            if (
                tok := self.match_token(token)
                or self.match_token(Tok.D_LBRACE)
                or self.match_token(Tok.D_RBRACE)
            ):
                return tok
            else:
                conversion = -1
                format_spec: uni.String | uni.FString | None = None
                self.consume_token(Tok.LBRACE)
                expr = self.consume(uni.Expr)
                if conv_tok := self.match_token(Tok.CONV):
                    conversion = ord(conv_tok.value[1:])
                if self.match_token(Tok.COLON):
                    parts = []
                    while part := self.match(uni.String) or self.match(
                        uni.FormattedValue
                    ):
                        parts.append(part)
                    if len(parts) == 1 and isinstance(parts[0], uni.String):
                        format_spec = parts[0]
                    elif parts:
                        format_spec = uni.FString(
                            start=None,
                            parts=parts,
                            end=None,
                            kid=parts,
                        )
                self.consume_token(Tok.RBRACE)
                return uni.FormattedValue(
                    format_part=expr,
                    conversion=conversion,
                    format_spec=format_spec,
                    kid=self.cur_nodes,
                )

        def list_val(self, _: None) -> uni.ListVal:
            """Grammar rule.

            list_val: LSQUARE (expr_list COMMA?)? RSQUARE
            """
            lsquare = self.consume_token(Tok.LSQUARE)
            values_node = self.match(list)
            trailing_comma = self.match_token(Tok.COMMA)
            rsquare = self.consume_token(Tok.RSQUARE)
            values = (
                self.extract_from_list(values_node, uni.Expr) if values_node else []
            )
            # Build kid list with all tokens
            kid_list = [lsquare]
            if values_node:
                kid_list.extend(values_node)
            if trailing_comma:
                kid_list.append(trailing_comma)
            kid_list.append(rsquare)
            return uni.ListVal(
                values=values,
                kid=kid_list,
            )

        def tuple_val(self, _: None) -> uni.TupleVal:
            """Grammar rule.

            tuple_val: LPAREN tuple_list? RPAREN
            """
            lparen = self.consume_token(Tok.LPAREN)
            target = self.match(list)
            rparen = self.consume_token(Tok.RPAREN)
            values: list[uni.Expr | uni.KWPair] = (
                self.extract_from_list(target, (uni.Expr, uni.KWPair)) if target else []
            )
            # Build kid list with all tokens
            kid_list = [lparen]
            if target:
                kid_list.extend(target)
            kid_list.append(rparen)
            return uni.TupleVal(
                values=values,
                kid=kid_list,
            )

        def set_val(self, _: None) -> uni.SetVal:
            """Grammar rule.

            set_val: LBRACE expr_list COMMA? RBRACE
            """
            lbrace = self.match_token(Tok.LBRACE)
            expr_list = self.match(list)
            trailing_comma = self.match_token(Tok.COMMA)
            rbrace = self.match_token(Tok.RBRACE)
            values = self.extract_from_list(expr_list, uni.Expr) if expr_list else []
            # Build kid list with all tokens
            kid_list: list[uni.UniNode] = []
            if lbrace:
                kid_list.append(lbrace)
            if expr_list:
                kid_list.extend(expr_list)
            if trailing_comma:
                kid_list.append(trailing_comma)
            if rbrace:
                kid_list.append(rbrace)
            return uni.SetVal(
                values=values,
                kid=kid_list,
            )

        def expr_list(self, kid: list[uni.UniNode]) -> list[uni.UniNode]:
            """Grammar rule.

            expr_list: (expr_list COMMA)? expression
            """
            return self.flat_cur_nodes

        def kw_expr_list(self, kid: list[uni.UniNode]) -> list[uni.UniNode]:
            """Grammar rule.

            kw_expr_list: (kw_expr_list COMMA)? kw_expr
            """
            return self.flat_cur_nodes

        def kw_expr(self, _: None) -> uni.KWPair:
            """Grammar rule.

            kw_expr: named_ref EQ expression | STAR_POW expression
            """
            if self.match_token(Tok.STAR_POW):
                value = self.consume(uni.Expr)
                key = None
            else:
                key = self.consume(uni.Name)
                self.consume_token(Tok.EQ)
                value = self.consume(uni.Expr)
            return uni.KWPair(
                key=key,
                value=value,
                kid=self.cur_nodes,
            )

        def name_list(self, _: None) -> list[uni.UniNode]:
            """Grammar rule.

            name_list: (named_ref COMMA)* named_ref
            """
            return self.flat_cur_nodes

        def tuple_list(self, _: None) -> list[uni.UniNode]:
            """Grammar rule.

            tuple_list: expression COMMA expr_list COMMA kw_expr_list COMMA?
                      | expression COMMA kw_expr_list COMMA?
                      | expression COMMA expr_list COMMA?
                      | expression COMMA
                      | kw_expr_list COMMA?
            """
            return self.flat_cur_nodes

        def dict_val(self, _: None) -> uni.DictVal:
            """Grammar rule.

            dict_val: LBRACE ((kv_pair COMMA)* kv_pair COMMA?)? RBRACE
            """
            lbrace = self.consume_token(Tok.LBRACE)
            kv_pairs: list = []
            kid_list: list[uni.UniNode] = [lbrace]
            while item := self.match(uni.KVPair):
                kv_pairs.append(item)
                kid_list.append(item)
                if comma := self.match_token(Tok.COMMA):
                    kid_list.append(comma)
            rbrace = self.consume_token(Tok.RBRACE)
            kid_list.append(rbrace)
            return uni.DictVal(
                kv_pairs=kv_pairs,
                kid=kid_list,
            )

        def kv_pair(self, _: None) -> uni.KVPair:
            """Grammar rule.

            kv_pair: expression COLON expression | STAR_POW expression
            """
            if star_pow := self.match_token(Tok.STAR_POW):
                value = self.consume(uni.Expr)
                return uni.KVPair(
                    key=None,
                    value=value,
                    kid=[star_pow, value],
                )
            key = self.consume(uni.Expr)
            colon = self.consume_token(Tok.COLON)
            value = self.consume(uni.Expr)
            return uni.KVPair(
                key=key,
                value=value,
                kid=[key, colon, value],
            )

        def list_compr(self, _: None) -> uni.ListCompr:
            """Grammar rule.

            list_compr: LSQUARE expression inner_compr+ RSQUARE
            """
            lsquare = self.consume_token(Tok.LSQUARE)
            out_expr = self.consume(uni.Expr)
            comprs = self.consume_many(uni.InnerCompr)
            rsquare = self.consume_token(Tok.RSQUARE)
            return uni.ListCompr(
                out_expr=out_expr,
                compr=comprs,
                kid=[lsquare, out_expr, *comprs, rsquare],
            )

        def gen_compr(self, _: None) -> uni.GenCompr:
            """Grammar rule.

            gen_compr: LPAREN expression inner_compr+ RPAREN
            """
            lparen = self.consume_token(Tok.LPAREN)
            out_expr = self.consume(uni.Expr)
            comprs = self.consume_many(uni.InnerCompr)
            rparen = self.consume_token(Tok.RPAREN)
            return uni.GenCompr(
                out_expr=out_expr,
                compr=comprs,
                kid=[lparen, out_expr, *comprs, rparen],
            )

        def set_compr(self, _: None) -> uni.SetCompr:
            """Grammar rule.

            set_compr: LBRACE expression inner_compr+ RBRACE
            """
            lbrace = self.consume_token(Tok.LBRACE)
            out_expr = self.consume(uni.Expr)
            comprs = self.consume_many(uni.InnerCompr)
            rbrace = self.consume_token(Tok.RBRACE)
            return uni.SetCompr(
                out_expr=out_expr,
                compr=comprs,
                kid=[lbrace, out_expr, *comprs, rbrace],
            )

        def dict_compr(self, _: None) -> uni.DictCompr:
            """Grammar rule.

            dict_compr: LBRACE kv_pair inner_compr+ RBRACE
            """
            lbrace = self.consume_token(Tok.LBRACE)
            kv_pair = self.consume(uni.KVPair)
            comprs = self.consume_many(uni.InnerCompr)
            rbrace = self.consume_token(Tok.RBRACE)
            return uni.DictCompr(
                kv_pair=kv_pair,
                compr=comprs,
                kid=[lbrace, kv_pair, *comprs, rbrace],
            )

        def inner_compr(self, _: None) -> uni.InnerCompr:
            """Grammar rule.

            inner_compr: KW_ASYNC? KW_FOR atomic_chain KW_IN pipe_call (KW_IF walrus_assign)*
            """
            conditional: list = []
            is_async = bool(self.match_token(Tok.KW_ASYNC))
            self.consume_token(Tok.KW_FOR)
            target = self.consume(uni.Expr)
            self.consume_token(Tok.KW_IN)
            collection = self.consume(uni.Expr)
            while self.match_token(Tok.KW_IF):
                conditional.append(self.consume(uni.Expr))
            return uni.InnerCompr(
                is_async=is_async,
                target=target,
                collection=collection,
                conditional=conditional,
                kid=self.cur_nodes,
            )

        def param_list(self, _: None) -> list[uni.UniNode]:
            """Grammar rule.

            param_list: expr_list    COMMA kw_expr_list COMMA?
                      | kw_expr_list COMMA?
                      | expr_list    COMMA?
            """
            return self.flat_cur_nodes

        def assignment_list(self, _: None) -> list[uni.UniNode]:
            """Grammar rule.

            assignment_list: (assignment | named_ref) (COMMA (assignment | named_ref))* COMMA?
            """

            def name_to_assign(name_consume: uni.NameAtom) -> uni.Assignment:
                return uni.Assignment(
                    target=[name_consume], value=None, type_tag=None, kid=[name_consume]
                )

            # Match first (assignment | named_ref)
            if self.match(uni.Assignment):
                pass
            elif name_consume := self.match(uni.NameAtom):
                self.cur_nodes[self.node_idx - 1] = name_to_assign(name_consume)
            else:
                raise self.ice()

            # Match (COMMA (assignment | named_ref))* COMMA?
            while self.match_token(Tok.COMMA):
                if self.match(uni.Assignment):
                    pass
                elif name_consume := self.match(uni.NameAtom):
                    self.cur_nodes[self.node_idx - 1] = name_to_assign(name_consume)
                else:
                    break  # trailing comma

            return self.flat_cur_nodes

        def type_ref(self, kid: list[uni.UniNode]) -> uni.TypeRef:
            """Grammar rule.

            type_ref: TYPE_OP (named_ref | builtin_type)
            """
            self.consume(uni.Token)
            arch_name = self.consume(uni.NameAtom)
            return uni.TypeRef(
                target=arch_name,
                kid=self.cur_nodes,
            )

        def jsx_element(self, _: None) -> uni.JsxElement:
            """Grammar rule.

            jsx_element: jsx_self_closing
                       | jsx_fragment
                       | jsx_opening_closing
            """
            return self.consume(uni.JsxElement)

        def jsx_self_closing(self, _: None) -> uni.JsxElement:
            """Grammar rule.

            jsx_self_closing: JSX_OPEN_START jsx_element_name jsx_attributes? JSX_SELF_CLOSE
            """
            self.consume_token(Tok.JSX_OPEN_START)
            name = self.consume(uni.JsxElementName)
            # jsx_attributes is optional and returns a list when present
            attrs_list = self.match(
                list
            )  # Will match jsx_attributes which returns a list
            attrs = attrs_list if attrs_list else []
            self.consume_token(Tok.JSX_SELF_CLOSE)

            return uni.JsxElement(
                name=name,
                attributes=attrs,
                children=None,
                is_self_closing=True,
                is_fragment=False,
                kid=self.flat_cur_nodes,
            )

        def jsx_opening_closing(self, _: None) -> uni.JsxElement:
            """Grammar rule.

            jsx_opening_closing: jsx_opening_element jsx_children? jsx_closing_element
            """
            opening = self.consume(uni.JsxElement)  # From jsx_opening_element
            # jsx_children is optional and returns a list when present
            children_list = self.match(
                list
            )  # Will match jsx_children which returns a list
            children = children_list if children_list else []
            self.consume(uni.JsxElement)  # From jsx_closing_element (closing tag)

            # Merge opening and closing into single element
            return uni.JsxElement(
                name=opening.name,
                attributes=opening.attributes,
                children=children if children else None,
                is_self_closing=False,
                is_fragment=False,
                kid=self.flat_cur_nodes,
            )

        def jsx_fragment(self, _: None) -> uni.JsxElement:
            """Grammar rule.

            jsx_fragment: JSX_FRAG_OPEN jsx_children? JSX_FRAG_CLOSE
            """
            self.consume_token(Tok.JSX_FRAG_OPEN)
            # jsx_children is optional and returns a list when present
            children_list = self.match(
                list
            )  # Will match jsx_children which returns a list
            children = children_list if children_list else []
            self.consume_token(Tok.JSX_FRAG_CLOSE)

            return uni.JsxElement(
                name=None,
                attributes=None,
                children=children if children else None,
                is_self_closing=False,
                is_fragment=True,
                kid=self.flat_cur_nodes,
            )

        def jsx_opening_element(self, _: None) -> uni.JsxElement:
            """Grammar rule.

            jsx_opening_element: JSX_OPEN_START jsx_element_name jsx_attributes? JSX_TAG_END
            """
            self.consume_token(Tok.JSX_OPEN_START)
            name = self.consume(uni.JsxElementName)
            # jsx_attributes is optional and returns a list when present
            attrs_list = self.match(
                list
            )  # Will match jsx_attributes which returns a list
            attrs = attrs_list if attrs_list else []
            self.consume_token(Tok.JSX_TAG_END)

            # Return partial element (will be completed in jsx_opening_closing)
            return uni.JsxElement(
                name=name,
                attributes=attrs,
                children=None,
                is_self_closing=False,
                is_fragment=False,
                kid=self.flat_cur_nodes,
            )

        def jsx_closing_element(self, _: None) -> uni.JsxElement:
            """Grammar rule.

            jsx_closing_element: JSX_CLOSE_START jsx_element_name JSX_TAG_END
            """
            self.consume_token(Tok.JSX_CLOSE_START)
            name = self.consume(uni.JsxElementName)
            self.consume_token(Tok.JSX_TAG_END)
            # Return stub element with just closing info
            return uni.JsxElement(
                name=name,
                attributes=None,
                children=None,
                is_self_closing=False,
                is_fragment=False,
                kid=self.cur_nodes,
            )

        def jsx_element_name(self, _: None) -> uni.JsxElementName:
            """Grammar rule.

            jsx_element_name: JSX_NAME (DOT JSX_NAME)*
            """
            parts = [self.consume_token(Tok.JSX_NAME)]
            while self.match_token(Tok.DOT):
                parts.append(self.consume_token(Tok.JSX_NAME))
            return uni.JsxElementName(
                parts=parts,
                kid=self.cur_nodes,
            )

        def jsx_attributes(self, _: None) -> list[uni.JsxAttribute]:
            """Grammar rule.

            jsx_attributes: jsx_attribute+
            """
            return self.consume_many(uni.JsxAttribute)

        def jsx_attribute(self, _: None) -> uni.JsxAttribute:
            """Grammar rule.

            jsx_attribute: jsx_spread_attribute | jsx_normal_attribute
            """
            return self.consume(uni.JsxAttribute)

        def jsx_spread_attribute(self, _: None) -> uni.JsxSpreadAttribute:
            """Grammar rule.

            jsx_spread_attribute: LBRACE ELLIPSIS expression RBRACE
            """
            self.consume_token(Tok.LBRACE)
            self.consume_token(Tok.ELLIPSIS)
            expr = self.consume(uni.Expr)
            self.consume_token(Tok.RBRACE)
            return uni.JsxSpreadAttribute(
                expr=expr,
                kid=self.cur_nodes,
            )

        def jsx_normal_attribute(self, _: None) -> uni.JsxNormalAttribute:
            """Grammar rule.

            jsx_normal_attribute: JSX_NAME (EQ jsx_attr_value)?
            """
            name = self.consume_token(Tok.JSX_NAME)
            value = None
            if self.match_token(Tok.EQ):
                value = self.consume(uni.Expr)
            kids = [*self.cur_nodes]
            # Insert attached tokens (braces) around expressions if present
            if isinstance(value, uni.Expr) and value.attached_tokens is not None:
                kids.insert(kids.index(value) + 1, value.attached_tokens[1])
                kids.insert(kids.index(value), value.attached_tokens[0])
            return uni.JsxNormalAttribute(
                name=name,
                value=value,
                kid=kids,
            )

        def jsx_attr_value(self, _: None) -> uni.String | uni.Expr:
            """Grammar rule.

            jsx_attr_value: STRING | LBRACE expression RBRACE
            """
            if string := self.match(uni.String):
                return string
            lbrace = self.consume_token(Tok.LBRACE)
            expr = self.consume(uni.Expr)
            rbrace = self.consume_token(Tok.RBRACE)
            expr.attached_tokens = [lbrace, rbrace]  # <-- TEMP WORKAROUND
            return expr

        def jsx_children(self, _: None) -> list[uni.JsxChild | uni.JsxElement]:
            """Grammar rule.

            jsx_children: jsx_child+
            """
            # The grammar already produces a list of children
            # Just collect all JsxChild nodes from cur_nodes
            children: list[uni.JsxChild | uni.JsxElement] = []
            while self.node_idx < len(self.cur_nodes):
                cur = self.cur_nodes[self.node_idx]
                if isinstance(cur, (uni.JsxChild, uni.JsxElement)):
                    children.append(cur)
                    self.node_idx += 1
                else:
                    break
            return children

        def jsx_child(self, _: None) -> uni.JsxChild | uni.JsxElement:
            """Grammar rule.

            jsx_child: jsx_element | jsx_expression
            """
            if jsx_elem := self.match(uni.JsxElement):
                return jsx_elem
            return self.consume(uni.JsxChild)

        def jsx_expression(self, _: None) -> uni.JsxExpression:
            """Grammar rule.

            jsx_expression: LBRACE expression RBRACE
            """
            self.consume_token(Tok.LBRACE)
            expr = self.consume(uni.Expr)
            self.consume_token(Tok.RBRACE)
            return uni.JsxExpression(
                expr=expr,
                kid=self.cur_nodes,
            )

        def jsx_text(self, _: None) -> uni.JsxText:
            """Grammar rule.

            jsx_text: JSX_TEXT | jsx_text_keyword
            """
            if text := self.match_token(Tok.JSX_TEXT):
                escaped = text.value.replace('"', '\\"').replace("'", "\\'")
                return uni.JsxText(
                    value=escaped,
                    kid=self.cur_nodes,
                )
            # Handle keywords that can appear as text in JSX content
            text = self.consume(uni.Token)
            return uni.JsxText(
                value=text,
                kid=self.cur_nodes,
            )

        def jsx_text_keyword(self, _: None) -> uni.Token:
            """Grammar rule.

            jsx_text_keyword: KW_TO | KW_AS | KW_FROM | ... (all keywords)

            Keywords that can appear as text in JSX content.
            """
            # This is handled by jsx_text - the Lark parser will match
            # keyword tokens and pass them through jsx_text_keyword rule
            return self.consume(uni.Token)

        def edge_ref_chain(self, _: None) -> uni.EdgeRefTrailer:
            """Grammar rule.

            LSQUARE (KW_NODE| KW_EDGE)? expression? (edge_op_ref (filter_compr | expression)?)+ RSQUARE
            """
            self.consume_token(Tok.LSQUARE)
            is_async = bool(self.match_token(Tok.KW_ASYNC))
            edges_only = bool(self.match_token(Tok.KW_EDGE))
            self.match_token(Tok.KW_NODE)
            valid_chain = []
            if expr := self.match(uni.Expr):
                valid_chain.append(expr)
            valid_chain.extend(self.match_many(uni.Expr))
            self.consume_token(Tok.RSQUARE)
            return uni.EdgeRefTrailer(
                chain=valid_chain,
                edges_only=edges_only,
                is_async=is_async,
                kid=self.cur_nodes,
            )

        def edge_op_ref(self, kid: list[uni.UniNode]) -> uni.EdgeOpRef:
            """Grammar rule.

            edge_op_ref: (edge_any | edge_from | edge_to)
            """
            return self.consume(uni.EdgeOpRef)

        def edge_to(self, _: None) -> uni.EdgeOpRef:
            """Grammar rule.

            edge_to: ARROW_R | ARROW_R_P1 typed_filter_compare_list ARROW_R_P2
            """
            if self.match_token(Tok.ARROW_R):
                fcond = None
            else:
                self.consume_token(Tok.ARROW_R_P1)
                fcond = self.consume(uni.FilterCompr)
                self.consume_token(Tok.ARROW_R_P2)
            return uni.EdgeOpRef(
                filter_cond=fcond, edge_dir=EdgeDir.OUT, kid=self.cur_nodes
            )

        def edge_from(self, _: None) -> uni.EdgeOpRef:
            """Grammar rule.

            edge_from: ARROW_L | ARROW_L_P1 typed_filter_compare_list ARROW_L_P2
            """
            if self.match_token(Tok.ARROW_L):
                fcond = None
            else:
                self.consume_token(Tok.ARROW_L_P1)
                fcond = self.consume(uni.FilterCompr)
                self.consume_token(Tok.ARROW_L_P2)
            return uni.EdgeOpRef(
                filter_cond=fcond, edge_dir=EdgeDir.IN, kid=self.cur_nodes
            )

        def edge_any(self, _: None) -> uni.EdgeOpRef:
            """Grammar rule.

            edge_any: ARROW_L_P1 typed_filter_compare_list ARROW_R_P2
                    | ARROW_BI
            """
            if self.match_token(Tok.ARROW_BI):
                fcond = None
            else:
                self.consume_token(Tok.ARROW_L_P1)
                fcond = self.consume(uni.FilterCompr)
                self.consume_token(Tok.ARROW_R_P2)
            return uni.EdgeOpRef(
                filter_cond=fcond, edge_dir=EdgeDir.ANY, kid=self.cur_nodes
            )

        def connect_op(self, _: None) -> uni.ConnectOp:
            """Grammar rule.

            connect_op: connect_from | connect_to | connect_any
            """
            return self.consume(uni.ConnectOp)

        def disconnect_op(self, kid: list[uni.UniNode]) -> uni.DisconnectOp:
            """Grammar rule.

            disconnect_op: KW_DELETE edge_op_ref
            """
            if isinstance(kid[1], uni.EdgeOpRef):
                return uni.DisconnectOp(
                    edge_spec=kid[1],
                    kid=kid,
                )
            else:
                raise self.ice()

        def connect_to(self, _: None) -> uni.ConnectOp:
            """Grammar rule.

            connect_to: CARROW_R | CARROW_R_P1 expression (COLON kw_expr_list)? CARROW_R_P2
            """
            conn_type: uni.Expr | None = None
            conn_assign_sub: list[uni.UniNode] | None = None
            if self.match_token(Tok.CARROW_R_P1):
                conn_type = self.consume(uni.Expr)
                conn_assign_sub = (
                    self.consume(list) if self.match_token(Tok.COLON) else None
                )
                self.consume_token(Tok.CARROW_R_P2)
            else:
                self.consume_token(Tok.CARROW_R)
            conn_assign = (
                uni.AssignCompr(
                    assigns=self.extract_from_list(conn_assign_sub, uni.KWPair),
                    kid=conn_assign_sub,
                )
                if conn_assign_sub
                else None
            )
            if conn_assign:
                self.cur_nodes[3] = conn_assign
            return uni.ConnectOp(
                conn_type=conn_type,
                conn_assign=conn_assign,
                edge_dir=EdgeDir.OUT,
                kid=self.flat_cur_nodes,
            )

        def connect_from(self, _: None) -> uni.ConnectOp:
            """Grammar rule.

            connect_from: CARROW_L | CARROW_L_P1 expression (COLON kw_expr_list)? CARROW_L_P2
            """
            conn_type: uni.Expr | None = None
            conn_assign_sub: list[uni.UniNode] | None = None
            if self.match_token(Tok.CARROW_L_P1):
                conn_type = self.consume(uni.Expr)
                conn_assign_sub = (
                    self.consume(list) if self.match_token(Tok.COLON) else None
                )
                self.consume_token(Tok.CARROW_L_P2)
            else:
                self.consume_token(Tok.CARROW_L)
            conn_assign = (
                uni.AssignCompr(
                    assigns=self.extract_from_list(conn_assign_sub, uni.KWPair),
                    kid=conn_assign_sub,
                )
                if conn_assign_sub
                else None
            )
            if conn_assign:
                self.cur_nodes[3] = conn_assign
            return uni.ConnectOp(
                conn_type=conn_type,
                conn_assign=conn_assign,
                edge_dir=EdgeDir.IN,
                kid=self.flat_cur_nodes,
            )

        def connect_any(self, _: None) -> uni.ConnectOp:
            """Grammar rule.

            connect_any: CARROW_BI | CARROW_L_P1 expression (COLON kw_expr_list)? CARROW_R_P2
            """
            conn_type: uni.Expr | None = None
            conn_assign_sub: list[uni.UniNode] | None = None
            if self.match_token(Tok.CARROW_L_P1):
                conn_type = self.consume(uni.Expr)
                conn_assign_sub = (
                    self.consume(list) if self.match_token(Tok.COLON) else None
                )
                self.consume_token(Tok.CARROW_R_P2)
            else:
                self.consume_token(Tok.CARROW_BI)
            conn_assign = (
                uni.AssignCompr(
                    assigns=self.extract_from_list(conn_assign_sub, uni.KWPair),
                    kid=conn_assign_sub,
                )
                if conn_assign_sub
                else None
            )
            if conn_assign:
                self.cur_nodes[3] = conn_assign
            return uni.ConnectOp(
                conn_type=conn_type,
                conn_assign=conn_assign,
                edge_dir=EdgeDir.ANY,
                kid=self.flat_cur_nodes,
            )

        def filter_compr(self, _: None) -> uni.FilterCompr:
            """Grammar rule.

            filter_compr: LPAREN NULL_OK filter_compare_list RPAREN
                        | LPAREN TYPE_OP NULL_OK typed_filter_compare_list RPAREN
            """
            kid = self.cur_nodes
            self.consume_token(Tok.LPAREN)
            if self.match_token(Tok.TYPE_OP):
                self.consume_token(Tok.NULL_OK)
                f_type = self.consume(uni.FilterCompr)
                f_type.add_kids_left(kid[:3])
                f_type.add_kids_right(kid[4:])
                self.consume_token(Tok.RPAREN)
                return f_type
            self.consume_token(Tok.NULL_OK)
            compares_list = self.consume(list)
            self.consume_token(Tok.RPAREN)
            return uni.FilterCompr(
                compares=self.extract_from_list(compares_list, uni.CompareExpr),
                f_type=None,
                kid=self.flat_cur_nodes,
            )

        def filter_compare_list(self, _: None) -> list[uni.UniNode]:
            """Grammar rule.

            filter_compare_list: (filter_compare_list COMMA)? filter_compare_item
            """
            return self.flat_cur_nodes

        def typed_filter_compare_list(self, _: None) -> uni.FilterCompr:
            """Grammar rule.

            typed_filter_compare_list: expression (COLON filter_compare_list)?
            """
            compares_list: list[uni.UniNode] | None = None
            expr = self.consume(uni.Expr)
            if self.match_token(Tok.COLON):
                compares_list = self.consume(list)
            return uni.FilterCompr(
                compares=self.extract_from_list(compares_list or [], uni.CompareExpr),
                f_type=expr,
                kid=self.flat_cur_nodes,
            )

        def filter_compare_item(self, _: None) -> uni.CompareExpr:
            """Grammar rule.

            filter_compare_item: name_ref cmp_op expression
            """
            name_ref = self.consume(uni.Name)
            cmp_op = self.consume(uni.Token)
            expr = self.consume(uni.Expr)
            return uni.CompareExpr(
                left=name_ref, ops=[cmp_op], rights=[expr], kid=self.cur_nodes
            )

        def assign_compr(self, _: None) -> uni.AssignCompr:
            """Grammar rule.

            filter_compr: LPAREN EQ kw_expr_list RPAREN
            """
            self.consume_token(Tok.LPAREN)
            self.consume_token(Tok.EQ)
            assigns_sn = self.extract_from_list(self.consume(list), uni.KWPair)
            self.consume_token(Tok.RPAREN)
            return uni.AssignCompr(assigns=assigns_sn, kid=self.flat_cur_nodes)

        def match_stmt(self, _: None) -> uni.MatchStmt:
            """Grammar rule.

            match_stmt: KW_MATCH expression LBRACE match_case_block+ RBRACE
            """
            self.consume_token(Tok.KW_MATCH)
            target = self.consume(uni.Expr)
            self.consume_token(Tok.LBRACE)
            cases = [self.consume(uni.MatchCase)]
            while case := self.match(uni.MatchCase):
                cases.append(case)
            self.consume_token(Tok.RBRACE)
            return uni.MatchStmt(
                target=target,
                cases=cases,
                kid=self.cur_nodes,
            )

        def match_case_block(self, _: None) -> uni.MatchCase:
            """Grammar rule.

            match_case_block: KW_CASE pattern_seq (KW_IF expression)? COLON statement+
            """
            guard: uni.Expr | None = None
            self.consume_token(Tok.KW_CASE)
            pattern = self.consume(uni.MatchPattern)
            if self.match_token(Tok.KW_IF):
                guard = self.consume(uni.Expr)
            self.consume_token(Tok.COLON)
            stmts = [self.consume(uni.CodeBlockStmt)]
            while stmt := self.match(uni.CodeBlockStmt):
                stmts.append(stmt)
            return uni.MatchCase(
                pattern=pattern,
                guard=guard,
                body=stmts,
                kid=self.cur_nodes,
            )

        def switch_stmt(self, _: None) -> uni.SwitchStmt:
            """Grammar rule.

            switch_stmt: KW_SWITCH expression LBRACE switch_case_block+ RBRACE
            """
            self.consume_token(Tok.KW_SWITCH)
            target = self.consume(uni.Expr)
            self.consume_token(Tok.LBRACE)
            cases = [self.consume(uni.SwitchCase)]
            while case := self.match(uni.SwitchCase):
                cases.append(case)
            self.consume_token(Tok.RBRACE)
            return uni.SwitchStmt(
                target=target,
                cases=cases,
                kid=self.cur_nodes,
            )

        def switch_case_block(self, _: None) -> uni.SwitchCase:
            """Grammar rule.

            switch_case_block: (KW_CASE pattern_seq | KW_DEFAULT) COLON statement*
            """
            stmts = []
            if self.match_token(Tok.KW_CASE):
                pattern = self.consume(uni.MatchPattern)
            else:
                self.consume_token(Tok.KW_DEFAULT)
                pattern = None
            self.consume_token(Tok.COLON)
            while stmt := self.match(uni.CodeBlockStmt):
                stmts.append(stmt)
            return uni.SwitchCase(
                pattern=pattern,
                body=stmts,
                kid=self.cur_nodes,
            )

        def pattern_seq(self, _: None) -> uni.MatchPattern:
            """Grammar rule.

            pattern_seq: (or_pattern | as_pattern)
            """
            return self.consume(uni.MatchPattern)

        def or_pattern(self, _: None) -> uni.MatchPattern:
            """Grammar rule.

            or_pattern: (pattern BW_OR)* pattern
            """
            patterns: list = [self.consume(uni.MatchPattern)]
            while self.match_token(Tok.BW_OR):
                patterns.append(self.consume(uni.MatchPattern))
            if len(patterns) == 1:
                return patterns[0]
            return uni.MatchOr(
                patterns=patterns,
                kid=self.cur_nodes,
            )

        def as_pattern(self, _: None) -> uni.MatchPattern:
            """Grammar rule.

            as_pattern: or_pattern KW_AS NAME
            """
            pattern = self.consume(uni.MatchPattern)
            self.consume_token(Tok.KW_AS)
            name = self.consume(uni.NameAtom)
            return uni.MatchAs(
                pattern=pattern,
                name=name,
                kid=self.cur_nodes,
            )

        def pattern(self, kid: list[uni.UniNode]) -> uni.MatchPattern:
            """Grammar rule.

            pattern: literal_pattern
                | capture_pattern
                | sequence_pattern
                | mapping_pattern
                | class_pattern
            """
            return self.consume(uni.MatchPattern)

        def literal_pattern(self, _: None) -> uni.MatchPattern:
            """Grammar rule.

            literal_pattern: (INT | FLOAT | multistring)
            """
            value = self.consume(uni.Expr)
            return uni.MatchValue(
                value=value,
                kid=self.cur_nodes,
            )

        def singleton_pattern(self, _: None) -> uni.MatchPattern:
            """Grammar rule.

            singleton_pattern: (NULL | BOOL)
            """
            value = self.match(uni.Null) or self.consume(uni.Bool)
            return uni.MatchSingleton(
                value=value,
                kid=self.cur_nodes,
            )

        def capture_pattern(self, _: None) -> uni.MatchPattern:
            """Grammar rule.

            capture_pattern: NAME
            """
            name = self.consume(uni.Name)
            if name.sym_name == "_":
                return uni.MatchWild(
                    kid=self.cur_nodes,
                )
            return uni.MatchAs(
                name=name,
                pattern=None,
                kid=self.cur_nodes,
            )

        def sequence_pattern(self, _: None) -> uni.MatchPattern:
            """Grammar rule.

            sequence_pattern: LSQUARE list_inner_pattern (COMMA list_inner_pattern)* RSQUARE
                            | LPAREN list_inner_pattern (COMMA list_inner_pattern)* RPAREN
            """
            self.consume_token(Tok.LSQUARE) or self.consume_token(Tok.LPAREN)
            patterns = [self.consume(uni.MatchPattern)]
            while self.match_token(Tok.COMMA):
                patterns.append(self.consume(uni.MatchPattern))
            self.consume_token(Tok.RSQUARE) or self.consume_token(Tok.RPAREN)
            return uni.MatchSequence(
                values=patterns,
                kid=self.cur_nodes,
            )

        def mapping_pattern(self, _: None) -> uni.MatchMapping:
            """Grammar rule.

            mapping_pattern: LBRACE (dict_inner_pattern (COMMA dict_inner_pattern)*)? RBRACE
            """
            self.consume_token(Tok.LBRACE)
            patterns = [self.match(uni.MatchKVPair) or self.consume(uni.MatchStar)]
            while self.match_token(Tok.COMMA):
                patterns.append(
                    self.match(uni.MatchKVPair) or self.consume(uni.MatchStar)
                )
            self.consume_token(Tok.RBRACE)
            return uni.MatchMapping(
                values=patterns,
                kid=self.cur_nodes,
            )

        def list_inner_pattern(self, _: None) -> uni.MatchPattern:
            """Grammar rule.

            list_inner_pattern: (pattern_seq | STAR_MUL NAME)
            """
            if self.match_token(Tok.STAR_MUL):
                name = self.consume(uni.Name)
                return uni.MatchStar(
                    is_list=True,
                    name=name,
                    kid=self.cur_nodes,
                )
            return self.consume(uni.MatchPattern)

        def dict_inner_pattern(self, _: None) -> uni.MatchKVPair | uni.MatchStar:
            """Grammar rule.

            dict_inner_pattern: (literal_pattern COLON pattern_seq | STAR_POW NAME)
            """
            if self.match_token(Tok.STAR_POW):
                name = self.consume(uni.Name)
                return uni.MatchStar(
                    is_list=False,
                    name=name,
                    kid=self.cur_nodes,
                )
            pattern = self.consume(uni.MatchPattern)
            self.consume_token(Tok.COLON)
            value = self.consume(uni.MatchPattern)
            return uni.MatchKVPair(key=pattern, value=value, kid=self.cur_nodes)

        def attr_pattern(self, _: None) -> uni.MatchValue:
            """Grammar rule.

            attr_pattern: NAME (DOT NAME)+
            """
            name_idx = 0
            cur_element = self.consume(uni.NameAtom)
            name_idx += 1
            trailer: uni.AtomTrailer | None = None
            while dot := self.match_token(Tok.DOT):
                target = trailer if trailer else cur_element
                right = self.consume(uni.NameAtom)
                name_idx += 2
                trailer = uni.AtomTrailer(
                    target=target,
                    right=right,
                    is_attr=True,
                    is_null_ok=False,
                    kid=[target, dot, right],
                )
            name = trailer if trailer else cur_element
            if not isinstance(name, (uni.NameAtom, uni.AtomTrailer)):
                raise TypeError(
                    f"Expected name to be either NameAtom or AtomTrailer, got {type(name)}"
                )
            return uni.MatchValue(
                value=name,
                kid=[name, *self.flat_cur_nodes[name_idx:]],
            )

        def class_pattern(self, _: None) -> uni.MatchArch:
            """Grammar rule.

            class_pattern: NAME (DOT NAME)* LPAREN kw_pattern_list? RPAREN
                        | NAME (DOT NAME)* LPAREN pattern_list (COMMA kw_pattern_list)? RPAREN
            """
            name_idx = 0
            cur_element = self.consume(uni.NameAtom)
            name_idx += 1
            trailer: uni.AtomTrailer | None = None
            while dot := self.match_token(Tok.DOT):
                target = trailer if trailer else cur_element
                right = self.consume(uni.NameAtom)
                name_idx += 2
                trailer = uni.AtomTrailer(
                    target=target,
                    right=right,
                    is_attr=True,
                    is_null_ok=False,
                    kid=[target, dot, right],
                )
            name = trailer if trailer else cur_element
            if not isinstance(name, (uni.NameAtom, uni.AtomTrailer)):
                raise TypeError(
                    f"Expected name to be either NameAtom or AtomTrailer, got {type(name)}"
                )
            self.consume_token(Tok.LPAREN)
            first = self.match(list)
            second: list[uni.UniNode] | None = None
            has_kw = bool(first and any(isinstance(i, uni.MatchKVPair) for i in first))
            if first and not has_kw and self.match_token(Tok.COMMA):
                second = self.consume(list)
            self.consume_token(Tok.RPAREN)
            if has_kw:
                arg = None
                kw_list = first
            else:
                arg = first
                kw_list = second
            return uni.MatchArch(
                name=name,
                arg_patterns=(
                    self.extract_from_list(arg, uni.MatchPattern) if arg else None
                ),
                kw_patterns=(
                    self.extract_from_list(kw_list, uni.MatchKVPair)
                    if kw_list
                    else None
                ),
                kid=[name, *self.flat_cur_nodes[name_idx:]],
            )

        def pattern_list(self, _: None) -> list[uni.UniNode]:
            """Grammar rule.

            pattern_list: (pattern_list COMMA)? pattern_seq
            """
            return self.flat_cur_nodes

        def kw_pattern_list(self, _: None) -> list[uni.UniNode]:
            """Grammar rule.

            kw_pattern_list: (kw_pattern_list COMMA)? named_ref EQ pattern_seq
            """
            new_kid: list[uni.UniNode] = []
            if consume := self.match(list):
                comma = self.consume_token(Tok.COMMA)
                new_kid.extend([*consume, comma])
            name = self.consume(uni.NameAtom)
            eq = self.consume_token(Tok.EQ)
            value = self.consume(uni.MatchPattern)
            new_kid.append(
                uni.MatchKVPair(key=name, value=value, kid=[name, eq, value])
            )
            return new_kid

        def __default_token__(self, token: jl.Token) -> uni.Token:
            """Token handler."""
            ret_type = uni.Token
            if token.type in [Tok.NAME, Tok.KWESC_NAME]:
                ret_type = uni.Name
            if token.type in [
                Tok.KW_INIT,
                Tok.KW_POST_INIT,
                Tok.KW_ROOT,
                Tok.KW_SUPER,
                Tok.KW_SELF,
                Tok.KW_PROPS,
                Tok.KW_HERE,
                Tok.KW_VISITOR,
            ]:
                ret_type = uni.Name
            elif token.type == Tok.SEMI:
                ret_type = uni.Semi
            elif token.type == Tok.NULL:
                ret_type = uni.Null
            elif token.type == Tok.ELLIPSIS:
                ret_type = uni.Ellipsis
            elif token.type == Tok.FLOAT:
                ret_type = uni.Float
            elif token.type in [Tok.INT, Tok.INT, Tok.HEX, Tok.BIN, Tok.OCT]:
                ret_type = uni.Int
            elif token.type in [
                Tok.STRING,
                Tok.D_LBRACE,
                Tok.D_RBRACE,
                Tok.F_TEXT_DQ,
                Tok.F_TEXT_SQ,
                Tok.F_TEXT_TDQ,
                Tok.F_TEXT_TSQ,
                Tok.RF_TEXT_DQ,
                Tok.RF_TEXT_SQ,
                Tok.RF_TEXT_TDQ,
                Tok.RF_TEXT_TSQ,
                Tok.F_FORMAT_TEXT,
            ]:
                ret_type = uni.String
                if token.type == Tok.D_LBRACE:
                    token.value = "{"
                elif token.type == Tok.D_RBRACE:
                    token.value = "}"
            elif token.type == Tok.BOOL:
                ret_type = uni.Bool
            elif token.type == Tok.PYNLINE and isinstance(token.value, str):
                token.value = token.value.replace("::py::", "")

            ret = ret_type(
                orig_src=self.parse_ref.ir_in,
                name=token.type,
                value=token.value[2:] if token.type == Tok.KWESC_NAME else token.value,
                line=token.line if token.line is not None else 0,
                end_line=token.end_line if token.end_line is not None else 0,
                col_start=token.column if token.column is not None else 0,
                col_end=token.end_column if token.end_column is not None else 0,
                pos_start=token.start_pos if token.start_pos is not None else 0,
                pos_end=token.end_pos if token.end_pos is not None else 0,
            )
            if isinstance(ret, uni.Name):
                if token.type == Tok.KWESC_NAME:
                    ret.is_kwesc = True
                # Check if Python-only keywords are used as names
                elif ret.sym_name in PYTHON_ONLY_KEYWORDS:
                    self.parse_ref._log_python_only_keyword_error(ret.sym_name, ret)

            self.terminals.append(ret)
            return ret

        def event_clause(self, _: None) -> uni.EventSignature:
            """Grammar rule.

            event_clause: KW_WITH expression? (KW_EXIT | KW_ENTRY)
            """
            self.consume_token(Tok.KW_WITH)
            type_specs = self.match(uni.Expr)
            event = self.match_token(Tok.KW_EXIT) or self.consume_token(Tok.KW_ENTRY)
            return uni.EventSignature(
                event=event,
                arch_tag_info=type_specs,
                kid=self.cur_nodes,
            )

        def block_tail(self, _: None) -> list[uni.CodeBlockStmt] | uni.Expr:
            """Grammar rule.

            block_tail: code_block | KW_BY expression SEMI
            """
            # Try to match code_block first
            if code_block := self.match(list):
                return code_block

            # Otherwise, it must be KW_BY expression SEMI
            by_token = self.consume_token(Tok.KW_BY)
            func_call = self.consume(uni.Expr)
            semi_token = self.consume_token(Tok.SEMI)

            # Add the tokens to the function call's kid array
            func_call.add_kids_left([by_token])
            func_call.add_kids_right([semi_token])

            return func_call
