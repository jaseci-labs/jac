impl DocIRGenPass.exit_jsx_expression with uni.JsxExpression exit {
    parts: list[doc.DocType] = [];
    for i in here.kid {
        parts.append(i.gen.doc_ir);
    }
    here.gen.doc_ir = self.concat(parts, ast_node=here);
}

impl DocIRGenPass.exit_jsx_slot with uni.JsxSlot exit {
    parts: list[doc.DocType] = [];
    for i in here.kid {
        parts.append(i.gen.doc_ir);
    }
    here.gen.doc_ir = self.concat(parts, ast_node=here);
}

impl DocIRGenPass.exit_jsx_text with uni.JsxText exit {
    first_kid = here.kid[0] if here.kid else None;
    source_tok = first_kid if isinstance(first_kid, uni.Token) else None;
    here.gen.doc_ir = doc.Text(here.get_normalized_text(), source_token=source_tok);
}

impl DocIRGenPass.exit_jsx_comment with uni.JsxComment exit {
    first_kid = here.kid[0] if here.kid else None;
    source_tok = first_kid if isinstance(first_kid, uni.Token) else None;
    raw = here.value.value if isinstance(here.value, uni.Token) else str(here.value);
    here.gen.doc_ir = doc.Text(raw, source_token=source_tok);
}

impl DocIRGenPass.jsx_whitespace -> doc.DocType {
    return self.if_break(
        self.concat([self.text('{" "}'), self.tight_line()]), self.space()
    );
}

impl DocIRGenPass.jsx_mixed_child_parts(
    children: Sequence[uni.UniNode]
) -> list[doc.DocType] {
    parts: list[doc.DocType] = [];

    pending = "";
    have_content = False;
    for child in children {
        content: (doc.DocType | None) = None;
        trail = "";
        if isinstance(child, uni.JsxText) {
            norm = child.get_normalized_text();
            if norm == "" {
                if pending != "space" {
                    pending = "break";
                }
                continue;
            } elif norm.strip(" ") == "" {
                pending = "space";
                continue;
            }
            if norm.startswith(" ") {
                pending = "space";
            }
            trail = "space" if norm.endswith(" ") else "";
            content = self.text(norm.strip(" "));
        } else {
            if isinstance(child, uni.JsxExpression) {
                expr = child.expr;
                is_ws = False;
                if isinstance(expr, uni.String) {
                    is_ws = expr.lit_value == " ";
                } elif isinstance(expr, uni.MultiString) {
                    is_ws = expr.lit_value == " ";
                }
                if is_ws {
                    pending = "space";
                    continue;
                }
            }
            content = child.gen.doc_ir;
        }
        if have_content {
            parts.append(
                self.jsx_whitespace() if pending == "space" else self.hard_line()
            );
        }
        parts.append(content);
        have_content = True;
        pending = trail;
    }
    return parts;
}

impl DocIRGenPass.exit_jsx_normal_attribute with uni.JsxNormalAttribute exit {
    parts: list[doc.DocType] = [];
    for child in here.kid {
        parts.append(child.gen.doc_ir);
    }
    here.gen.doc_ir = self.concat(parts, ast_node=here);
}

impl DocIRGenPass.exit_jsx_spread_attribute with uni.JsxSpreadAttribute exit {
    parts: list[doc.DocType] = [];
    for i in here.kid {
        parts.append(i.gen.doc_ir);
    }
    here.gen.doc_ir = self.concat(parts, ast_node=here);
}

impl DocIRGenPass.exit_jsx_element_name with uni.JsxElementName exit {
    parts: list[doc.DocType] = [];
    for i in here.kid {
        parts.append(i.gen.doc_ir);
    }
    here.gen.doc_ir = self.concat(parts, ast_node=here);
}

impl DocIRGenPass.exit_jsx_element with uni.JsxElement exit {
    has_tokens = any(isinstance(kid, uni.Token) for kid in here.kid);
    if has_tokens {
        first_child = here.kid[0] if here.kid else None;
        if (
            isinstance(first_child, uni.Token)
            and (first_child.name == Tok.JSX_CLOSE_START)
        ) {
            here.gen.doc_ir = self.group(
                self.concat([kid.gen.doc_ir for kid in here.kid])
            );
            return;
        }
        start_token = here.kid[0]
            if (here.kid and isinstance(here.kid[0], uni.Token))
            else None;
        end_token = here.kid[-1]
            if (here.kid and isinstance(here.kid[-1], uni.Token))
            else None;
        if (not start_token or not end_token) {
            here.gen.doc_ir = self.group(
                self.concat([kid.gen.doc_ir for kid in here.kid])
            );
            return;
        }
        name_kids = [
            kid
            for kid in here.kid
            if isinstance(kid, uni.JsxElementName)
        ];
        name_node = name_kids[0] if name_kids else None;
        attr_docs = [attr.gen.doc_ir for attr in here.attributes];
        parts: list[doc.DocType] = [start_token.gen.doc_ir];
        if name_node {
            parts.append(name_node.gen.doc_ir);
        } elif not here.is_fragment {
            for k in here.kid[1:] {
                if (
                    isinstance(k, uni.JsxNormalAttribute)
                    or isinstance(k, uni.JsxSpreadAttribute)
                    or (
                        isinstance(k, uni.Token)
                        and k.name in (Tok.JSX_TAG_END, Tok.JSX_SELF_CLOSE)
                    )
                ) {
                    break;
                }
                parts.append(k.gen.doc_ir);
            }
        }

        if attr_docs {
            attr_content: list[doc.DocType] = [self.line()];
            attr_content.extend(self.intersperse(attr_docs, self.line()));
            attr_group = self.group(
                self.concat(
                    [
                        self.indent(self.concat(attr_content), ast_node=here),
                        self.if_break(self.line(), self.concat([]))
                    ]
                ),
                ast_node=here
            );
            parts.append(attr_group);
        }
        is_self_closing = end_token.name == Tok.JSX_SELF_CLOSE;
        open_end_tok: (uni.Token | None) = None;
        close_start_idx = -1;
        for (_ki, _kn) in enumerate(here.kid) {
            if not isinstance(_kn, uni.Token) {
                continue;
            }
            if open_end_tok is None
                and _kn.name in (Tok.JSX_TAG_END, Tok.JSX_SELF_CLOSE) {
                open_end_tok = _kn;
            }
            if _kn.value == "</" {
                close_start_idx = _ki;
            }
        }
        if (not is_self_closing and close_start_idx > 0 and open_end_tok is not None) {
            parts.append(open_end_tok.gen.doc_ir);
        }
        if (not is_self_closing and here.children) {
            child_parts = self.jsx_mixed_child_parts(here.children);
            inline_child_types = (uni.JsxText, uni.JsxExpression, uni.JsxComment);
            all_inline_children = bool(here.children)
                and all(
                    isinstance(child, inline_child_types) for child in here.children
                );

            if all_inline_children {
                inline_doc = self.concat([child.gen.doc_ir for child in here.children]);
                parts.append(
                    self.group(
                        self.concat(
                            [
                                self.indent(
                                    self.concat([self.tight_line(), inline_doc]),
                                    ast_node=here
                                ),
                                self.tight_line()
                            ]
                        ),
                        break_contiguous=True,
                        ast_node=here
                    )
                );
            } elif child_parts {
                has_jsx_ws = any(isinstance(p, doc.IfBreak) for p in child_parts);
                lead = self.tight_line() if has_jsx_ws else self.hard_line();
                tail = self.tight_line() if has_jsx_ws else self.hard_line();
                parts.append(
                    self.group(
                        self.concat(
                            [
                                self.indent(
                                    self.concat([lead, *child_parts]), ast_node=here
                                ),
                                tail
                            ]
                        ),
                        break_contiguous=True,
                        ast_node=here
                    )
                );
            }
        }
        if is_self_closing {
            parts.append(self.if_break(self.concat([]), self.space()));
            parts.append(end_token.gen.doc_ir);
        } elif close_start_idx > 0 {
            for _ck in here.kid[close_start_idx:] {
                parts.append(_ck.gen.doc_ir);
            }
        } else {
            parts.append(end_token.gen.doc_ir);
        }
        here.gen.doc_ir = self.group(self.concat(parts), ast_node=here);
        return;
    }
    if not here.kid {
        here.gen.doc_ir = self.group(self.concat([]));
        return;
    }
    opening_doc = here.kid[0].gen.doc_ir;
    closing_doc = here.kid[-1].gen.doc_ir if (len(here.kid) > 1) else self.concat([]);
    children: Sequence[uni.UniNode] = here.children or [];
    child_parts = self.jsx_mixed_child_parts(children);
    inline_child_types = (uni.JsxText, uni.JsxExpression);
    all_inline_children = bool(children)
        and all(isinstance(child, inline_child_types) for child in children);
    parts = [opening_doc];

    if all_inline_children {
        inline_doc = self.concat([child.gen.doc_ir for child in children]);
        parts.append(
            self.group(
                self.concat(
                    [
                        self.indent(
                            self.concat([self.tight_line(), inline_doc]), ast_node=here
                        ),
                        self.tight_line()
                    ]
                ),
                break_contiguous=True,
                ast_node=here
            )
        );
    } elif child_parts {
        has_jsx_ws = any(isinstance(p, doc.IfBreak) for p in child_parts);
        lead = self.tight_line() if has_jsx_ws else self.hard_line();
        tail = self.tight_line() if has_jsx_ws else self.hard_line();
        parts.append(
            self.group(
                self.concat(
                    [
                        self.indent(self.concat([lead, *child_parts]), ast_node=here),
                        tail
                    ]
                ),
                break_contiguous=True,
                ast_node=here
            )
        );
    }
    parts.append(closing_doc);
    here.gen.doc_ir = self.group(self.concat(parts), ast_node=here);
}

