"""Initialize the DocIRGenPass."""
impl DocIRGenPass.init(ir_in: uni.Module, prog: Any, cancel_token: Any = None) -> None {
    super.init(ir_in, prog, cancel_token);
}

"""Generate DocIR for JSX expressions."""
impl DocIRGenPass.exit_jsx_expression(<>node: uni.JsxExpression) -> None {
    parts: list[doc.DocType] = [];
    for i in <>node.kid {
        parts.append(i.gen.doc_ir);
    }
    <>node.gen.doc_ir = self.concat(parts, ast_node=<>node);
}

"""Generate DocIR for JSX text."""
impl DocIRGenPass.exit_jsx_text(<>node: uni.JsxText) -> None {
    parts: list[doc.DocType] = [];
    for i in <>node.kid {
        parts.append(i.gen.doc_ir);
    }
    <>node.gen.doc_ir = self.concat(parts, ast_node=<>node);
}

"""Generate DocIR for JSX normal attributes."""
impl DocIRGenPass.exit_jsx_normal_attribute(<>node: uni.JsxNormalAttribute) -> None {
    parts: list[doc.DocType] = [];
    for child in <>node.kid {
        parts.append(child.gen.doc_ir);
    }
    <>node.gen.doc_ir = self.concat(parts, ast_node=<>node);
}

"""Generate DocIR for JSX spread attributes."""
impl DocIRGenPass.exit_jsx_spread_attribute(<>node: uni.JsxSpreadAttribute) -> None {
    parts: list[doc.DocType] = [];
    for i in <>node.kid {
        parts.append(i.gen.doc_ir);
    }
    <>node.gen.doc_ir = self.concat(parts, ast_node=<>node);
}

"""Generate DocIR for JSX element names."""
impl DocIRGenPass.exit_jsx_element_name(<>node: uni.JsxElementName) -> None {
    parts: list[doc.DocType] = [];
    for i in <>node.kid {
        parts.append(i.gen.doc_ir);
    }
    <>node.gen.doc_ir = self.concat(parts, ast_node=<>node);
}

"""Generate DocIR for JSX elements with prettier-inspired formatting."""
impl DocIRGenPass.exit_jsx_element(<>node: uni.JsxElement) -> None {
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
        parts: list[doc.DocType] = [start_token.gen.doc_ir];
        if name_node {
            parts.append(name_node.gen.doc_ir);
        }
        # Use soft lines for attributes - formatter decides based on line length
        if attr_docs {
            # Indent attributes with soft line breaks
            attr_content: list[doc.DocType] = [self.line()];
            attr_content.extend(self.intersperse(attr_docs, self.line()));
            parts.append(self.indent(self.concat(attr_content), ast_node=<>node));
            # When broken: newline before closing bracket; when flat: nothing
            parts.append(self.if_break(self.line(), self.concat([])));
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
                    isinstance(child, inline_child_types) for child in <>node.children
                )
            );
            if all_inline_children {
                inline_doc = self.concat(
                    [child.gen.doc_ir for child in <>node.children]
                );
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
        }
        if is_self_closing {
            # Space before /> when inline, nothing extra when broken (line handles it)
            parts.append(self.if_break(self.concat([]), self.space()));
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
            self.indent(self.concat([self.hard_line(), inline_doc]), ast_node=<>node)
        );
        parts.append(self.hard_line());
    } elif child_parts {
        parts.append(
            self.indent(self.concat([self.hard_line(), *child_parts]), ast_node=<>node)
        );
        parts.append(self.hard_line());
    }
    parts.append(closing_doc);
    <>node.gen.doc_ir = self.group(self.concat(parts), ast_node=<>node);
}

"""Generate DocIR for ellipsis."""
impl DocIRGenPass.exit_ellipsis(<>node: uni.Ellipsis) -> None {
    <>node.gen.doc_ir = self.text(<>node.value, source_token=<>node);
}

"""Generate DocIR for null values."""
impl DocIRGenPass.exit_null(<>node: uni.Null) -> None {
    <>node.gen.doc_ir = self.text(<>node.value, source_token=<>node);
}

"""Generate DocIR for boolean values."""
impl DocIRGenPass.exit_bool(<>node: uni.Bool) -> None {
    <>node.gen.doc_ir = self.text(<>node.value, source_token=<>node);
}

"""Generate DocIR for special variable references."""
impl DocIRGenPass.exit_special_var_ref(<>node: uni.SpecialVarRef) -> None {
    <>node.gen.doc_ir = self.text(<>node.value.replace('_', ''), source_token=<>node);
}

