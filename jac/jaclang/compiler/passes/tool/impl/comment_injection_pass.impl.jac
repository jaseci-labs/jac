"""Initialize CommentInjectionPass."""

impl CommentInjectionPass.init(ir_in: uni.Module, prog: Any, cancel_token: Any = None) {
    super.init(ir_in, prog, cancel_token);
}

"""Remove redundant line breaks after inline comments."""
impl CommentInjectionPass._remove_redundant_lines(<>node: doc.DocType) -> doc.DocType {
    if isinstance(<>node, doc.Concat) {
        new_parts = [];
        i = 0;
        while (i < len(<>node.parts)) {
            part = <>node.parts[i];
            processed_part = self._remove_redundant_lines(part);
            if (
                self._ends_with_inline_comment_line(processed_part)
                and ((i + 1) < len(<>node.parts))
                and self._is_standalone_comment(<>node.parts[(i + 1)])
            ) {
                processed_part = self._remove_trailing_line_from_inline_comment(
                    processed_part
                );
                new_parts.append(processed_part);
                new_parts.append(doc.Line(hard=True));
                next_part = self._remove_redundant_lines(<>node.parts[(i + 1)]);
                if (isinstance(next_part, doc.Concat) and (len(next_part.parts) == 2)) {
                    new_parts.append(
                        doc.Concat([next_part.parts[0]], ast_node=next_part.ast_node)
                    );
                } else {
                    new_parts.append(next_part);
                }
                i += 2;
                continue;
            }
            next_line = <>node.parts[(i + 1)]
            if ((i + 1) < len(<>node.parts))
            else None;
            if (
                self._ends_with_inline_comment_line(processed_part)
                and isinstance(next_line, doc.Line)
                and next_line.hard
            ) {
                processed_part = self._remove_trailing_line_from_inline_comment(
                    processed_part
                );
            }
            if (
                isinstance(processed_part, doc.Indent)
                and (
                    self._ends_with_inline_comment_line(processed_part)
                    or (
                        isinstance(processed_part.contents, doc.Concat)
                        and processed_part.contents.parts
                        and self._is_standalone_comment(
                            processed_part.contents.parts[-1]
                        )
                    )
                )
                and isinstance(next_line, doc.Line)
                and not next_line.hard
            ) {
                if self._ends_with_inline_comment_line(processed_part) {
                    processed_part = self._remove_trailing_line_from_inline_comment(
                        processed_part
                    );
                } elif (
                    isinstance(processed_part.contents, doc.Concat)
                    and processed_part.contents.parts
                    and self._is_standalone_comment(processed_part.contents.parts[-1])
                ) {
                    indent_parts = <>list(processed_part.contents.parts);
                    last_comment = indent_parts[-1];
                    assert isinstance(last_comment, doc.Concat);
                    indent_parts[-1] = doc.Concat(
                        [last_comment.parts[0]], ast_node=last_comment.ast_node
                    );
                    processed_part = doc.Indent(
                        doc.Concat(
                            indent_parts, ast_node=processed_part.contents.ast_node
                        ),
                        ast_node=processed_part.ast_node
                    );
                }
                new_parts.append(processed_part);
                new_parts.append(doc.Line(hard=True));
                i += 2;
                continue;
            }
            new_parts.append(processed_part);
            i += 1;
        }
        return doc.Concat(new_parts, ast_node=<>node.ast_node);
    } elif isinstance(<>node, doc.Group) {
        return doc.Group(
            self._remove_redundant_lines(<>node.contents),
            <>node.break_contiguous,
            <>node.id,
            ast_node=<>node.ast_node
        );
    } elif isinstance(<>node, doc.Indent) {
        return doc.Indent(
            self._remove_redundant_lines(<>node.contents), ast_node=<>node.ast_node
        );
    } elif isinstance(<>node, doc.IfBreak) {
        return doc.IfBreak(
            self._remove_redundant_lines(<>node.break_contents),
            self._remove_redundant_lines(<>node.flat_contents)
        );
    } elif isinstance(<>node, doc.Align) {
        return doc.Align(self._remove_redundant_lines(<>node.contents), <>node.n);
    }
    return <>node;
}

