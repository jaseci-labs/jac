"""DocIrGenPass for Jaseci Ast.\n\nThis is a pass for generating DocIr for Jac code.\n"""
import from collections.abc { Sequence }
import jaclang.compiler.passes.tool.doc_ir as doc;
import jaclang.pycore.unitree as uni;
import from jaclang.pycore.constant { Tokens as Tok }
import from jaclang.pycore.passes { UniPass }
"""DocIrGenPass generate DocIr for Jac code."""
class DocIRGenPass(UniPass) {
    """Create a Text node."""
    def text(
        self: DocIRGenPass, text: str, source_token: (uni.Token | None) = None
    ) -> doc.Text {
        return doc.Text(text, source_token=source_token);
    }

    """Create a space node."""
    def space(self: DocIRGenPass) -> doc.Text {
        return doc.Text(' ');
    }

    """Create a Line node."""
    def line(self: DocIRGenPass, hard: bool = False, literal: bool = False) -> doc.Line {
        return doc.Line(hard, literal);
    }

    """Create a hard line break."""
    def hard_line(self: DocIRGenPass) -> doc.Line {
        return doc.Line(hard=True);
    }

    """Create a tight line break."""
    def tight_line(self: DocIRGenPass) -> doc.Line {
        return doc.Line(tight=True);
    }

    """Create a literal line break."""
    def literal_line(self: DocIRGenPass) -> doc.Line {
        return doc.Line(literal=True);
    }

    """\n        Create a Group node.\n\n        Args:\n            contents: The contents to group\n            break_contiguous: If True, break when parent group breaks (currently unused in formatter)\n            ast_node: Optional reference to the AST node this represents\n        """
    def group(
        self: DocIRGenPass,
        contents: doc.DocType,
        break_contiguous: bool = False,
        ast_node: (uni.UniNode | None) = None
    ) -> doc.Group {
        return doc.Group(contents, break_contiguous, ast_node=ast_node);
    }

    """Create an Indent node."""
    def indent(
        self: DocIRGenPass,
        contents: doc.DocType,
        ast_node: (uni.UniNode | None) = None
    ) -> doc.Indent {
        return doc.Indent(contents, ast_node=ast_node);
    }

    """Create a Concat node."""
    def concat(
        self: DocIRGenPass,
        parts: list[doc.DocType],
        ast_node: (uni.UniNode | None) = None
    ) -> doc.Concat {
        return doc.Concat(parts, ast_node=ast_node);
    }

    """Create an IfBreak node."""
    def if_break(
        self: DocIRGenPass, break_contents: doc.DocType, flat_contents: doc.DocType
    ) -> doc.IfBreak {
        return doc.IfBreak(break_contents, flat_contents);
    }

    """Create an Align node."""
    def align(
        self: DocIRGenPass, contents: doc.DocType, n: (int | None) = None
    ) -> doc.Align {
        return doc.Align(contents, n);
    }

    """Join parts with separator."""
    def join(
        self: DocIRGenPass, separator: doc.DocType, parts: list[doc.DocType]
    ) -> doc.DocType {
        if not parts {
            return self.concat([]);
        }
        result = [parts[0]];
        for part in parts[1:] {
            result.append(separator);
            result.append(part);
        }
        return self.concat(result);
    }

    """Join parts with space separator."""
    def join_with_space(self: DocIRGenPass, parts: list[doc.DocType]) -> doc.DocType {
        return self.join(self.space(), parts);
    }

    """Join parts with line separator."""
    def join_with_line(self: DocIRGenPass, parts: list[doc.DocType]) -> doc.DocType {
        return self.join(self.line(), parts);
    }

    """Return generated DocIR for each child."""
    def _child_docs(self: DocIRGenPass, <>node: uni.UniNode) -> list[doc.DocType] {
        docs: list[doc.DocType] = [];
        for kid in <>node.kid {
            docs.append(kid.gen.doc_ir);
        }
        return docs;
    }

    """Assign a simple Concat of child documents."""
    def _assign_concat(self: DocIRGenPass, <>node: uni.UniNode) -> None {
        <>node.gen.doc_ir = self.concat(self._child_docs(<>node), ast_node=<>node);
    }

    """Assign a grouped Concat of child documents."""
    def _assign_group_concat(self: DocIRGenPass, <>node: uni.UniNode) -> None {
        <>node.gen.doc_ir = self.group(
            self.concat(self._child_docs(<>node), ast_node=<>node), ast_node=<>node
        );
    }

    """Assign a grouped, space-joined document for the children."""
    def _assign_space_group(self: DocIRGenPass, <>node: uni.UniNode) -> None {
        <>node.gen.doc_ir = self.group(
            self.join_with_space(self._child_docs(<>node)), ast_node=<>node
        );
    }

    """Intersperse separator between items (returns flat list)."""
    def intersperse(
        self: DocIRGenPass, items: list[doc.DocType], separator: doc.DocType
    ) -> list[doc.DocType] {
        if not items {
            return [];
        }
        result = [items[0]];
        for item in items[1:] {
            result.append(separator);
            result.append(item);
        }
        return result;
    }

    """\n        Format a simple statement with a body block (while/for/try/etc).\n\n        Common pattern for statements that have:\n        - keyword + condition/target\n        - body block\n        - possible trailing elements\n        """
    def format_simple_stmt_with_body(
        self: DocIRGenPass,
        <>node: uni.UniNode,
        body: Sequence[uni.UniNode],
        space_between_parts: bool = True
    ) -> doc.DocType {
        parts: list[doc.DocType] = [];
        body_parts: list[doc.DocType] = [self.hard_line()];
        prev_body_item: (uni.UniNode | None) = None;
        for i in <>node.kid {
            if (isinstance(body, Sequence) and self.is_within(i, body)) {
                if (body and (i == body[0])) {
                    parts.append(self.indent(self.concat(body_parts), ast_node=<>node));
                    parts.append(self.hard_line());
                }
                self.add_body_stmt_with_spacing(body_parts, i, prev_body_item);
                prev_body_item = i;
            } else {
                parts.append(i.gen.doc_ir);
                if space_between_parts {
                    parts.append(self.space());
                }
            }
        }
        if (parts and isinstance(parts[-1], doc.Text) and (parts[-1].text == ' ')) {
            parts.pop();
        }
        if (body_parts and isinstance(body_parts[-1], doc.Line)) {
            body_parts.pop();
        }
        return self.group(self.concat(parts, ast_node=<>node), ast_node=<>node);
    }

    """\n        Format comprehension with defensive checks.\n\n        Expected structure: [opening, space, expr, space, inner_compr..., space, closing, space]\n        We need to remove spaces adjacent to brackets.\n        """
    def format_comprehension(
        self: DocIRGenPass, parts: list[doc.DocType]
    ) -> doc.DocType {
        if (parts and isinstance(parts[-1], doc.Text) and (parts[-1].text == ' ')) {
            parts.pop();
        }
        if (len(parts) >= 3) {
            opening = parts[0];
            closing = parts[-1];
            middle = parts[1:-1] if (len(parts) > 2) else [];
            if (middle and isinstance(middle[0], doc.Text) and (middle[0].text == ' ')) {
                middle = middle[1:];
            }
            if (
                middle
                and isinstance(middle[-1], doc.Text)
                and (middle[-1].text == ' ')
            ) {
                middle = middle[:-1];
            }
            return self.group(
                self.concat(
                    [
                        opening,
                        self.indent(self.concat([self.tight_line(), *middle])),
                        self.tight_line(),
                        closing
                    ]
                )
            );
        } else {
            return self.group(self.concat(parts));
        }
    }

    """Check if the node is a one line node."""
    def is_one_line(self: DocIRGenPass, <>node: uni.UniNode) -> bool {
        return (
            bool(<>node.kid)
            and (<>node.kid[0].loc.first_line == <>node.kid[-1].loc.last_line)
        );
    }

    """Check if there is a gap between the previous and current node."""
    def has_gap(
        self: DocIRGenPass, prev_kid: uni.UniNode, curr_kid: uni.UniNode
    ) -> bool {
        return ((prev_kid.loc.last_line + 1) < curr_kid.loc.first_line);
    }

    """Add a body statement preserving single blank lines from source."""
    def add_body_stmt_with_spacing(
        self: DocIRGenPass,
        body_parts: list[doc.DocType],
        current: uni.UniNode,
        previous: (uni.UniNode | None)
    ) -> None {
        if (previous and self.has_gap(previous, current)) {
            body_parts.append(self.hard_line());
        }
        body_parts.append(current.gen.doc_ir);
        body_parts.append(self.hard_line());
    }

    """Check if kid node is within the block."""
    def is_within(
        self: DocIRGenPass, kid_node: uni.UniNode, block: Sequence[uni.UniNode]
    ) -> bool {
        if not block {
            return False;
        }
        (start, end, kid) = (block[0].loc, block[-1].loc, kid_node.loc);
        first = (
            (start.first_line < kid.first_line)
            or (
                (start.first_line == kid.first_line)
                and (start.col_start <= kid.col_start)
            )
        );
        last = (
            (end.last_line > kid.last_line)
            or ((end.last_line == kid.last_line) and (end.col_end >= kid.col_end))
        );
        return (first and last);
    }

    """Recursively trim trailing Line (soft or hard) nodes from parts."""
    def trim_trailing_line(self: DocIRGenPass, parts: list[doc.DocType]) -> None {
        if not parts {
            return;
        }
        while parts {
            last = parts[-1];
            if isinstance(last, doc.Line) {
                parts.pop();
                continue;
            } elif isinstance(last, doc.Concat) {
                self.trim_trailing_line(last.parts);
                if not last.parts {
                    parts.pop();
                    continue;
                }
            } elif isinstance(last, doc.Group) {
                contents = last.contents;
                if isinstance(contents, doc.Concat) {
                    self.trim_trailing_line(contents.parts);
                    if not contents.parts {
                        parts.pop();
                        continue;
                    }
                } elif isinstance(contents, doc.Line) {
                    parts.pop();
                    continue;
                }
            }
            break;
        }
    }

    """Recursively remove all space nodes from a doc_ir tree."""
    def remove_all_spaces(self: DocIRGenPass, doc_node: doc.DocType) -> doc.DocType {
        if isinstance(doc_node, doc.Text) {
            if (doc_node.text == ' ') {
                return self.concat([]);
            }
            return doc_node;
        } elif isinstance(doc_node, doc.Concat) {
            new_parts = [];
            for part in doc_node.parts {
                processed = self.remove_all_spaces(part);
                if not (isinstance(processed, doc.Concat) and not processed.parts) {
                    new_parts.append(processed);
                }
            }
            return doc.Concat(new_parts, ast_node=doc_node.ast_node);
        } elif isinstance(doc_node, doc.Group) {
            return doc.Group(
                self.remove_all_spaces(doc_node.contents),
                doc_node.break_contiguous,
                ast_node=doc_node.ast_node
            );
        } elif isinstance(doc_node, doc.Indent) {
            return doc.Indent(
                self.remove_all_spaces(doc_node.contents), ast_node=doc_node.ast_node
            );
        } elif isinstance(doc_node, doc.IfBreak) {
            return doc.IfBreak(
                self.remove_all_spaces(doc_node.break_contents),
                self.remove_all_spaces(doc_node.flat_contents)
            );
        } else {
            return doc_node;
        }
    }