impl DocIRGenPass.exit_ellipsis with uni.Ellipsis exit {
    here.gen.doc_ir = self.text(here.value, source_token=here);
}

impl DocIRGenPass.exit_null with uni.Null exit {
    here.gen.doc_ir = self.text(here.value, source_token=here);
}

impl DocIRGenPass.exit_bool with uni.Bool exit {
    here.gen.doc_ir = self.text(here.value, source_token=here);
}

impl DocIRGenPass.exit_special_var_ref with uni.SpecialVarRef exit {
    here.gen.doc_ir = self.text(here.value.replace('_', ''), source_token=here);
}

impl DocIRGenPass.exit_string with uni.String exit {
    is_escaped_curly = (
        (here.lit_value in ['{', '}'])
        and here.parent
        and isinstance(here.parent, uni.FString)
    );
    if is_escaped_curly {
        here.gen.doc_ir = self.concat(
            [
                self.text(here.value, source_token=here),
                self.text(here.value, source_token=here)
            ]
        );
        return;
    }
    here.gen.doc_ir = self.text(here.value, source_token=here);
}

impl DocIRGenPass.exit_float with uni.Float exit {
    here.gen.doc_ir = self.text(here.value, source_token=here);
}

impl DocIRGenPass.exit_builtin_type with uni.BuiltinType exit {
    here.gen.doc_ir = self.text(here.value, source_token=here);
}

impl DocIRGenPass.exit_int with uni.Int exit {
    here.gen.doc_ir = self.text(here.value, source_token=here);
}

impl DocIRGenPass.exit_name with uni.Name exit {
    if here.__class__ is not uni.Name {
        return;
    }
    name_text = f"`{here.value}" if here.is_kwesc else here.value;
    by_kids = [
        k
        for k in here.kid
        if (isinstance(k, uni.Token) and (k.name == Tok.KW_BY))
    ];
    by_kid = by_kids[0] if by_kids else None;
    if by_kid is not None {
        semi_kids = [
            k
            for k in here.kid
            if isinstance(k, uni.Semi)
        ];
        semi_kid = semi_kids[0] if semi_kids else None;
        parts: list[doc.DocType] = [
            by_kid.gen.doc_ir,
            self.space(),
            self.text(name_text, source_token=here)
        ];
        if semi_kid is not None {
            parts.append(semi_kid.gen.doc_ir);
        }
        here.gen.doc_ir = self.concat(parts, ast_node=here);
    } else {
        here.gen.doc_ir = self.text(name_text, source_token=here);
    }
}

impl DocIRGenPass.exit_semi with uni.Semi exit {
    here.gen.doc_ir = self.text(here.value, source_token=here);
}

impl DocIRGenPass.exit_token with uni.Token exit {
    if here.__class__ is not uni.Token {
        return;
    }
    here.gen.doc_ir = self.text(here.value, source_token=here);
}

impl DocIRGenPass.exit_typed_ctx_block with uni.TypedCtxBlock exit {
    self._assign_group_concat(here);
}

impl DocIRGenPass.exit_event_signature with uni.EventSignature exit {
    self._assign_space_group(here);
}