"""Remove the trailing hard line from the last inline comment in the node."""
impl CommentInjectionPass._remove_trailing_line_from_inline_comment(
    <>node: doc.DocType
) -> doc.DocType {
    if (isinstance(<>node, doc.Concat) and (len(<>node.parts) == 3)) {
        (first, second, third) = <>node.parts;
        if (
            isinstance(first, doc.Text)
            and (first.text.strip() == '')
            and isinstance(second, doc.Text)
            and second.text.strip().startswith('#')
            and isinstance(third, doc.Line)
            and third.hard
        ) {
            return doc.Concat(<>list(<>node.parts[:-1]));
        }
    }
    if (isinstance(<>node, doc.Concat) and <>node.parts) {
        new_parts = <>list(<>node.parts);
        new_parts[-1] = self._remove_trailing_line_from_inline_comment(new_parts[-1]);
        return doc.Concat(new_parts, ast_node=<>node.ast_node);
    }
    if isinstance(<>node, doc.Group) {
        return doc.Group(
            self._remove_trailing_line_from_inline_comment(<>node.contents),
            <>node.break_contiguous,
            <>node.id,
            ast_node=<>node.ast_node
        );
    }
    if isinstance(<>node, doc.Indent) {
        return doc.Indent(
            self._remove_trailing_line_from_inline_comment(<>node.contents),
            ast_node=<>node.ast_node
        );
    }
    return <>node;
}

"""Check if a node ends with an inline comment that has a hard line break."""
impl CommentInjectionPass._ends_with_inline_comment_line(<>node: doc.DocType) -> bool {
    if (isinstance(<>node, doc.Concat) and (len(<>node.parts) == 3)) {
        (first, second, third) = <>node.parts;
        if (
            isinstance(first, doc.Text)
            and (first.text.strip() == '')
            and isinstance(second, doc.Text)
            and second.text.strip().startswith('#')
            and isinstance(third, doc.Line)
            and third.hard
        ) {
            return True;
        }
    }
    if (isinstance(<>node, doc.Concat) and <>node.parts) {
        return self._ends_with_inline_comment_line(<>node.parts[-1]);
    }
    if isinstance(<>node, doc.Group) {
        return self._ends_with_inline_comment_line(<>node.contents);
    }
    if isinstance(<>node, doc.Indent) {
        return self._ends_with_inline_comment_line(<>node.contents);
    }
    return False;
}

"""Ensure we never end up with consecutive hard lines from injection."""
impl CommentInjectionPass._collapse_duplicate_hard_lines(
    sink: list[doc.DocType]
) -> None {
    while (
        (len(sink) >= 2)
        and isinstance(sink[-1], doc.Line)
        and sink[-1].hard
        and isinstance(sink[-2], doc.Line)
        and sink[-2].hard
    ) {
        sink.pop();
    }
}

"""
Return True when the sink already ends with a line break.

        This includes hard lines and tight lines, since tight lines will become
        line breaks when the containing group breaks (e.g., in multi-line function calls).
"""
impl CommentInjectionPass._ends_with_hard_line(sink: Sequence[doc.DocType]) -> bool {
    if not sink {
        return False;
    }
    last = sink[-1];
    if isinstance(last, doc.Line) {
        return True;
    }
    if (isinstance(last, doc.Concat) and last.parts) {
        last_part = last.parts[-1];
        if isinstance(last_part, doc.Line) {
            return True;
        }
    }
    return False;
}

"""Remove the trailing hard line from a comment Concat."""
impl CommentInjectionPass._strip_trailing_line_from_comment(
    comment: doc.DocType
) -> doc.DocType {
    if (
        isinstance(comment, doc.Concat)
        and (len(comment.parts) >= 2)
        and isinstance(comment.parts[-1], doc.Line)
        and comment.parts[-1].hard
    ) {
        return doc.Concat(<>list(comment.parts[:-1]), ast_node=comment.ast_node);
    }
    return comment;
}

"""Check if a doc part is a comment (inline or standalone) with a hard line."""
impl CommentInjectionPass._is_comment_with_line(part: doc.DocType) -> bool {
    if isinstance(part, doc.Concat) {
        if (len(part.parts) == 2) {
            return self._is_standalone_comment(part);
        } elif (len(part.parts) == 3) {
            (first, second, third) = part.parts;
            return (
                isinstance(first, doc.Text)
                and (first.text.strip() == '')
                and isinstance(second, doc.Text)
                and second.text.strip().startswith('#')
                and isinstance(third, doc.Line)
                and third.hard
            );
        }
    }
    return False;
}

"""Check if a doc part is a standalone comment."""
impl CommentInjectionPass._is_standalone_comment(part: doc.DocType) -> bool {
    if (isinstance(part, doc.Concat) and (len(part.parts) == 2)) {
        (first, second) = part.parts;
        return (
            isinstance(first, doc.Text)
            and first.text.strip().startswith('#')
            and isinstance(second, doc.Line)
        );
    }
    return False;
}