    """Exit module."""
    def exit_module(self: DocIRGenPass, <>node: uni.Module) -> None {
        parts: list[doc.DocType] = [];
        prev_kid = None;
        first_kid = True;
        for i in <>node.kid {
            if (
                (isinstance(i, uni.Import) and isinstance(prev_kid, uni.Import))
                or (
                    (
                        isinstance(i, uni.GlobalVars)
                        and isinstance(prev_kid, uni.GlobalVars)
                    )
                    or (prev_kid == <>node.doc)
                )
            ) {
                if (prev_kid and self.has_gap(prev_kid, i)) {
                    parts.append(self.hard_line());
                }
                parts.append(i.gen.doc_ir);
            } else {
                if (
                    not first_kid
                    and not (
                        prev_kid
                        and self.is_one_line(prev_kid)
                        and not self.has_gap(prev_kid, i)
                    )
                ) {
                    parts.append(self.hard_line());
                }
                parts.append(i.gen.doc_ir);
            }
            parts.append(self.hard_line());
            prev_kid = i;
            first_kid = False;
        }
        <>node.gen.doc_ir = self.concat(parts, ast_node=<>node);
    }

    """Exit import node."""
    def exit_import(self: DocIRGenPass, <>node: uni.Import) -> None {
        parts: list[doc.DocType] = [];
        mod_items: list[doc.DocType] = [];
        is_in_items: bool = False;
        for i in <>node.kid {
            if (isinstance(i, uni.Token) and (i.name == Tok.COMMA)) {
                if is_in_items {
                    mod_items.pop();
                    mod_items.append(i.gen.doc_ir);
                    mod_items.append(self.line());
                } else {
                    parts.pop();
                    parts.append(i.gen.doc_ir);
                    parts.append(self.line());
                }
            } elif (isinstance(i, uni.Token) and (i.name == Tok.SEMI)) {
                parts.pop();
                parts.append(i.gen.doc_ir);
            } elif (isinstance(i, uni.Token) and (i.name == Tok.RBRACE)) {
                is_in_items = False;
                mod_items.pop();
                parts.append(
                    self.group(
                        self.concat(
                            [
                                self.indent(self.concat([self.line(), *mod_items])),
                                self.line()
                            ]
                        )
                    )
                );
                parts.append(i.gen.doc_ir);
            } elif (isinstance(i, uni.Token) and (i.name == Tok.LBRACE)) {
                is_in_items = True;
                parts.append(i.gen.doc_ir);
            } elif is_in_items {
                mod_items.append(i.gen.doc_ir);
                mod_items.append(self.space());
            } else {
                parts.append(i.gen.doc_ir);
                parts.append(self.space());
            }
        }
        <>node.gen.doc_ir = self.group(
            self.concat(parts, ast_node=<>node), ast_node=<>node
        );
    }

    """Generate DocIR for module items."""
    def exit_module_item(self: DocIRGenPass, <>node: uni.ModuleItem) -> None {
        parts: list[doc.DocType] = [];
        for i in <>node.kid {
            if (isinstance(i, uni.Token) and (i.name == Tok.KW_AS)) {
                parts.append(self.space());
                parts.append(i.gen.doc_ir);
                parts.append(self.space());
            } else {
                parts.append(i.gen.doc_ir);
            }
        }
        <>node.gen.doc_ir = self.concat(parts, ast_node=<>node);
    }

    """Generate DocIR for module paths."""
    def exit_module_path(self: DocIRGenPass, <>node: uni.ModulePath) -> None {
        parts: list[doc.DocType] = [];
        for i in <>node.kid {
            if (isinstance(i, uni.Token) and (i.name == Tok.KW_AS)) {
                parts.append(self.space());
                parts.append(i.gen.doc_ir);
                parts.append(self.space());
            } else {
                parts.append(i.gen.doc_ir);
            }
        }
        <>node.gen.doc_ir = self.concat(parts, ast_node=<>node);
    }

    """Generate DocIR for archetypes."""
    def exit_archetype(self: DocIRGenPass, <>node: uni.Archetype) -> None {
        parts: list[doc.DocType] = [];
        body_parts: list[doc.DocType] = [];
        prev_item = None;
        in_body = False;
        for i in <>node.kid {
            if (
                (<>node.doc and (i is <>node.doc))
                or (<>node.decorators and (i in <>node.decorators))
            ) {
                parts.append(i.gen.doc_ir);
                parts.append(self.hard_line());
            } elif (i == <>node.name) {
                parts.append(i.gen.doc_ir);
                parts.append(self.space());
            } elif (isinstance(i, uni.Token) and (i.name == Tok.LBRACE)) {
                parts.append(i.gen.doc_ir);
            } elif (isinstance(i, uni.Token) and (i.name == Tok.LPAREN)) {
                parts.pop();
                parts.append(i.gen.doc_ir);
            } elif (isinstance(i, uni.Token) and (i.name == Tok.RPAREN)) {
                parts.pop();
                parts.append(i.gen.doc_ir);
                parts.append(self.space());
            } elif (isinstance(<>node.body, Sequence) and (i in <>node.body)) {
                if not in_body {
                    body_parts.append(self.hard_line());
                }
                if (
                    (prev_item and (<>type(prev_item) is not <>type(i)))
                    or (prev_item and not self.is_one_line(prev_item))
                ) {
                    body_parts.append(self.hard_line());
                }
                body_parts.append(i.gen.doc_ir);
                body_parts.append(self.hard_line());
                prev_item = i;
                in_body = True;
            } elif in_body {
                in_body = False;
                body_parts.pop();
                parts.append(self.indent(self.concat(body_parts), ast_node=<>node));
                parts.append(self.hard_line());
                parts.append(i.gen.doc_ir);
                parts.append(self.space());
            } elif (isinstance(i, uni.Token) and (i.name == Tok.SEMI)) {
                parts.pop();
                parts.append(i.gen.doc_ir);
                parts.append(self.space());
            } elif (
                not in_body and isinstance(i, uni.Token) and (i.name == Tok.DECOR_OP)
            ) {
                parts.append(i.gen.doc_ir);
            } else {
                parts.append(i.gen.doc_ir);
                parts.append(self.space());
            }
        }
        <>node.gen.doc_ir = self.group(
            self.concat(parts, ast_node=<>node), ast_node=<>node
        );
    }

    """Generate DocIR for abilities."""
    def exit_ability(self: DocIRGenPass, <>node: uni.Ability) -> None {
        parts: list[doc.DocType] = [];
        body_parts: list[doc.DocType] = [];
        in_body = False;
        prev_body_item: (uni.UniNode | None) = None;
        for i in <>node.kid {
            if ((i == <>node.doc) or (<>node.decorators and (i in <>node.decorators))) {
                parts.append(i.gen.doc_ir);
                parts.append(self.hard_line());
            } elif (i == <>node.name_ref) {
                parts.append(i.gen.doc_ir);
                if not isinstance(<>node.signature, uni.FuncSignature) {
                    parts.append(self.space());
                }
            } elif (isinstance(i, uni.Token) and (i.name == Tok.LBRACE)) {
                parts.append(i.gen.doc_ir);
                body_parts.append(self.hard_line());
                in_body = True;
            } elif (isinstance(i, uni.Token) and (i.name == Tok.RBRACE)) {
                in_body = False;
                self.trim_trailing_line(body_parts);
                parts.append(self.indent(self.concat(body_parts), ast_node=<>node));
                if (len(body_parts) > 0) {
                    parts.append(self.hard_line());
                } else {
                    parts.append(self.space());
                }
                parts.append(i.gen.doc_ir);
                parts.append(self.space());
            } elif in_body {
                self.add_body_stmt_with_spacing(body_parts, i, prev_body_item);
                prev_body_item = i;
            } elif (
                not in_body and isinstance(i, uni.Token) and (i.name == Tok.DECOR_OP)
            ) {
                parts.append(i.gen.doc_ir);
            } elif (isinstance(i, uni.Token) and (i.name == Tok.SEMI)) {
                parts.pop();
                parts.append(i.gen.doc_ir);
                parts.append(self.space());
            } else {
                parts.append(i.gen.doc_ir);
                parts.append(self.space());
            }
        }
        <>node.gen.doc_ir = self.group(
            self.concat(parts, ast_node=<>node), ast_node=<>node
        );
    }

    """Generate DocIR for function signatures."""
    def exit_func_signature(self: DocIRGenPass, <>node: uni.FuncSignature) -> None {
        parts: list[doc.DocType] = [];
        indent_parts: list[doc.DocType] = [];
        in_params = False;
        has_parens = False;
        for i in <>node.kid {
            if (isinstance(i, uni.Token) and (i.name == Tok.LPAREN) and <>node.params) {
                in_params = True;
                parts.append(i.gen.doc_ir);
            } elif (
                isinstance(i, uni.Token) and (i.name == Tok.RPAREN) and <>node.params
            ) {
                in_params = False;
                has_parens = True;
                if isinstance(indent_parts[-1], doc.Line) {
                    indent_parts.pop();
                }
                parts.append(
                    self.indent(
                        self.concat(
                            [
                                self.tight_line(),
                                self.group(self.concat([*indent_parts]))
                            ]
                        )
                    )
                );
                parts.append(self.tight_line());
                parts.append(i.gen.doc_ir);
                parts.append(self.space());
            } elif (isinstance(i, uni.Token) and (i.name == Tok.RPAREN)) {
                parts.pop();
                parts.append(i.gen.doc_ir);
                parts.append(self.space());
            } elif in_params {
                if (isinstance(i, uni.Token) and (i.name == Tok.COMMA)) {
                    indent_parts.append(i.gen.doc_ir);
                    indent_parts.append(self.line());
                } else {
                    indent_parts.append(i.gen.doc_ir);
                }
            } else {
                if (
                    isinstance(i, uni.Token)
                    and (i.name == Tok.RETURN_HINT)
                    and not has_parens
                ) {
                    parts.append(self.space());
                }
                parts.append(i.gen.doc_ir);
                parts.append(self.space());
            }
        }
        parts.pop();
        <>node.gen.doc_ir = self.group(self.concat(parts, ast_node=<>node));
    }

    """Generate DocIR for parameter variables."""
    def exit_param_var(self: DocIRGenPass, <>node: uni.ParamVar) -> None {
        parts: list[doc.DocType] = [];
        for i in <>node.kid {
            if (isinstance(i, uni.Token) and (i.name == Tok.EQ)) {
                parts.append(self.space());
                parts.append(i.gen.doc_ir);
                parts.append(self.space());
            } else {
                parts.append(i.gen.doc_ir);
            }
        }
        <>node.gen.doc_ir = self.group(
            self.concat(parts, ast_node=<>node), ast_node=<>node
        );
    }

