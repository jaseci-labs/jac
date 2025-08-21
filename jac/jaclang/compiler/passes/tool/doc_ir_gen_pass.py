"""DocIrGenPass for Jaseci Ast.

This is a pass for generating DocIr for Jac code.
"""

from typing import List, Optional, Sequence

import jaclang.compiler.passes.tool.doc_ir as doc
import jaclang.compiler.unitree as uni
from jaclang.compiler.constant import Tokens as Tok
from jaclang.compiler.passes import UniPass


class DocIRGenPass(UniPass):
    """DocIrGenPass generate DocIr for Jac code."""

    def text(self, text: str) -> doc.Text:
        """Create a Text node."""
        return doc.Text(text)

    def space(self) -> doc.Text:
        """Create a space node."""
        return doc.Text(" ")

    def line(self, hard: bool = False, literal: bool = False) -> doc.Line:
        """Create a Line node."""
        return doc.Line(hard, literal)

    def hard_line(self) -> doc.Line:
        """Create a hard line break."""
        return doc.Line(hard=True)

    def tight_line(self) -> doc.Line:
        """Create a tight line break."""
        return doc.Line(tight=True)

    def literal_line(self) -> doc.Line:
        """Create a literal line break."""
        return doc.Line(literal=True)

    def group(
        self,
        contents: doc.DocType,
        break_contiguous: bool = False,
    ) -> doc.Group:
        """Create a Group node."""
        return doc.Group(contents, break_contiguous)

    def indent(self, contents: doc.DocType) -> doc.Indent:
        """Create an Indent node."""
        return doc.Indent(contents)

    def concat(self, parts: List[doc.DocType]) -> doc.Concat:
        """Create a Concat node."""
        return doc.Concat(parts)

    def if_break(
        self,
        break_contents: doc.DocType,
        flat_contents: doc.DocType,
    ) -> doc.IfBreak:
        """Create an IfBreak node."""
        return doc.IfBreak(break_contents, flat_contents)

    def align(self, contents: doc.DocType, n: Optional[int] = None) -> doc.Align:
        """Create an Align node."""
        return doc.Align(contents, n)

    def join(self, separator: doc.DocType, parts: List[doc.DocType]) -> doc.DocType:
        """Join parts with separator."""
        if not parts:
            return self.concat([])

        result = [parts[0]]
        for part in parts[1:]:
            result.append(separator)
            result.append(part)

        return self.concat(result)

    def is_one_line(self, node: uni.UniNode) -> bool:
        """Check if the node is a one line node."""
        kid = [i for i in node.kid if not isinstance(i, uni.CommentToken)]
        return bool(kid) and kid[0].loc.first_line == kid[-1].loc.last_line

    def has_gap(self, prev_kid: uni.UniNode, curr_kid: uni.UniNode) -> bool:
        """Check if there is a gap between the previous and current node."""
        return prev_kid.loc.last_line + 1 < curr_kid.loc.first_line

    def is_within(self, kid_node: uni.UniNode, block: Sequence[uni.UniNode]) -> bool:
        """Check if kid node is within the block."""
        if not block:
            return False

        start, end, kid = block[0].loc, block[-1].loc, kid_node.loc

        first = start.first_line < kid.first_line or (
            start.first_line == kid.first_line and start.col_start <= kid.col_start
        )

        last = end.last_line > kid.last_line or (
            end.last_line == kid.last_line and end.col_end >= kid.col_end
        )

        return first and last

    def exit_module(self, node: uni.Module) -> None:
        """Exit module."""
        parts: list[doc.DocType] = []
        prev_kid = None
        first_kid = True
        for i in node.kid:
            if (isinstance(i, uni.Import) and isinstance(prev_kid, uni.Import)) or (
                isinstance(i, uni.GlobalVars)
                and isinstance(prev_kid, uni.GlobalVars)
                or prev_kid == node.doc
            ):
                if prev_kid and self.has_gap(prev_kid, i):
                    parts.append(self.hard_line())
                parts.append(i.gen.doc_ir)
            else:
                if not first_kid and not (
                    prev_kid
                    and self.is_one_line(prev_kid)
                    and not self.has_gap(prev_kid, i)
                ):
                    parts.append(self.hard_line())
                    parts.append(self.hard_line())
                parts.append(i.gen.doc_ir)
            parts.append(self.hard_line())
            prev_kid = i
            first_kid = False
        node.gen.doc_ir = self.concat(parts)

    def exit_import(self, node: uni.Import) -> None:
        """Exit import node."""
        parts: list[doc.DocType] = []
        for i in node.kid:
            if isinstance(i, uni.Token) and i.name == Tok.COMMA:
                parts.pop()
                parts.append(i.gen.doc_ir)
                parts.append(self.space())
            elif isinstance(i, uni.Token) and i.name == Tok.SEMI:
                parts.pop()
                parts.append(i.gen.doc_ir)
            elif isinstance(i, uni.Token) and i.name == Tok.RBRACE:
                parts.append(i.gen.doc_ir)
            else:
                parts.append(i.gen.doc_ir)
                parts.append(self.space())
        node.gen.doc_ir = self.group(self.concat(parts))

    def exit_module_item(self, node: uni.ModuleItem) -> None:
        """Generate DocIR for module items."""
        parts: list[doc.DocType] = []
        for i in node.kid:
            if isinstance(i, uni.Token) and i.name == Tok.KW_AS:
                parts.append(self.space())
                parts.append(i.gen.doc_ir)
                parts.append(self.space())
            else:
                parts.append(i.gen.doc_ir)
        node.gen.doc_ir = self.concat(parts)

    def exit_module_path(self, node: uni.ModulePath) -> None:
        """Generate DocIR for module paths."""
        parts: list[doc.DocType] = []
        for i in node.kid:
            if isinstance(i, uni.Token) and i.name == Tok.KW_AS:
                parts.append(self.space())
                parts.append(i.gen.doc_ir)
                parts.append(self.space())
            else:
                parts.append(i.gen.doc_ir)
        node.gen.doc_ir = self.concat(parts)

    def exit_archetype(self, node: uni.Archetype) -> None:
        """Generate DocIR for archetypes."""
        parts: list[doc.DocType] = []
        body_parts: list[doc.DocType] = []
        prev_item = None
        in_body = False
        for i in node.kid:
            if (node.doc and i is node.doc) or (
                node.decorators and i in node.decorators
            ):
                parts.append(i.gen.doc_ir)
                parts.append(self.hard_line())
            elif i == node.name:
                parts.append(i.gen.doc_ir)
                parts.append(self.space())
            elif isinstance(i, uni.Token) and i.name == Tok.LBRACE:
                parts.append(i.gen.doc_ir)
            elif isinstance(i, uni.Token) and i.name == Tok.LPAREN:
                parts.pop()
                parts.append(i.gen.doc_ir)
            elif isinstance(i, uni.Token) and i.name == Tok.RPAREN:
                parts.pop()
                parts.append(i.gen.doc_ir)
                parts.append(self.space())
            elif isinstance(node.body, Sequence) and i in node.body:
                if not in_body:
                    body_parts.append(self.hard_line())
                if (prev_item and type(prev_item) is not type(i)) or (
                    prev_item and not self.is_one_line(prev_item)
                ):
                    body_parts.append(self.hard_line())
                body_parts.append(i.gen.doc_ir)
                body_parts.append(self.hard_line())
                prev_item = i
                in_body = True
            elif in_body:
                in_body = False
                body_parts.pop()
                parts.append(self.indent(self.concat(body_parts)))
                parts.append(self.hard_line())
                parts.append(i.gen.doc_ir)
                parts.append(self.space())
            elif isinstance(i, uni.Token) and i.name == Tok.SEMI:
                parts.pop()
                parts.append(i.gen.doc_ir)
                parts.append(self.space())
            else:
                parts.append(i.gen.doc_ir)
                parts.append(self.space())

        node.gen.doc_ir = self.group(self.concat(parts))

    def exit_ability(self, node: uni.Ability) -> None:
        """Generate DocIR for abilities."""
        parts: list[doc.DocType] = []
        body_parts: list[doc.DocType] = []
        in_body = False
        for i in node.kid:
            if i == node.doc or (node.decorators and i in node.decorators):
                parts.append(i.gen.doc_ir)
                parts.append(self.hard_line())
            elif i == node.name_ref:
                parts.append(i.gen.doc_ir)
                if not isinstance(node.signature, uni.FuncSignature):
                    parts.append(self.space())
            elif isinstance(node.body, Sequence) and i in node.body:
                if not in_body:
                    parts.pop()
                    body_parts.append(self.hard_line())
                body_parts.append(i.gen.doc_ir)
                body_parts.append(self.hard_line())
                in_body = True
            elif in_body:
                in_body = False
                body_parts.pop()
                parts.append(self.indent(self.concat(body_parts)))
                parts.append(self.hard_line())
                parts.append(i.gen.doc_ir)
                parts.append(self.space())
            elif isinstance(i, uni.Token) and i.name == Tok.SEMI:
                parts.pop()
                parts.append(i.gen.doc_ir)
                parts.append(self.space())
            else:
                parts.append(i.gen.doc_ir)
                parts.append(self.space())
        node.gen.doc_ir = self.group(self.concat(parts))

    def exit_func_signature(self, node: uni.FuncSignature) -> None:
        """Generate DocIR for function signatures."""
        parts: list[doc.DocType] = []
        indent_parts: list[doc.DocType] = []
        in_params = False
        has_parens = False
        for i in node.kid:
            if isinstance(i, uni.Token) and i.name == Tok.LPAREN and node.params:
                in_params = True
                parts.append(i.gen.doc_ir)
            elif isinstance(i, uni.Token) and i.name == Tok.RPAREN and node.params:
                in_params = False
                has_parens = True
                parts.append(
                    self.indent(self.concat([self.tight_line(), *indent_parts]))
                )
                parts.append(self.tight_line())
                parts.append(i.gen.doc_ir)
                parts.append(self.space())
            elif isinstance(i, uni.Token) and i.name == Tok.RPAREN:
                parts.pop()
                parts.append(i.gen.doc_ir)
                parts.append(self.space())
            elif in_params:
                if isinstance(i, uni.Token) and i.name == Tok.COMMA:
                    indent_parts.append(i.gen.doc_ir)
                    indent_parts.append(self.line())
                else:
                    indent_parts.append(i.gen.doc_ir)
            else:
                if (
                    isinstance(i, uni.Token)
                    and i.name == Tok.RETURN_HINT
                    and not has_parens
                ):
                    parts.append(self.space())
                parts.append(i.gen.doc_ir)
                parts.append(self.space())
        parts.pop()
        node.gen.doc_ir = self.group(self.concat(parts))

    def exit_param_var(self, node: uni.ParamVar) -> None:
        """Generate DocIR for parameter variables."""
        parts: list[doc.DocType] = []
        for i in node.kid:
            if isinstance(i, uni.Token) and i.name == Tok.EQ:
                parts.append(self.space())
                parts.append(i.gen.doc_ir)
                parts.append(self.space())
            else:
                parts.append(i.gen.doc_ir)
        node.gen.doc_ir = self.group(self.concat(parts))

    def exit_type_ref(self, node: uni.TypeRef) -> None:
        """Generate DocIR for type references."""
        parts: list[doc.DocType] = []
        for i in node.kid:
            parts.append(i.gen.doc_ir)
        node.gen.doc_ir = self.group(self.concat(parts))

    def exit_assignment(self, node: uni.Assignment) -> None:
        """Generate DocIR for assignments."""
        lhs_parts: list[doc.DocType] = []
        rhs_parts: list[doc.DocType] = []
        eq_tok: Optional[doc.DocType] = None
        seen_eq = False

        for i in node.kid:
            if isinstance(i, uni.Token) and i.name == Tok.KW_LET:
                lhs_parts.append(i.gen.doc_ir)
                lhs_parts.append(self.space())
            elif isinstance(i, uni.Token) and i.name == Tok.EQ and not seen_eq:
                eq_tok = i.gen.doc_ir
                seen_eq = True
            elif seen_eq:
                rhs_parts.append(i.gen.doc_ir)
            else:
                if i == node.aug_op:
                    lhs_parts.append(self.space())
                lhs_parts.append(i.gen.doc_ir)
                if i == node.aug_op:
                    lhs_parts.append(self.space())

        if eq_tok is not None:
            rhs_concat = self.concat(rhs_parts)
            node.gen.doc_ir = self.group(
                self.concat(
                    [
                        *lhs_parts,
                        self.space(),
                        eq_tok,
                        self.indent(self.concat([self.line(), rhs_concat])),
                    ]
                )
            )
        else:
            node.gen.doc_ir = self.group(self.concat(lhs_parts + rhs_parts))

    def exit_if_stmt(self, node: uni.IfStmt) -> None:
        """Generate DocIR for if statements."""
        parts: list[doc.DocType] = []
        body_parts: list[doc.DocType] = [self.hard_line()]
        for i in node.kid:
            if isinstance(node.body, Sequence) and self.is_within(i, node.body):
                if i == node.body[0]:
                    parts.append(self.indent(self.concat(body_parts)))
                    parts.append(self.hard_line())
                body_parts.append(i.gen.doc_ir)
                body_parts.append(self.hard_line())
            elif isinstance(i, uni.Token) and i.name == Tok.SEMI:
                parts.pop()
                parts.append(i.gen.doc_ir)
                parts.append(self.space())
            else:
                parts.append(i.gen.doc_ir)
                parts.append(self.space())
        parts.pop()
        body_parts.pop()
        node.gen.doc_ir = self.group(self.concat(parts))

    def exit_else_if(self, node: uni.ElseIf) -> None:
        """Generate DocIR for else if statements."""
        parts: list[doc.DocType] = []
        body_parts: list[doc.DocType] = [self.hard_line()]
        for i in node.kid:
            if isinstance(node.body, Sequence) and self.is_within(i, node.body):
                if i == node.body[0]:
                    parts.append(self.indent(self.concat(body_parts)))
                    parts.append(self.hard_line())
                body_parts.append(i.gen.doc_ir)
                body_parts.append(self.hard_line())
            elif isinstance(i, uni.Token) and i.name == Tok.SEMI:
                parts.pop()
                parts.append(i.gen.doc_ir)
                parts.append(self.space())
            else:
                parts.append(i.gen.doc_ir)
                parts.append(self.space())
        body_parts.pop()
        node.gen.doc_ir = self.group(self.concat(parts))

    def exit_else_stmt(self, node: uni.ElseStmt) -> None:
        """Generate DocIR for else statements."""
        parts: list[doc.DocType] = []
        body_parts: list[doc.DocType] = [self.hard_line()]
        for i in node.kid:
            if isinstance(node.body, Sequence) and self.is_within(i, node.body):
                if i == node.body[0]:
                    parts.append(self.indent(self.concat(body_parts)))
                    parts.append(self.hard_line())
                body_parts.append(i.gen.doc_ir)
                body_parts.append(self.hard_line())
            elif isinstance(i, uni.Token) and i.name == Tok.SEMI:
                parts.pop()
                parts.append(i.gen.doc_ir)
                parts.append(self.space())
            else:
                parts.append(i.gen.doc_ir)
                parts.append(self.space())
        body_parts.pop()
        node.gen.doc_ir = self.group(self.concat(parts))

    def exit_binary_expr(self, node: uni.BinaryExpr) -> None:
        """Generate DocIR for binary expressions."""
        parts: list[doc.DocType] = []
        for i in node.kid:
            parts.append(i.gen.doc_ir)
            parts.append(self.space())
        parts.pop()
        node.gen.doc_ir = self.group(self.concat(parts))

    def exit_expr_stmt(self, node: uni.ExprStmt) -> None:
        """Generate DocIR for expression statements."""
        parts: list[doc.DocType] = []
        for i in node.kid:
            parts.append(i.gen.doc_ir)
        node.gen.doc_ir = self.group(self.concat(parts))

    def exit_concurrent_expr(self, node: uni.ConcurrentExpr) -> None:
        """Generate DocIR for concurrent expressions."""
        parts: list[doc.DocType] = []
        for i in node.kid:
            parts.append(i.gen.doc_ir)
            parts.append(self.space())
        node.gen.doc_ir = self.group(self.concat(parts))

    def exit_return_stmt(self, node: uni.ReturnStmt) -> None:
        """Generate DocIR for return statements."""
        parts: list[doc.DocType] = []
        for i in node.kid:
            if isinstance(i, uni.Token) and i.name == Tok.SEMI:
                parts.pop()
                parts.append(i.gen.doc_ir)
            else:
                parts.append(i.gen.doc_ir)
            parts.append(self.space())
        node.gen.doc_ir = self.group(self.concat(parts))

    def exit_func_call(self, node: uni.FuncCall) -> None:
        """Generate DocIR for function calls."""
        parts: list[doc.DocType] = []
        indent_parts: list[doc.DocType] = []
        in_params = False
        for i in node.kid:
            if isinstance(i, uni.Token) and i.name == Tok.LPAREN and node.params:
                in_params = True
                parts.append(i.gen.doc_ir)
            elif isinstance(i, uni.Token) and i.name == Tok.RPAREN and node.params:
                in_params = False
                parts.append(
                    self.indent(self.concat([self.tight_line(), *indent_parts]))
                )
                parts.append(self.tight_line())
                parts.append(i.gen.doc_ir)
            elif in_params:
                if isinstance(i, uni.Token) and i.name == Tok.COMMA:
                    indent_parts.append(i.gen.doc_ir)
                    indent_parts.append(self.line())
                else:
                    indent_parts.append(i.gen.doc_ir)
            else:
                parts.append(i.gen.doc_ir)
                if isinstance(i, uni.Token) and i.name == Tok.KW_BY:
                    parts.append(self.space())
        node.gen.doc_ir = self.group(self.concat(parts))

    def exit_atom_trailer(self, node: uni.AtomTrailer) -> None:
        """Generate DocIR for atom trailers."""
        parts: list[doc.DocType] = []
        for i in node.kid:
            parts.append(i.gen.doc_ir)
        node.gen.doc_ir = self.group(self.concat(parts))

    def exit_list_val(self, node: uni.ListVal) -> None:
        """Generate DocIR for list values."""
        parts: list[doc.DocType] = []
        for i in node.kid:
            if isinstance(i, uni.Token) and i.name == Tok.COMMA:
                parts.append(i.gen.doc_ir)
                parts.append(self.space())
            else:
                parts.append(i.gen.doc_ir)
        not_broke = self.concat(parts)
        parts = []
        for i in node.kid:
            if isinstance(i, uni.Token) and i.name == Tok.COMMA:
                parts.append(i.gen.doc_ir)
                parts.append(self.hard_line())
            elif isinstance(i, uni.Token) and i.name == Tok.LSQUARE:
                parts.append(self.hard_line())
                parts.append(i.gen.doc_ir)
            else:
                parts.append(i.gen.doc_ir)
        broke = self.concat(parts)
        node.gen.doc_ir = self.group(self.if_break(broke, not_broke))

    def exit_dict_val(self, node: uni.DictVal) -> None:
        """Generate DocIR for dictionary values."""
        parts: list[doc.DocType] = []
        for i in node.kid:
            if isinstance(i, uni.Token) and i.name == Tok.LBRACE:
                parts.append(self.tight_line())
                parts.append(i.gen.doc_ir)
            elif isinstance(i, uni.Token) and i.name == Tok.RBRACE:
                parts.append(i.gen.doc_ir)
            else:
                parts.append(i.gen.doc_ir)
                parts.append(self.space())
        node.gen.doc_ir = self.group(self.concat(parts))

    def exit_k_v_pair(self, node: uni.KVPair) -> None:
        """Generate DocIR for key-value pairs."""
        parts: list[doc.DocType] = []
        for i in node.kid:
            parts.append(i.gen.doc_ir)
            parts.append(self.space())
        parts.pop()
        node.gen.doc_ir = self.group(self.concat(parts))

    def exit_has_var(self, node: uni.HasVar) -> None:
        """Generate DocIR for has variable declarations."""
        parts: list[doc.DocType] = []
        for i in node.kid:
            if isinstance(i, uni.Token) and i.name == Tok.EQ:
                parts.append(self.space())
                parts.append(i.gen.doc_ir)
                parts.append(self.space())
            elif isinstance(i, uni.Token) and i.name in [Tok.KW_BY, Tok.KW_POST_INIT]:
                parts.append(self.space())
                parts.append(i.gen.doc_ir)
            else:
                parts.append(i.gen.doc_ir)
        # parts.pop()
        node.gen.doc_ir = self.group(self.concat(parts))

    def exit_arch_has(self, node: uni.ArchHas) -> None:
        """Generate DocIR for architecture has declarations."""
        parts: list[doc.DocType] = []
        for i in node.kid:
            if i == node.doc:
                parts.append(i.gen.doc_ir)
                parts.append(self.hard_line())
            elif isinstance(i, uni.Token) and i.name == Tok.SEMI:
                parts.pop()
                parts.append(i.gen.doc_ir)
            elif isinstance(i, uni.Token) and i.name == Tok.COMMA:
                parts.pop()
                parts.append(i.gen.doc_ir)
                parts.append(self.indent(self.hard_line()))
            else:
                parts.append(i.gen.doc_ir)
                parts.append(self.space())
        node.gen.doc_ir = self.group(self.concat(parts))

    def exit_while_stmt(self, node: uni.WhileStmt) -> None:
        """Generate DocIR for while statements."""
        parts: list[doc.DocType] = []
        body_parts: list[doc.DocType] = [self.hard_line()]
        for i in node.kid:
            if isinstance(node.body, Sequence) and self.is_within(i, node.body):
                if i == node.body[0]:
                    parts.append(self.indent(self.concat(body_parts)))
                    parts.append(self.hard_line())
                body_parts.append(i.gen.doc_ir)
                body_parts.append(self.hard_line())
            else:
                parts.append(i.gen.doc_ir)
                parts.append(self.space())
        parts.pop()
        body_parts.pop()
        node.gen.doc_ir = self.group(self.concat(parts))

    def exit_in_for_stmt(self, node: uni.InForStmt) -> None:
        """Generate DocIR for for-in statements."""
        parts: list[doc.DocType] = []
        body_parts: list[doc.DocType] = [self.hard_line()]
        for i in node.kid:
            if isinstance(node.body, Sequence) and self.is_within(i, node.body):
                if i == node.body[0]:
                    parts.append(self.indent(self.concat(body_parts)))
                    parts.append(self.hard_line())
                body_parts.append(i.gen.doc_ir)
                body_parts.append(self.hard_line())
            else:
                parts.append(i.gen.doc_ir)
                parts.append(self.space())
        parts.pop()
        body_parts.pop()
        node.gen.doc_ir = self.group(self.concat(parts))

    def exit_iter_for_stmt(self, node: uni.IterForStmt) -> None:
        """Generate DocIR for iterative for statements."""
        parts: list[doc.DocType] = []
        body_parts: list[doc.DocType] = [self.hard_line()]
        for i in node.kid:
            if isinstance(node.body, Sequence) and self.is_within(i, node.body):
                if i == node.body[0]:
                    parts.append(self.indent(self.concat(body_parts)))
                    parts.append(self.hard_line())
                body_parts.append(i.gen.doc_ir)
                body_parts.append(self.hard_line())
            else:
                parts.append(i.gen.doc_ir)
                parts.append(self.space())
        parts.pop()
        body_parts.pop()
        node.gen.doc_ir = self.group(self.concat(parts))

    def exit_try_stmt(self, node: uni.TryStmt) -> None:
        """Generate DocIR for try statements."""
        parts: list[doc.DocType] = []
        body_parts: list[doc.DocType] = [self.hard_line()]
        for i in node.kid:
            if isinstance(node.body, Sequence) and self.is_within(i, node.body):
                if i == node.body[0]:
                    parts.append(self.indent(self.concat(body_parts)))
                    parts.append(self.hard_line())
                body_parts.append(i.gen.doc_ir)
                body_parts.append(self.hard_line())
            else:
                parts.append(i.gen.doc_ir)
                parts.append(self.space())
        parts.pop()
        body_parts.pop()
        node.gen.doc_ir = self.group(self.concat(parts))

    def exit_except(self, node: uni.Except) -> None:
        """Generate DocIR for except clauses."""
        parts: list[doc.DocType] = []
        body_parts: list[doc.DocType] = [self.hard_line()]
        for i in node.kid:
            if isinstance(node.body, Sequence) and self.is_within(i, node.body):
                if i == node.body[0]:
                    parts.append(self.indent(self.concat(body_parts)))
                    parts.append(self.hard_line())
                body_parts.append(i.gen.doc_ir)
                body_parts.append(self.hard_line())
            else:
                parts.append(i.gen.doc_ir)
                parts.append(self.space())
        parts.pop()
        body_parts.pop()
        node.gen.doc_ir = self.group(self.concat(parts))

    def exit_finally_stmt(self, node: uni.FinallyStmt) -> None:
        """Generate DocIR for finally statements."""
        parts: list[doc.DocType] = []
        body_parts: list[doc.DocType] = [self.hard_line()]
        for i in node.kid:
            if isinstance(node.body, Sequence) and self.is_within(i, node.body):
                if i == node.body[0]:
                    parts.append(self.indent(self.concat(body_parts)))
                    parts.append(self.hard_line())
                body_parts.append(i.gen.doc_ir)
                body_parts.append(self.hard_line())
            else:
                parts.append(i.gen.doc_ir)
                parts.append(self.space())
        parts.pop()
        body_parts.pop()
        node.gen.doc_ir = self.group(self.concat(parts))

    def exit_tuple_val(self, node: uni.TupleVal) -> None:
        """Generate DocIR for tuple values."""
        parts: list[doc.DocType] = []
        for i in node.kid:
            if isinstance(i, uni.Token) and i.name == Tok.COMMA:
                parts.append(i.gen.doc_ir)
                parts.append(self.space())
            else:
                parts.append(i.gen.doc_ir)
        not_broke = self.concat(parts)
        parts = []
        for i in node.kid:
            if isinstance(i, uni.Token) and i.name == Tok.COMMA:
                parts.append(i.gen.doc_ir)
                parts.append(self.hard_line())
            elif isinstance(i, uni.Token) and i.name == Tok.LPAREN:
                parts.append(self.hard_line())
                parts.append(i.gen.doc_ir)
            else:
                parts.append(i.gen.doc_ir)
        broke = self.concat(parts)
        node.gen.doc_ir = self.group(self.if_break(broke, not_broke))

    def exit_multi_string(self, node: uni.MultiString) -> None:
        """Generate DocIR for multiline strings."""
        parts: list[doc.DocType] = []
        for i in node.kid:
            parts.append(i.gen.doc_ir)
        node.gen.doc_ir = self.group(self.concat(parts))

    def exit_set_val(self, node: uni.SetVal) -> None:
        """Generate DocIR for set values."""
        parts: list[doc.DocType] = []
        for i in node.kid:
            parts.append(i.gen.doc_ir)

        node.gen.doc_ir = self.group(self.concat(parts))

    def exit_with_stmt(self, node: uni.WithStmt) -> None:
        """Generate DocIR for with statements."""
        parts: list[doc.DocType] = []
        body_parts: list[doc.DocType] = [self.hard_line()]
        for i in node.kid:
            if isinstance(node.body, Sequence) and self.is_within(i, node.body):
                if i == node.body[0]:
                    parts.append(self.indent(self.concat(body_parts)))
                    parts.append(self.hard_line())
                body_parts.append(i.gen.doc_ir)
                body_parts.append(self.hard_line())
            elif isinstance(i, uni.Token) and i.name == Tok.COMMA:
                parts.pop()
                parts.append(i.gen.doc_ir)
                parts.append(self.space())
            else:
                parts.append(i.gen.doc_ir)
                parts.append(self.space())
        parts.pop()
        body_parts.pop()
        node.gen.doc_ir = self.group(self.concat(parts))

    def exit_list_compr(self, node: uni.ListCompr) -> None:
        """Generate DocIR for list comprehensions."""
        parts: list[doc.DocType] = []
        for i in node.kid:
            parts.append(i.gen.doc_ir)
            parts.append(self.space())
        parts.pop()
        node.gen.doc_ir = self.group(self.concat(parts))

    def exit_inner_compr(self, node: uni.InnerCompr) -> None:
        """Generate DocIR for inner comprehension clauses."""
        parts: list[doc.DocType] = []
        for i in node.kid:
            parts.append(i.gen.doc_ir)
            parts.append(self.space())
        parts.pop()
        node.gen.doc_ir = self.group(self.concat(parts))

    def exit_f_string(self, node: uni.FString) -> None:
        """Generate DocIR for formatted strings."""
        parts: list[doc.DocType] = []
        for i in node.kid:
            parts.append(i.gen.doc_ir)
        node.gen.doc_ir = self.group(self.concat(parts))

    def exit_if_else_expr(self, node: uni.IfElseExpr) -> None:
        """Generate DocIR for conditional expressions."""
        parts: list[doc.DocType] = []

        for i in node.kid:
            if isinstance(i, uni.Expr):
                parts.append(i.gen.doc_ir)
                parts.append(self.line())  # Potential break
            elif isinstance(i, uni.Token):
                parts.append(i.gen.doc_ir)
                parts.append(self.space())
            else:
                parts.append(i.gen.doc_ir)
                parts.append(self.space())
        parts.pop()
        node.gen.doc_ir = self.group(self.concat(parts))

    def exit_bool_expr(self, node: uni.BoolExpr) -> None:
        """Generate DocIR for boolean expressions (and/or)."""
        parts: list[doc.DocType] = []
        for i in node.kid:
            if isinstance(i, uni.Token):
                parts.append(i.gen.doc_ir)
                parts.append(self.space())
            else:
                parts.append(i.gen.doc_ir)
                parts.append(self.line())  # Potential break
        node.gen.doc_ir = self.group(self.concat(parts))

    def exit_unary_expr(self, node: uni.UnaryExpr) -> None:
        """Generate DocIR for unary expressions."""
        parts: list[doc.DocType] = []
        for i in node.kid:
            if (
                isinstance(i, uni.Token) and i.value in ["-", "~", "+", "*"]
            ) or isinstance(i, uni.Expr):
                parts.append(i.gen.doc_ir)
            else:
                parts.append(i.gen.doc_ir)
                parts.append(self.space())

        node.gen.doc_ir = self.group(self.concat(parts))

    def exit_lambda_expr(self, node: uni.LambdaExpr) -> None:
        """Generate DocIR for lambda expressions."""
        parts: list[doc.DocType] = []
        for i in node.kid:
            if isinstance(i, uni.Token):
                parts.append(i.gen.doc_ir)
                parts.append(self.space())
            elif isinstance(i, uni.Expr):
                parts.append(
                    self.if_break(
                        self.indent(self.concat([self.line(), i.gen.doc_ir])),
                        i.gen.doc_ir,
                    )
                )
            elif isinstance(i, uni.FuncSignature):
                if isinstance(i.gen.doc_ir, doc.Text) and i.gen.doc_ir.text == "()":
                    parts.append(i.gen.doc_ir)
                else:
                    parts.append(self.space())
                    parts.append(i.gen.doc_ir)
            else:
                parts.append(i.gen.doc_ir)

        node.gen.doc_ir = self.group(self.concat(parts))

    def exit_edge_ref_trailer(self, node: uni.EdgeRefTrailer) -> None:
        """Generate DocIR for edge reference trailers."""
        parts: list[doc.DocType] = []
        for i in node.kid:
            if isinstance(i, uni.Token) and i.name in [Tok.KW_EDGE, Tok.KW_NODE]:
                parts.append(i.gen.doc_ir)
                parts.append(self.space())
            else:
                parts.append(i.gen.doc_ir)
        node.gen.doc_ir = self.group(self.concat(parts))

    def exit_edge_op_ref(self, node: uni.EdgeOpRef) -> None:
        """Generate DocIR for edge operation references."""
        parts: list[doc.DocType] = []
        for i in node.kid:
            parts.append(i.gen.doc_ir)
        node.gen.doc_ir = self.group(self.concat(parts))

    def exit_index_slice(self, node: uni.IndexSlice) -> None:
        """Generate DocIR for index slices."""
        parts: list[doc.DocType] = []
        for i in node.kid:
            parts.append(i.gen.doc_ir)
            parts.append(self.space())
        parts.pop()
        node.gen.doc_ir = self.group(self.concat(parts))

    def exit_gen_compr(self, node: uni.GenCompr) -> None:
        """Generate DocIR for generator comprehensions."""
        parts: list[doc.DocType] = []
        for i in node.kid:
            parts.append(i.gen.doc_ir)
            parts.append(self.space())
        parts.pop()
        node.gen.doc_ir = self.group(self.concat(parts))

    def exit_set_compr(self, node: uni.SetCompr) -> None:
        """Generate DocIR for set comprehensions."""
        parts: list[doc.DocType] = []
        for i in node.kid:
            parts.append(i.gen.doc_ir)
            parts.append(self.space())
        parts.pop()
        node.gen.doc_ir = self.group(self.concat(parts))

    def exit_dict_compr(self, node: uni.DictCompr) -> None:
        """Generate DocIR for dictionary comprehensions."""
        parts: list[doc.DocType] = []
        for i in node.kid:
            if isinstance(i, uni.Token) and i.name in [Tok.STAR_POW, Tok.STAR_MUL]:
                parts.append(i.gen.doc_ir)
            else:
                parts.append(i.gen.doc_ir)
                parts.append(self.space())
        parts.pop()
        node.gen.doc_ir = self.group(self.concat(parts))

    def exit_k_w_pair(self, node: uni.KWPair) -> None:
        """Generate DocIR for keyword arguments."""
        parts: list[doc.DocType] = []
        for i in node.kid:
            parts.append(i.gen.doc_ir)
        node.gen.doc_ir = self.group(self.concat(parts))

    def exit_await_expr(self, node: uni.AwaitExpr) -> None:
        """Generate DocIR for await expressions."""
        parts: list[doc.DocType] = []
        for i in node.kid:
            parts.append(i.gen.doc_ir)
            parts.append(self.space())
        parts.pop()
        node.gen.doc_ir = self.group(self.concat(parts))

    def exit_yield_expr(self, node: uni.YieldExpr) -> None:
        """Generate DocIR for yield expressions."""
        parts: list[doc.DocType] = []
        for i in node.kid:
            parts.append(i.gen.doc_ir)
            parts.append(self.space())
        parts.pop()
        node.gen.doc_ir = self.group(self.concat(parts))

    def exit_ctrl_stmt(self, node: uni.CtrlStmt) -> None:
        """Generate DocIR for control statements (break, continue, skip)."""
        parts: list[doc.DocType] = []
        for i in node.kid:
            parts.append(i.gen.doc_ir)
        node.gen.doc_ir = self.group(self.concat(parts))

    def exit_delete_stmt(self, node: uni.DeleteStmt) -> None:
        """Generate DocIR for delete statements."""
        parts: list[doc.DocType] = []
        for i in node.kid:
            parts.append(i.gen.doc_ir)
            parts.append(self.space())
        parts.pop()
        node.gen.doc_ir = self.group(self.concat(parts))

    def exit_disengage_stmt(self, node: uni.DisengageStmt) -> None:
        """Generate DocIR for disengage statements."""
        parts: list[doc.DocType] = []
        for i in node.kid:
            parts.append(i.gen.doc_ir)
        node.gen.doc_ir = self.group(self.concat(parts))

    def exit_report_stmt(self, node: uni.ReportStmt) -> None:
        """Generate DocIR for report statements."""
        parts: list[doc.DocType] = []
        for i in node.kid:
            parts.append(i.gen.doc_ir)
            parts.append(self.space())
        parts.pop()
        node.gen.doc_ir = self.group(self.concat(parts))

    def exit_assert_stmt(self, node: uni.AssertStmt) -> None:
        """Generate DocIR for assert statements."""
        parts: list[doc.DocType] = []
        for i in node.kid:
            parts.append(i.gen.doc_ir)
            parts.append(self.space())
        parts.pop()
        node.gen.doc_ir = self.group(self.concat(parts))

    def exit_raise_stmt(self, node: uni.RaiseStmt) -> None:
        """Generate DocIR for raise statements."""
        parts: list[doc.DocType] = []
        for i in node.kid:
            parts.append(i.gen.doc_ir)
            parts.append(self.space())
        parts.pop()
        node.gen.doc_ir = self.group(self.concat(parts))

    def exit_global_vars(self, node: uni.GlobalVars) -> None:
        """Generate DocIR for global variables."""
        parts: list[doc.DocType] = []
        for i in node.kid:
            if i == node.doc:
                parts.append(i.gen.doc_ir)
                parts.append(self.hard_line())
            elif isinstance(i, uni.Token) and i.name == Tok.SEMI:
                parts.pop()
                parts.append(i.gen.doc_ir)
                parts.append(self.space())
            else:
                parts.append(i.gen.doc_ir)
                parts.append(self.space())
        node.gen.doc_ir = self.group(self.concat(parts))

    def exit_module_code(self, node: uni.ModuleCode) -> None:
        """Generate DocIR for module code."""
        parts: list[doc.DocType] = []
        body_parts: list[doc.DocType] = []
        in_body = False
        for i in node.kid:
            if node.doc and i is node.doc:
                parts.append(i.gen.doc_ir)
                parts.append(self.hard_line())
            elif i == node.name:
                parts.append(i.gen.doc_ir)
                parts.append(self.space())
            elif isinstance(i, uni.Token) and i.name == Tok.COLON:
                parts.pop()
                parts.append(i.gen.doc_ir)
            elif isinstance(node.body, Sequence) and i in node.body:
                if not in_body:
                    parts.pop()
                    body_parts.append(self.hard_line())
                body_parts.append(i.gen.doc_ir)
                body_parts.append(self.hard_line())
                in_body = True
            elif in_body:
                in_body = False
                body_parts.pop()
                parts.append(self.indent(self.concat(body_parts)))
                parts.append(self.hard_line())
                parts.append(i.gen.doc_ir)
                parts.append(self.space())
            elif isinstance(i, uni.Token) and i.name == Tok.SEMI:
                parts.pop()
                parts.append(i.gen.doc_ir)
                parts.append(self.space())
            else:
                parts.append(i.gen.doc_ir)
                parts.append(self.space())
        node.gen.doc_ir = self.group(self.concat(parts))

    def exit_global_stmt(self, node: uni.GlobalStmt) -> None:
        """Generate DocIR for global statements."""
        parts: list[doc.DocType] = []
        for i in node.kid:
            parts.append(i.gen.doc_ir)
            if isinstance(i, uni.Token) and i.name == Tok.GLOBAL_OP:
                parts.append(self.space())
        node.gen.doc_ir = self.group(self.concat(parts))

    def exit_non_local_stmt(self, node: uni.NonLocalStmt) -> None:
        """Generate DocIR for nonlocal statements."""
        parts: list[doc.DocType] = []
        for i in node.kid:
            parts.append(i.gen.doc_ir)
            parts.append(self.space())
        node.gen.doc_ir = self.group(self.concat(parts))

    def exit_visit_stmt(self, node: uni.VisitStmt) -> None:
        """Generate DocIR for visit statements."""
        parts: list[doc.DocType] = []
        for i in node.kid:
            if isinstance(i, uni.Token) and i.name == Tok.SEMI:
                parts.pop()
                parts.append(i.gen.doc_ir)
                parts.append(self.space())
            else:
                parts.append(i.gen.doc_ir)
                parts.append(self.space())
        node.gen.doc_ir = self.group(self.concat(parts))

    def exit_connect_op(self, node: uni.ConnectOp) -> None:
        """Generate DocIR for connect operator."""
        parts: list[doc.DocType] = []
        for i in node.kid:
            parts.append(i.gen.doc_ir)
            parts.append(self.space())
        parts.pop()
        node.gen.doc_ir = self.group(self.concat(parts))

    def exit_disconnect_op(self, node: uni.DisconnectOp) -> None:
        """Generate DocIR for disconnect operator."""
        parts: list[doc.DocType] = []
        for i in node.kid:
            parts.append(i.gen.doc_ir)
            parts.append(self.space())
        parts.pop()
        node.gen.doc_ir = self.group(self.concat(parts))

    def exit_compare_expr(self, node: uni.CompareExpr) -> None:
        """Generate DocIR for comparison expressions."""
        parts: list[doc.DocType] = []
        for i in node.kid:
            parts.append(i.gen.doc_ir)
            parts.append(self.space())
        parts.pop()
        node.gen.doc_ir = self.group(self.concat(parts))

    def exit_atom_unit(self, node: uni.AtomUnit) -> None:
        """Generate DocIR for atom units (parenthesized expressions)."""
        parts: list[doc.DocType] = []
        prev_item: Optional[uni.UniNode] = None
        for i in node.kid:
            if isinstance(i, uni.Token) and i.name == Tok.LPAREN:
                parts.append(i.gen.doc_ir)
            elif isinstance(i, uni.Token) and i.name == Tok.RPAREN:
                if not (
                    prev_item
                    and isinstance(prev_item, uni.Token)
                    and prev_item.name == Tok.LPAREN
                ):
                    parts.pop()
                parts.append(i.gen.doc_ir)
                parts.append(self.space())
            else:
                parts.append(i.gen.doc_ir)
                parts.append(self.space())
            prev_item = i
        parts.pop()
        node.gen.doc_ir = self.group(self.concat(parts))

    def exit_expr_as_item(self, node: uni.ExprAsItem) -> None:
        """Generate DocIR for expression as item nodes."""
        parts: list[doc.DocType] = []
        for i in node.kid:
            parts.append(i.gen.doc_ir)
            parts.append(self.space())
        node.gen.doc_ir = self.group(self.concat(parts))

    def exit_filter_compr(self, node: uni.FilterCompr) -> None:
        """Generate DocIR for filter comprehensions."""
        parts: list[doc.DocType] = []
        for i in node.kid:
            parts.append(i.gen.doc_ir)
            parts.append(self.space())
        node.gen.doc_ir = self.group(self.concat(parts))

    def exit_assign_compr(self, node: uni.AssignCompr) -> None:
        """Generate DocIR for assignment comprehensions."""
        parts: list[doc.DocType] = []
        for i in node.kid:
            parts.append(i.gen.doc_ir)
            parts.append(self.space())
        node.gen.doc_ir = self.group(self.concat(parts))

    def exit_py_inline_code(self, node: uni.PyInlineCode) -> None:
        """Generate DocIR for Python inline code blocks."""
        parts: list[doc.DocType] = []
        for i in node.kid:
            if i == node.doc:
                parts.append(i.gen.doc_ir)
                parts.append(self.hard_line())
            elif isinstance(i, uni.Token) and i.name == Tok.PYNLINE:
                parts.append(self.text("::py::"))
                parts.append(i.gen.doc_ir)
                parts.append(self.text("::py::"))
                parts.append(self.hard_line())
            else:
                parts.append(i.gen.doc_ir)
                parts.append(self.space())
        node.gen.doc_ir = self.group(self.concat(parts))

    def exit_test(self, node: uni.Test) -> None:
        """Generate DocIR for test nodes."""
        parts: list[doc.DocType] = []
        for i in node.kid:
            if i == node.doc:
                parts.append(i.gen.doc_ir)
                parts.append(self.hard_line())
            elif i == node.name and isinstance(i, uni.Name):
                if not i.value.startswith("_jac_gen_"):
                    parts.append(i.gen.doc_ir)
                    parts.append(self.space())
            else:
                parts.append(i.gen.doc_ir)
                parts.append(self.space())
        node.gen.doc_ir = self.group(self.concat(parts))

    def exit_check_stmt(self, node: uni.CheckStmt) -> None:
        """Generate DocIR for check statements."""
        parts: list[doc.DocType] = []
        for i in node.kid:
            if isinstance(i, uni.Token) and i.name == Tok.SEMI:
                parts.pop()
            parts.append(i.gen.doc_ir)
            parts.append(self.space())
        node.gen.doc_ir = self.group(self.concat(parts))

    def exit_match_stmt(self, node: uni.MatchStmt) -> None:
        """Generate DocIR for match statements."""
        parts: list[doc.DocType] = []
        match_parts: list[doc.DocType] = [self.hard_line()]
        for i in node.kid:
            if i == node.target:
                parts.append(i.gen.doc_ir)
                parts.append(self.space())
            elif isinstance(i, uni.MatchCase):
                match_parts.append(i.gen.doc_ir)
                match_parts.append(self.hard_line())
            elif isinstance(i, uni.Token) and i.name == Tok.RBRACE:
                parts.append(self.indent(self.concat(match_parts)))
                parts.append(i.gen.doc_ir)
                parts.append(self.space())
            else:
                parts.append(i.gen.doc_ir)
                parts.append(self.space())
        node.gen.doc_ir = self.group(self.concat(parts))

    def exit_match_case(self, node: uni.MatchCase) -> None:
        """Generate DocIR for match cases."""
        parts: list[doc.DocType] = []
        indent_parts: list[doc.DocType] = []
        for i in node.kid:
            if isinstance(i, uni.Token) and i.name == Tok.COLON:
                parts.pop()
                parts.append(i.gen.doc_ir)
            elif i in node.body:
                indent_parts.append(i.gen.doc_ir)
                indent_parts.append(self.hard_line())
            else:
                parts.append(i.gen.doc_ir)
                parts.append(self.space())
        parts.append(self.indent(self.concat([self.hard_line()] + indent_parts)))
        node.gen.doc_ir = self.group(self.concat(parts))

    def exit_match_value(self, node: uni.MatchValue) -> None:
        """Generate DocIR for match value patterns."""
        parts: list[doc.DocType] = []
        for i in node.kid:
            parts.append(i.gen.doc_ir)
            parts.append(self.space())
        parts.pop()
        node.gen.doc_ir = self.group(self.concat(parts))

    def exit_match_singleton(self, node: uni.MatchSingleton) -> None:
        """Generate DocIR for match singleton patterns."""
        parts: list[doc.DocType] = []
        for i in node.kid:
            parts.append(i.gen.doc_ir)
            parts.append(self.space())
        parts.pop()
        node.gen.doc_ir = self.group(self.concat(parts))

    def exit_match_sequence(self, node: uni.MatchSequence) -> None:
        """Generate DocIR for match sequence patterns."""
        parts: list[doc.DocType] = []
        for i in node.kid:
            parts.append(i.gen.doc_ir)
            parts.append(self.space())
        parts.pop()
        node.gen.doc_ir = self.group(self.concat(parts))

    def exit_match_mapping(self, node: uni.MatchMapping) -> None:
        """Generate DocIR for match mapping patterns."""
        parts: list[doc.DocType] = []
        for i in node.kid:
            parts.append(i.gen.doc_ir)
            parts.append(self.space())
        parts.pop()
        node.gen.doc_ir = self.group(self.concat(parts))

    def exit_match_or(self, node: uni.MatchOr) -> None:
        """Generate DocIR for match OR patterns."""
        parts: list[doc.DocType] = []
        for i in node.kid:
            parts.append(i.gen.doc_ir)
            parts.append(self.space())
        parts.pop()
        node.gen.doc_ir = self.group(self.concat(parts))

    def exit_match_as(self, node: uni.MatchAs) -> None:
        """Generate DocIR for match AS patterns."""
        parts: list[doc.DocType] = []
        for i in node.kid:
            parts.append(i.gen.doc_ir)
            parts.append(self.space())
        parts.pop()
        node.gen.doc_ir = self.group(self.concat(parts))

    def exit_match_wild(self, node: uni.MatchWild) -> None:
        """Generate DocIR for match wildcard patterns."""
        parts: list[doc.DocType] = []
        for i in node.kid:
            parts.append(i.gen.doc_ir)
            parts.append(self.space())
        parts.pop()
        node.gen.doc_ir = self.group(self.concat(parts))

    def exit_match_star(self, node: uni.MatchStar) -> None:
        """Generate DocIR for match star patterns (e.g., *args, **kwargs)."""
        parts: list[doc.DocType] = []
        for i in node.kid:
            parts.append(i.gen.doc_ir)
            parts.append(self.space())
        parts.pop()
        node.gen.doc_ir = self.group(self.concat(parts))

    def exit_match_k_v_pair(self, node: uni.MatchKVPair) -> None:
        """Generate DocIR for match key-value pairs."""
        parts: list[doc.DocType] = []
        for i in node.kid:
            if isinstance(i, uni.Token) and i.name in [Tok.STAR_POW, Tok.STAR_MUL]:
                parts.append(i.gen.doc_ir)
            else:
                parts.append(i.gen.doc_ir)
                parts.append(self.space())
        parts.pop()
        node.gen.doc_ir = self.group(self.concat(parts))

    def exit_match_arch(self, node: uni.MatchArch) -> None:
        """Generate DocIR for match architecture patterns."""
        parts: list[doc.DocType] = []
        for i in node.kid:
            if isinstance(i, uni.Token) and i.name == Tok.COMMA:
                parts.append(i.gen.doc_ir)
                parts.append(self.space())
            else:
                parts.append(i.gen.doc_ir)
        node.gen.doc_ir = self.group(self.concat(parts))

    def exit_enum(self, node: uni.Enum) -> None:
        """Generate DocIR for enum declarations."""
        parts: list[doc.DocType] = []
        for i in node.kid:
            if (node.doc and i is node.doc) or (
                node.decorators and i in node.decorators
            ):
                parts.append(i.gen.doc_ir)
                parts.append(self.hard_line())
            elif isinstance(i, uni.Token) and i.name == Tok.SEMI:
                parts.pop()
                parts.append(i.gen.doc_ir)
                parts.append(self.space())
            else:
                parts.append(i.gen.doc_ir)
                parts.append(self.space())
        node.gen.doc_ir = self.group(self.concat(parts))

    def exit_sub_tag(self, node: uni.SubTag) -> None:
        """Generate DocIR for sub-tag nodes."""
        before_colon: list[doc.DocType] = []
        after_colon: list[doc.DocType] = []
        seen_colon = False

        for i in node.kid:
            if isinstance(i, uni.Token) and i.name == Tok.COLON and not seen_colon:
                colon_tok = i.gen.doc_ir
                seen_colon = True
            elif seen_colon:
                after_colon.append(i.gen.doc_ir)
            else:
                before_colon.append(i.gen.doc_ir)

        if seen_colon:
            flat = self.concat([*before_colon, colon_tok, self.space(), *after_colon])
            broke = self.concat(
                [
                    *before_colon,
                    colon_tok,
                    self.indent(self.concat([self.line(), *after_colon])),
                ]
            )
            node.gen.doc_ir = self.group(self.if_break(broke, flat))
        else:
            node.gen.doc_ir = self.concat(before_colon + after_colon)

    def exit_impl_def(self, node: uni.ImplDef) -> None:
        """Generate DocIR for implementation definitions."""
        parts: list[doc.DocType] = []
        body_parts: list[doc.DocType] = []
        in_body = False
        for i in node.kid:
            if i == node.doc or (node.decorators and i in node.decorators):
                parts.append(i.gen.doc_ir)
                parts.append(self.hard_line())
            elif self.is_within(i, node.target):
                parts.append(i.gen.doc_ir)
            elif (
                in_body
                or isinstance(node.body, Sequence)
                and node.body
                and i == node.body[0]
            ):
                if not in_body:
                    parts.pop()
                    body_parts.append(self.hard_line())
                if isinstance(i, uni.Token) and i.name == Tok.COMMA:
                    body_parts.pop()
                body_parts.append(i.gen.doc_ir)
                body_parts.append(self.hard_line())
                in_body = True
                if in_body and isinstance(node.body, Sequence) and i == node.body[-1]:
                    in_body = False
                    body_parts.pop()
                    parts.append(self.indent(self.concat(body_parts)))
                    parts.append(self.hard_line())
            elif isinstance(i, uni.Token) and i.name == Tok.SEMI:
                parts.pop()
                parts.append(i.gen.doc_ir)
                parts.append(self.space())
            else:
                parts.append(i.gen.doc_ir)
                parts.append(self.space())
        node.gen.doc_ir = self.group(self.concat(parts))

    def exit_sem_def(self, node: uni.SemDef) -> None:
        """Generate DocIR for semantic definitions."""
        parts: list[doc.DocType] = []
        for i in node.kid:
            if i in node.target:
                parts.append(i.gen.doc_ir)
            elif isinstance(i, uni.Token) and i.name == Tok.SEMI:
                parts.pop()
                parts.append(i.gen.doc_ir)
                parts.append(self.space())
            else:
                parts.append(i.gen.doc_ir)
                parts.append(self.space())
        node.gen.doc_ir = self.group(self.concat(parts))

    def exit_event_signature(self, node: uni.EventSignature) -> None:
        """Generate DocIR for event signatures."""
        parts: list[doc.DocType] = []
        for i in node.kid:
            parts.append(i.gen.doc_ir)
            parts.append(self.space())
        parts.pop()
        node.gen.doc_ir = self.group(self.concat(parts))

    def exit_typed_ctx_block(self, node: uni.TypedCtxBlock) -> None:
        """Generate DocIR for typed context blocks."""
        parts: list[doc.DocType] = []
        for i in node.kid:
            parts.append(i.gen.doc_ir)
        node.gen.doc_ir = self.group(self.concat(parts))

    def exit_token(self, node: uni.Token) -> None:
        """Generate DocIR for tokens."""
        node.gen.doc_ir = self.text(node.value)

    def exit_semi(self, node: uni.Semi) -> None:
        """Generate DocIR for semicolons."""
        node.gen.doc_ir = self.text(node.value)

    def exit_name(self, node: uni.Name) -> None:
        """Generate DocIR for names."""
        if node.is_kwesc:
            node.gen.doc_ir = self.text(f"<>{node.value}")
        else:
            node.gen.doc_ir = self.text(node.value)

    def exit_int(self, node: uni.Int) -> None:
        """Generate DocIR for integers."""
        node.gen.doc_ir = self.text(node.value)

    def exit_builtin_type(self, node: uni.BuiltinType) -> None:
        """Generate DocIR for builtin type nodes."""
        node.gen.doc_ir = self.text(node.value)

    def exit_float(self, node: uni.Float) -> None:
        """Generate DocIR for floats."""
        node.gen.doc_ir = self.text(node.value)

    def exit_string(self, node: uni.String) -> None:
        """Generate DocIR for strings."""
        # Check if this is an escaped curly brace in an f-string context
        is_escaped_curly = (
            node.lit_value in ["{", "}"]
            and node.parent
            and isinstance(node.parent, uni.FString)
        )

        if "\n" in node.value:
            lines = node.value.split("\n")
            parts: list[doc.DocType] = [self.text(lines[0])]
            for line in lines[1:]:
                parts.append(self.hard_line())
                parts.append(self.text(line.lstrip()))
            node.gen.doc_ir = self.group(self.concat(parts))
            return
        if is_escaped_curly:
            node.gen.doc_ir = self.concat(
                [self.text(node.value), self.text(node.value)]
            )
            return

        # Regular string
        node.gen.doc_ir = self.text(node.value)

    def exit_special_var_ref(self, node: uni.SpecialVarRef) -> None:
        """Generate DocIR for special variable references."""
        node.gen.doc_ir = self.text(node.value.replace("_", ""))

    def exit_bool(self, node: uni.Bool) -> None:
        """Generate DocIR for boolean values."""
        node.gen.doc_ir = self.text(node.value)

    def exit_null(self, node: uni.Null) -> None:
        """Generate DocIR for null values."""
        node.gen.doc_ir = self.text(node.value)

    def exit_ellipsis(self, node: uni.Ellipsis) -> None:
        """Generate DocIR for ellipsis."""
        node.gen.doc_ir = self.text(node.value)

    def exit_comment_token(self, node: uni.CommentToken) -> None:
        """Generate DocIR for comment tokens."""
        if isinstance(node.left_node, uni.CommentToken):
            node.gen.doc_ir = self.group(
                self.concat([self.text(node.value), self.hard_line()])
            )
        elif node.left_node and node.left_node.loc.last_line == node.loc.first_line:
            node.gen.doc_ir = self.group(
                self.concat(
                    [self.tight_line(), self.text(node.value), self.hard_line()]
                )
            )
        else:
            node.gen.doc_ir = self.group(
                self.concat([self.text(node.value), self.hard_line()])
            )