"""Check whether the given doc part begins with a line break."""
impl CommentInjectionPass._starts_with_line(part: doc.DocType) -> bool {
    if isinstance(part, doc.Line) {
        return True;
    }
    if isinstance(part, doc.Concat) {
        for child in part.parts {
            if (isinstance(child, doc.Text) and not child.text.strip()) {
                continue;
            }
            return self._starts_with_line(child);
        }
        return False;
    }
    if isinstance(part, doc.Group) {
        return self._starts_with_line(part.contents);
    }
    if isinstance(part, doc.Indent) {
        return self._starts_with_line(part.contents);
    }
    if isinstance(part, doc.Align) {
        return self._starts_with_line(part.contents);
    }
    if isinstance(part, doc.IfBreak) {
        return self._starts_with_line(part.break_contents);
    }
    return False;
}

"""Append standalone comments to sink while preserving vertical spacing."""
impl CommentInjectionPass._emit_standalone_comments(
    sink: list[doc.DocType],
    comments: Sequence[CommentInfo],
    *,
    prev_item_line: (int | None)
) -> (int | None) {
    last_line = prev_item_line;
    prev_comment_line: (int | None) = None;
    for info in comments {
        comment_line = info.first_line;
        should_add_line = (
            (
                (prev_comment_line is not None)
                and (comment_line > (prev_comment_line + 1))
            )
            or ((last_line is not None) and (comment_line > (last_line + 1)))
        );
        if should_add_line {
            if (not sink or not isinstance(sink[-1], doc.Line)) {
                sink.append(doc.Line(hard=True));
            }
        } else {
            self._collapse_duplicate_hard_lines(sink);
            if (sink and not self._ends_with_hard_line(sink)) {
                sink.append(doc.Line(hard=True));
            }
        }
        sink.append(self._make_standalone_comment(info.token));
        last_line = info.last_line;
        prev_comment_line = comment_line;
    }
    return last_line;
}

"""Create inline comment DocIR."""
impl CommentInjectionPass._make_inline_comment(
    comment: uni.CommentToken, add_line: bool = True
) -> doc.DocType {
    parts: list[doc.DocType] = [doc.Text('  '), doc.Text(comment.value)];
    if add_line {
        parts.append(doc.Line(hard=True));
    }
    return doc.Concat(parts);
}

"""Create standalone comment DocIR."""
impl CommentInjectionPass._make_standalone_comment(
    comment: uni.CommentToken
) -> doc.DocType {
    return doc.Concat([doc.Text(comment.value), doc.Line(hard=True)]);
}

"""
Fix spacing for empty regions (bodies/params) that now contain comments.

        When DocIR was generated, empty regions had a Space before the closing
        delimiter. After injecting comments, we need a hard line instead.
"""
impl CommentInjectionPass._fix_empty_region_spacing(
    parts: list[doc.DocType]
) -> list[doc.DocType] {
    result: list[doc.DocType] = [];
    i: int = 0;
    while (i < len(parts)) {
        part = parts[i];
        if (
            isinstance(part, doc.Indent)
            and isinstance(part.contents, doc.Concat)
            and part.contents.parts
            and ((i + 1) < len(parts))
        ) {
            next_part = parts[(i + 1)];
            if (
                isinstance(next_part, doc.Text)
                and (next_part.text.strip() == '')
                and (len(next_part.text) <= 1)
            ) {
                result.append(part);
                result.append(doc.Line(hard=True));
                i += 2;
                continue;
            }
        }
        result.append(part);
        i += 1;
    }
    return result;
}

"""
Handle comments inside empty bodies (e.g., empty if/elif/else blocks).

        For empty bodies, no Indent node is created, so we need to inject comments
        directly between the { and } tokens at the Concat level.
"""
impl CommentInjectionPass._handle_empty_body_comments(
    <>node: uni.UniNode, parts: list[doc.DocType]
) -> list[doc.DocType] {
    if not self._comments {
        return parts;
    }
    body = getattr(<>node, 'body', None);
    if ((body is None) or (isinstance(body, Sequence) and (len(body) > 0))) {
        return parts;
    }
    lbrace_line: (int | None) = None;
    rbrace_line: (int | None) = None;
    lbrace_idx: (int | None) = None;
    rbrace_idx: (int | None) = None;
    for (i, part) in enumerate(parts) {
        if (isinstance(part, doc.Text) and part.source_token) {
            if ((part.source_token.name == Tok.LBRACE) and (lbrace_line is None)) {
                lbrace_line = part.source_token.loc.last_line;
                lbrace_idx = i;
            } elif (
                (part.source_token.name == Tok.RBRACE) and (lbrace_line is not None)
            ) {
                rbrace_line = part.source_token.loc.first_line;
                rbrace_idx = i;
                break;
            }
        }
    }
    if (
        (lbrace_line is None)
        or (rbrace_line is None)
        or (lbrace_idx is None)
        or (rbrace_idx is None)
    ) {
        return parts;
    }
    comments = self._comments.take_standalone_between((lbrace_line + 1), rbrace_line);
    if not comments {
        return parts;
    }
    result: list[doc.DocType] = <>list(parts[:(lbrace_idx + 1)]);
    comment_parts: list[doc.DocType] = [doc.Line(hard=True)];
    for info in comments {
        comment_parts.append(doc.Text(info.token.value));
        comment_parts.append(doc.Line(hard=True));
    }
    if (comment_parts and isinstance(comment_parts[-1], doc.Line)) {
        comment_parts.pop();
    }
    result.append(doc.Indent(doc.Concat(comment_parts)));
    result.append(doc.Line(hard=True));
    start_idx = lbrace_idx + 1;
    while (start_idx < rbrace_idx) {
        part = parts[start_idx];
        if (isinstance(part, doc.Text) and (part.text.strip() == '')) {
            start_idx += 1;
        } else {
            break;
        }
    }
    result.extend(parts[start_idx:]);
    return result;
}