    """Generate DocIR for type references."""
    def exit_type_ref(self: DocIRGenPass, <>node: uni.TypeRef) -> None {
        parts: list[doc.DocType] = [];
        for i in <>node.kid {
            parts.append(i.gen.doc_ir);
        }
        <>node.gen.doc_ir = self.group(
            self.concat(parts, ast_node=<>node), ast_node=<>node
        );
    }

    """Generate DocIR for assignments."""
    def exit_assignment(self: DocIRGenPass, <>node: uni.Assignment) -> None {
        lhs_parts: list[doc.DocType] = [];
        rhs_parts: list[doc.DocType] = [];
        eq_tok: (doc.DocType | None) = None;
        seen_eq = False;
        for i in <>node.kid {
            if (isinstance(i, uni.Token) and (i.name == Tok.EQ) and not seen_eq) {
                eq_tok = i.gen.doc_ir;
                seen_eq = True;
            } elif seen_eq {
                rhs_parts.append(i.gen.doc_ir);
            } else {
                if (i == <>node.aug_op) {
                    lhs_parts.append(self.space());
                }
                lhs_parts.append(i.gen.doc_ir);
                if (i == <>node.aug_op) {
                    lhs_parts.append(self.space());
                }
            }
        }
        if (eq_tok is not None) {
            rhs_concat = self.group(self.concat(rhs_parts));
            <>node.gen.doc_ir = self.group(
                self.concat(
                    [
                        *lhs_parts,
                        self.space(),
                        eq_tok,
                        self.concat([self.space(), rhs_concat])
                    ]
                )
            );
        } else {
            <>node.gen.doc_ir = self.group(self.concat((lhs_parts + rhs_parts)));
        }
    }

    """Generate DocIR for if statements."""
    def exit_if_stmt(self: DocIRGenPass, <>node: uni.IfStmt) -> None {
        parts: list[doc.DocType] = [];
        body_parts: list[doc.DocType] = [self.hard_line()];
        for i in <>node.kid {
            if (isinstance(<>node.body, Sequence) and self.is_within(i, <>node.body)) {
                if (i == <>node.body[0]) {
                    parts.append(self.indent(self.concat(body_parts), ast_node=<>node));
                    parts.append(self.hard_line());
                }
                body_parts.append(i.gen.doc_ir);
                body_parts.append(self.hard_line());
            } elif (isinstance(i, uni.Token) and (i.name == Tok.SEMI)) {
                parts.pop();
                parts.append(i.gen.doc_ir);
                parts.append(self.space());
            } else {
                parts.append(i.gen.doc_ir);
                parts.append(self.space());
            }
        }
        parts.pop();
        body_parts.pop();
        <>node.gen.doc_ir = self.group(
            self.concat(parts, ast_node=<>node), ast_node=<>node
        );
    }

    """Generate DocIR for else if statements."""
    def exit_else_if(self: DocIRGenPass, <>node: uni.ElseIf) -> None {
        parts: list[doc.DocType] = [];
        body_parts: list[doc.DocType] = [self.hard_line()];
        for i in <>node.kid {
            if (isinstance(<>node.body, Sequence) and self.is_within(i, <>node.body)) {
                if (i == <>node.body[0]) {
                    parts.append(self.indent(self.concat(body_parts), ast_node=<>node));
                    parts.append(self.hard_line());
                }
                body_parts.append(i.gen.doc_ir);
                body_parts.append(self.hard_line());
            } elif (isinstance(i, uni.Token) and (i.name == Tok.SEMI)) {
                parts.pop();
                parts.append(i.gen.doc_ir);
                parts.append(self.space());
            } else {
                parts.append(i.gen.doc_ir);
                parts.append(self.space());
            }
        }
        body_parts.pop();
        <>node.gen.doc_ir = self.group(
            self.concat(parts, ast_node=<>node), ast_node=<>node
        );
    }

    """Generate DocIR for else statements."""
    def exit_else_stmt(self: DocIRGenPass, <>node: uni.ElseStmt) -> None {
        parts: list[doc.DocType] = [];
        body_parts: list[doc.DocType] = [self.hard_line()];
        for i in <>node.kid {
            if (isinstance(<>node.body, Sequence) and self.is_within(i, <>node.body)) {
                if (i == <>node.body[0]) {
                    parts.append(self.indent(self.concat(body_parts), ast_node=<>node));
                    parts.append(self.hard_line());
                }
                body_parts.append(i.gen.doc_ir);
                body_parts.append(self.hard_line());
            } elif (isinstance(i, uni.Token) and (i.name == Tok.SEMI)) {
                parts.pop();
                parts.append(i.gen.doc_ir);
                parts.append(self.space());
            } else {
                parts.append(i.gen.doc_ir);
                parts.append(self.space());
            }
        }
        body_parts.pop();
        <>node.gen.doc_ir = self.group(
            self.concat(parts, ast_node=<>node), ast_node=<>node
        );
    }

    """Generate DocIR for binary expressions."""
    def exit_binary_expr(self: DocIRGenPass, <>node: uni.BinaryExpr) -> None {
        self._assign_space_group(<>node);
    }

    """Generate DocIR for expression statements."""
    def exit_expr_stmt(self: DocIRGenPass, <>node: uni.ExprStmt) -> None {
        self._assign_group_concat(<>node);
    }

    """Generate DocIR for concurrent expressions."""
    def exit_concurrent_expr(self: DocIRGenPass, <>node: uni.ConcurrentExpr) -> None {
        parts: list[doc.DocType] = [];
        for i in <>node.kid {
            parts.append(i.gen.doc_ir);
            parts.append(self.space());
        }
        <>node.gen.doc_ir = self.group(self.concat(parts), ast_node=<>node);
    }

    """Generate DocIR for return statements."""
    def exit_return_stmt(self: DocIRGenPass, <>node: uni.ReturnStmt) -> None {
        parts: list[doc.DocType] = [];
        for i in <>node.kid {
            if (isinstance(i, uni.Token) and (i.name == Tok.SEMI)) {
                parts.pop();
                parts.append(i.gen.doc_ir);
            } else {
                parts.append(i.gen.doc_ir);
            }
            parts.append(self.space());
        }
        <>node.gen.doc_ir = self.group(
            self.concat(parts, ast_node=<>node), ast_node=<>node
        );
    }

    """Generate DocIR for function calls."""
    def exit_func_call(self: DocIRGenPass, <>node: uni.FuncCall) -> None {
        parts: list[doc.DocType] = [];
        indent_parts: list[doc.DocType] = [];
        in_params = False;
        for i in <>node.kid {
            if (isinstance(i, uni.Token) and (i.name == Tok.LPAREN) and <>node.params) {
                in_params = True;
                parts.append(i.gen.doc_ir);
            } elif (
                isinstance(i, uni.Token) and (i.name == Tok.RPAREN) and <>node.params
            ) {
                in_params = False;
                if isinstance(indent_parts[-1], doc.Line) {
                    indent_parts.pop();
                }
                parts.append(
                    self.indent(
                        self.concat(
                            [
                                self.tight_line(),
                                self.group(self.concat([*indent_parts]))
                            ]
                        ),
                        ast_node=<>node
                    )
                );
                parts.append(self.tight_line());
                parts.append(i.gen.doc_ir);
            } elif in_params {
                if (isinstance(i, uni.Token) and (i.name == Tok.COMMA)) {
                    indent_parts.append(i.gen.doc_ir);
                    indent_parts.append(self.line());
                } else {
                    indent_parts.append(i.gen.doc_ir);
                }
            } else {
                parts.append(i.gen.doc_ir);
                if (isinstance(i, uni.Token) and (i.name == Tok.KW_BY)) {
                    parts.append(self.space());
                }
            }
        }
        <>node.gen.doc_ir = self.group(
            self.concat(parts, ast_node=<>node), ast_node=<>node
        );
    }

    """Generate DocIR for atom trailers."""
    def exit_atom_trailer(self: DocIRGenPass, <>node: uni.AtomTrailer) -> None {
        parts: list[doc.DocType] = [];
        for i in <>node.kid {
            parts.append(i.gen.doc_ir);
            if (isinstance(i, uni.Token) and (i.name == Tok.KW_BY)) {
                parts.append(self.space());
            }
        }
        <>node.gen.doc_ir = self.group(
            self.concat(parts, ast_node=<>node), ast_node=<>node
        );
    }

    """Generate DocIR for list values."""
    def exit_list_val(self: DocIRGenPass, <>node: uni.ListVal) -> None {
        parts: list[doc.DocType] = [];
        for i in <>node.kid {
            if (isinstance(i, uni.Token) and (i.name == Tok.COMMA)) {
                parts.append(i.gen.doc_ir);
                parts.append(self.space());
            } else {
                parts.append(i.gen.doc_ir);
            }
        }
        not_broke = self.concat(parts, ast_node=<>node);
        parts = [];
        for i in <>node.kid {
            if (isinstance(i, uni.Token) and (i.name == Tok.COMMA)) {
                parts.append(i.gen.doc_ir);
                parts.append(self.hard_line());
            } else {
                parts.append(i.gen.doc_ir);
            }
        }
        if (len(parts) >= 3) {
            broke = self.concat(
                [
                    parts[0],
                    self.indent(
                        self.concat([self.hard_line(), *parts[1:-1]], ast_node=<>node),
                        ast_node=<>node
                    ),
                    self.hard_line(),
                    parts[-1]
                ],
                ast_node=<>node
            );
        } else {
            broke = self.concat(parts, ast_node=<>node);
        }
        <>node.gen.doc_ir = self.group(
            self.if_break(broke, not_broke), ast_node=<>node
        );
    }

    """Generate DocIR for dictionary values."""
    def exit_dict_val(self: DocIRGenPass, <>node: uni.DictVal) -> None {
        if not <>node.kid {
            <>node.gen.doc_ir = self.group(self.concat([]));
            return;
        }
        if not <>node.kv_pairs {
            <>node.gen.doc_ir = self.group(
                self.concat([kid.gen.doc_ir for kid in <>node.kid])
            );
            return;
        }
        inline_parts: list[doc.DocType] = [];
        broken_parts: list[doc.DocType] = [];
        for i in <>node.kid {
            if (
                (isinstance(i, uni.Token) and (i.name in [Tok.LBRACE, Tok.RBRACE]))
                or isinstance(i, uni.KVPair)
            ) {
                inline_parts.append(i.gen.doc_ir);
                broken_parts.append(i.gen.doc_ir);
            } elif (isinstance(i, uni.Token) and (i.name == Tok.COMMA)) {
                inline_parts.append(i.gen.doc_ir);
                inline_parts.append(self.space());
                broken_parts.append(i.gen.doc_ir);
                broken_parts.append(self.hard_line());
            }
        }
        if (
            (len(inline_parts) >= 2)
            and isinstance(inline_parts[-2], doc.Text)
            and (inline_parts[-2].text == ' ')
        ) {
            inline_parts.pop(-2);
        }
        self.trim_trailing_line(broken_parts);
        not_broke = self.concat(inline_parts);
        lbrace_doc = broken_parts[0];
        rbrace_doc = broken_parts[-1];
        middle_parts = broken_parts[1:-1];
        broke = self.concat(
            [
                lbrace_doc,
                self.indent(
                    self.concat([self.hard_line(), *middle_parts]), ast_node=<>node
                ),
                self.hard_line(),
                rbrace_doc
            ]
        );
        <>node.gen.doc_ir = self.group(self.if_break(broke, not_broke));
    }