impl DocIRGenPass.exit_sem_def with uni.SemDef exit {
    parts: list[doc.DocType] = [];
    for i in here.kid {
        if (i in here.target) {
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
    here.gen.doc_ir = self.group(self.concat(parts, ast_node=here), ast_node=here);
}

impl DocIRGenPass.exit_impl_def with uni.ImplDef exit {
    parts: list[doc.DocType] = [];
    body_parts: list[doc.DocType] = [];
    in_body = False;
    prev_body_item: (uni.UniNode | None) = None;
    for i in here.kid {
        if ((i == here.doc) or (here.decorators and (i in here.decorators))) {
            parts.append(i.gen.doc_ir);
            parts.append(self.hard_line());
        } elif self.is_within(i, here.target) {
            parts.append(i.gen.doc_ir);
        } elif (
            isinstance(i, uni.Token)
            and (i.name == Tok.DOT)
            and here.target
            and len(here.target) > 1
        ) {
            parts.append(i.gen.doc_ir);
        } elif (
            in_body
            or (isinstance(here.body, Sequence) and here.body and (i == here.body[0]))
        ) {
            if not in_body {
                parts.pop();
                body_parts.append(self.hard_line());
            }
            if (isinstance(i, uni.Token) and (i.name == Tok.COMMA)) {
                body_parts.pop();
                body_parts.append(i.gen.doc_ir);
                body_parts.append(self.hard_line());
            } else {
                self.add_body_stmt_with_spacing(body_parts, i, prev_body_item);
                prev_body_item = i;
            }
            in_body = True;
            if (in_body and isinstance(here.body, Sequence) and (i == here.body[-1])) {
                in_body = False;
                self.trim_trailing_line(body_parts);
                parts.append(self.indent(self.concat(body_parts), ast_node=here));
                parts.append(self.hard_line());
            }
        } elif (isinstance(i, uni.Token) and (i.name == Tok.SEMI)) {
            parts.pop();
            parts.append(i.gen.doc_ir);
            parts.append(self.space());
        } elif (isinstance(i, uni.Token) and (i.name == Tok.DECOR_OP)) {
            parts.append(i.gen.doc_ir);
        } elif isinstance(i, uni.EventSignature) {
            parts.append(self.space());
            parts.append(i.gen.doc_ir);
            parts.append(self.space());
        } elif (
            isinstance(i, uni.Token)
            and (i.name == Tok.LBRACE)
            and isinstance(here.body, Sequence)
            and not here.body
        ) {
            parts.append(i.gen.doc_ir);
        } else {
            parts.append(i.gen.doc_ir);
            parts.append(self.space());
        }
    }
    here.gen.doc_ir = self.group(self.concat(parts, ast_node=here), ast_node=here);
}

impl DocIRGenPass.exit_sub_tag with uni.SubTag exit {
    before_colon: list[doc.DocType] = [];
    after_colon: list[doc.DocType] = [];
    seen_colon = False;
    prev_after: (uni.UniNode | None) = None;
    for i in here.kid {
        if (isinstance(i, uni.Token) and (i.name == Tok.COLON) and not seen_colon) {
            colon_tok = i.gen.doc_ir;
            seen_colon = True;
        } elif seen_colon {
            if after_colon
                and not (
                    isinstance(prev_after, uni.Token)
                    and (prev_after.name == Tok.BW_AND)
                ) {
                after_colon.append(self.space());
            }
            after_colon.append(i.gen.doc_ir);
            prev_after = i;
        } else {
            before_colon.append(i.gen.doc_ir);
        }
    }
    if seen_colon {
        is_access_modifier = (
            isinstance(here.tag, uni.Token)
            and (here.tag.name in [Tok.KW_PUB, Tok.KW_PRIV, Tok.KW_PROT])
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
        here.gen.doc_ir = self.group(self.if_break(broke, flat));
    } else {
        here.gen.doc_ir = self.concat((before_colon + after_colon));
    }
}

impl DocIRGenPass.exit_enum with uni.Enum exit {
    parts: list[doc.DocType] = [];
    body_parts: list[doc.DocType] = [];
    in_body = False;
    for i in here.kid {
        if (
            (here.doc and (i is here.doc))
            or (here.decorators and (i in here.decorators))
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
            parts.append(self.indent(self.concat(body_parts), ast_node=here));
            parts.append(self.line());
            parts.append(i.gen.doc_ir);
            parts.append(self.space());
        } elif in_body {
            body_parts.append(i.gen.doc_ir);
            if (isinstance(i, uni.Token) and (i.name == Tok.COMMA)) {
                body_parts.append(self.line());
            }
        } elif (isinstance(i, uni.Token) and (i.name == Tok.COLON)) {
            parts.pop();
            parts.append(i.gen.doc_ir);
            parts.append(self.space());
        } elif (isinstance(i, uni.Token) and (i.name == Tok.LPAREN)) {
            parts.pop();
            parts.append(i.gen.doc_ir);
        } elif (isinstance(i, uni.Token) and (i.name == Tok.RPAREN)) {
            parts.pop();
            parts.append(i.gen.doc_ir);
            parts.append(self.space());
        } elif (isinstance(i, uni.Token) and (i.name == Tok.COMMA)) {
            parts.pop();
            parts.append(i.gen.doc_ir);
            parts.append(self.space());
        } elif isinstance(i, uni.SubTag) {
            parts.pop();
            parts.append(i.gen.doc_ir);
            parts.append(self.space());
        } elif (isinstance(i, uni.Token) and (i.name == Tok.DECOR_OP)) {
            parts.append(i.gen.doc_ir);
        } else {
            parts.append(i.gen.doc_ir);
            parts.append(self.space());
        }
    }
    here.gen.doc_ir = self.group(self.concat(parts, ast_node=here), ast_node=here);
}

impl DocIRGenPass.exit_match_arch with uni.MatchArch exit {
    parts: list[doc.DocType] = [];
    for i in here.kid {
        if (isinstance(i, uni.Token) and (i.name == Tok.COMMA)) {
            parts.append(i.gen.doc_ir);
            parts.append(self.space());
        } else {
            parts.append(i.gen.doc_ir);
        }
    }
    here.gen.doc_ir = self.group(self.concat(parts, ast_node=here), ast_node=here);
}

impl DocIRGenPass.exit_match_k_v_pair with uni.MatchKVPair exit {
    parts: list[doc.DocType] = [];
    for i in here.kid {
        if (isinstance(i, uni.Token) and (i.name in [Tok.STAR_POW, Tok.STAR_MUL])) {
            parts.append(i.gen.doc_ir);
        } else {
            parts.append(i.gen.doc_ir);
            parts.append(self.space());
        }
    }
    parts.pop();
    here.gen.doc_ir = self.group(self.concat(parts, ast_node=here), ast_node=here);
}

impl DocIRGenPass.exit_match_star with uni.MatchStar exit {
    self._assign_space_group(here);
}

impl DocIRGenPass.exit_match_wild with uni.MatchWild exit {
    self._assign_space_group(here);
}

impl DocIRGenPass.exit_match_as with uni.MatchAs exit {
    self._assign_space_group(here);
}

impl DocIRGenPass.exit_match_or with uni.MatchOr exit {
    operands: list[uni.UniNode] = [];
    ops: list[uni.UniNode] = [];
    for i in here.kid {
        if (isinstance(i, uni.Token) and (i.name == Tok.BW_OR)) {
            ops.append(i);
        } else {
            operands.append(i);
        }
    }
    if len(operands) != (len(ops) + 1) {
        self._assign_space_group(here);
        return;
    }
    self._assign_operator_chain(here, operands, ops);
}

impl DocIRGenPass.exit_match_mapping with uni.MatchMapping exit {
    self._assign_space_group(here);
}

impl DocIRGenPass.exit_match_sequence with uni.MatchSequence exit {
    self._assign_space_group(here);
}

impl DocIRGenPass.exit_match_singleton with uni.MatchSingleton exit {
    self._assign_space_group(here);
}

impl DocIRGenPass.exit_match_value with uni.MatchValue exit {
    self._assign_space_group(here);
}

impl DocIRGenPass.exit_switch_case with uni.SwitchCase exit {
    parts: list[doc.DocType] = [];
    indent_parts: list[doc.DocType] = [];
    prev_body_item: (uni.UniNode | None) = None;
    for i in here.kid {
        if (isinstance(i, uni.Token) and (i.name == Tok.COLON)) {
            parts.pop();
            parts.append(i.gen.doc_ir);
        } elif (i in here.body) {
            self.add_body_stmt_with_spacing(indent_parts, i, prev_body_item);
            prev_body_item = i;
        } else {
            parts.append(i.gen.doc_ir);
            parts.append(self.space());
        }
    }
    parts.append(
        self.indent(self.concat(([self.hard_line()] + indent_parts)), ast_node=here)
    );
    here.gen.doc_ir = self.group(self.concat(parts, ast_node=here), ast_node=here);
}

impl DocIRGenPass._assign_case_block_doc_ir(
    nd: (uni.SwitchStmt | uni.MatchStmt)
) -> None {
    parts: list[doc.DocType] = [];
    case_parts: list[doc.DocType] = [self.hard_line()];
    for i in nd.kid {
        if (i == nd.target) {
            parts.append(i.gen.doc_ir);
            parts.append(self.space());
        } elif isinstance(i, (uni.SwitchCase, uni.MatchCase)) {
            case_parts.append(i.gen.doc_ir);
            case_parts.append(self.hard_line());
        } elif (isinstance(i, uni.Token) and (i.name == Tok.RBRACE)) {
            if (case_parts and isinstance(case_parts[-1], doc.Line)) {
                case_parts.pop();
            }
            parts.append(
                self.indent(self.concat(case_parts, ast_node=nd), ast_node=nd)
            );
            parts.append(self.hard_line());
            parts.append(i.gen.doc_ir);
            parts.append(self.space());
        } else {
            parts.append(i.gen.doc_ir);
            parts.append(self.space());
        }
    }
    nd.gen.doc_ir = self.group(self.concat(parts, ast_node=nd), ast_node=nd);
}

impl DocIRGenPass.exit_switch_stmt with uni.SwitchStmt exit {
    self._assign_case_block_doc_ir(here);
}

impl DocIRGenPass.exit_match_case with uni.MatchCase exit {
    parts: list[doc.DocType] = [];
    indent_parts: list[doc.DocType] = [];
    prev_body_item: (uni.UniNode | None) = None;
    for i in here.kid {
        if (isinstance(i, uni.Token) and (i.name == Tok.COLON)) {
            parts.pop();
            parts.append(i.gen.doc_ir);
        } elif (i in here.body) {
            self.add_body_stmt_with_spacing(indent_parts, i, prev_body_item);
            prev_body_item = i;
        } else {
            parts.append(i.gen.doc_ir);
            parts.append(self.space());
        }
    }
    parts.append(
        self.indent(self.concat(([self.hard_line()] + indent_parts)), ast_node=here)
    );
    here.gen.doc_ir = self.group(self.concat(parts, ast_node=here), ast_node=here);
}

impl DocIRGenPass.exit_match_stmt with uni.MatchStmt exit {
    self._assign_case_block_doc_ir(here);
}

impl DocIRGenPass.exit_test with uni.Test exit {
    parts: list[doc.DocType] = [];
    body_parts: list[doc.DocType] = [];
    in_body = False;
    prev_body_item: (uni.UniNode | None) = None;
    for i in here.kid {
        if (i == here.doc) {
            parts.append(i.gen.doc_ir);
            parts.append(self.hard_line());
        } elif (here.description is not None and i == here.description) {
            parts.append(i.gen.doc_ir);
            parts.append(self.space());
        } elif ((i == here.name) and isinstance(i, uni.Name)) {
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
            parts.append(self.indent(self.concat(body_parts), ast_node=here));
            if (len(body_parts) > 0) {
                parts.append(self.hard_line());
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
    here.gen.doc_ir = self.group(self.concat(parts, ast_node=here), ast_node=here);
}

impl DocIRGenPass.exit_py_inline_code with uni.PyInlineCode exit {
    parts: list[doc.DocType] = [];
    for i in here.kid {
        if (i == here.doc) {
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
    here.gen.doc_ir = self.group(self.concat(parts, ast_node=here), ast_node=here);
}

impl DocIRGenPass.exit_assign_compr with uni.AssignCompr exit {
    parts: list[doc.DocType] = [];
    for i in here.kid {
        if isinstance(i, uni.Token) and i.name == Tok.COMMA {
            parts.append(doc.Text(", "));
        } else {
            parts.append(self.remove_all_spaces(i.gen.doc_ir));
        }
    }
    here.gen.doc_ir = self.group(self.concat(parts));
}

impl DocIRGenPass.exit_filter_compr with uni.FilterCompr exit {
    parts: list[doc.DocType] = [];
    for i in here.kid {
        if isinstance(i, uni.Token) and i.name == Tok.COMMA {
            parts.append(doc.Text(", "));
        } else {
            parts.append(self.remove_all_spaces(i.gen.doc_ir));
        }
    }
    here.gen.doc_ir = self.group(self.concat(parts));
}

impl DocIRGenPass.exit_expr_as_item with uni.ExprAsItem exit {
    self._assign_space_group(here);
}

impl DocIRGenPass.exit_atom_unit with uni.AtomUnit exit {
    parts: list[doc.DocType] = [];
    prev_item: (uni.UniNode | None) = None;
    for i in here.kid {
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
        isinstance(here.parent, uni.Assignment)
        or (
            isinstance(here.parent, uni.IfStmt) and isinstance(here.value, uni.BoolExpr)
        )
    ) {
        here.gen.doc_ir = self.if_break(
            flat_contents=self.group(self.concat(parts[1:-1])), break_contents=broken
        );
    } else {
        here.gen.doc_ir = broken;
    }
}

impl DocIRGenPass.exit_compare_expr with uni.CompareExpr exit {
    self._assign_operator_chain(here, [here.left] + list(here.rights), list(here.ops));
}

impl DocIRGenPass.exit_disconnect_op with uni.DisconnectOp exit {
    self._assign_space_group(here);
}

impl DocIRGenPass.exit_connect_op with uni.ConnectOp exit {
    self._assign_group_concat(here);
}

impl DocIRGenPass.exit_visit_stmt with uni.VisitStmt exit {
    parts: list[doc.DocType] = [];
    for i in here.kid {
        if (isinstance(i, uni.Token) and (i.name == Tok.SEMI)) {
            parts.pop();
            parts.append(i.gen.doc_ir);
            parts.append(self.space());
        } else {
            parts.append(i.gen.doc_ir);
            parts.append(self.space());
        }
    }
    here.gen.doc_ir = self.group(self.concat(parts, ast_node=here), ast_node=here);
}

impl DocIRGenPass.exit_module_code with uni.ModuleCode exit {
    parts: list[doc.DocType] = [];
    body_parts: list[doc.DocType] = [];
    in_body = False;
    prev_body_item: (uni.UniNode | None) = None;
    for i in here.kid {
        if (here.doc and (i is here.doc)) {
            parts.append(i.gen.doc_ir);
            parts.append(self.hard_line());
        } elif (i == here.name) {
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
            parts.append(self.indent(self.concat(body_parts), ast_node=here));
            if len(body_parts) {
                parts.append(self.hard_line());
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
    here.gen.doc_ir = self.group(self.concat(parts, ast_node=here), ast_node=here);
}

impl DocIRGenPass.exit_global_vars with uni.GlobalVars exit {
    prefix_parts: list[doc.DocType] = [];
    assignment_parts: list[doc.DocType] = [];
    semi_doc: (doc.DocType | None) = None;
    has_multiple_assignments = len(here.assignments) > 1;
    for i in here.kid {
        if (i == here.doc) {
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

    aligned_assignments = self.align(self.concat(assignment_parts), n=5);
    prefix_parts.append(aligned_assignments);
    if semi_doc {
        prefix_parts.append(semi_doc);
    }
    here.gen.doc_ir = self.group(
        self.concat(prefix_parts, ast_node=here), ast_node=here
    );
}

impl DocIRGenPass.exit_raise_stmt with uni.RaiseStmt exit {
    self._assign_semi_stmt_doc_ir(here);
}

impl DocIRGenPass.exit_assert_stmt with uni.AssertStmt exit {
    self._assign_semi_stmt_doc_ir(here);
}

impl DocIRGenPass.exit_report_stmt with uni.ReportStmt exit {
    self._assign_semi_stmt_doc_ir(here);
}

impl DocIRGenPass.exit_disengage_stmt with uni.DisengageStmt exit {
    self._assign_group_concat(here);
}

impl DocIRGenPass.exit_delete_stmt with uni.DeleteStmt exit {
    self._assign_semi_stmt_doc_ir(here);
}

impl DocIRGenPass.exit_ctrl_stmt with uni.CtrlStmt exit {
    self._assign_group_concat(here);
}

impl DocIRGenPass.exit_yield_expr with uni.YieldExpr exit {
    self._assign_space_group(here);
}

impl DocIRGenPass.exit_await_expr with uni.AwaitExpr exit {
    self._assign_space_group(here);
}

impl DocIRGenPass.exit_cast_expr with uni.CastExpr exit {
    self._assign_space_group(here);
}

impl DocIRGenPass.exit_k_w_pair with uni.KWPair exit {
    self._assign_group_concat(here);
}

impl DocIRGenPass.exit_dict_compr with uni.DictCompr exit {
    parts: list[doc.DocType] = [];
    for i in here.kid {
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
    here.gen.doc_ir = self.format_comprehension(parts);
}

impl DocIRGenPass.exit_set_compr with uni.SetCompr exit {
    self._assign_compr_doc_ir(here);
}

impl DocIRGenPass.exit_gen_compr with uni.GenCompr exit {
    self._assign_compr_doc_ir(here);
}

impl DocIRGenPass.exit_slice with uni.Slice exit {
    self._assign_group_concat(here);
}

impl DocIRGenPass.exit_index_slice with uni.IndexSlice exit {
    self._assign_group_concat(here);
}

impl DocIRGenPass.exit_edge_op_ref with uni.EdgeOpRef exit {
    self._assign_group_concat(here);
}

impl DocIRGenPass.exit_edge_ref_trailer with uni.EdgeRefTrailer exit {
    parts: list[doc.DocType] = [];
    for i in here.kid {
        if (isinstance(i, uni.Token) and (i.name in [Tok.KW_EDGE, Tok.KW_NODE])) {
            parts.append(i.gen.doc_ir);
            parts.append(self.space());
        } else {
            parts.append(i.gen.doc_ir);
        }
    }
    here.gen.doc_ir = self.group(self.concat(parts, ast_node=here), ast_node=here);
}

impl DocIRGenPass.exit_lambda_expr with uni.LambdaExpr exit {
    parts: list[doc.DocType] = [];

    body_stmts = list(here.body) if isinstance(here.body, Sequence) else [];
    has_multi_stmt_body = len(body_stmts) > 1;

    _sbrace = len(body_stmts) == 0;
    if len(body_stmts) == 1 and body_stmts[0].kid {
        _cur: uni.UniNode = body_stmts[0];
        while _cur.kid {
            _last = _cur.kid[-1];
            if isinstance(_last, uni.Token) {
                _sbrace = _last.name == Tok.RBRACE;
                break;
            }
            _cur = _last;
        }
    }
    single_body_ends_with_brace = _sbrace;
    body_parts: list[doc.DocType] = [];
    in_body = False;
    for i in here.kid {
        if (
            has_multi_stmt_body and isinstance(i, uni.Token) and (i.name == Tok.LBRACE)
        ) {
            parts.append(i.gen.doc_ir);
            in_body = True;
            continue;
        }
        if (
            has_multi_stmt_body and isinstance(i, uni.Token) and (i.name == Tok.RBRACE)
        ) {
            in_body = False;
            self.trim_trailing_line(body_parts);
            parts.append(self.indent(self.concat(body_parts), ast_node=here));
            if body_parts {
                parts.append(self.hard_line());
            } else {
                parts.append(self.space());
            }
            parts.append(i.gen.doc_ir);
            continue;
        }
        if in_body {
            if (i in body_stmts) {
                body_parts.append(self.hard_line());
                body_parts.append(i.gen.doc_ir);
            } else {
                body_parts.append(i.gen.doc_ir);
            }
            continue;
        }
        if (isinstance(i, uni.Token) and (i.name == Tok.RBRACE)) {
            if not single_body_ends_with_brace {
                parts.append(self.space());
            }
            parts.append(i.gen.doc_ir);
        } elif (
            isinstance(i, uni.Token) and (i.name == Tok.LBRACE) and not body_stmts
        ) {
            parts.append(i.gen.doc_ir);
        } elif isinstance(i, uni.Token) {
            parts.append(i.gen.doc_ir);
            parts.append(self.space());
        } elif isinstance(i, uni.Expr) {
            parts.append(
                self.if_break(
                    self.indent(self.concat([self.line(), i.gen.doc_ir])), i.gen.doc_ir
                )
            );
        } elif isinstance(i, uni.FuncSignature) {
            if (isinstance(i.gen.doc_ir, doc.Text) and (i.gen.doc_ir.text == '()')) {
                parts.append(i.gen.doc_ir);
            } elif not i.params {
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
    here.gen.doc_ir = self.group(self.concat(parts, ast_node=here), ast_node=here);
}

impl DocIRGenPass.exit_unary_expr with uni.UnaryExpr exit {
    if is_mut_kind(here.ownership) {
        here.gen.doc_ir = self.group(
            self.concat(
                [
                    here.op.gen.doc_ir,
                    self.text("mut"),
                    self.space(),
                    here.operand.gen.doc_ir
                ],
                ast_node=here
            ),
            ast_node=here
        );
        return;
    }
    parts: list[doc.DocType] = [];
    for i in here.kid {
        if (
            (isinstance(i, uni.Token) and (i.value in ['-', '~', '+', '*', '&']))
            or isinstance(i, uni.Expr)
        ) {
            parts.append(i.gen.doc_ir);
        } else {
            parts.append(i.gen.doc_ir);
            parts.append(self.space());
        }
    }
    here.gen.doc_ir = self.group(self.concat(parts, ast_node=here), ast_node=here);
}

impl DocIRGenPass.exit_cfg_expr with uni.CfgExpr exit {
    here.gen.doc_ir = here.expr.gen.doc_ir;
}

impl DocIRGenPass.exit_bool_expr with uni.BoolExpr exit {
    operands: list[uni.UniNode] = [];
    ops: list[uni.UniNode] = [];
    def __flatten(expr: uni.Expr) {
        inner = expr.expr if isinstance(expr, uni.CfgExpr) else expr;
        if isinstance(inner, uni.BoolExpr) {
            first = True;
            for val in inner.values {
                if not first {
                    ops.append(inner.op);
                }
                __flatten(val);
                first = False;
            }
        } else {
            operands.append(expr);
        }
    }
    __flatten(here);
    self._assign_operator_chain(here, operands, ops);
}

impl DocIRGenPass.exit_if_else_expr with uni.IfElseExpr exit {
    parts: list[doc.DocType] = [];
    continuation: list[doc.DocType] = [];
    seen_first_expr = False;
    for i in here.kid {
        if isinstance(i, uni.Expr) and not seen_first_expr {
            parts.append(i.gen.doc_ir);
            seen_first_expr = True;
        } elif (isinstance(i, uni.Token) and not isinstance(i, uni.Expr)) {
            continuation.append(i.gen.doc_ir);
            continuation.append(self.space());
        } elif isinstance(i, uni.Expr) {
            continuation.append(i.gen.doc_ir);
            continuation.append(self.line());
        } else {
            continuation.append(i.gen.doc_ir);
            continuation.append(self.line());
        }
    }
    if continuation and isinstance(continuation[-1], doc.Line) {
        continuation.pop();
    }

    parts.append(self.indent(self.concat([self.line(), *continuation])));
    here.gen.doc_ir = self.group(self.concat(parts, ast_node=here), ast_node=here);
}

impl DocIRGenPass.exit_formatted_value with uni.FormattedValue exit {
    self._assign_group_concat(here);
}

impl DocIRGenPass.exit_f_string with uni.FString exit {
    self._assign_group_concat(here);
}

impl DocIRGenPass.exit_inner_compr with uni.InnerCompr exit {
    parts: list[doc.DocType] = [];
    for i in here.kid {
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
    here.gen.doc_ir = self.group(self.concat(parts, ast_node=here), ast_node=here);
}

impl DocIRGenPass.exit_list_compr with uni.ListCompr exit {
    if here.__class__ is not uni.ListCompr {
        return;
    }
    self._assign_compr_doc_ir(here);
}

impl DocIRGenPass.exit_with_stmt with uni.WithStmt exit {
    parts: list[doc.DocType] = [];
    body_parts: list[doc.DocType] = [self.hard_line()];
    for i in here.kid {
        if (isinstance(here.body, Sequence) and self.is_within(i, here.body)) {
            if (i == here.body[0]) {
                parts.append(self.indent(self.concat(body_parts), ast_node=here));
                parts.append(self.hard_line());
            }
            body_parts.append(i.gen.doc_ir);
            body_parts.append(self.hard_line());
        } elif (
            isinstance(i, uni.Token) and (i.name == Tok.LBRACE) and not here.body
        ) {
            parts.append(i.gen.doc_ir);
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
    here.gen.doc_ir = self.group(self.concat(parts), ast_node=here);
}

impl DocIRGenPass.exit_set_val with uni.SetVal exit {
    here.gen.doc_ir = self.format_comma_collection(here);
}

impl DocIRGenPass.format_comma_collection(nd: uni.UniNode) -> doc.DocType {
    flat_parts: list[doc.DocType] = [];
    for i in nd.kid {
        if (isinstance(i, uni.Token) and (i.name == Tok.COMMA)) {
            flat_parts.append(i.gen.doc_ir);
            flat_parts.append(self.space());
        } else {
            flat_parts.append(i.gen.doc_ir);
        }
    }
    not_broke = self.concat(flat_parts, ast_node=nd);
    broken_parts: list[doc.DocType] = [];
    for i in nd.kid {
        if (isinstance(i, uni.Token) and (i.name == Tok.COMMA)) {
            broken_parts.append(i.gen.doc_ir);
            broken_parts.append(self.hard_line());
        } else {
            broken_parts.append(i.gen.doc_ir);
        }
    }
    if (len(broken_parts) >= 3) {
        broke = self.concat(
            [
                broken_parts[0],
                self.indent(
                    self.concat([self.hard_line(), *broken_parts[1:-1]], ast_node=nd),
                    ast_node=nd
                ),
                self.hard_line(),
                broken_parts[-1]
            ],
            ast_node=nd
        );
    } else {
        broke = self.concat(broken_parts, ast_node=nd);
    }
    return self.group(self.if_break(broke, not_broke), ast_node=nd);
}

impl DocIRGenPass.exit_multi_string with uni.MultiString exit {
    parts: list[doc.DocType] = [];
    for i in here.kid {
        parts.append(i.gen.doc_ir);
    }
    here.gen.doc_ir = self.group(
        self.concat(self.intersperse(parts, self.line()), ast_node=here), ast_node=here
    );
}

impl DocIRGenPass.exit_tuple_val with uni.TupleVal exit {
    here.gen.doc_ir = self.format_comma_collection(here);
}

impl DocIRGenPass.exit_finally_stmt with uni.FinallyStmt exit {
    here.gen.doc_ir = self.format_simple_stmt_with_body(here, here.body);
}

impl DocIRGenPass.exit_except with uni.Except exit {
    here.gen.doc_ir = self.format_simple_stmt_with_body(here, here.body);
}

impl DocIRGenPass.exit_try_stmt with uni.TryStmt exit {
    here.gen.doc_ir = self.format_simple_stmt_with_body(here, here.body);
}

impl DocIRGenPass.exit_awaiting_clause with uni.AwaitingClause exit {
    here.gen.doc_ir = self.format_simple_stmt_with_body(here, here.body);
}

impl DocIRGenPass.exit_iter_for_stmt with uni.IterForStmt exit {
    here.gen.doc_ir = self.format_simple_stmt_with_body(here, here.body);
}

impl DocIRGenPass.exit_in_for_stmt with uni.InForStmt exit {
    here.gen.doc_ir = self.format_simple_stmt_with_body(here, here.body);
}

impl DocIRGenPass.exit_while_stmt with uni.WhileStmt exit {
    here.gen.doc_ir = self.format_simple_stmt_with_body(here, here.body);
}

impl DocIRGenPass.exit_open_stmt with uni.OpenStmt exit {
    here.gen.doc_ir = self.format_simple_stmt_with_body(here, here.body);
}

impl DocIRGenPass.exit_forever_stmt with uni.ForeverStmt exit {
    here.gen.doc_ir = self.format_simple_stmt_with_body(here, here.body);
}

impl DocIRGenPass.exit_arch_has with uni.ArchHas exit {
    parts: list[doc.DocType] = [];
    indent_parts: list[doc.DocType] = [];
    first_comma_seen = False;
    semi_doc: (doc.DocType | None) = None;
    for i in here.kid {
        if (i == here.doc) {
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
            self.indent(self.concat([self.hard_line(), *indent_parts]), ast_node=here)
        );
    }
    if semi_doc {
        parts.append(semi_doc);
    }
    here.gen.doc_ir = self.group(self.concat(parts, ast_node=here), ast_node=here);
}

impl DocIRGenPass.exit_has_var with uni.HasVar exit {
    parts: list[doc.DocType] = [];
    acc_docs: list[doc.DocType] = [];
    lbrace_doc: (doc.DocType | None) = None;
    in_acc = False;
    for i in here.kid {
        if (isinstance(i, uni.Token) and (i.name == Tok.EQ)) {
            parts.append(self.space());
            parts.append(i.gen.doc_ir);
            parts.append(self.space());
        } elif (isinstance(i, uni.Token) and (i.name == Tok.KW_POST_INIT)) {
            parts.append(self.space());
            parts.append(i.gen.doc_ir);
        } elif (isinstance(i, uni.Token) and (i.name == Tok.LBRACE)) {
            lbrace_doc = i.gen.doc_ir;
            in_acc = True;
        } elif (isinstance(i, uni.Token) and (i.name == Tok.RBRACE)) {
            in_acc = False;
            inner: list[doc.DocType] = [];
            for ad in acc_docs {
                inner.append(self.line());
                inner.append(ad);
            }
            open_doc: doc.DocType = lbrace_doc or self.concat([]);
            block = self.concat(
                [
                    open_doc,
                    self.indent(self.concat(inner), ast_node=here),
                    self.line(),
                    i.gen.doc_ir
                ]
            );
            parts.append(self.space());
            parts.append(self.group(block, ast_node=here));
        } elif in_acc {
            acc_docs.append(i.gen.doc_ir);
        } else {
            parts.append(i.gen.doc_ir);
        }
    }
    here.gen.doc_ir = self.group(self.concat(parts, ast_node=here), ast_node=here);
}

impl DocIRGenPass.exit_k_v_pair with uni.KVPair exit {
    parts: list[doc.DocType] = [];
    kid_count = len(here.kid);
    for (idx, kid) in enumerate(here.kid) {
        parts.append(kid.gen.doc_ir);
        is_last = idx == (kid_count - 1);
        if (isinstance(kid, uni.Token) and (kid.name == Tok.COLON)) {
            if not is_last {
                parts.append(self.space());
            }
        } elif not is_last {
            next_kid = here.kid[(idx + 1)];
            if (isinstance(next_kid, uni.Token) and (next_kid.name == Tok.COLON)) {
                continue;
            }
            parts.append(self.space());
        }
    }
    here.gen.doc_ir = self.concat(parts, ast_node=here);
}

impl DocIRGenPass.exit_dict_val with uni.DictVal exit {
    if not here.kid {
        here.gen.doc_ir = self.group(self.concat([]));
        return;
    }
    if not here.kv_pairs {
        here.gen.doc_ir = self.group(self.concat([kid.gen.doc_ir for kid in here.kid]));
        return;
    }
    inline_parts: list[doc.DocType] = [];
    broken_parts: list[doc.DocType] = [];
    for i in here.kid {
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
            self.indent(self.concat([self.hard_line(), *middle_parts]), ast_node=here),
            self.hard_line(),
            rbrace_doc
        ]
    );
    here.gen.doc_ir = self.group(self.if_break(broke, not_broke));
}

impl DocIRGenPass.exit_list_val with uni.ListVal exit {
    here.gen.doc_ir = self.format_comma_collection(here);
}

impl DocIRGenPass.exit_graph_expr with uni.GraphExpr exit {
    parts: list[doc.DocType] = [];
    for (index, child) in enumerate(here.kid[2:-1]) {
        if isinstance(child, uni.Expr) {
            parts.extend([self.line(), child.gen.doc_ir]);
            following = here.kid[index + 3];
            if not (isinstance(following, uni.Token) and following.name == Tok.SEMI) {
                parts.append(self.text(";"));
            }
        } else {
            parts.append(child.gen.doc_ir);
        }
    }
    here.gen.doc_ir = self.group(
        self.concat(
            [
                here.kid[0].gen.doc_ir,
                self.space(),
                here.kid[1].gen.doc_ir,
                self.indent(self.concat(parts), ast_node=here),
                self.line(),
                here.kid[-1].gen.doc_ir
            ],
            ast_node=here
        ),
        ast_node=here
    );
}

impl DocIRGenPass.exit_atom_trailer with uni.AtomTrailer exit {
    parts: list[doc.DocType] = [];
    for i in here.kid {
        parts.append(i.gen.doc_ir);
        if (isinstance(i, uni.Token) and (i.name == Tok.KW_BY)) {
            parts.append(self.space());
        }
    }
    here.gen.doc_ir = self.group(self.concat(parts, ast_node=here), ast_node=here);
}

impl DocIRGenPass.exit_func_call with uni.FuncCall exit {
    parts: list[doc.DocType] = [];
    indent_parts: list[doc.DocType] = [];
    in_params = False;
    for i in here.kid {
        if (isinstance(i, uni.Token) and (i.name == Tok.LPAREN) and here.params) {
            in_params = True;
            parts.append(i.gen.doc_ir);
        } elif (isinstance(i, uni.Token) and (i.name == Tok.RPAREN) and here.params) {
            in_params = False;
            if isinstance(indent_parts[-1], doc.Line) {
                indent_parts.pop();
            }
            parts.append(
                self.indent(
                    self.concat(
                        [self.tight_line(), self.group(self.concat([*indent_parts]))]
                    ),
                    ast_node=here
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
    here.gen.doc_ir = self.group(self.concat(parts, ast_node=here), ast_node=here);
}

impl DocIRGenPass.exit_return_stmt with uni.ReturnStmt exit {
    parts: list[doc.DocType] = [];

    if here.is_implicit {
        for i in here.kid {
            parts.append(i.gen.doc_ir);
        }
        here.gen.doc_ir = self.group(self.concat(parts, ast_node=here), ast_node=here);
        return;
    }

    is_jsx_return = isinstance(here.expr, uni.JsxElement);
    if is_jsx_return {
        for i in here.kid {
            if (isinstance(i, uni.Token) and (i.name == Tok.SEMI)) {
                parts.append(i.gen.doc_ir);
            } elif isinstance(i, uni.JsxElement) {
                parts.append(self.indent(self.concat([self.line(), i.gen.doc_ir])));
            } else {
                parts.append(i.gen.doc_ir);
            }
        }
        here.gen.doc_ir = self.group(self.concat(parts, ast_node=here), ast_node=here);
        return;
    }
    for i in here.kid {
        if (isinstance(i, uni.Token) and (i.name == Tok.SEMI)) {
            parts.pop();
            parts.append(i.gen.doc_ir);
        } else {
            parts.append(i.gen.doc_ir);
        }
        parts.append(self.space());
    }
    parts.pop();
    here.gen.doc_ir = self.group(self.concat(parts, ast_node=here), ast_node=here);
}

impl DocIRGenPass.exit_concurrent_expr with uni.ConcurrentExpr exit {
    parts: list[doc.DocType] = [];
    for i in here.kid {
        parts.append(i.gen.doc_ir);
        parts.append(self.space());
    }
    here.gen.doc_ir = self.group(self.concat(parts), ast_node=here);
}

impl DocIRGenPass.exit_expr_stmt with uni.ExprStmt exit {
    self._assign_group_concat(here);
}

impl DocIRGenPass.exit_binary_expr with uni.BinaryExpr exit {
    if not isinstance(here.op, uni.Token) or here.op.name.startswith('KW_') {
        self._assign_space_group(here);
        return;
    }
    operands: list[uni.UniNode] = [];
    ops: list[uni.UniNode] = [];
    def __flatten(expr: uni.UniNode) {
        if (
            isinstance(expr, uni.BinaryExpr)
            and isinstance(expr.op, uni.Token)
            and (expr.op.name == here.op.name)
        ) {
            __flatten(expr.left);
            ops.append(expr.op);
            __flatten(expr.right);
        } else {
            operands.append(expr);
        }
    }
    __flatten(here);
    self._assign_operator_chain(here, operands, ops);
}

impl DocIRGenPass.exit_else_stmt with uni.ElseStmt exit {
    self._assign_else_doc_ir(here, here.body);
}

impl DocIRGenPass.exit_else_if with uni.ElseIf exit {
    self._assign_else_doc_ir(here, here.body);
}

impl DocIRGenPass.exit_if_stmt with uni.IfStmt exit {
    if here.__class__ is not uni.IfStmt {
        return;
    }
    flat_capable = (
        isinstance(here.parent, uni.LambdaExpr)
        and not (
            isinstance(here.parent.body, Sequence) and len(list(here.parent.body)) > 1
        )
        and (here.else_body is None)
        and (len(here.body) == 1)
        and not self.has_gap(here, here.body[0])
    );
    if flat_capable {
        parts: list[doc.DocType] = [];
        body_placed = False;
        for i in here.kid {
            if (isinstance(i, uni.Token) and (i.name == Tok.LBRACE)) {
                parts.append(i.gen.doc_ir);
            } elif (isinstance(i, uni.Token) and (i.name == Tok.RBRACE)) {
                parts.append(self.line());
                parts.append(i.gen.doc_ir);
            } elif (isinstance(here.body, Sequence) and self.is_within(i, here.body)) {
                if not body_placed {
                    parts.append(
                        self.indent(
                            self.concat([self.line(), i.gen.doc_ir]), ast_node=here
                        )
                    );
                    body_placed = True;
                }
            } else {
                parts.append(i.gen.doc_ir);
                parts.append(self.space());
            }
        }
        here.gen.doc_ir = self.group(self.concat(parts, ast_node=here), ast_node=here);
        return;
    }
    parts = [];
    body_parts: list[doc.DocType] = [self.hard_line()];
    prev_body_item: (uni.UniNode | None) = None;
    for i in here.kid {
        if (isinstance(here.body, Sequence) and self.is_within(i, here.body)) {
            if (i == here.body[0]) {
                parts.append(self.indent(self.concat(body_parts), ast_node=here));
                parts.append(self.hard_line());
            }
            self.add_body_stmt_with_spacing(body_parts, i, prev_body_item);
            prev_body_item = i;
        } elif (
            isinstance(i, uni.Token) and (i.name == Tok.LBRACE) and not here.body
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
    parts.pop();
    body_parts.pop();
    here.gen.doc_ir = self.group(self.concat(parts, ast_node=here), ast_node=here);
}

impl DocIRGenPass.exit_assignment with uni.Assignment exit {
    lhs_parts: list[doc.DocType] = [];
    rhs_parts: list[doc.DocType] = [];
    eq_tok: (doc.DocType | None) = None;
    seen_eq = False;
    for i in here.kid {
        if (isinstance(i, uni.Token) and (i.name == Tok.EQ) and not seen_eq) {
            eq_tok = i.gen.doc_ir;
            seen_eq = True;
        } elif seen_eq {
            rhs_parts.append(i.gen.doc_ir);
        } else {
            if (i == here.aug_op) {
                lhs_parts.append(self.space());
            }
            lhs_parts.append(i.gen.doc_ir);
            if (i == here.aug_op)
                or (isinstance(i, uni.Token) and (i.name == Tok.KW_COMPTIME)) {
                lhs_parts.append(self.space());
            }
        }
    }
    if (eq_tok is not None) {
        rhs_concat = self.group(self.concat(rhs_parts));
        here.gen.doc_ir = self.group(
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
        here.gen.doc_ir = self.group(self.concat((lhs_parts + rhs_parts)));
    }
}

impl DocIRGenPass.exit_param_var with uni.ParamVar exit {
    parts: list[doc.DocType] = [];
    for i in here.kid {
        if (isinstance(i, uni.Token) and (i.name == Tok.EQ)) {
            parts.append(self.space());
            parts.append(i.gen.doc_ir);
            parts.append(self.space());
        } elif (isinstance(i, uni.Token) and (i.name == Tok.KW_COMPTIME)) {
            parts.append(i.gen.doc_ir);
            parts.append(self.space());
        } else {
            parts.append(i.gen.doc_ir);
        }
    }
    here.gen.doc_ir = self.group(self.concat(parts, ast_node=here), ast_node=here);
}

impl DocIRGenPass.exit_func_signature with uni.FuncSignature exit {
    parts: list[doc.DocType] = [];
    indent_parts: list[doc.DocType] = [];
    in_params = False;
    has_parens = False;

    has_any_params = (
        here.params
        or here.varargs
        or here.kwargs
        or here.kwonlyargs
        or here.posonly_params
    );
    for i in here.kid {
        if (isinstance(i, uni.Token) and (i.name == Tok.LPAREN) and has_any_params) {
            in_params = True;
            parts.append(i.gen.doc_ir);
        } elif (
            isinstance(i, uni.Token) and (i.name == Tok.RPAREN) and has_any_params
        ) {
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
                and not parts
            ) {
                parts.append(self.space());
            }
            parts.append(i.gen.doc_ir);
            parts.append(self.space());
        }
    }
    parts.pop();
    here.gen.doc_ir = self.group(self.concat(parts, ast_node=here));
}

impl DocIRGenPass.exit_ability with uni.Ability exit {
    parts: list[doc.DocType] = [];
    body_parts: list[doc.DocType] = [];
    in_body = False;
    prev_body_item: (uni.UniNode | None) = None;
    for i in here.kid {
        if ((i == here.doc) or (here.decorators and (i in here.decorators))) {
            parts.append(i.gen.doc_ir);
            parts.append(self.hard_line());
        } elif (i == here.name_ref) {
            parts.append(i.gen.doc_ir);
            if not isinstance(here.signature, uni.FuncSignature) {
                parts.append(self.space());
            }
        } elif (isinstance(i, uni.Token) and (i.name == Tok.LBRACE)) {
            parts.append(i.gen.doc_ir);
            body_parts.append(self.hard_line());
            in_body = True;
        } elif (isinstance(i, uni.Token) and (i.name == Tok.RBRACE)) {
            in_body = False;
            self.trim_trailing_line(body_parts);
            parts.append(self.indent(self.concat(body_parts), ast_node=here));
            if (len(body_parts) > 0) {
                parts.append(self.hard_line());
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
            if (here.accessor_kind == "") {
                parts.append(self.space());
            }
        } elif isinstance(i, uni.SubTag) {
            parts.pop();
            parts.append(i.gen.doc_ir);
            parts.append(self.space());
        } elif (isinstance(i, uni.Token) and (i.name == Tok.LSQUARE)) {
            parts.append(i.gen.doc_ir);
        } elif (isinstance(i, uni.Token) and (i.name == Tok.RSQUARE)) {
            parts.append(i.gen.doc_ir);
        } elif isinstance(i, uni.TypeParam) {
            parts.append(i.gen.doc_ir);
        } elif (isinstance(i, uni.Token) and (i.name == Tok.COMMA)) {
            parts.append(i.gen.doc_ir);
            parts.append(self.space());
        } else {
            parts.append(i.gen.doc_ir);
            parts.append(self.space());
        }
    }
    here.gen.doc_ir = self.group(self.concat(parts, ast_node=here), ast_node=here);
}

impl DocIRGenPass.exit_archetype with uni.Archetype exit {
    parts: list[doc.DocType] = [];
    body_parts: list[doc.DocType] = [];
    prev_item: (uni.UniNode | None) = None;
    in_body = False;
    for i in here.kid {
        if (
            (here.doc and (i is here.doc))
            or (here.decorators and (i in here.decorators))
        ) {
            parts.append(i.gen.doc_ir);
            parts.append(self.hard_line());
        } elif (i == here.name) {
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
        } elif (isinstance(i, uni.Token) and (i.name == Tok.COLON)) {
            parts.pop();
            parts.append(i.gen.doc_ir);
            parts.append(self.space());
        } elif (isinstance(here.body, Sequence) and (i in here.body)) {
            if not in_body {
                body_parts.append(self.hard_line());
            }
            if (
                (
                    (prev_item and (type(prev_item) is not type(i)))
                    or (prev_item and not self.is_one_line(prev_item))
                )
                and not (
                    prev_item
                    and (self.effective_first_line(i) <= (prev_item.loc.last_line + 1))
                    and (self.effective_first_line(i) < i.loc.first_line)
                )
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
            parts.append(self.indent(self.concat(body_parts), ast_node=here));
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
        } elif (
            not in_body and isinstance(i, uni.Token) and (i.name == Tok.DECOR_OP)
        ) {
            parts.append(i.gen.doc_ir);
        } elif isinstance(i, uni.SubTag) {
            parts.pop();
            parts.append(i.gen.doc_ir);
            parts.append(self.space());
        } elif (isinstance(i, uni.Token) and (i.name == Tok.LSQUARE)) {
            parts.pop();
            parts.append(i.gen.doc_ir);
        } elif (isinstance(i, uni.Token) and (i.name == Tok.RSQUARE)) {
            parts.pop();
            parts.append(i.gen.doc_ir);
            parts.append(self.space());
        } else {
            parts.append(i.gen.doc_ir);
            parts.append(self.space());
        }
    }
    here.gen.doc_ir = self.group(self.concat(parts, ast_node=here), ast_node=here);
}

impl DocIRGenPass.exit_type_param with uni.TypeParam exit {
    parts: list[doc.DocType] = [];
    for i in here.kid {
        if (isinstance(i, uni.Token) and (i.name == Tok.COLON)) {
            parts.append(i.gen.doc_ir);
            parts.append(self.space());
        } elif (isinstance(i, uni.Token) and (i.name == Tok.KW_COMPTIME)) {
            parts.append(i.gen.doc_ir);
            parts.append(self.space());
        } elif (isinstance(i, uni.Token) and (i.name == Tok.EQ)) {
            parts.append(self.space());
            parts.append(i.gen.doc_ir);
            parts.append(self.space());
        } else {
            parts.append(i.gen.doc_ir);
        }
    }
    here.gen.doc_ir = self.concat(parts, ast_node=here);
}

impl DocIRGenPass.exit_type_alias with uni.TypeAlias exit {
    parts: list[doc.DocType] = [];
    for i in here.kid {
        if (isinstance(i, uni.Token) and (i.name == Tok.LSQUARE)) {
            parts.pop();
            parts.append(i.gen.doc_ir);
        } elif (isinstance(i, uni.Token) and (i.name == Tok.RSQUARE)) {
            parts.pop();
            parts.append(i.gen.doc_ir);
            parts.append(self.space());
        } elif (isinstance(i, uni.Token) and (i.name == Tok.EQ)) {
            parts.append(i.gen.doc_ir);
            parts.append(self.space());
        } elif (isinstance(i, uni.Token) and (i.name == Tok.SEMI)) {
            parts.pop();
            parts.append(i.gen.doc_ir);
        } elif (isinstance(i, uni.Token) and (i.name == Tok.COMMA)) {
            parts.pop();
            parts.append(i.gen.doc_ir);
            parts.append(self.space());
        } else {
            parts.append(i.gen.doc_ir);
            parts.append(self.space());
        }
    }
    here.gen.doc_ir = self.group(self.concat(parts, ast_node=here), ast_node=here);
}

impl DocIRGenPass.exit_module_path with uni.ModulePath exit {
    parts: list[doc.DocType] = [];
    for i in here.kid {
        if (isinstance(i, uni.Token) and (i.name == Tok.KW_AS)) {
            parts.append(self.space());
            parts.append(i.gen.doc_ir);
            parts.append(self.space());
        } else {
            parts.append(i.gen.doc_ir);
        }
    }
    here.gen.doc_ir = self.concat(parts, ast_node=here);
}

impl DocIRGenPass.exit_module_item with uni.ModuleItem exit {
    parts: list[doc.DocType] = [];
    for i in here.kid {
        if (isinstance(i, uni.Token) and (i.name == Tok.KW_AS)) {
            parts.append(self.space());
            parts.append(i.gen.doc_ir);
            parts.append(self.space());
        } else {
            parts.append(i.gen.doc_ir);
        }
    }
    here.gen.doc_ir = self.concat(parts, ast_node=here);
}

impl DocIRGenPass.exit_import with uni.Import exit {
    parts: list[doc.DocType] = [];
    mod_items: list[doc.DocType] = [];
    is_in_items: bool = False;
    for i in here.kid {
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
    here.gen.doc_ir = self.group(self.concat(parts, ast_node=here), ast_node=here);
}

impl DocIRGenPass.exit_module with uni.Module exit {
    parts: list[doc.DocType] = [];
    prev_kid: (uni.UniNode | None) = None;
    first_kid = True;
    for i in here.kid {
        if (
            (isinstance(i, uni.Import) and isinstance(prev_kid, uni.Import))
            or (
                (isinstance(i, uni.GlobalVars) and isinstance(prev_kid, uni.GlobalVars))
                or (prev_kid == here.doc)
            )
        ) {
            if (prev_kid and self.has_gap(prev_kid, i)) {
                parts.append(self.hard_line());
            }
            self._rescue_lost_comments(here, parts, i);
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

                if prev_kid and here.source {
                    src_lines = here.source.code.split('\n');

                    start = prev_kid.loc.last_line;
                    end = self.effective_first_line(i) - 1;
                    consecutive_blanks = 0;
                    for line_idx in range(start, min(end, len(src_lines))) {
                        if not src_lines[line_idx].strip() {
                            consecutive_blanks += 1;
                            if consecutive_blanks >= 2 {
                                parts.append(self.hard_line());
                                break;
                            }
                        } else {
                            consecutive_blanks = 0;
                        }
                    }
                }
            }
            self._rescue_lost_comments(here, parts, i);
            parts.append(i.gen.doc_ir);
        }
        parts.append(self.hard_line());
        prev_kid = i;
        first_kid = False;
    }
    self._rescue_lost_comments(here, parts, None);
    here.gen.doc_ir = self.concat(parts, ast_node=here);
}

impl DocIRGenPass._rescue_lost_comments(
    nd: uni.Module, parts: list[doc.DocType], next_kid: (uni.UniNode | None)
) -> None {
    if not (isinstance(nd, uni.Module) and nd.source and nd.source.comments) {
        return;
    }
    if self._emitted_comment_ids is None {
        self._emitted_comment_ids = set();
    }
    mod_dc = nd.gen.doc_comments;
    own_ids: set[int] = set();
    if mod_dc is not None {
        for c in (mod_dc.leading + mod_dc.trailing_inline + mod_dc.trailing_own) {
            own_ids.add(id(c));
        }
    }
    limit = self.effective_first_line(next_kid) if (next_kid is not None) else None;
    prev_line: (int | None) = None;
    for c in nd.source.comments {
        if ((id(c) in self._emitted_comment_ids) or (id(c) in own_ids)) {
            continue;
        }
        if not self._comment_is_live(c) {
            continue;
        }
        if (limit is not None and (c.loc.first_line >= limit)) {
            continue;
        }
        if (prev_line is not None and ((prev_line + 1) < c.loc.first_line)) {
            parts.append(self.hard_line());
        }
        parts.append(self.text(c.value, source_token=c));
        parts.append(self.hard_line());
        self._emitted_comment_ids.add(id(c));
        prev_line = c.loc.last_line;
    }
}

impl DocIRGenPass.remove_all_spaces(doc_node: doc.DocType) -> doc.DocType {
    if isinstance(doc_node, doc.Text) {
        if (doc_node.text == ' ') {
            return self.concat([]);
        }
        return doc_node;
    } elif isinstance(doc_node, doc.Line) {
        if not (doc_node.hard or doc_node.literal) {
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

impl DocIRGenPass.is_within(
    kid_node: uni.UniNode, block: Sequence[uni.UniNode]
) -> bool {
    if not block {
        return False;
    }
    (start, end, kid) = (block[0].loc, block[-1].loc, kid_node.loc);
    first = (
        (start.first_line < kid.first_line)
        or ((start.first_line == kid.first_line) and (start.col_start <= kid.col_start))
    );
    last = (
        (end.last_line > kid.last_line)
        or ((end.last_line == kid.last_line) and (end.col_end >= kid.col_end))
    );
    return (first and last);
}

impl DocIRGenPass.add_body_stmt_with_spacing(
    body_parts: list[doc.DocType], current: uni.UniNode, previous: (uni.UniNode | None)
) -> None {
    if (previous and self.has_gap(previous, current)) {
        body_parts.append(self.hard_line());
    }
    body_parts.append(current.gen.doc_ir);
    body_parts.append(self.hard_line());
}

impl DocIRGenPass.has_gap(prev_kid: uni.UniNode, curr_kid: uni.UniNode) -> bool {
    return ((prev_kid.loc.last_line + 1) < self.effective_first_line(curr_kid));
}

impl DocIRGenPass.is_one_line(nd: uni.UniNode) -> bool {
    return (bool(nd.kid) and (nd.kid[0].loc.first_line == nd.kid[-1].loc.last_line));
}

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

impl DocIRGenPass.format_simple_stmt_with_body(
    nd: uni.UniNode, body: Sequence[uni.UniNode], space_between_parts: bool = True
) -> doc.DocType {
    parts: list[doc.DocType] = [];
    body_parts: list[doc.DocType] = [self.hard_line()];
    prev_body_item: (uni.UniNode | None) = None;
    for i in nd.kid {
        if (isinstance(body, Sequence) and self.is_within(i, body)) {
            if (body and (i == body[0])) {
                parts.append(self.indent(self.concat(body_parts), ast_node=nd));
                parts.append(self.hard_line());
            }
            self.add_body_stmt_with_spacing(body_parts, i, prev_body_item);
            prev_body_item = i;
        } elif (isinstance(i, uni.Token) and (i.name == Tok.LBRACE) and not body) {
            parts.append(i.gen.doc_ir);
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
    return self.group(self.concat(parts, ast_node=nd), ast_node=nd);
}

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

impl DocIRGenPass._assign_space_group(nd: uni.UniNode) -> None {
    nd.gen.doc_ir = self.group(self.join_with_space(self._child_docs(nd)), ast_node=nd);
}

impl DocIRGenPass._assign_operator_chain(
    nd: uni.UniNode, operands: list, ops: list
) -> None {
    rest: list[doc.DocType] = [];
    for i in range(len(ops)) {
        rest += [
            self.line(),
            ops[i].gen.doc_ir,
            self.space(),
            operands[(i + 1)].gen.doc_ir
        ];
    }

    tail: doc.DocType = self.concat(rest);
    parent = nd.parent;
    if isinstance(parent, uni.CfgExpr) {
        parent = parent.parent;
    }
    if not isinstance(parent, uni.AtomUnit) {
        tail = self.indent(tail);
    }
    nd.gen.doc_ir = self.group(
        self.concat([operands[0].gen.doc_ir, tail], ast_node=nd), ast_node=nd
    );
}

impl DocIRGenPass._assign_group_concat(nd: uni.UniNode) -> None {
    nd.gen.doc_ir = self.group(
        self.concat(self._child_docs(nd), ast_node=nd), ast_node=nd
    );
}

impl DocIRGenPass._assign_semi_stmt_doc_ir(nd: uni.UniNode) -> None {
    parts: list[doc.DocType] = [];
    for i in nd.kid {
        if (isinstance(i, uni.Token) and (i.name == Tok.SEMI) and len(parts)) {
            parts.pop();
        }
        parts.append(i.gen.doc_ir);
        parts.append(self.space());
    }
    parts.pop();
    nd.gen.doc_ir = self.group(self.concat(parts, ast_node=nd), ast_node=nd);
}

impl DocIRGenPass._assign_compr_doc_ir(nd: uni.UniNode) -> None {
    parts: list[doc.DocType] = [];
    for i in nd.kid {
        if isinstance(i, uni.InnerCompr) {
            parts.append(self.group(self.concat([self.tight_line(), i.gen.doc_ir])));
        } else {
            parts.append(i.gen.doc_ir);
        }
        parts.append(self.space());
    }
    nd.gen.doc_ir = self.format_comprehension(parts);
}

impl DocIRGenPass._assign_else_doc_ir(
    nd: uni.UniNode, body: Sequence[uni.UniNode]
) -> None {
    parts: list[doc.DocType] = [];
    body_parts: list[doc.DocType] = [self.hard_line()];
    for i in nd.kid {
        if (isinstance(body, Sequence) and self.is_within(i, body)) {
            if (i == body[0]) {
                parts.append(self.indent(self.concat(body_parts), ast_node=nd));
                parts.append(self.hard_line());
            }
            body_parts.append(i.gen.doc_ir);
            body_parts.append(self.hard_line());
        } elif (isinstance(i, uni.Token) and (i.name == Tok.LBRACE) and not body) {
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
    body_parts.pop();
    nd.gen.doc_ir = self.group(self.concat(parts, ast_node=nd), ast_node=nd);
}

impl DocIRGenPass._emit_keyword_block(nd: uni.UniNode, kw: Tok) -> None {
    parts: list[doc.DocType] = [];
    body_parts: list[doc.DocType] = [];
    in_body = False;
    prev_body_item: (uni.UniNode | None) = None;
    for i in nd.kid {
        if (isinstance(i, uni.Token) and (i.name == kw)) {
            parts.append(i.gen.doc_ir);
            parts.append(self.space());
        } elif (isinstance(i, uni.Token) and (i.name == Tok.LBRACE)) {
            parts.append(i.gen.doc_ir);
            body_parts.append(self.hard_line());
            in_body = True;
        } elif (isinstance(i, uni.Token) and (i.name == Tok.RBRACE)) {
            in_body = False;
            self.trim_trailing_line(body_parts);
            parts.append(self.indent(self.concat(body_parts), ast_node=nd));
            if len(body_parts) {
                parts.append(self.hard_line());
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
    nd.gen.doc_ir = self.group(self.concat(parts, ast_node=nd), ast_node=nd);
}

impl DocIRGenPass._child_docs(nd: uni.UniNode) -> list[doc.DocType] {
    docs: list[doc.DocType] = [];
    for kid in nd.kid {
        docs.append(kid.gen.doc_ir);
    }
    return docs;
}

impl DocIRGenPass.join_with_space(parts: list[doc.DocType]) -> doc.DocType {
    return self.join(self.space(), parts);
}

impl DocIRGenPass.join(
    separator: doc.DocType, parts: list[doc.DocType]
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

impl DocIRGenPass.align(contents: doc.DocType, n: (int | None) = None) -> doc.Align {
    return doc.Align(contents, n);
}

impl DocIRGenPass.if_break(
    break_contents: doc.DocType, flat_contents: doc.DocType
) -> doc.IfBreak {
    return doc.IfBreak(break_contents, flat_contents);
}

impl DocIRGenPass.concat(
    parts: list[doc.DocType], ast_node: (uni.UniNode | None) = None
) -> doc.Concat {
    return doc.Concat(parts, ast_node=ast_node);
}

impl DocIRGenPass.indent(
    contents: doc.DocType, ast_node: (uni.UniNode | None) = None
) -> doc.Indent {
    return doc.Indent(contents, ast_node=ast_node);
}

impl DocIRGenPass.group(
    contents: doc.DocType,
    break_contiguous: bool = False,
    ast_node: (uni.UniNode | None) = None
) -> doc.Group {
    return doc.Group(contents, break_contiguous, ast_node=ast_node);
}

impl DocIRGenPass.tight_line -> doc.Line {
    return doc.Line(tight=True);
}

impl DocIRGenPass.hard_line -> doc.Line {
    return doc.Line(hard=True);
}

impl DocIRGenPass.line(hard: bool = False, literal: bool = False) -> doc.Line {
    return doc.Line(hard, literal);
}

impl DocIRGenPass.space -> doc.Text {
    return doc.Text(' ');
}

impl DocIRGenPass.text(text: str, source_token: (uni.Token | None) = None) -> doc.Text {
    return doc.Text(text, source_token=source_token);
}

impl DocIRGenPass.line_suffix(contents: doc.DocType) -> doc.LineSuffix {
    return doc.LineSuffix(contents);
}

impl DocIRGenPass.break_parent -> doc.BreakParent {
    return doc.BreakParent();
}

impl DocIRGenPass.doc_ir_default_exit with uni.UniNode exit {
    if (here.gen._doc_ir is None) and here.kid {
        self._assign_space_group(here);
    }
}

impl DocIRGenPass.finish_doc_comments with uni.UniNode exit {
    if here.gen.doc_comments is not None {
        self._wrap_doc_comments(here);
    }
}

impl DocIRGenPass._comment_is_live(c: uni.CommentToken) -> bool {
    if self._live_comment_ids is None {
        src = self.ir_in.source if isinstance(self.ir_in, uni.Module) else None;
        self._live_comment_ids = {id(lc) for lc in (src.comments if src else [])};
    }
    return id(c) in self._live_comment_ids;
}

impl DocIRGenPass.effective_first_line(nd: uni.UniNode) -> int {
    dc = nd.gen.doc_comments;
    if (dc is not None and dc.leading) {
        for c in dc.leading {
            if self._comment_is_live(c) {
                return c.loc.first_line;
            }
        }
    }
    return nd.loc.first_line;
}

impl DocIRGenPass._wrap_doc_comments(nd: uni.UniNode) -> None {
    dc = nd.gen.doc_comments;
    if dc is None {
        return;
    }
    base = nd.gen.doc_ir;
    leading = [
        c
        for c in dc.leading
        if self._comment_is_live(c)
    ];
    trailing_inline = [
        c
        for c in dc.trailing_inline
        if self._comment_is_live(c)
    ];
    trailing_own = [
        c
        for c in dc.trailing_own
        if self._comment_is_live(c)
    ];
    if self._emitted_comment_ids is None {
        self._emitted_comment_ids = set();
    }
    for c in (leading + trailing_inline + trailing_own) {
        self._emitted_comment_ids.add(id(c));
    }
    if leading {
        pre: list[doc.DocType] = [doc.Line(hard=True, fresh=True)];
        prev_last: (int | None) = None;
        for c in leading {
            if (prev_last is not None and ((prev_last + 1) < c.loc.first_line)) {
                pre.append(self.hard_line());
            }
            pre.append(self.text(c.value, source_token=c));
            pre.append(self.hard_line());
            prev_last = c.loc.last_line;
        }
        if (prev_last is not None and ((prev_last + 1) < nd.loc.first_line)) {
            pre.append(self.hard_line());
        }
        pre.append(base);
        base = self.concat(pre);
    }
    if trailing_inline {
        inline_parts: list[doc.DocType] = [base];
        for c in trailing_inline {
            inline_parts.append(
                self.line_suffix(
                    self.concat([self.text('  '), self.text(c.value, source_token=c)])
                )
            );
        }
        inline_parts.append(self.break_parent());
        base = self.concat(inline_parts);
    }
    if trailing_own {
        post: list[doc.DocType] = [];
        own_prev = nd.loc.last_line;
        for c in trailing_own {
            post.append(self.hard_line());
            if ((own_prev + 1) < c.loc.first_line) {
                post.append(self.hard_line());
            }
            post.append(self.text(c.value, source_token=c));
            own_prev = c.loc.last_line;
        }
        if dc.indent_trailing_own {
            base = self.concat(
                [base, self.indent(self.concat(post)), self.hard_line()]
            );
        } else {
            base = self.concat([base, *post]);
        }
    }
    nd.gen.doc_ir = base;
}