"""Handle comment injection within parenthesized regions (params/args)."""
impl CommentInjectionPass._handle_paren_comments(
    items: (Sequence[uni.UniNode] | None), parts: list[doc.DocType]
) -> list[doc.DocType] {
    if not self._comments {
        return parts;
    }
    delim = self._find_delimiters(parts, Tok.LPAREN, Tok.RPAREN);
    if (delim is None) {
        return parts;
    }
    comments = self._comments.take_standalone_between(
        (delim.open_line + 1), delim.close_line
    );
    if not comments {
        return parts;
    }
    indent_idx = next(
        (
            i
            for (i, p) in enumerate(parts)
            if isinstance(p, doc.Indent)
        ),
        None
    );
    if not items {
        result = <>list(parts[:(delim.open_idx + 1)]);
        comment_parts: list[doc.DocType] = [doc.Line(hard=True, tight=True)];
        for info in comments {
            comment_parts.append(doc.Text(info.token.value));
            comment_parts.append(doc.Line(hard=True));
        }
        if (comment_parts and isinstance(comment_parts[-1], doc.Line)) {
            comment_parts.pop();
        }
        result.append(doc.Indent(doc.Concat(comment_parts)));
        result.append(doc.Line(hard=True, tight=True));
        result.extend(parts[delim.close_idx:]);
        return result;
    }
    if (indent_idx is not None) {
        result = <>list(parts);
        indent_part = result[indent_idx];
        if (
            isinstance(indent_part, doc.Indent)
            and isinstance(indent_part.contents, doc.Concat)
        ) {
            new_indent_parts = <>list(indent_part.contents.parts);
            for info in comments {
                new_indent_parts.append(doc.Line(hard=True));
                new_indent_parts.append(doc.Text(info.token.value));
            }
            result[indent_idx] = doc.Indent(
                doc.Concat(new_indent_parts, ast_node=indent_part.contents.ast_node),
                ast_node=indent_part.ast_node
            );
        }
        return result;
    }
    return parts;
}