    """Generate DocIR for key-value pairs."""
    def exit_k_v_pair(self: DocIRGenPass, <>node: uni.KVPair) -> None {
        parts: list[doc.DocType] = [];
        kid_count = len(<>node.kid);
        for (idx, kid) in enumerate(<>node.kid) {
            parts.append(kid.gen.doc_ir);
            is_last = idx == (kid_count - 1);
            if (isinstance(kid, uni.Token) and (kid.name == Tok.COLON)) {
                if not is_last {
                    parts.append(self.space());
                }
            } elif not is_last {
                next_kid = <>node.kid[(idx + 1)];
                if (isinstance(next_kid, uni.Token) and (next_kid.name == Tok.COLON)) {
                    continue;
                }
                parts.append(self.space());
            }
        }
        <>node.gen.doc_ir = self.concat(parts, ast_node=<>node);
    }

    """Generate DocIR for has variable declarations."""
    def exit_has_var(self: DocIRGenPass, <>node: uni.HasVar) -> None {
        parts: list[doc.DocType] = [];
        for i in <>node.kid {
            if (isinstance(i, uni.Token) and (i.name == Tok.EQ)) {
                parts.append(self.space());
                parts.append(i.gen.doc_ir);
                parts.append(self.space());
            } elif (
                isinstance(i, uni.Token) and (i.name in [Tok.KW_BY, Tok.KW_POST_INIT])
            ) {
                parts.append(self.space());
                parts.append(i.gen.doc_ir);
            } else {
                parts.append(i.gen.doc_ir);
            }
        }
        <>node.gen.doc_ir = self.group(
            self.concat(parts, ast_node=<>node), ast_node=<>node
        );
    }

    """Generate DocIR for architecture has declarations."""
    def exit_arch_has(self: DocIRGenPass, <>node: uni.ArchHas) -> None {
        parts: list[doc.DocType] = [];
        indent_parts: list[doc.DocType] = [];
        first_comma_seen = False;
        semi_doc: (doc.DocType | None) = None;
        for i in <>node.kid {
            if (i == <>node.doc) {
                parts.append(i.gen.doc_ir);
                parts.append(self.hard_line());
            } elif (isinstance(i, uni.Token) and (i.name == Tok.SEMI)) {
                if indent_parts {
                    indent_parts.pop();
                } elif parts {
                    parts.pop();
                }
                semi_doc = i.gen.doc_ir;
            } elif (isinstance(i, uni.Token) and (i.name == Tok.COMMA)) {
                if first_comma_seen {
                    indent_parts.pop();
                    indent_parts.append(i.gen.doc_ir);
                    indent_parts.append(self.hard_line());
                } else {
                    parts.pop();
                    parts.append(i.gen.doc_ir);
                    first_comma_seen = True;
                }
            } elif isinstance(i, uni.HasVar) {
                if first_comma_seen {
                    indent_parts.append(i.gen.doc_ir);
                    indent_parts.append(self.space());
                } else {
                    parts.append(i.gen.doc_ir);
                    parts.append(self.space());
                }
            } else {
                parts.append(i.gen.doc_ir);
                parts.append(self.space());
            }
        }
        if indent_parts {
            self.trim_trailing_line(indent_parts);
            parts.append(
                self.indent(
                    self.concat([self.hard_line(), *indent_parts]), ast_node=<>node
                )
            );
        }
        if semi_doc {
            parts.append(semi_doc);
        }
        <>node.gen.doc_ir = self.group(
            self.concat(parts, ast_node=<>node), ast_node=<>node
        );
    }

    """Generate DocIR for while statements."""
    def exit_while_stmt(self: DocIRGenPass, <>node: uni.WhileStmt) -> None {
        <>node.gen.doc_ir = self.format_simple_stmt_with_body(<>node, <>node.body);
    }

    """Generate DocIR for for-in statements."""
    def exit_in_for_stmt(self: DocIRGenPass, <>node: uni.InForStmt) -> None {
        <>node.gen.doc_ir = self.format_simple_stmt_with_body(<>node, <>node.body);
    }

    """Generate DocIR for iterative for statements."""
    def exit_iter_for_stmt(self: DocIRGenPass, <>node: uni.IterForStmt) -> None {
        <>node.gen.doc_ir = self.format_simple_stmt_with_body(<>node, <>node.body);
    }

    """Generate DocIR for try statements."""
    def exit_try_stmt(self: DocIRGenPass, <>node: uni.TryStmt) -> None {
        <>node.gen.doc_ir = self.format_simple_stmt_with_body(<>node, <>node.body);
    }

    """Generate DocIR for except clauses."""
    def exit_except(self: DocIRGenPass, <>node: uni.Except) -> None {
        <>node.gen.doc_ir = self.format_simple_stmt_with_body(<>node, <>node.body);
    }

    """Generate DocIR for finally statements."""
    def exit_finally_stmt(self: DocIRGenPass, <>node: uni.FinallyStmt) -> None {
        <>node.gen.doc_ir = self.format_simple_stmt_with_body(<>node, <>node.body);
    }

    """Generate DocIR for tuple values."""
    def exit_tuple_val(self: DocIRGenPass, <>node: uni.TupleVal) -> None {
        parts: list[doc.DocType] = [];
        for i in <>node.kid {
            if (isinstance(i, uni.Token) and (i.name == Tok.COMMA)) {
                parts.append(i.gen.doc_ir);
                parts.append(self.space());
            } else {
                parts.append(i.gen.doc_ir);
            }
        }
        not_broke = self.concat(parts);
        parts = [];
        for i in <>node.kid {
            if (isinstance(i, uni.Token) and (i.name == Tok.COMMA)) {
                parts.append(i.gen.doc_ir);
                parts.append(self.hard_line());
            } else {
                parts.append(i.gen.doc_ir);
            }
        }
        if (len(parts) >= 3) {
            broke = self.concat(
                [
                    parts[0],
                    self.indent(self.concat([self.hard_line(), *parts[1:-1]])),
                    self.hard_line(),
                    parts[-1]
                ]
            );
        } else {
            broke = self.concat(parts);
        }
        <>node.gen.doc_ir = self.group(self.if_break(broke, not_broke));
    }

    """Generate DocIR for multiline strings."""
    def exit_multi_string(self: DocIRGenPass, <>node: uni.MultiString) -> None {
        parts: list[doc.DocType] = [];
        for i in <>node.kid {
            parts.append(i.gen.doc_ir);
        }
        <>node.gen.doc_ir = self.group(
            self.concat(self.intersperse(parts, self.line()), ast_node=<>node),
            ast_node=<>node
        );
    }

    """Generate DocIR for set values."""
    def exit_set_val(self: DocIRGenPass, <>node: uni.SetVal) -> None {
        parts: list[doc.DocType] = [];
        for i in <>node.kid {
            parts.append(i.gen.doc_ir);
        }
        <>node.gen.doc_ir = self.group(
            self.concat(parts, ast_node=<>node), ast_node=<>node
        );
    }

    """Generate DocIR for with statements."""
    def exit_with_stmt(self: DocIRGenPass, <>node: uni.WithStmt) -> None {
        parts: list[doc.DocType] = [];
        body_parts: list[doc.DocType] = [self.hard_line()];
        for i in <>node.kid {
            if (isinstance(<>node.body, Sequence) and self.is_within(i, <>node.body)) {
                if (i == <>node.body[0]) {
                    parts.append(self.indent(self.concat(body_parts), ast_node=<>node));
                    parts.append(self.hard_line());
                }
                body_parts.append(i.gen.doc_ir);
                body_parts.append(self.hard_line());
            } elif (isinstance(i, uni.Token) and (i.name == Tok.COMMA)) {
                parts.pop();
                parts.append(i.gen.doc_ir);
                parts.append(self.space());
            } else {
                parts.append(i.gen.doc_ir);
                parts.append(self.space());
            }
        }
        parts.pop();
        body_parts.pop();
        <>node.gen.doc_ir = self.group(self.concat(parts), ast_node=<>node);
    }

    """Generate DocIR for list comprehensions."""
    def exit_list_compr(self: DocIRGenPass, <>node: uni.ListCompr) -> None {
        parts: list[doc.DocType] = [];
        for i in <>node.kid {
            if isinstance(i, uni.InnerCompr) {
                parts.append(
                    self.group(self.concat([self.tight_line(), i.gen.doc_ir]))
                );
            } else {
                parts.append(i.gen.doc_ir);
            }
            parts.append(self.space());
        }
        <>node.gen.doc_ir = self.format_comprehension(parts);
    }

    """Generate DocIR for inner comprehension clauses."""
    def exit_inner_compr(self: DocIRGenPass, <>node: uni.InnerCompr) -> None {
        parts: list[doc.DocType] = [];
        for i in <>node.kid {
            if (isinstance(i, uni.Token) and (i.name == Tok.KW_IF)) {
                parts.append(self.hard_line());
                parts.append(i.gen.doc_ir);
                parts.append(self.space());
            } else {
                parts.append(i.gen.doc_ir);
                parts.append(self.space());
            }
        }
        parts.pop();
        <>node.gen.doc_ir = self.group(
            self.concat(parts, ast_node=<>node), ast_node=<>node
        );
    }

    """Generate DocIR for formatted strings."""
    def exit_f_string(self: DocIRGenPass, <>node: uni.FString) -> None {
        parts: list[doc.DocType] = [];
        for i in <>node.kid {
            parts.append(i.gen.doc_ir);
        }
        <>node.gen.doc_ir = self.group(
            self.concat(parts, ast_node=<>node), ast_node=<>node
        );
    }

    """Generate DocIR for formatted value expressions."""
    def exit_formatted_value(self: DocIRGenPass, <>node: uni.FormattedValue) -> None {
        parts: list[doc.DocType] = [];
        for i in <>node.kid {
            parts.append(i.gen.doc_ir);
        }
        <>node.gen.doc_ir = self.group(
            self.concat(parts, ast_node=<>node), ast_node=<>node
        );
    }