"""Generate DocIR for strings."""
impl DocIRGenPass.exit_string(<>node: uni.String) -> None {
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

"""Generate DocIR for floats."""
impl DocIRGenPass.exit_float(<>node: uni.Float) -> None {
    <>node.gen.doc_ir = self.text(<>node.value, source_token=<>node);
}

"""Generate DocIR for builtin type nodes."""
impl DocIRGenPass.exit_builtin_type(<>node: uni.BuiltinType) -> None {
    <>node.gen.doc_ir = self.text(<>node.value, source_token=<>node);
}

"""Generate DocIR for integers."""
impl DocIRGenPass.exit_int(<>node: uni.Int) -> None {
    <>node.gen.doc_ir = self.text(<>node.value, source_token=<>node);
}

"""Generate DocIR for names."""
impl DocIRGenPass.exit_name(<>node: uni.Name) -> None {
    if <>node.is_kwesc {
        <>node.gen.doc_ir = self.text(f"<>{node.value}", source_token=<>node);
    } else {
        <>node.gen.doc_ir = self.text(<>node.value, source_token=<>node);
    }
}

"""Generate DocIR for semicolons."""
impl DocIRGenPass.exit_semi(<>node: uni.Semi) -> None {
    <>node.gen.doc_ir = self.text(<>node.value, source_token=<>node);
}

"""Generate DocIR for tokens."""
impl DocIRGenPass.exit_token(<>node: uni.Token) -> None {
    <>node.gen.doc_ir = self.text(<>node.value, source_token=<>node);
}

"""Generate DocIR for typed context blocks."""
impl DocIRGenPass.exit_typed_ctx_block(<>node: uni.TypedCtxBlock) -> None {
    parts: list[doc.DocType] = [];
    for i in <>node.kid {
        parts.append(i.gen.doc_ir);
    }
    <>node.gen.doc_ir = self.group(
        self.concat(parts, ast_node=<>node), ast_node=<>node
    );
}

"""Generate DocIR for event signatures."""
impl DocIRGenPass.exit_event_signature(<>node: uni.EventSignature) -> None {
    self._assign_space_group(<>node);
}

"""Generate DocIR for semantic definitions."""
impl DocIRGenPass.exit_sem_def(<>node: uni.SemDef) -> None {
    parts: list[doc.DocType] = [];
    for i in <>node.kid {
        if (i in <>node.target) {
            parts.append(i.gen.doc_ir);
        } elif (isinstance(i, uni.Token) and (i.name == Tok.DOT)) {
            parts.append(i.gen.doc_ir);
        } elif (isinstance(i, uni.Token) and (i.name == Tok.SEMI)) {
            parts.pop();
            parts.append(i.gen.doc_ir);
        } elif (isinstance(i, uni.Token) and (i.name in [Tok.EQ, Tok.KW_IS])) {
            parts.append(self.space());
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

"""Generate DocIR for implementation definitions."""
impl DocIRGenPass.exit_impl_def(<>node: uni.ImplDef) -> None {
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

"""Generate DocIR for sub-tag nodes."""
impl DocIRGenPass.exit_sub_tag(<>node: uni.SubTag) -> None {
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
        # Access modifiers (pub/priv/protect keywords) don't get space after colon
        # Type annotations and other uses get a space after the colon
        is_access_modifier = (
            isinstance(<>node.tag, uni.Token)
            and (<>node.tag.name in [Tok.KW_PUB, Tok.KW_PRIV, Tok.KW_PROT])
        );
        if is_access_modifier {
            flat = self.concat([*before_colon, colon_tok, *after_colon]);
            broke = self.concat(
                [
                    *before_colon,
                    colon_tok,
                    self.indent(self.concat([self.line(), *after_colon]))
                ]
            );
        } else {
            flat = self.concat([*before_colon, colon_tok, self.space(), *after_colon]);
            broke = self.concat(
                [
                    *before_colon,
                    colon_tok,
                    self.indent(self.concat([self.line(), *after_colon]))
                ]
            );
        }
        <>node.gen.doc_ir = self.group(self.if_break(broke, flat));
    } else {
        <>node.gen.doc_ir = self.concat((before_colon + after_colon));
    }
}

"""Generate DocIR for enum declarations."""
impl DocIRGenPass.exit_enum(<>node: uni.Enum) -> None {
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
        } elif isinstance(i, uni.SubTag) {
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

"""Generate DocIR for match architecture patterns."""
impl DocIRGenPass.exit_match_arch(<>node: uni.MatchArch) -> None {
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

"""Generate DocIR for match key-value pairs."""
impl DocIRGenPass.exit_match_k_v_pair(<>node: uni.MatchKVPair) -> None {
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

"""Generate DocIR for match star patterns (e.g., *args, **kwargs)."""
impl DocIRGenPass.exit_match_star(<>node: uni.MatchStar) -> None {
    self._assign_space_group(<>node);
}

"""Generate DocIR for match wildcard patterns."""
impl DocIRGenPass.exit_match_wild(<>node: uni.MatchWild) -> None {
    self._assign_space_group(<>node);
}

"""Generate DocIR for match AS patterns."""
impl DocIRGenPass.exit_match_as(<>node: uni.MatchAs) -> None {
    self._assign_space_group(<>node);
}

"""Generate DocIR for match OR patterns."""
impl DocIRGenPass.exit_match_or(<>node: uni.MatchOr) -> None {
    self._assign_space_group(<>node);
}

"""Generate DocIR for match mapping patterns."""
impl DocIRGenPass.exit_match_mapping(<>node: uni.MatchMapping) -> None {
    self._assign_space_group(<>node);
}

"""Generate DocIR for match sequence patterns."""
impl DocIRGenPass.exit_match_sequence(<>node: uni.MatchSequence) -> None {
    self._assign_space_group(<>node);
}

"""Generate DocIR for match singleton patterns."""
impl DocIRGenPass.exit_match_singleton(<>node: uni.MatchSingleton) -> None {
    self._assign_space_group(<>node);
}

"""Generate DocIR for match value patterns."""
impl DocIRGenPass.exit_match_value(<>node: uni.MatchValue) -> None {
    self._assign_space_group(<>node);
}

"""Generate DocIR for switch cases."""
impl DocIRGenPass.exit_switch_case(<>node: uni.SwitchCase) -> None {
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
        self.indent(self.concat(([self.hard_line()] + indent_parts)), ast_node=<>node)
    );
    <>node.gen.doc_ir = self.group(
        self.concat(parts, ast_node=<>node), ast_node=<>node
    );
}

"""Generate DocIR for switch statements."""
impl DocIRGenPass.exit_switch_stmt(<>node: uni.SwitchStmt) -> None {
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

"""Generate DocIR for match cases."""
impl DocIRGenPass.exit_match_case(<>node: uni.MatchCase) -> None {
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
        self.indent(self.concat(([self.hard_line()] + indent_parts)), ast_node=<>node)
    );
    <>node.gen.doc_ir = self.group(
        self.concat(parts, ast_node=<>node), ast_node=<>node
    );
}

"""Generate DocIR for match statements."""
impl DocIRGenPass.exit_match_stmt(<>node: uni.MatchStmt) -> None {
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
                self.indent(self.concat(match_parts, ast_node=<>node), ast_node=<>node)
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

"""Generate DocIR for test nodes."""
impl DocIRGenPass.exit_test(<>node: uni.Test) -> None {
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

"""Generate DocIR for Python inline code blocks."""
impl DocIRGenPass.exit_py_inline_code(<>node: uni.PyInlineCode) -> None {
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

"""Generate DocIR for assignment comprehensions."""
impl DocIRGenPass.exit_assign_compr(<>node: uni.AssignCompr) -> None {
    parts: list[doc.DocType] = [];
    for i in <>node.kid {
        parts.append(i.gen.doc_ir);
    }
    compact_doc = self.remove_all_spaces(self.concat(parts));
    <>node.gen.doc_ir = self.group(compact_doc);
}

"""Generate DocIR for filter comprehensions."""
impl DocIRGenPass.exit_filter_compr(<>node: uni.FilterCompr) -> None {
    parts: list[doc.DocType] = [];
    for i in <>node.kid {
        parts.append(i.gen.doc_ir);
    }
    compact_doc = self.remove_all_spaces(self.concat(parts));
    <>node.gen.doc_ir = self.group(compact_doc);
}

"""Generate DocIR for expression as item nodes."""
impl DocIRGenPass.exit_expr_as_item(<>node: uni.ExprAsItem) -> None {
    self._assign_space_group(<>node);
}

"""Generate DocIR for atom units (parenthesized expressions)."""
impl DocIRGenPass.exit_atom_unit(<>node: uni.AtomUnit) -> None {
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
            flat_contents=self.group(self.concat(parts[1:-1])), break_contents=broken
        );
    } else {
        <>node.gen.doc_ir = broken;
    }
}

"""Generate DocIR for comparison expressions."""
impl DocIRGenPass.exit_compare_expr(<>node: uni.CompareExpr) -> None {
    self._assign_space_group(<>node);
}

"""Generate DocIR for disconnect operator."""
impl DocIRGenPass.exit_disconnect_op(<>node: uni.DisconnectOp) -> None {
    self._assign_space_group(<>node);
}

"""Generate DocIR for connect operator."""
impl DocIRGenPass.exit_connect_op(<>node: uni.ConnectOp) -> None {
    self._assign_space_group(<>node);
}

"""Generate DocIR for visit statements."""
impl DocIRGenPass.exit_visit_stmt(<>node: uni.VisitStmt) -> None {
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

"""Generate DocIR for nonlocal statements."""
impl DocIRGenPass.exit_non_local_stmt(<>node: uni.NonLocalStmt) -> None {
    self._assign_space_group(<>node);
}

"""Generate DocIR for global statements."""
impl DocIRGenPass.exit_global_stmt(<>node: uni.GlobalStmt) -> None {
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

"""Generate DocIR for module code."""
impl DocIRGenPass.exit_module_code(<>node: uni.ModuleCode) -> None {
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

"""Generate DocIR for client blocks (cl { ... })."""
impl DocIRGenPass.exit_client_block(<>node: uni.ClientBlock) -> None {
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

"""Generate DocIR for server blocks (sv { ... })."""
impl DocIRGenPass.exit_server_block(<>node: uni.ServerBlock) -> None {
    parts: list[doc.DocType] = [];
    body_parts: list[doc.DocType] = [];
    in_body = False;
    prev_body_item: (uni.UniNode | None) = None;
    for i in <>node.kid {
        if (isinstance(i, uni.Token) and (i.name == Tok.KW_SERVER)) {
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

"""Generate DocIR for global variables."""
impl DocIRGenPass.exit_global_vars(<>node: uni.GlobalVars) -> None {
    prefix_parts: list[doc.DocType] = [];
    assignment_parts: list[doc.DocType] = [];
    semi_doc: (doc.DocType | None) = None;
    has_multiple_assignments = len(<>node.assignments) > 1;
    for i in <>node.kid {
        if (i == <>node.doc) {
            prefix_parts.append(i.gen.doc_ir);
            prefix_parts.append(self.hard_line());
        } elif (isinstance(i, uni.Token) and (i.name == Tok.SEMI)) {
            if assignment_parts {
                assignment_parts.pop();
            }
            semi_doc = i.gen.doc_ir;
        } elif (isinstance(i, uni.Token) and (i.name == Tok.COMMA)) {
            assignment_parts.pop();
            assignment_parts.append(i.gen.doc_ir);
            if has_multiple_assignments {
                assignment_parts.append(self.hard_line());
            } else {
                assignment_parts.append(self.space());
            }
        } elif isinstance(i, uni.Assignment) {
            assignment_parts.append(i.gen.doc_ir);
            assignment_parts.append(self.space());
        } elif isinstance(i, uni.SubTag) {
            prefix_parts.pop();
            prefix_parts.append(i.gen.doc_ir);
            prefix_parts.append(self.space());
        } else {
            prefix_parts.append(i.gen.doc_ir);
            prefix_parts.append(self.space());
        }
    }
    self.trim_trailing_line(assignment_parts);
    # Wrap all assignments in Align(n=5) for "glob " alignment
    aligned_assignments = self.align(self.concat(assignment_parts), n=5);
    prefix_parts.append(aligned_assignments);
    if semi_doc {
        prefix_parts.append(semi_doc);
    }
    <>node.gen.doc_ir = self.group(
        self.concat(prefix_parts, ast_node=<>node), ast_node=<>node
    );
}

"""Generate DocIR for raise statements."""
impl DocIRGenPass.exit_raise_stmt(<>node: uni.RaiseStmt) -> None {
    self._assign_space_group(<>node);
}

"""Generate DocIR for assert statements."""
impl DocIRGenPass.exit_assert_stmt(<>node: uni.AssertStmt) -> None {
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

"""Generate DocIR for report statements."""
impl DocIRGenPass.exit_report_stmt(<>node: uni.ReportStmt) -> None {
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

"""Generate DocIR for disengage statements."""
impl DocIRGenPass.exit_disengage_stmt(<>node: uni.DisengageStmt) -> None {
    self._assign_group_concat(<>node);
}

"""Generate DocIR for delete statements."""
impl DocIRGenPass.exit_delete_stmt(<>node: uni.DeleteStmt) -> None {
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

"""Generate DocIR for control statements (break, continue, skip)."""
impl DocIRGenPass.exit_ctrl_stmt(<>node: uni.CtrlStmt) -> None {
    self._assign_group_concat(<>node);
}

"""Generate DocIR for yield expressions."""
impl DocIRGenPass.exit_yield_expr(<>node: uni.YieldExpr) -> None {
    self._assign_space_group(<>node);
}

"""Generate DocIR for await expressions."""
impl DocIRGenPass.exit_await_expr(<>node: uni.AwaitExpr) -> None {
    self._assign_space_group(<>node);
}

"""Generate DocIR for keyword arguments."""
impl DocIRGenPass.exit_k_w_pair(<>node: uni.KWPair) -> None {
    self._assign_group_concat(<>node);
}

"""Generate DocIR for dictionary comprehensions."""
impl DocIRGenPass.exit_dict_compr(<>node: uni.DictCompr) -> None {
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

"""Generate DocIR for set comprehensions."""
impl DocIRGenPass.exit_set_compr(<>node: uni.SetCompr) -> None {
    parts: list[doc.DocType] = [];
    for i in <>node.kid {
        if isinstance(i, uni.InnerCompr) {
            parts.append(self.group(self.concat([self.tight_line(), i.gen.doc_ir])));
        } else {
            parts.append(i.gen.doc_ir);
        }
        parts.append(self.space());
    }
    <>node.gen.doc_ir = self.format_comprehension(parts);
}

"""Generate DocIR for generator comprehensions."""
impl DocIRGenPass.exit_gen_compr(<>node: uni.GenCompr) -> None {
    parts: list[doc.DocType] = [];
    for i in <>node.kid {
        if isinstance(i, uni.InnerCompr) {
            parts.append(self.group(self.concat([self.tight_line(), i.gen.doc_ir])));
        } else {
            parts.append(i.gen.doc_ir);
        }
        parts.append(self.space());
    }
    <>node.gen.doc_ir = self.format_comprehension(parts);
}

"""Generate DocIR for index slices."""
impl DocIRGenPass.exit_index_slice(<>node: uni.IndexSlice) -> None {
    parts: list[doc.DocType] = [];
    for i in <>node.kid {
        parts.append(i.gen.doc_ir);
    }
    <>node.gen.doc_ir = self.group(
        self.concat(parts, ast_node=<>node), ast_node=<>node
    );
}

"""Generate DocIR for edge operation references."""
impl DocIRGenPass.exit_edge_op_ref(<>node: uni.EdgeOpRef) -> None {
    parts: list[doc.DocType] = [];
    for i in <>node.kid {
        parts.append(i.gen.doc_ir);
    }
    <>node.gen.doc_ir = self.group(
        self.concat(parts, ast_node=<>node), ast_node=<>node
    );
}

"""Generate DocIR for edge reference trailers."""
impl DocIRGenPass.exit_edge_ref_trailer(<>node: uni.EdgeRefTrailer) -> None {
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

"""Generate DocIR for lambda expressions."""
impl DocIRGenPass.exit_lambda_expr(<>node: uni.LambdaExpr) -> None {
    parts: list[doc.DocType] = [];
    for i in <>node.kid {
        if (isinstance(i, uni.Token) and (i.name == Tok.RBRACE)) {
            # Don't add trailing space after closing brace of code block lambda
            parts.append(i.gen.doc_ir);
        } elif isinstance(i, uni.Token) {
            parts.append(i.gen.doc_ir);
            parts.append(self.space());
        } elif isinstance(i, uni.Expr) {
            # Add space before body expression (e.g., before { in lambda -> None { ... })
            parts.append(
                self.if_break(
                    self.indent(self.concat([self.line(), i.gen.doc_ir])), i.gen.doc_ir
                )
            );
        } elif isinstance(i, uni.FuncSignature) {
            # For empty params like (), don't add space before
            # For signatures without params (just -> Type), pop the trailing space from lambda keyword
            if (isinstance(i.gen.doc_ir, doc.Text) and (i.gen.doc_ir.text == '()')) {
                parts.append(i.gen.doc_ir);
            } elif not <>node.signature.params {
                # Lambda without params: "lambda -> Type" - don't add extra space
                parts.pop();
                parts.append(i.gen.doc_ir);
                parts.append(self.space());
            } else {
                parts.append(i.gen.doc_ir);
                parts.append(self.space());
            }
        } else {
            parts.append(i.gen.doc_ir);
        }
    }
    <>node.gen.doc_ir = self.group(
        self.concat(parts, ast_node=<>node), ast_node=<>node
    );
}

"""Generate DocIR for unary expressions."""
impl DocIRGenPass.exit_unary_expr(<>node: uni.UnaryExpr) -> None {
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

"""Generate DocIR for boolean expressions (and/or)."""
impl DocIRGenPass.exit_bool_expr(<>node: uni.BoolExpr) -> None {
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

"""Generate DocIR for conditional expressions."""
impl DocIRGenPass.exit_if_else_expr(<>node: uni.IfElseExpr) -> None {
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

"""Generate DocIR for formatted value expressions."""
impl DocIRGenPass.exit_formatted_value(<>node: uni.FormattedValue) -> None {
    parts: list[doc.DocType] = [];
    for i in <>node.kid {
        parts.append(i.gen.doc_ir);
    }
    <>node.gen.doc_ir = self.group(
        self.concat(parts, ast_node=<>node), ast_node=<>node
    );
}

"""Generate DocIR for formatted strings."""
impl DocIRGenPass.exit_f_string(<>node: uni.FString) -> None {
    parts: list[doc.DocType] = [];
    for i in <>node.kid {
        parts.append(i.gen.doc_ir);
    }
    <>node.gen.doc_ir = self.group(
        self.concat(parts, ast_node=<>node), ast_node=<>node
    );
}

"""Generate DocIR for inner comprehension clauses."""
impl DocIRGenPass.exit_inner_compr(<>node: uni.InnerCompr) -> None {
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

"""Generate DocIR for list comprehensions."""
impl DocIRGenPass.exit_list_compr(<>node: uni.ListCompr) -> None {
    parts: list[doc.DocType] = [];
    for i in <>node.kid {
        if isinstance(i, uni.InnerCompr) {
            parts.append(self.group(self.concat([self.tight_line(), i.gen.doc_ir])));
        } else {
            parts.append(i.gen.doc_ir);
        }
        parts.append(self.space());
    }
    <>node.gen.doc_ir = self.format_comprehension(parts);
}

"""Generate DocIR for with statements."""
impl DocIRGenPass.exit_with_stmt(<>node: uni.WithStmt) -> None {
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

"""Generate DocIR for set values."""
impl DocIRGenPass.exit_set_val(<>node: uni.SetVal) -> None {
    parts: list[doc.DocType] = [];
    for i in <>node.kid {
        parts.append(i.gen.doc_ir);
    }
    <>node.gen.doc_ir = self.group(
        self.concat(parts, ast_node=<>node), ast_node=<>node
    );
}

"""Generate DocIR for multiline strings."""
impl DocIRGenPass.exit_multi_string(<>node: uni.MultiString) -> None {
    parts: list[doc.DocType] = [];
    for i in <>node.kid {
        parts.append(i.gen.doc_ir);
    }
    <>node.gen.doc_ir = self.group(
        self.concat(self.intersperse(parts, self.line()), ast_node=<>node),
        ast_node=<>node
    );
}

"""Generate DocIR for tuple values."""
impl DocIRGenPass.exit_tuple_val(<>node: uni.TupleVal) -> None {
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

"""Generate DocIR for finally statements."""
impl DocIRGenPass.exit_finally_stmt(<>node: uni.FinallyStmt) -> None {
    <>node.gen.doc_ir = self.format_simple_stmt_with_body(<>node, <>node.body);
}

"""Generate DocIR for except clauses."""
impl DocIRGenPass.exit_except(<>node: uni.Except) -> None {
    <>node.gen.doc_ir = self.format_simple_stmt_with_body(<>node, <>node.body);
}

"""Generate DocIR for try statements."""
impl DocIRGenPass.exit_try_stmt(<>node: uni.TryStmt) -> None {
    <>node.gen.doc_ir = self.format_simple_stmt_with_body(<>node, <>node.body);
}

"""Generate DocIR for iterative for statements."""
impl DocIRGenPass.exit_iter_for_stmt(<>node: uni.IterForStmt) -> None {
    <>node.gen.doc_ir = self.format_simple_stmt_with_body(<>node, <>node.body);
}

"""Generate DocIR for for-in statements."""
impl DocIRGenPass.exit_in_for_stmt(<>node: uni.InForStmt) -> None {
    <>node.gen.doc_ir = self.format_simple_stmt_with_body(<>node, <>node.body);
}

"""Generate DocIR for while statements."""
impl DocIRGenPass.exit_while_stmt(<>node: uni.WhileStmt) -> None {
    <>node.gen.doc_ir = self.format_simple_stmt_with_body(<>node, <>node.body);
}

"""Generate DocIR for architecture has declarations."""
impl DocIRGenPass.exit_arch_has(<>node: uni.ArchHas) -> None {
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
        } elif isinstance(i, uni.SubTag) {
            parts.pop();
            parts.append(i.gen.doc_ir);
            parts.append(self.space());
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

"""Generate DocIR for has variable declarations."""
impl DocIRGenPass.exit_has_var(<>node: uni.HasVar) -> None {
    parts: list[doc.DocType] = [];
    for i in <>node.kid {
        if (isinstance(i, uni.Token) and (i.name == Tok.EQ)) {
            parts.append(self.space());
            parts.append(i.gen.doc_ir);
            parts.append(self.space());
        } elif (isinstance(i, uni.Token) and (i.name in [Tok.KW_BY, Tok.KW_POST_INIT])) {
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

"""Generate DocIR for key-value pairs."""
impl DocIRGenPass.exit_k_v_pair(<>node: uni.KVPair) -> None {
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

"""Generate DocIR for dictionary values."""
impl DocIRGenPass.exit_dict_val(<>node: uni.DictVal) -> None {
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

"""Generate DocIR for list values."""
impl DocIRGenPass.exit_list_val(<>node: uni.ListVal) -> None {
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
    <>node.gen.doc_ir = self.group(self.if_break(broke, not_broke), ast_node=<>node);
}

"""Generate DocIR for atom trailers."""
impl DocIRGenPass.exit_atom_trailer(<>node: uni.AtomTrailer) -> None {
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

"""Generate DocIR for function calls."""
impl DocIRGenPass.exit_func_call(<>node: uni.FuncCall) -> None {
    parts: list[doc.DocType] = [];
    indent_parts: list[doc.DocType] = [];
    in_params = False;
    for i in <>node.kid {
        if (isinstance(i, uni.Token) and (i.name == Tok.LPAREN) and <>node.params) {
            in_params = True;
            parts.append(i.gen.doc_ir);
        } elif (isinstance(i, uni.Token) and (i.name == Tok.RPAREN) and <>node.params) {
            in_params = False;
            if isinstance(indent_parts[-1], doc.Line) {
                indent_parts.pop();
            }
            parts.append(
                self.indent(
                    self.concat(
                        [self.tight_line(), self.group(self.concat([*indent_parts]))]
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

"""Generate DocIR for return statements."""
impl DocIRGenPass.exit_return_stmt(<>node: uni.ReturnStmt) -> None {
    parts: list[doc.DocType] = [];
    # Check if returning a JSX element directly (not wrapped in parens)
    is_jsx_return = isinstance(<>node.expr, uni.JsxElement);
    for i in <>node.kid {
        if (isinstance(i, uni.Token) and (i.name == Tok.SEMI)) {
            parts.pop();
            parts.append(i.gen.doc_ir);
        } elif (is_jsx_return and isinstance(i, uni.JsxElement)) {
            # For JSX returns, add hard line and indent
            parts.append(self.indent(self.concat([self.hard_line(), i.gen.doc_ir])));
        } else {
            parts.append(i.gen.doc_ir);
        }
        parts.append(self.space());
    }
    <>node.gen.doc_ir = self.group(
        self.concat(parts, ast_node=<>node), ast_node=<>node
    );
}

"""Generate DocIR for concurrent expressions."""
impl DocIRGenPass.exit_concurrent_expr(<>node: uni.ConcurrentExpr) -> None {
    parts: list[doc.DocType] = [];
    for i in <>node.kid {
        parts.append(i.gen.doc_ir);
        parts.append(self.space());
    }
    <>node.gen.doc_ir = self.group(self.concat(parts), ast_node=<>node);
}

"""Generate DocIR for expression statements."""
impl DocIRGenPass.exit_expr_stmt(<>node: uni.ExprStmt) -> None {
    self._assign_group_concat(<>node);
}

"""Generate DocIR for binary expressions."""
impl DocIRGenPass.exit_binary_expr(<>node: uni.BinaryExpr) -> None {
    self._assign_space_group(<>node);
}

"""Generate DocIR for else statements."""
impl DocIRGenPass.exit_else_stmt(<>node: uni.ElseStmt) -> None {
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

"""Generate DocIR for else if statements."""
impl DocIRGenPass.exit_else_if(<>node: uni.ElseIf) -> None {
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

"""Generate DocIR for if statements."""
impl DocIRGenPass.exit_if_stmt(<>node: uni.IfStmt) -> None {
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

"""Generate DocIR for assignments."""
impl DocIRGenPass.exit_assignment(<>node: uni.Assignment) -> None {
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

"""Generate DocIR for type references."""
impl DocIRGenPass.exit_type_ref(<>node: uni.TypeRef) -> None {
    parts: list[doc.DocType] = [];
    for i in <>node.kid {
        parts.append(i.gen.doc_ir);
    }
    <>node.gen.doc_ir = self.group(
        self.concat(parts, ast_node=<>node), ast_node=<>node
    );
}

"""Generate DocIR for parameter variables."""
impl DocIRGenPass.exit_param_var(<>node: uni.ParamVar) -> None {
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

"""Generate DocIR for function signatures."""
impl DocIRGenPass.exit_func_signature(<>node: uni.FuncSignature) -> None {
    parts: list[doc.DocType] = [];
    indent_parts: list[doc.DocType] = [];
    in_params = False;
    has_parens = False;
    # Check for any kind of parameters (regular, varargs, kwargs, etc.)
    has_any_params = (
        <>node.params
        or <>node.varargs
        or <>node.kwargs
        or <>node.kwonlyargs
        or <>node.posonly_params
    );
    for i in <>node.kid {
        if (isinstance(i, uni.Token) and (i.name == Tok.LPAREN) and has_any_params) {
            in_params = True;
            parts.append(i.gen.doc_ir);
        } elif (isinstance(i, uni.Token) and (i.name == Tok.RPAREN) and has_any_params) {
            in_params = False;
            has_parens = True;
            if isinstance(indent_parts[-1], doc.Line) {
                indent_parts.pop();
            }
            parts.append(
                self.indent(
                    self.concat(
                        [self.tight_line(), self.group(self.concat([*indent_parts]))]
                    )
                )
            );
            parts.append(self.tight_line());
            parts.append(i.gen.doc_ir);
            parts.append(self.space());
        } elif (isinstance(i, uni.Token) and (i.name == Tok.RPAREN)) {
            has_parens = True;
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

"""Generate DocIR for abilities."""
impl DocIRGenPass.exit_ability(<>node: uni.Ability) -> None {
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
        } elif (not in_body and isinstance(i, uni.Token) and (i.name == Tok.DECOR_OP)) {
            parts.append(i.gen.doc_ir);
        } elif (isinstance(i, uni.Token) and (i.name == Tok.SEMI)) {
            parts.pop();
            parts.append(i.gen.doc_ir);
            parts.append(self.space());
        } elif isinstance(i, uni.SubTag) {
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

"""Generate DocIR for archetypes."""
impl DocIRGenPass.exit_archetype(<>node: uni.Archetype) -> None {
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
        } elif (isinstance(i, uni.Token) and (i.name == Tok.COMMA)) {
            parts.pop();
            parts.append(i.gen.doc_ir);
            parts.append(self.space());
        } elif (not in_body and isinstance(i, uni.Token) and (i.name == Tok.DECOR_OP)) {
            parts.append(i.gen.doc_ir);
        } elif isinstance(i, uni.SubTag) {
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

"""Generate DocIR for module paths."""
impl DocIRGenPass.exit_module_path(<>node: uni.ModulePath) -> None {
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

"""Generate DocIR for module items."""
impl DocIRGenPass.exit_module_item(<>node: uni.ModuleItem) -> None {
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

"""Exit import node."""
impl DocIRGenPass.exit_import(<>node: uni.Import) -> None {
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

"""Exit module."""
impl DocIRGenPass.exit_module(<>node: uni.Module) -> None {
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
    # Traverse impl modules (.impl.jac files)
    # Only do this for the main module (not annex modules themselves)
    if <>node.annexable_by is None {
        for impl_mod in <>node.impl_mod {
            self.traverse(impl_mod);
        }
    }
}

"""Recursively remove all space nodes from a doc_ir tree."""
impl DocIRGenPass.remove_all_spaces(doc_node: doc.DocType) -> doc.DocType {
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

"""Recursively trim trailing Line (soft or hard) nodes from parts."""
impl DocIRGenPass.trim_trailing_line(parts: list[doc.DocType]) -> None {
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

"""Check if kid node is within the block."""
impl DocIRGenPass.is_within(
    kid_node: uni.UniNode, block: Sequence[uni.UniNode]
) -> bool {
    if not block {
        return False;
    }
    (start, end, kid) = (block[0].loc, block[-1].loc, kid_node.loc);
    first = (
        (start.first_line < kid.first_line)
        or (
            (start.first_line == kid.first_line) and (start.col_start <= kid.col_start)
        )
    );
    last = (
        (end.last_line > kid.last_line)
        or ((end.last_line == kid.last_line) and (end.col_end >= kid.col_end))
    );
    return (first and last);
}

"""Add a body statement preserving single blank lines from source."""
impl DocIRGenPass.add_body_stmt_with_spacing(
    body_parts: list[doc.DocType], current: uni.UniNode, previous: (uni.UniNode | None)
) -> None {
    if (previous and self.has_gap(previous, current)) {
        body_parts.append(self.hard_line());
    }
    body_parts.append(current.gen.doc_ir);
    body_parts.append(self.hard_line());
}

"""Check if there is a gap between the previous and current node."""
impl DocIRGenPass.has_gap(prev_kid: uni.UniNode, curr_kid: uni.UniNode) -> bool {
    return ((prev_kid.loc.last_line + 1) < curr_kid.loc.first_line);
}

"""Check if the node is a one line node."""
impl DocIRGenPass.is_one_line(<>node: uni.UniNode) -> bool {
    return (
        bool(<>node.kid)
        and (<>node.kid[0].loc.first_line == <>node.kid[-1].loc.last_line)
    );
}

"""
        Format comprehension with defensive checks.

        Expected structure: [opening, space, expr, space, inner_compr..., space, closing, space]
        We need to remove spaces adjacent to brackets.
"""
impl DocIRGenPass.format_comprehension(parts: list[doc.DocType]) -> doc.DocType {
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
        if (middle and isinstance(middle[-1], doc.Text) and (middle[-1].text == ' ')) {
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

"""
        Format a simple statement with a body block (while/for/try/etc).

        Common pattern for statements that have:
        - keyword + condition/target
        - body block
        - possible trailing elements
"""
impl DocIRGenPass.format_simple_stmt_with_body(
    <>node: uni.UniNode, body: Sequence[uni.UniNode], space_between_parts: bool = True
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

"""Intersperse separator between items (returns flat list)."""
impl DocIRGenPass.intersperse(
    items: list[doc.DocType], separator: doc.DocType
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

"""Assign a grouped, space-joined document for the children."""
impl DocIRGenPass._assign_space_group(<>node: uni.UniNode) -> None {
    <>node.gen.doc_ir = self.group(
        self.join_with_space(self._child_docs(<>node)), ast_node=<>node
    );
}

"""Assign a grouped Concat of child documents."""
impl DocIRGenPass._assign_group_concat(<>node: uni.UniNode) -> None {
    <>node.gen.doc_ir = self.group(
        self.concat(self._child_docs(<>node), ast_node=<>node), ast_node=<>node
    );
}

"""Assign a simple Concat of child documents."""
impl DocIRGenPass._assign_concat(<>node: uni.UniNode) -> None {
    <>node.gen.doc_ir = self.concat(self._child_docs(<>node), ast_node=<>node);
}

"""Return generated DocIR for each child."""
impl DocIRGenPass._child_docs(<>node: uni.UniNode) -> list[doc.DocType] {
    docs: list[doc.DocType] = [];
    for kid in <>node.kid {
        docs.append(kid.gen.doc_ir);
    }
    return docs;
}

"""Join parts with line separator."""
impl DocIRGenPass.join_with_line(parts: list[doc.DocType]) -> doc.DocType {
    return self.join(self.line(), parts);
}

"""Join parts with space separator."""
impl DocIRGenPass.join_with_space(parts: list[doc.DocType]) -> doc.DocType {
    return self.join(self.space(), parts);
}

"""Join parts with separator."""
impl DocIRGenPass.join(separator: doc.DocType, parts: list[doc.DocType]) -> doc.DocType {
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

"""Create an Align node."""
impl DocIRGenPass.align(contents: doc.DocType, n: (int | None) = None) -> doc.Align {
    return doc.Align(contents, n);
}

"""Create an IfBreak node."""
impl DocIRGenPass.if_break(
    break_contents: doc.DocType, flat_contents: doc.DocType
) -> doc.IfBreak {
    return doc.IfBreak(break_contents, flat_contents);
}

"""Create a Concat node."""
impl DocIRGenPass.concat(
    parts: list[doc.DocType], ast_node: (uni.UniNode | None) = None
) -> doc.Concat {
    return doc.Concat(parts, ast_node=ast_node);
}

"""Create an Indent node."""
impl DocIRGenPass.indent(
    contents: doc.DocType, ast_node: (uni.UniNode | None) = None
) -> doc.Indent {
    return doc.Indent(contents, ast_node=ast_node);
}

"""
        Create a Group node.

        Args:
            contents: The contents to group
            break_contiguous: If True, break when parent group breaks (currently unused in formatter)
            ast_node: Optional reference to the AST node this represents
"""
impl DocIRGenPass.group(
    contents: doc.DocType,
    break_contiguous: bool = False,
    ast_node: (uni.UniNode | None) = None
) -> doc.Group {
    return doc.Group(contents, break_contiguous, ast_node=ast_node);
}

"""Create a literal line break."""
impl DocIRGenPass.literal_line -> doc.Line {
    return doc.Line(literal=True);
}

"""Create a tight line break."""
impl DocIRGenPass.tight_line -> doc.Line {
    return doc.Line(tight=True);
}

"""Create a hard line break."""
impl DocIRGenPass.hard_line -> doc.Line {
    return doc.Line(hard=True);
}

"""Create a Line node."""
impl DocIRGenPass.line(hard: bool = False, literal: bool = False) -> doc.Line {
    return doc.Line(hard, literal);
}

"""Create a space node."""
impl DocIRGenPass.space -> doc.Text {
    return doc.Text(' ');
}

"""Create a Text node."""
impl DocIRGenPass.text(text: str, source_token: (uni.Token | None) = None) -> doc.Text {
    return doc.Text(text, source_token=source_token);
}