"""Handle comment injection within bodies (functions, classes, etc)."""
impl CommentInjectionPass._handle_body_comments(
    <>node: uni.UniNode, indent: doc.Indent
) -> doc.Indent {
    body: (Sequence[uni.UniNode] | None) = None;
    if <>node?.body {
        body = <>node.body;
    } elif (isinstance(<>node, uni.JsxElement) and <>node.children) {
        body = <>node.children;
    } elif (isinstance(<>node, uni.ArchHas) and <>node.vars) {
        body = <>node.vars;
    } elif (isinstance(<>node, uni.DictVal) and <>node.kv_pairs) {
        body = <>node.kv_pairs;
    } elif (isinstance(<>node, uni.ListVal) and <>node.values) {
        body = <>node.values;
    } elif (isinstance(<>node, uni.FuncCall) and <>node.params) {
        body = <>node.params;
    }
    if (
        (body is None)
        or not isinstance(body, Sequence)
        or not isinstance(indent.contents, doc.Concat)
    ) {
        return indent;
    }
    body_start: (int | None) = next(
        (
            (k.loc.last_line + 1)
            for k in <>node.kid
            if (isinstance(k, uni.Token) and (k.name == Tok.LBRACE) and k.loc)
        ),
        None
    );
    body_end: (int | None) = next(
        (
            k.loc.first_line
            for k in <>node.kid
            if (isinstance(k, uni.Token) and (k.name == Tok.RBRACE) and k.loc)
        ),
        None
    );
    if ((body_start is None) and isinstance(<>node, (uni.MatchCase, uni.SwitchCase))) {
        body_start = next(
            (
                (k.loc.last_line + 1)
                for k in <>node.kid
                if (isinstance(k, uni.Token) and (k.name == Tok.COLON) and k.loc)
            ),
            None
        );
        if (body and body[-1].loc) {
            body_end = body[-1].loc.last_line + 1;
        } elif <>node.loc {
            body_end = <>node.loc.last_line + 1;
        }
    }
    if ((body_start is None) and isinstance(<>node, uni.JsxElement) and <>node.kid) {
        opening_tag = <>node.kid[0];
        if isinstance(opening_tag, uni.JsxElement) {
            body_start = next(
                (
                    (k.loc.last_line + 1)
                    for k in opening_tag.kid
                    if (
                        isinstance(k, uni.Token)
                        and (k.name == Tok.JSX_TAG_END)
                        and k.loc
                    )
                ),
                None
            );
        }
        closing_tag = <>node.kid[-1];
        if isinstance(closing_tag, uni.JsxElement) {
            body_end = next(
                (
                    k.loc.first_line
                    for k in closing_tag.kid
                    if (
                        isinstance(k, uni.Token)
                        and (k.name == Tok.JSX_CLOSE_START)
                        and k.loc
                    )
                ),
                None
            );
        }
    }
    if ((body_start is None) and isinstance(<>node, uni.ArchHas)) {
        body_start = next(
            (
                (k.loc.last_line + 1)
                for k in <>node.kid
                if (isinstance(k, uni.Token) and (k.name == Tok.COMMA) and k.loc)
            ),
            None
        );
        body_end = next(
            (
                k.loc.first_line
                for k in <>node.kid
                if (isinstance(k, uni.Token) and (k.name == Tok.SEMI) and k.loc)
            ),
            None
        );
    }
    if ((body_start is None) and isinstance(<>node, uni.ListVal)) {
        body_start = next(
            (
                (k.loc.last_line + 1)
                for k in <>node.kid
                if (isinstance(k, uni.Token) and (k.name == Tok.LSQUARE) and k.loc)
            ),
            None
        );
        body_end = next(
            (
                k.loc.first_line
                for k in <>node.kid
                if (isinstance(k, uni.Token) and (k.name == Tok.RSQUARE) and k.loc)
            ),
            None
        );
    }
    if ((body_start is None) and isinstance(<>node, uni.FuncCall)) {
        body_start = next(
            (
                (k.loc.last_line + 1)
                for k in <>node.kid
                if (isinstance(k, uni.Token) and (k.name == Tok.LPAREN) and k.loc)
            ),
            None
        );
        body_end = next(
            (
                k.loc.first_line
                for k in <>node.kid
                if (isinstance(k, uni.Token) and (k.name == Tok.RPAREN) and k.loc)
            ),
            None
        );
    }
    if (body_start is None) {
        return indent;
    }
    result: list[doc.DocType] = [];
    current_line: int = body_start;
    body_idx: int = 0;
    parts_with_standalone: list[doc.DocType] = [];
    for part in indent.contents.parts {
        if isinstance(part, doc.Line) {
            parts_with_standalone.append(part);
            continue;
        }
        part_line: (int | None) = None;
        tokens = self._get_tokens(part);
        if tokens {
            part_line = min(
                t.loc.first_line
                for t in tokens
                if t.loc
            );
        }
        if (part_line and (body_idx < len(body))) {
            while (body_idx < len(body)) {
                body_item = body[body_idx];
                if not body_item.loc {
                    body_idx += 1;
                    continue;
                }
                if (part_line < body_item.loc.first_line) {
                    break;
                }
                prev_item_line: (int | None) = body[(body_idx - 1)].loc.last_line
                if ((body_idx > 0) and body[(body_idx - 1)].loc)
                else (current_line - 1);
                comments = [];
                if self._comments {
                    comments = self._comments.take_standalone_between(
                        current_line, body_item.loc.first_line
                    );
                }
                if comments {
                    prev_item_line = self._emit_standalone_comments(
                        parts_with_standalone, comments, prev_item_line=prev_item_line
                    );
                }
                current_line = body_item.loc.last_line + 1;
                if (part_line <= body_item.loc.last_line) {
                    body_idx += 1;
                    break;
                } else {
                    body_idx += 1;
                }
            }
        }
        parts_with_standalone.append(part);
    }
    result = self._inject_into_parts(parts_with_standalone, <>node);
    if (body_end is not None) {
        if body {
            last_body_line = body[-1].loc.last_line
            if body[-1].loc
            else (current_line - 1);
            comments = [];
            if self._comments {
                comments = self._comments.take_standalone_between(
                    (last_body_line + 1), body_end
                );
            }
            if comments {
                self._emit_standalone_comments(
                    result, comments, prev_item_line=last_body_line
                );
                if (result and self._is_comment_with_line(result[-1])) {
                    result[-1] = self._strip_trailing_line_from_comment(result[-1]);
                }
            }
        } else {
            comments = [];
            if self._comments {
                comments = self._comments.take_standalone_between(body_start, body_end);
            }
            if comments {
                result.append(doc.Line(hard=True));
                self._emit_standalone_comments(
                    result, comments, prev_item_line=(body_start - 1)
                );
                if (result and self._is_comment_with_line(result[-1])) {
                    result[-1] = self._strip_trailing_line_from_comment(result[-1]);
                }
            }
        }
    }
    return doc.Indent(doc.Concat(result), ast_node=<>node);
}