    """Generate DocIR for conditional expressions."""
    def exit_if_else_expr(self: DocIRGenPass, <>node: uni.IfElseExpr) -> None {
        parts: list[doc.DocType] = [];
        for i in <>node.kid {
            if isinstance(i, uni.Expr) {
                parts.append(i.gen.doc_ir);
                parts.append(self.line());
            } elif isinstance(i, uni.Token) {
                parts.append(i.gen.doc_ir);
                parts.append(self.space());
            } else {
                parts.append(i.gen.doc_ir);
                parts.append(self.line());
            }
        }
        parts.pop();
        <>node.gen.doc_ir = self.group(
            self.concat(parts, ast_node=<>node), ast_node=<>node
        );
    }

    """Generate DocIR for boolean expressions (and/or)."""
    def exit_bool_expr(self: DocIRGenPass, <>node: uni.BoolExpr) -> None {
        exprs: list[uni.UniNode] = [];
        parts: list[doc.DocType] = [];
        def __flatten_bool_expr(expr: uni.Expr) -> list[uni.UniNode] {
            if isinstance(expr, uni.BoolExpr) {
                out: list[uni.UniNode] = [];
                for val in expr.values {
                    out += __flatten_bool_expr(val);
                    out.append(expr.op);
                }
                out.pop();
                return out;
            } else {
                return [expr];
            }
        }
        exprs = __flatten_bool_expr(<>node);
        parts += [exprs[0].gen.doc_ir, self.line()];
        for i in range(1, len(exprs), 2) {
            (op, expr) = (exprs[(i + 1)], exprs[i]);
            parts += [expr.gen.doc_ir, self.space(), op.gen.doc_ir, self.line()];
        }
        parts.pop();
        flat = self.concat(parts);
        <>node.gen.doc_ir = self.group(flat);
    }

    """Generate DocIR for unary expressions."""
    def exit_unary_expr(self: DocIRGenPass, <>node: uni.UnaryExpr) -> None {
        parts: list[doc.DocType] = [];
        for i in <>node.kid {
            if (
                (isinstance(i, uni.Token) and (i.value in ['-', '~', '+', '*']))
                or isinstance(i, uni.Expr)
            ) {
                parts.append(i.gen.doc_ir);
            } else {
                parts.append(i.gen.doc_ir);
                parts.append(self.space());
            }
        }
        <>node.gen.doc_ir = self.group(
            self.concat(parts, ast_node=<>node), ast_node=<>node
        );
    }

    """Generate DocIR for lambda expressions."""
    def exit_lambda_expr(self: DocIRGenPass, <>node: uni.LambdaExpr) -> None {
        parts: list[doc.DocType] = [];
        for i in <>node.kid {
            if isinstance(i, uni.Token) {
                parts.append(i.gen.doc_ir);
                parts.append(self.space());
            } elif isinstance(i, uni.Expr) {
                parts.append(
                    self.if_break(
                        self.indent(self.concat([self.line(), i.gen.doc_ir])),
                        i.gen.doc_ir
                    )
                );
            } elif isinstance(i, uni.FuncSignature) {
                if (isinstance(i.gen.doc_ir, doc.Text) and (i.gen.doc_ir.text == '()')) {
                    parts.append(i.gen.doc_ir);
                } else {
                    parts.append(self.space());
                    parts.append(i.gen.doc_ir);
                }
            } else {
                parts.append(i.gen.doc_ir);
            }
        }
        <>node.gen.doc_ir = self.group(
            self.concat(parts, ast_node=<>node), ast_node=<>node
        );
    }

    """Generate DocIR for edge reference trailers."""
    def exit_edge_ref_trailer(self: DocIRGenPass, <>node: uni.EdgeRefTrailer) -> None {
        parts: list[doc.DocType] = [];
        for i in <>node.kid {
            if (isinstance(i, uni.Token) and (i.name in [Tok.KW_EDGE, Tok.KW_NODE])) {
                parts.append(i.gen.doc_ir);
                parts.append(self.space());
            } else {
                parts.append(i.gen.doc_ir);
            }
        }
        <>node.gen.doc_ir = self.group(
            self.concat(parts, ast_node=<>node), ast_node=<>node
        );
    }

    """Generate DocIR for edge operation references."""
    def exit_edge_op_ref(self: DocIRGenPass, <>node: uni.EdgeOpRef) -> None {
        parts: list[doc.DocType] = [];
        for i in <>node.kid {
            parts.append(i.gen.doc_ir);
        }
        <>node.gen.doc_ir = self.group(
            self.concat(parts, ast_node=<>node), ast_node=<>node
        );
    }

    """Generate DocIR for index slices."""
    def exit_index_slice(self: DocIRGenPass, <>node: uni.IndexSlice) -> None {
        parts: list[doc.DocType] = [];
        for i in <>node.kid {
            parts.append(i.gen.doc_ir);
        }
        <>node.gen.doc_ir = self.group(
            self.concat(parts, ast_node=<>node), ast_node=<>node
        );
    }

    """Generate DocIR for generator comprehensions."""
    def exit_gen_compr(self: DocIRGenPass, <>node: uni.GenCompr) -> None {
        parts: list[doc.DocType] = [];
        for i in <>node.kid {
            if isinstance(i, uni.InnerCompr) {
                parts.append(
                    self.group(self.concat([self.tight_line(), i.gen.doc_ir]))
                );
            } else {
                parts.append(i.gen.doc_ir);
            }
            parts.append(self.space());
        }
        <>node.gen.doc_ir = self.format_comprehension(parts);
    }

    """Generate DocIR for set comprehensions."""
    def exit_set_compr(self: DocIRGenPass, <>node: uni.SetCompr) -> None {
        parts: list[doc.DocType] = [];
        for i in <>node.kid {
            if isinstance(i, uni.InnerCompr) {
                parts.append(
                    self.group(self.concat([self.tight_line(), i.gen.doc_ir]))
                );
            } else {
                parts.append(i.gen.doc_ir);
            }
            parts.append(self.space());
        }
        <>node.gen.doc_ir = self.format_comprehension(parts);
    }

    """Generate DocIR for dictionary comprehensions."""
    def exit_dict_compr(self: DocIRGenPass, <>node: uni.DictCompr) -> None {
        parts: list[doc.DocType] = [];
        for i in <>node.kid {
            if (isinstance(i, uni.Token) and (i.name in [Tok.STAR_POW, Tok.STAR_MUL])) {
                parts.append(i.gen.doc_ir);
            } else {
                if isinstance(i, uni.InnerCompr) {
                    parts.append(
                        self.group(self.concat([self.tight_line(), i.gen.doc_ir]))
                    );
                } else {
                    parts.append(i.gen.doc_ir);
                }
                parts.append(self.space());
            }
        }
        <>node.gen.doc_ir = self.format_comprehension(parts);
    }

    """Generate DocIR for keyword arguments."""
    def exit_k_w_pair(self: DocIRGenPass, <>node: uni.KWPair) -> None {
        self._assign_group_concat(<>node);
    }

    """Generate DocIR for await expressions."""
    def exit_await_expr(self: DocIRGenPass, <>node: uni.AwaitExpr) -> None {
        self._assign_space_group(<>node);
    }

    """Generate DocIR for yield expressions."""
    def exit_yield_expr(self: DocIRGenPass, <>node: uni.YieldExpr) -> None {
        self._assign_space_group(<>node);
    }

    """Generate DocIR for control statements (break, continue, skip)."""
    def exit_ctrl_stmt(self: DocIRGenPass, <>node: uni.CtrlStmt) -> None {
        self._assign_group_concat(<>node);
    }

    """Generate DocIR for delete statements."""
    def exit_delete_stmt(self: DocIRGenPass, <>node: uni.DeleteStmt) -> None {
        self._assign_space_group(<>node);
    }

    """Generate DocIR for disengage statements."""
    def exit_disengage_stmt(self: DocIRGenPass, <>node: uni.DisengageStmt) -> None {
        self._assign_group_concat(<>node);
    }

    """Generate DocIR for report statements."""
    def exit_report_stmt(self: DocIRGenPass, <>node: uni.ReportStmt) -> None {
        self._assign_space_group(<>node);
    }

    """Generate DocIR for assert statements."""
    def exit_assert_stmt(self: DocIRGenPass, <>node: uni.AssertStmt) -> None {
        parts: list[doc.DocType] = [];
        for i in <>node.kid {
            if (isinstance(i, uni.Token) and (i.name == Tok.SEMI) and len(parts)) {
                parts.pop();
            }
            parts.append(i.gen.doc_ir);
            parts.append(self.space());
        }
        parts.pop();
        <>node.gen.doc_ir = self.group(
            self.concat(parts, ast_node=<>node), ast_node=<>node
        );
    }

    """Generate DocIR for raise statements."""
    def exit_raise_stmt(self: DocIRGenPass, <>node: uni.RaiseStmt) -> None {
        self._assign_space_group(<>node);
    }

    """Generate DocIR for global variables."""
    def exit_global_vars(self: DocIRGenPass, <>node: uni.GlobalVars) -> None {
        parts: list[doc.DocType] = [];
        indent_parts: list[doc.DocType] = [];
        semi_doc: (doc.DocType | None) = None;
        has_multiple_assignments = len(<>node.assignments) > 1;
        for i in <>node.kid {
            if (i == <>node.doc) {
                parts.append(i.gen.doc_ir);
                parts.append(self.hard_line());
            } elif (isinstance(i, uni.Token) and (i.name == Tok.SEMI)) {
                if indent_parts {
                    indent_parts.pop();
                } elif parts {
                    parts.pop();
                }
                semi_doc = i.gen.doc_ir;
            } elif (isinstance(i, uni.Token) and (i.name == Tok.COMMA)) {
                if has_multiple_assignments {
                    indent_parts.pop();
                    indent_parts.append(i.gen.doc_ir);
                    indent_parts.append(self.hard_line());
                } else {
                    parts.pop();
                    parts.append(i.gen.doc_ir);
                    parts.append(self.space());
                }
            } elif isinstance(i, uni.Assignment) {
                if has_multiple_assignments {
                    indent_parts.append(i.gen.doc_ir);
                    indent_parts.append(self.space());
                } else {
                    parts.append(i.gen.doc_ir);
                    parts.append(self.space());
                }
            } else {
                parts.append(i.gen.doc_ir);
                parts.append(self.space());
            }
        }
        if indent_parts {
            self.trim_trailing_line(indent_parts);
            parts.append(
                self.indent(
                    self.concat([self.hard_line(), *indent_parts]), ast_node=<>node
                )
            );
        }
        if semi_doc {
            parts.append(semi_doc);
        }
        <>node.gen.doc_ir = self.group(
            self.concat(parts, ast_node=<>node), ast_node=<>node
        );
    }