"""Inject standalone comments using token line spans, generically."""
impl CommentInjectionPass._inject_standalone_by_spans(
    parts: list[doc.DocType], ctx: uni.UniNode, *, drain_after: bool = False
) -> list[doc.DocType] {
    if not self._comments {
        return parts;
    }
    start_line = 1
    if isinstance(ctx, uni.Module)
    else ctx.loc.first_line if ctx.loc else None;
    end_line = (ctx.loc.last_line + 1) if ctx.loc else None;
    prev_line = (start_line - 1) if (start_line is not None) else None;
    result: list[doc.DocType] = [];
    for part in parts {
        (part_start, part_end) = self._doc_line_span(part);
        if (part_start is not None) {
            comments = self._comments.take_standalone_between(
                (prev_line + 1) if (prev_line is not None) else 1, part_start
            );
            if comments {
                prev_line = self._emit_standalone_comments(
                    result, comments, prev_item_line=prev_line
                );
            }
        }
        result.append(part);
        if (part_end is not None) {
            prev_line = part_end;
        }
    }
    if (end_line is not None) {
        trailing = self._comments.take_standalone_between(
            (prev_line + 1) if (prev_line is not None) else 1, end_line
        );
        if trailing {
            prev_line = self._emit_standalone_comments(
                result, trailing, prev_item_line=prev_line
            );
        }
    }
    if drain_after {
        leftovers = self._comments.take_standalone_after(
            (prev_line + 1) if (prev_line is not None) else 1
        );
        if leftovers {
            self._emit_standalone_comments(result, leftovers, prev_item_line=prev_line);
        }
    }
    return result;
}

"""Inject inline comments after their anchor tokens."""
impl CommentInjectionPass._inject_into_parts(
    parts: list[doc.DocType], ctx: uni.UniNode
) -> list[doc.DocType] {
    result: list[doc.DocType] = [];
    for (index, part) in enumerate(parts) {
        processed = self._process(ctx, part);
        result.append(processed);
        tokens = self._get_tokens(processed);
        if (tokens and self._comments) {
            last_token = max(
                tokens, key=lambda t: Any : (t.loc.last_line, t.loc.col_end)
            );
            token_id: int = id(last_token);
            for info in self._comments.take_inline(token_id) {
                add_line: bool = True;
                if ((index + 1) < len(parts)) {
                    next_part = parts[(index + 1)];
                    if (
                        self._starts_with_line(next_part)
                        or self._is_standalone_comment(next_part)
                    ) {
                        add_line = False;
                    }
                }
                result.append(self._make_inline_comment(info.token, add_line=add_line));
            }
        }
    }
    return result;
}

"""Return the first and last line covered by a DocIR node."""
impl CommentInjectionPass._doc_line_span(
    <>node: doc.DocType
) -> tuple[(int | None), (int | None)] {
    tokens = [
        t
        for t in self._get_tokens(<>node)
        if getattr(t, 'loc', None)
    ];
    if not tokens {
        return (None, None);
    }
    return (
        min(
            t.loc.first_line
            for t in tokens
            if t.loc
        ),
        max(
            t.loc.last_line
            for t in tokens
            if t.loc
        )
    );
}

"""Extract source tokens from a DocIR node (visitor pattern)."""
impl CommentInjectionPass._get_tokens(<>node: doc.DocType) -> list[uni.Token] {
    if isinstance(<>node, doc.Text) {
        return [<>node.source_token] if <>node.source_token else [];
    } elif isinstance(<>node, (doc.Concat, doc.Group, doc.Indent, doc.Align)) {
        tokens = [];
        children = <>node.parts
        if isinstance(<>node, doc.Concat)
        else [<>node.contents];
        for child in children {
            tokens.extend(self._get_tokens(child));
        }
        return tokens;
    } elif isinstance(<>node, doc.IfBreak) {
        return (
            self._get_tokens(<>node.break_contents) + self._get_tokens(
                <>node.flat_contents
            )
        );
    }
    return [];
}

"""
Find opening and closing delimiter tokens and their line numbers.

        Returns: DelimiterInfo if both delimiters found, None otherwise
"""
impl CommentInjectionPass._find_delimiters(
    parts: list[doc.DocType], open_tok: Tok, close_tok: Tok
) -> (DelimiterInfo | None) {
    open_idx: (int | None) = None;
    open_line: (int | None) = None;
    close_idx: (int | None) = None;
    close_line: (int | None) = None;
    for (i, part) in enumerate(parts) {
        if not isinstance(part, doc.Text) {
            continue;
        }
        if part.source_token {
            if ((part.source_token.name == open_tok) and (open_idx is None)) {
                (open_idx, open_line) = (i, part.source_token.loc.last_line);
            } elif (part.source_token.name == close_tok) {
                (close_idx, close_line) = (i, part.source_token.loc.first_line);
            }
        }
    }
    if (
        (open_idx is not None)
        and (close_idx is not None)
        and (open_line is not None)
        and (close_line is not None)
    ) {
        return DelimiterInfo(open_idx, close_idx, open_line, close_line);
    }
    return None;
}

"""Main recursive processor with type-specific handling."""
impl CommentInjectionPass._process(
    ctx: uni.UniNode, <>node: doc.DocType
) -> doc.DocType {
    if isinstance(<>node, doc.Concat) {
        ctx = <>node.ast_node or ctx;
        processed_parts = self._inject_into_parts(<>node.parts, ctx);
        if isinstance(ctx, (uni.FuncSignature, uni.FuncCall)) {
            items = ctx?.params or [];
            processed_parts = self._handle_paren_comments(items, processed_parts);
        }
        if isinstance(
            ctx, (uni.IfStmt, uni.ElseIf, uni.ElseStmt, uni.WhileStmt, uni.InForStmt)
        ) {
            processed_parts = self._handle_empty_body_comments(ctx, processed_parts);
        }
        target_ctx = <>node.ast_node;
        if target_ctx {
            processed_parts = self._inject_standalone_by_spans(
                processed_parts,
                target_ctx,
                drain_after=isinstance(target_ctx, uni.Module)
            );
        }
        processed_parts = self._fix_empty_region_spacing(processed_parts);
        return doc.Concat(processed_parts, ast_node=ctx);
    } elif isinstance(<>node, doc.Group) {
        ctx = <>node.ast_node or ctx;
        return doc.Group(
            self._process(ctx, <>node.contents),
            <>node.break_contiguous,
            <>node.id,
            ast_node=ctx
        );
    } elif isinstance(<>node, doc.Indent) {
        ctx = <>node.ast_node or ctx;
        has_body = (
            <>node.ast_node
            and (
                (getattr(ctx, 'body', None) is not None)
                or (isinstance(ctx, uni.JsxElement) and ctx.children)
                or (isinstance(ctx, uni.ArchHas) and ctx.vars)
                or (isinstance(ctx, uni.DictVal) and ctx.kv_pairs)
                or (isinstance(ctx, uni.ListVal) and ctx.values)
                or (isinstance(ctx, uni.FuncCall) and ctx.params)
            )
        );
        if has_body {
            return self._handle_body_comments(ctx, <>node);
        }
        return doc.Indent(self._process(ctx, <>node.contents), ast_node=ctx);
    } elif isinstance(<>node, doc.IfBreak) {
        return doc.IfBreak(
            self._process(ctx, <>node.break_contents),
            self._process(ctx, <>node.flat_contents)
        );
    } elif isinstance(<>node, doc.Align) {
        return doc.Align(self._process(ctx, <>node.contents), <>node.n);
    }
    return <>node;
}

"""Inject comments using token-level precision."""
impl CommentInjectionPass.transform(ir_in: uni.Module) -> uni.Module {
    self._comments: (CommentStore | None) = None;
    if isinstance(ir_in, uni.Module) {
        self._comments = CommentStore.from_module(ir_in);
    }
    if (not isinstance(ir_in, uni.Module) or not self._comments) {
        return ir_in;
    }
    processed = self._process(ir_in, ir_in.gen.doc_ir);
    leftovers = self._comments.drain_unattached();
    if leftovers {
        for info in leftovers {
            comment_preview = info.token.value[:50];
            if (len(info.token.value) > 50) {
                comment_preview += '...';
            }
            self.log_warning(
                "Comment could not be placed precisely; emitting near the end of the formatted output: "
                f"{comment_preview!r}",
                node_override=info.token
            );
        }
        sink: list[doc.DocType] = [processed];
        self._emit_standalone_comments(
            sink, leftovers, prev_item_line=ir_in.loc.last_line if ir_in.loc else None
        );
        processed = doc.Concat(sink);
    }
    ir_in.gen.doc_ir = self._remove_redundant_lines(processed);
    # Process impl modules (includes .impl.jac and .cl.jac files)
    # Only do this for the main module (not annex modules themselves)
    if ir_in.annexable_by is None {
        for impl_mod in ir_in.impl_mod {
            self.transform(impl_mod);
        }
    }
    return ir_in;
}