    """Generate DocIR for client blocks (cl { ... })."""
    def exit_client_block(self: DocIRGenPass, <>node: uni.ClientBlock) -> None {
        parts: list[doc.DocType] = [];
        body_parts: list[doc.DocType] = [];
        in_body = False;
        prev_body_item: (uni.UniNode | None) = None;
        for i in <>node.kid {
            if (isinstance(i, uni.Token) and (i.name == Tok.KW_CLIENT)) {
                parts.append(i.gen.doc_ir);
                parts.append(self.space());
            } elif (isinstance(i, uni.Token) and (i.name == Tok.LBRACE)) {
                parts.append(i.gen.doc_ir);
                body_parts.append(self.hard_line());
                in_body = True;
            } elif (isinstance(i, uni.Token) and (i.name == Tok.RBRACE)) {
                in_body = False;
                self.trim_trailing_line(body_parts);
                parts.append(self.indent(self.concat(body_parts), ast_node=<>node));
                if len(body_parts) {
                    parts.append(self.hard_line());
                } else {
                    parts.append(self.line());
                }
                parts.append(i.gen.doc_ir);
                parts.append(self.space());
            } elif in_body {
                self.add_body_stmt_with_spacing(body_parts, i, prev_body_item);
                prev_body_item = i;
            } else {
                parts.append(i.gen.doc_ir);
                parts.append(self.space());
            }
        }
        <>node.gen.doc_ir = self.group(
            self.concat(parts, ast_node=<>node), ast_node=<>node
        );
    }

    """Generate DocIR for module code."""
    def exit_module_code(self: DocIRGenPass, <>node: uni.ModuleCode) -> None {
        parts: list[doc.DocType] = [];
        body_parts: list[doc.DocType] = [];
        in_body = False;
        prev_body_item: (uni.UniNode | None) = None;
        for i in <>node.kid {
            if (<>node.doc and (i is <>node.doc)) {
                parts.append(i.gen.doc_ir);
                parts.append(self.hard_line());
            } elif (i == <>node.name) {
                parts.append(i.gen.doc_ir);
                parts.append(self.space());
            } elif (isinstance(i, uni.Token) and (i.name == Tok.COLON)) {
                parts.pop();
                parts.append(i.gen.doc_ir);
            } elif (isinstance(i, uni.Token) and (i.name == Tok.LBRACE)) {
                parts.append(i.gen.doc_ir);
                body_parts.append(self.hard_line());
                in_body = True;
            } elif (isinstance(i, uni.Token) and (i.name == Tok.RBRACE)) {
                in_body = False;
                self.trim_trailing_line(body_parts);
                parts.append(self.indent(self.concat(body_parts), ast_node=<>node));
                if len(body_parts) {
                    parts.append(self.hard_line());
                } else {
                    parts.append(self.line());
                }
                parts.append(i.gen.doc_ir);
                parts.append(self.space());
            } elif in_body {
                self.add_body_stmt_with_spacing(body_parts, i, prev_body_item);
                prev_body_item = i;
            } else {
                parts.append(i.gen.doc_ir);
                parts.append(self.space());
            }
        }
        <>node.gen.doc_ir = self.group(
            self.concat(parts, ast_node=<>node), ast_node=<>node
        );
    }

    """Generate DocIR for global statements."""
    def exit_global_stmt(self: DocIRGenPass, <>node: uni.GlobalStmt) -> None {
        parts: list[doc.DocType] = [];
        for i in <>node.kid {
            parts.append(i.gen.doc_ir);
            if (isinstance(i, uni.Token) and (i.name == Tok.GLOBAL_OP)) {
                parts.append(self.space());
            }
        }
        <>node.gen.doc_ir = self.group(
            self.concat(parts, ast_node=<>node), ast_node=<>node
        );
    }

    """Generate DocIR for nonlocal statements."""
    def exit_non_local_stmt(self: DocIRGenPass, <>node: uni.NonLocalStmt) -> None {
        self._assign_space_group(<>node);
    }

    """Generate DocIR for visit statements."""
    def exit_visit_stmt(self: DocIRGenPass, <>node: uni.VisitStmt) -> None {
        parts: list[doc.DocType] = [];
        for i in <>node.kid {
            if (isinstance(i, uni.Token) and (i.name == Tok.SEMI)) {
                parts.pop();
                parts.append(i.gen.doc_ir);
                parts.append(self.space());
            } else {
                parts.append(i.gen.doc_ir);
                parts.append(self.space());
            }
        }
        <>node.gen.doc_ir = self.group(
            self.concat(parts, ast_node=<>node), ast_node=<>node
        );
    }

    """Generate DocIR for connect operator."""
    def exit_connect_op(self: DocIRGenPass, <>node: uni.ConnectOp) -> None {
        self._assign_space_group(<>node);
    }

    """Generate DocIR for disconnect operator."""
    def exit_disconnect_op(self: DocIRGenPass, <>node: uni.DisconnectOp) -> None {
        self._assign_space_group(<>node);
    }

    """Generate DocIR for comparison expressions."""
    def exit_compare_expr(self: DocIRGenPass, <>node: uni.CompareExpr) -> None {
        self._assign_space_group(<>node);
    }

    """Generate DocIR for atom units (parenthesized expressions)."""
    def exit_atom_unit(self: DocIRGenPass, <>node: uni.AtomUnit) -> None {
        parts: list[doc.DocType] = [];
        prev_item: (uni.UniNode | None) = None;
        for i in <>node.kid {
            if (isinstance(i, uni.Token) and (i.name == Tok.LPAREN)) {
                parts.append(i.gen.doc_ir);
            } elif (isinstance(i, uni.Token) and (i.name == Tok.RPAREN)) {
                if not (
                    prev_item
                    and isinstance(prev_item, uni.Token)
                    and (prev_item.name == Tok.LPAREN)
                ) {
                    parts.pop();
                }
                parts.append(i.gen.doc_ir);
                parts.append(self.space());
            } else {
                parts.append(i.gen.doc_ir);
                parts.append(self.space());
            }
            prev_item = i;
        }
        parts.pop();
        broken = self.group(
            self.concat(
                [
                    parts[0],
                    self.indent(self.concat([self.tight_line(), *parts[1:-1]])),
                    self.tight_line(),
                    parts[-1]
                ]
            )
        );
        if (
            isinstance(<>node.parent, uni.Assignment)
            or (
                isinstance(<>node.parent, uni.IfStmt)
                and isinstance(<>node.value, uni.BoolExpr)
            )
        ) {
            <>node.gen.doc_ir = self.if_break(
                flat_contents=self.group(self.concat(parts[1:-1])),
                break_contents=broken
            );
        } else {
            <>node.gen.doc_ir = broken;
        }
    }

    """Generate DocIR for expression as item nodes."""
    def exit_expr_as_item(self: DocIRGenPass, <>node: uni.ExprAsItem) -> None {
        self._assign_space_group(<>node);
    }

    """Generate DocIR for filter comprehensions."""
    def exit_filter_compr(self: DocIRGenPass, <>node: uni.FilterCompr) -> None {
        parts: list[doc.DocType] = [];
        for i in <>node.kid {
            parts.append(i.gen.doc_ir);
        }
        compact_doc = self.remove_all_spaces(self.concat(parts));
        <>node.gen.doc_ir = self.group(compact_doc);
    }

    """Generate DocIR for assignment comprehensions."""
    def exit_assign_compr(self: DocIRGenPass, <>node: uni.AssignCompr) -> None {
        parts: list[doc.DocType] = [];
        for i in <>node.kid {
            parts.append(i.gen.doc_ir);
        }
        compact_doc = self.remove_all_spaces(self.concat(parts));
        <>node.gen.doc_ir = self.group(compact_doc);
    }

    """Generate DocIR for Python inline code blocks."""
    def exit_py_inline_code(self: DocIRGenPass, <>node: uni.PyInlineCode) -> None {
        parts: list[doc.DocType] = [];
        for i in <>node.kid {
            if (i == <>node.doc) {
                parts.append(i.gen.doc_ir);
                parts.append(self.hard_line());
            } elif (isinstance(i, uni.Token) and (i.name == Tok.PYNLINE)) {
                parts.append(self.text('::py::'));
                parts.append(i.gen.doc_ir);
                parts.append(self.text('::py::'));
                parts.append(self.hard_line());
            } else {
                parts.append(i.gen.doc_ir);
                parts.append(self.space());
            }
        }
        <>node.gen.doc_ir = self.group(
            self.concat(parts, ast_node=<>node), ast_node=<>node
        );
    }

    """Generate DocIR for test nodes."""
    def exit_test(self: DocIRGenPass, <>node: uni.Test) -> None {
        parts: list[doc.DocType] = [];
        body_parts: list[doc.DocType] = [];
        in_body = False;
        prev_body_item: (uni.UniNode | None) = None;
        for i in <>node.kid {
            if (i == <>node.doc) {
                parts.append(i.gen.doc_ir);
                parts.append(self.hard_line());
            } elif ((i == <>node.name) and isinstance(i, uni.Name)) {
                if not i.value.startswith('_jac_gen_') {
                    parts.append(i.gen.doc_ir);
                    parts.append(self.space());
                }
            } elif (isinstance(i, uni.Token) and (i.name == Tok.LBRACE)) {
                parts.append(i.gen.doc_ir);
                body_parts.append(self.hard_line());
                in_body = True;
            } elif (isinstance(i, uni.Token) and (i.name == Tok.RBRACE)) {
                in_body = False;
                self.trim_trailing_line(body_parts);
                parts.append(self.indent(self.concat(body_parts), ast_node=<>node));
                if (len(body_parts) > 0) {
                    parts.append(self.hard_line());
                } else {
                    parts.append(self.space());
                }
                parts.append(i.gen.doc_ir);
                parts.append(self.space());
            } elif in_body {
                self.add_body_stmt_with_spacing(body_parts, i, prev_body_item);
                prev_body_item = i;
            } else {
                parts.append(i.gen.doc_ir);
                parts.append(self.space());
            }
        }
        <>node.gen.doc_ir = self.group(
            self.concat(parts, ast_node=<>node), ast_node=<>node
        );
    }

    """Generate DocIR for match statements."""
    def exit_match_stmt(self: DocIRGenPass, <>node: uni.MatchStmt) -> None {
        parts: list[doc.DocType] = [];
        match_parts: list[doc.DocType] = [self.hard_line()];
        for i in <>node.kid {
            if (i == <>node.target) {
                parts.append(i.gen.doc_ir);
                parts.append(self.space());
            } elif isinstance(i, uni.MatchCase) {
                match_parts.append(i.gen.doc_ir);
                match_parts.append(self.hard_line());
            } elif (isinstance(i, uni.Token) and (i.name == Tok.RBRACE)) {
                if (match_parts and isinstance(match_parts[-1], doc.Line)) {
                    match_parts.pop();
                }
                parts.append(
                    self.indent(
                        self.concat(match_parts, ast_node=<>node), ast_node=<>node
                    )
                );
                parts.append(self.hard_line());
                parts.append(i.gen.doc_ir);
                parts.append(self.space());
            } else {
                parts.append(i.gen.doc_ir);
                parts.append(self.space());
            }
        }
        <>node.gen.doc_ir = self.group(
            self.concat(parts, ast_node=<>node), ast_node=<>node
        );
    }

    """Generate DocIR for match cases."""
    def exit_match_case(self: DocIRGenPass, <>node: uni.MatchCase) -> None {
        parts: list[doc.DocType] = [];
        indent_parts: list[doc.DocType] = [];
        prev_body_item: (uni.UniNode | None) = None;
        for i in <>node.kid {
            if (isinstance(i, uni.Token) and (i.name == Tok.COLON)) {
                parts.pop();
                parts.append(i.gen.doc_ir);
            } elif (i in <>node.body) {
                self.add_body_stmt_with_spacing(indent_parts, i, prev_body_item);
                prev_body_item = i;
            } else {
                parts.append(i.gen.doc_ir);
                parts.append(self.space());
            }
        }
        parts.append(
            self.indent(
                self.concat(([self.hard_line()] + indent_parts)), ast_node=<>node
            )
        );
        <>node.gen.doc_ir = self.group(
            self.concat(parts, ast_node=<>node), ast_node=<>node
        );
    }

    """Generate DocIR for switch statements."""
    def exit_switch_stmt(self: DocIRGenPass, <>node: uni.SwitchStmt) -> None {
        parts: list[doc.DocType] = [];
        switch_parts: list[doc.DocType] = [self.hard_line()];
        for i in <>node.kid {
            if (i == <>node.target) {
                parts.append(i.gen.doc_ir);
                parts.append(self.space());
            } elif isinstance(i, uni.SwitchCase) {
                switch_parts.append(i.gen.doc_ir);
                switch_parts.append(self.hard_line());
            } elif (isinstance(i, uni.Token) and (i.name == Tok.RBRACE)) {
                if (switch_parts and isinstance(switch_parts[-1], doc.Line)) {
                    switch_parts.pop();
                }
                parts.append(
                    self.indent(
                        self.concat(switch_parts, ast_node=<>node), ast_node=<>node
                    )
                );
                parts.append(self.hard_line());
                parts.append(i.gen.doc_ir);
                parts.append(self.space());
            } else {
                parts.append(i.gen.doc_ir);
                parts.append(self.space());
            }
        }
        <>node.gen.doc_ir = self.group(
            self.concat(parts, ast_node=<>node), ast_node=<>node
        );
    }

    """Generate DocIR for switch cases."""
    def exit_switch_case(self: DocIRGenPass, <>node: uni.SwitchCase) -> None {
        parts: list[doc.DocType] = [];
        indent_parts: list[doc.DocType] = [];
        prev_body_item: (uni.UniNode | None) = None;
        for i in <>node.kid {
            if (isinstance(i, uni.Token) and (i.name == Tok.COLON)) {
                parts.pop();
                parts.append(i.gen.doc_ir);
            } elif (i in <>node.body) {
                self.add_body_stmt_with_spacing(indent_parts, i, prev_body_item);
                prev_body_item = i;
            } else {
                parts.append(i.gen.doc_ir);
                parts.append(self.space());
            }
        }
        parts.append(
            self.indent(
                self.concat(([self.hard_line()] + indent_parts)), ast_node=<>node
            )
        );
        <>node.gen.doc_ir = self.group(
            self.concat(parts, ast_node=<>node), ast_node=<>node
        );
    }

    """Generate DocIR for match value patterns."""
    def exit_match_value(self: DocIRGenPass, <>node: uni.MatchValue) -> None {
        self._assign_space_group(<>node);
    }

    """Generate DocIR for match singleton patterns."""
    def exit_match_singleton(self: DocIRGenPass, <>node: uni.MatchSingleton) -> None {
        self._assign_space_group(<>node);
    }

    """Generate DocIR for match sequence patterns."""
    def exit_match_sequence(self: DocIRGenPass, <>node: uni.MatchSequence) -> None {
        self._assign_space_group(<>node);
    }

    """Generate DocIR for match mapping patterns."""
    def exit_match_mapping(self: DocIRGenPass, <>node: uni.MatchMapping) -> None {
        self._assign_space_group(<>node);
    }

    """Generate DocIR for match OR patterns."""
    def exit_match_or(self: DocIRGenPass, <>node: uni.MatchOr) -> None {
        self._assign_space_group(<>node);
    }

    """Generate DocIR for match AS patterns."""
    def exit_match_as(self: DocIRGenPass, <>node: uni.MatchAs) -> None {
        self._assign_space_group(<>node);
    }

    """Generate DocIR for match wildcard patterns."""
    def exit_match_wild(self: DocIRGenPass, <>node: uni.MatchWild) -> None {
        self._assign_space_group(<>node);
    }

    """Generate DocIR for match star patterns (e.g., *args, **kwargs)."""
    def exit_match_star(self: DocIRGenPass, <>node: uni.MatchStar) -> None {
        self._assign_space_group(<>node);
    }

    """Generate DocIR for match key-value pairs."""
    def exit_match_k_v_pair(self: DocIRGenPass, <>node: uni.MatchKVPair) -> None {
        parts: list[doc.DocType] = [];
        for i in <>node.kid {
            if (isinstance(i, uni.Token) and (i.name in [Tok.STAR_POW, Tok.STAR_MUL])) {
                parts.append(i.gen.doc_ir);
            } else {
                parts.append(i.gen.doc_ir);
                parts.append(self.space());
            }
        }
        parts.pop();
        <>node.gen.doc_ir = self.group(
            self.concat(parts, ast_node=<>node), ast_node=<>node
        );
    }

    """Generate DocIR for match architecture patterns."""
    def exit_match_arch(self: DocIRGenPass, <>node: uni.MatchArch) -> None {
        parts: list[doc.DocType] = [];
        for i in <>node.kid {
            if (isinstance(i, uni.Token) and (i.name == Tok.COMMA)) {
                parts.append(i.gen.doc_ir);
                parts.append(self.space());
            } else {
                parts.append(i.gen.doc_ir);
            }
        }
        <>node.gen.doc_ir = self.group(
            self.concat(parts, ast_node=<>node), ast_node=<>node
        );
    }

    """Generate DocIR for enum declarations."""
    def exit_enum(self: DocIRGenPass, <>node: uni.Enum) -> None {
        parts: list[doc.DocType] = [];
        body_parts: list[doc.DocType] = [];
        in_body = False;
        for i in <>node.kid {
            if (
                (<>node.doc and (i is <>node.doc))
                or (<>node.decorators and (i in <>node.decorators))
            ) {
                parts.append(i.gen.doc_ir);
                parts.append(self.hard_line());
            } elif (isinstance(i, uni.Token) and (i.name == Tok.SEMI)) {
                parts.pop();
                parts.append(i.gen.doc_ir);
                parts.append(self.space());
            } elif (isinstance(i, uni.Token) and (i.name == Tok.LBRACE)) {
                parts.append(i.gen.doc_ir);
                body_parts.append(self.line());
                in_body = True;
            } elif (isinstance(i, uni.Token) and (i.name == Tok.RBRACE)) {
                in_body = False;
                if (len(body_parts) and isinstance(body_parts[-1], doc.Line)) {
                    body_parts.pop();
                }
                parts.append(self.indent(self.concat(body_parts), ast_node=<>node));
                parts.append(self.line());
                parts.append(i.gen.doc_ir);
                parts.append(self.space());
            } elif in_body {
                body_parts.append(i.gen.doc_ir);
                if (isinstance(i, uni.Token) and (i.name == Tok.COMMA)) {
                    body_parts.append(self.line());
                }
            } else {
                parts.append(i.gen.doc_ir);
                parts.append(self.space());
            }
        }
        <>node.gen.doc_ir = self.group(
            self.concat(parts, ast_node=<>node), ast_node=<>node
        );
    }

    """Generate DocIR for sub-tag nodes."""
    def exit_sub_tag(self: DocIRGenPass, <>node: uni.SubTag) -> None {
        before_colon: list[doc.DocType] = [];
        after_colon: list[doc.DocType] = [];
        seen_colon = False;
        for i in <>node.kid {
            if (isinstance(i, uni.Token) and (i.name == Tok.COLON) and not seen_colon) {
                colon_tok = i.gen.doc_ir;
                seen_colon = True;
            } elif seen_colon {
                after_colon.append(i.gen.doc_ir);
            } else {
                before_colon.append(i.gen.doc_ir);
            }
        }
        if seen_colon {
            flat = self.concat([*before_colon, colon_tok, self.space(), *after_colon]);
            broke = self.concat(
                [
                    *before_colon,
                    colon_tok,
                    self.indent(self.concat([self.line(), *after_colon]))
                ]
            );
            <>node.gen.doc_ir = self.group(self.if_break(broke, flat));
        } else {
            <>node.gen.doc_ir = self.concat((before_colon + after_colon));
        }
    }

    """Generate DocIR for implementation definitions."""
    def exit_impl_def(self: DocIRGenPass, <>node: uni.ImplDef) -> None {
        parts: list[doc.DocType] = [];
        body_parts: list[doc.DocType] = [];
        in_body = False;
        for i in <>node.kid {
            if ((i == <>node.doc) or (<>node.decorators and (i in <>node.decorators))) {
                parts.append(i.gen.doc_ir);
                parts.append(self.hard_line());
            } elif self.is_within(i, <>node.target) {
                parts.append(i.gen.doc_ir);
            } elif (
                in_body
                or (
                    isinstance(<>node.body, Sequence)
                    and <>node.body
                    and (i == <>node.body[0])
                )
            ) {
                if not in_body {
                    parts.pop();
                    body_parts.append(self.hard_line());
                }
                if (isinstance(i, uni.Token) and (i.name == Tok.COMMA)) {
                    body_parts.pop();
                }
                body_parts.append(i.gen.doc_ir);
                body_parts.append(self.hard_line());
                in_body = True;
                if (
                    in_body
                    and isinstance(<>node.body, Sequence)
                    and (i == <>node.body[-1])
                ) {
                    in_body = False;
                    body_parts.pop();
                    parts.append(self.indent(self.concat(body_parts), ast_node=<>node));
                    parts.append(self.hard_line());
                }
            } elif (isinstance(i, uni.Token) and (i.name == Tok.SEMI)) {
                parts.pop();
                parts.append(i.gen.doc_ir);
                parts.append(self.space());
            } else {
                parts.append(i.gen.doc_ir);
                parts.append(self.space());
            }
        }
        <>node.gen.doc_ir = self.group(
            self.concat(parts, ast_node=<>node), ast_node=<>node
        );
    }

    """Generate DocIR for semantic definitions."""
    def exit_sem_def(self: DocIRGenPass, <>node: uni.SemDef) -> None {
        parts: list[doc.DocType] = [];
        for i in <>node.kid {
            if (i in <>node.target) {
                parts.append(i.gen.doc_ir);
            } elif (isinstance(i, uni.Token) and (i.name == Tok.SEMI)) {
                parts.pop();
                parts.append(i.gen.doc_ir);
                parts.append(self.space());
            } else {
                parts.append(i.gen.doc_ir);
                parts.append(self.space());
            }
        }
        <>node.gen.doc_ir = self.group(
            self.concat(parts, ast_node=<>node), ast_node=<>node
        );
    }