"""Return comments we never placed (should be rare)."""
impl CommentStore.drain_unattached -> list[CommentInfo] {
    leftovers: list[CommentInfo] = [];
    for bucket in self._inline.values() {
        for info in bucket {
            if self._mark_used(info) {
                leftovers.append(info);
            }
        }
    }
    for info in self._standalone {
        if self._mark_used(info) {
            leftovers.append(info);
        }
    }
    leftovers.sort(key=lambda c: Any : (c.first_line, c.index));
    return leftovers;
}

"""Drain standalone comments that occur on or after start_line."""
impl CommentStore.take_standalone_after(start_line: int) -> list[CommentInfo] {
    idx = bisect_left(self._standalone_lines, start_line);
    result: list[CommentInfo] = [];
    while (idx < len(self._standalone)) {
        info = self._standalone[idx];
        if self._mark_used(info) {
            result.append(info);
        }
        idx += 1;
    }
    return result;
}

"""Return standalone comments within [start_line, end_line)."""
impl CommentStore.take_standalone_between(
    start_line: int, end_line: int
) -> list[CommentInfo] {
    if (start_line >= end_line) {
        return [];
    }
    idx = bisect_left(self._standalone_lines, start_line);
    result: list[CommentInfo] = [];
    while (idx < len(self._standalone)) {
        info = self._standalone[idx];
        if (info.first_line >= end_line) {
            break;
        }
        if self._mark_used(info) {
            result.append(info);
        }
        idx += 1;
    }
    return result;
}

"""Return inline comments attached to a given token in source order."""
impl CommentStore.take_inline(token_id: int) -> list[CommentInfo] {
    matches = [];
    for info in self._inline.get(token_id, []) {
        if self._mark_used(info) {
            matches.append(info);
        }
    }
    return matches;
}

impl CommentStore._mark_used(info: CommentInfo) -> bool {
    if (info.index in self._used) {
        return False;
    }
    self._used.add(info.index);
    return True;
}

"""Build a comment store by analysing module tokens once."""
impl CommentStore.from_module(module: uni.Module) -> CommentStore {
    items: list[tuple[(str, int, (uni.Token | uni.CommentToken))]] = [];
    for token in module.src_terminals {
        if not isinstance(token, uni.CommentToken) {
            items.append(('token', id(token), token));
        }
    }
    for (idx, comment) in enumerate(module.source.comments) {
        items.append(('comment', idx, comment));
    }
    items.sort(
        key=lambda <>entry: Any : (<>entry[2].loc.first_line, <>entry[2].loc.col_start)
    );
    inline: dict[(int, list[CommentInfo])] = {};
    standalone: list[CommentInfo] = [];
    for (offset, <>entry) in enumerate(items) {
        if (<>entry[0] != 'comment') {
            continue;
        }
        comment_idx = <>entry[1];
        comment_raw = <>entry[2];
        if not isinstance(comment_raw, uni.CommentToken) {
            continue;
        }
        comment = comment_raw;
        left_token = None;
        for i in range((offset - 1), -1, -1) {
            if (items[i][0] == 'token') {
                left_token = items[i][2];
                break;
            }
        }
        anchor_token_id: (int | None) = None;
        if (left_token and (left_token.loc.last_line == comment.loc.first_line)) {
            anchor_token_id = id(left_token);
        }
        info = CommentInfo(comment_idx, comment, anchor_token_id);
        if info.is_inline {
            assert (info.anchor_token_id is not None);
            inline.setdefault(info.anchor_token_id, []).append(info);
        } else {
            standalone.append(info);
        }
    }
    for collection in inline.values() {
        collection.sort(key=lambda c: Any : (c.first_line, c.index));
    }
    standalone.sort(key=lambda c: Any : (c.first_line, c.index));
    return CommentStore(_inline=inline, _standalone=standalone);
}

"""Post-initialization to prepare lookup structures."""
impl CommentStore.postinit -> None {
    self._standalone_lines = [c.first_line for c in self._standalone];
    self._used = set();
}

"""Return the final line this comment occupies."""
impl CommentInfo.last_line -> int {
    return self.token.loc.last_line;
}

"""Return the starting line for quick range comparisons."""
impl CommentInfo.first_line -> int {
    return self.token.loc.first_line;
}

"""Return True when the comment attaches to a token on the same line."""
impl CommentInfo.is_inline -> bool {
    return (self.anchor_token_id is not None);
}