    """Generate DocIR for event signatures."""
    def exit_event_signature(self: DocIRGenPass, <>node: uni.EventSignature) -> None {
        self._assign_space_group(<>node);
    }

    """Generate DocIR for typed context blocks."""
    def exit_typed_ctx_block(self: DocIRGenPass, <>node: uni.TypedCtxBlock) -> None {
        parts: list[doc.DocType] = [];
        for i in <>node.kid {
            parts.append(i.gen.doc_ir);
        }
        <>node.gen.doc_ir = self.group(
            self.concat(parts, ast_node=<>node), ast_node=<>node
        );
    }

    """Generate DocIR for tokens."""
    def exit_token(self: DocIRGenPass, <>node: uni.Token) -> None {
        <>node.gen.doc_ir = self.text(<>node.value, source_token=<>node);
    }

    """Generate DocIR for semicolons."""
    def exit_semi(self: DocIRGenPass, <>node: uni.Semi) -> None {
        <>node.gen.doc_ir = self.text(<>node.value, source_token=<>node);
    }

    """Generate DocIR for names."""
    def exit_name(self: DocIRGenPass, <>node: uni.Name) -> None {
        if <>node.is_kwesc {
            <>node.gen.doc_ir = self.text(f"<>{node.value}", source_token=<>node);
        } else {
            <>node.gen.doc_ir = self.text(<>node.value, source_token=<>node);
        }
    }

    """Generate DocIR for integers."""
    def exit_int(self: DocIRGenPass, <>node: uni.Int) -> None {
        <>node.gen.doc_ir = self.text(<>node.value, source_token=<>node);
    }

    """Generate DocIR for builtin type nodes."""
    def exit_builtin_type(self: DocIRGenPass, <>node: uni.BuiltinType) -> None {
        <>node.gen.doc_ir = self.text(<>node.value, source_token=<>node);
    }

    """Generate DocIR for floats."""
    def exit_float(self: DocIRGenPass, <>node: uni.Float) -> None {
        <>node.gen.doc_ir = self.text(<>node.value, source_token=<>node);
    }

    """Generate DocIR for strings."""
    def exit_string(self: DocIRGenPass, <>node: uni.String) -> None {
        is_escaped_curly = (
            (<>node.lit_value in ['{', '}'])
            and <>node.parent
            and isinstance(<>node.parent, uni.FString)
        );
        if is_escaped_curly {
            <>node.gen.doc_ir = self.concat(
                [
                    self.text(<>node.value, source_token=<>node),
                    self.text(<>node.value, source_token=<>node)
                ]
            );
            return;
        }
        <>node.gen.doc_ir = self.text(<>node.value, source_token=<>node);
    }

    """Generate DocIR for special variable references."""
    def exit_special_var_ref(self: DocIRGenPass, <>node: uni.SpecialVarRef) -> None {
        <>node.gen.doc_ir = self.text(
            <>node.value.replace('_', ''), source_token=<>node
        );
    }

    """Generate DocIR for boolean values."""
    def exit_bool(self: DocIRGenPass, <>node: uni.Bool) -> None {
        <>node.gen.doc_ir = self.text(<>node.value, source_token=<>node);
    }

    """Generate DocIR for null values."""
    def exit_null(self: DocIRGenPass, <>node: uni.Null) -> None {
        <>node.gen.doc_ir = self.text(<>node.value, source_token=<>node);
    }

    """Generate DocIR for ellipsis."""
    def exit_ellipsis(self: DocIRGenPass, <>node: uni.Ellipsis) -> None {
        <>node.gen.doc_ir = self.text(<>node.value, source_token=<>node);
    }

    """Return True if JSX attributes should be split across multiple lines."""
    def _jsx_attrs_need_multiline(self: DocIRGenPass, <>node: uni.JsxElement) -> bool {
        if (len(<>node.attributes) > 1) {
            return True;
        }
        for attr in <>node.attributes {
            if isinstance(attr, uni.JsxNormalAttribute) {
                if ((attr.value is None) or isinstance(attr.value, uni.String)) {
                    continue;
                }
                return True;
            }
            return True;
        }
        return False;
    }

    """Generate DocIR for JSX elements with prettier-inspired formatting."""
    def exit_jsx_element(self: DocIRGenPass, <>node: uni.JsxElement) -> None {
        has_tokens = <>any(isinstance(kid, uni.Token) for kid in <>node.kid);
        if has_tokens {
            first_child = <>node.kid[0] if <>node.kid else None;
            if (
                isinstance(first_child, uni.Token)
                and (first_child.name == Tok.JSX_CLOSE_START)
            ) {
                <>node.gen.doc_ir = self.group(
                    self.concat([kid.gen.doc_ir for kid in <>node.kid])
                );
                return;
            }
            start_token = <>node.kid[0]
            if (<>node.kid and isinstance(<>node.kid[0], uni.Token))
            else None;
            end_token = <>node.kid[-1]
            if (<>node.kid and isinstance(<>node.kid[-1], uni.Token))
            else None;
            if (not start_token or not end_token) {
                <>node.gen.doc_ir = self.group(
                    self.concat([kid.gen.doc_ir for kid in <>node.kid])
                );
                return;
            }
            name_node = next(
                (
                    kid
                    for kid in <>node.kid
                    if isinstance(kid, uni.JsxElementName)
                ),
                None
            );
            attr_docs = [attr.gen.doc_ir for attr in <>node.attributes];
            needs_multiline = self._jsx_attrs_need_multiline(<>node);
            parts: list[doc.DocType] = [start_token.gen.doc_ir];
            if name_node {
                parts.append(name_node.gen.doc_ir);
            }
            if attr_docs {
                if needs_multiline {
                    attr_block: list[doc.DocType] = [self.hard_line()];
                    attr_block.extend(self.intersperse(attr_docs, self.hard_line()));
                    parts.append(self.indent(self.concat(attr_block), ast_node=<>node));
                    parts.append(self.hard_line());
                } else {
                    parts.append(self.space());
                    parts.append(self.join(self.space(), attr_docs));
                }
            }
            is_self_closing = end_token.name == Tok.JSX_SELF_CLOSE;
            if (not is_self_closing and <>node.children) {
                child_parts: list[doc.DocType] = [];
                for child in <>node.children {
                    child_parts.append(child.gen.doc_ir);
                    child_parts.append(self.hard_line());
                }
                self.trim_trailing_line(child_parts);
                inline_child_types = (uni.JsxText, uni.JsxExpression);
                all_inline_children = (
                    <>node.children
                    and all(
                        isinstance(child, inline_child_types)
                        for child in <>node.children
                    )
                );
                if all_inline_children {
                    inline_doc = self.concat(
                        [child.gen.doc_ir for child in <>node.children]
                    );
                    parts.append(
                        self.indent(
                            self.concat([self.hard_line(), inline_doc]),
                            ast_node=<>node
                        )
                    );
                    parts.append(self.hard_line());
                } elif child_parts {
                    parts.append(
                        self.indent(
                            self.concat([self.hard_line(), *child_parts]),
                            ast_node=<>node
                        )
                    );
                    parts.append(self.hard_line());
                }
            }
            if is_self_closing {
                if ((attr_docs and not needs_multiline) or not attr_docs) {
                    parts.append(self.space());
                }
                parts.append(end_token.gen.doc_ir);
            } else {
                parts.append(end_token.gen.doc_ir);
            }
            <>node.gen.doc_ir = self.group(self.concat(parts), ast_node=<>node);
            return;
        }
        if not <>node.kid {
            <>node.gen.doc_ir = self.group(self.concat([]));
            return;
        }
        opening_doc = <>node.kid[0].gen.doc_ir;
        closing_doc = <>node.kid[-1].gen.doc_ir
        if (len(<>node.kid) > 1)
        else self.concat([]);
        child_parts = [];
        for child in <>node.children {
            child_parts.append(child.gen.doc_ir);
            child_parts.append(self.hard_line());
        }
        self.trim_trailing_line(child_parts);
        inline_child_types = (uni.JsxText, uni.JsxExpression);
        all_inline_children = (
            <>node.children
            and all(isinstance(child, inline_child_types) for child in <>node.children)
        );
        parts = [opening_doc];
        if all_inline_children {
            inline_doc = self.concat([child.gen.doc_ir for child in <>node.children]);
            parts.append(
                self.indent(
                    self.concat([self.hard_line(), inline_doc]), ast_node=<>node
                )
            );
            parts.append(self.hard_line());
        } elif child_parts {
            parts.append(
                self.indent(
                    self.concat([self.hard_line(), *child_parts]), ast_node=<>node
                )
            );
            parts.append(self.hard_line());
        }
        parts.append(closing_doc);
        <>node.gen.doc_ir = self.group(self.concat(parts), ast_node=<>node);
    }

    """Generate DocIR for JSX element names."""
    def exit_jsx_element_name(self: DocIRGenPass, <>node: uni.JsxElementName) -> None {
        parts: list[doc.DocType] = [];
        for i in <>node.kid {
            parts.append(i.gen.doc_ir);
        }
        <>node.gen.doc_ir = self.concat(parts, ast_node=<>node);
    }

    """Generate DocIR for JSX spread attributes."""
    def exit_jsx_spread_attribute(
        self: DocIRGenPass, <>node: uni.JsxSpreadAttribute
    ) -> None {
        parts: list[doc.DocType] = [];
        for i in <>node.kid {
            parts.append(i.gen.doc_ir);
        }
        <>node.gen.doc_ir = self.concat(parts, ast_node=<>node);
    }

    """Generate DocIR for JSX normal attributes."""
    def exit_jsx_normal_attribute(
        self: DocIRGenPass, <>node: uni.JsxNormalAttribute
    ) -> None {
        parts: list[doc.DocType] = [];
        for child in <>node.kid {
            parts.append(child.gen.doc_ir);
        }
        <>node.gen.doc_ir = self.concat(parts, ast_node=<>node);
    }

    """Generate DocIR for JSX text."""
    def exit_jsx_text(self: DocIRGenPass, <>node: uni.JsxText) -> None {
        parts: list[doc.DocType] = [];
        for i in <>node.kid {
            parts.append(i.gen.doc_ir);
        }
        <>node.gen.doc_ir = self.concat(parts, ast_node=<>node);
    }

    """Generate DocIR for JSX expressions."""
    def exit_jsx_expression(self: DocIRGenPass, <>node: uni.JsxExpression) -> None {
        parts: list[doc.DocType] = [];
        for i in <>node.kid {
            parts.append(i.gen.doc_ir);
        }
        <>node.gen.doc_ir = self.concat(parts, ast_node=<>node);
    }
}
