import from bisect { bisect_left }
import jaclang.jac0core.unitree as uni;
import from jaclang.jac0core.constant { Tokens as Tok }

glob _CLOSING_DELIMS = [Tok.RBRACE, Tok.RPAREN, Tok.RSQUARE],
     _OPENING_DELIMS = [Tok.LBRACE, Tok.LPAREN, Tok.LSQUARE];

impl CommentAttachPass.transform(ir_in: uni.Module) -> uni.Module {
    if not isinstance(ir_in, uni.Module) {
        return ir_in;
    }
    if ir_in.gen.doc_comments is not None {
        return ir_in;
    }
    ir_in.gen.doc_comments = NodeComments();
    comments = ir_in.source.comments if ir_in.source else [];
    if not comments {
        return ir_in;
    }
    tree_tokens: list[uni.Token] = [];
    stack: list[uni.UniNode] = [ir_in];
    while stack {
        nd = stack.pop();
        if isinstance(nd, uni.Token) {
            if (not isinstance(nd, uni.CommentToken)) and (not nd._is_synthetic) {
                tree_tokens.append(nd);
            }
        } else {
            for k in nd.kid {
                if k is not None {
                    stack.append(k);
                }
            }
        }
    }
    decorated = [
        ((t.loc.first_line, t.loc.col_start, idx), t)
        for (idx, t) in enumerate(tree_tokens)
    ];
    decorated.sort();
    starts = [(key[0], key[1]) for (key, _t) in decorated];
    for c in comments {
        cpos = (c.loc.first_line, c.loc.col_start);
        idx = bisect_left(starts, cpos);
        prev_tok = decorated[idx - 1][1] if (idx > 0) else None;
        next_tok = decorated[idx][1] if (idx < len(decorated)) else None;
        if (prev_tok is not None and (prev_tok.loc.last_line == c.loc.first_line)) {
            target = self._largest_ending_at(prev_tok);
            self._node_comments(target).trailing_inline.append(c);
        } elif next_tok is None {
            if prev_tok is not None {
                self._attach_trailing_own(prev_tok, c);
            } else {
                self._node_comments(ir_in).leading.append(c);
            }
        } else {
            lead_target = self._largest_starting_at(next_tok);
            if (
                isinstance(lead_target, uni.Token)
                and (lead_target.name in _CLOSING_DELIMS)
                and (prev_tok is not None)
            ) {
                self._attach_trailing_own(prev_tok, c);
            } else {
                self._node_comments(lead_target).leading.append(c);
            }
        }
    }
    return ir_in;
}

impl CommentAttachPass._node_comments(nd: uni.UniNode) -> NodeComments {
    if nd.gen.doc_comments is None {
        nd.gen.doc_comments = NodeComments();
    }
    return nd.gen.doc_comments;
}

impl CommentAttachPass._attach_trailing_own(
    tok: uni.Token, comment: uni.CommentToken
) -> None {
    target = self._largest_ending_at(tok);
    nc = self._node_comments(target);
    nc.trailing_own.append(comment);
    if (isinstance(target, uni.Token) and (target.name in _OPENING_DELIMS)) {
        nc.indent_trailing_own = True;
    }
}

impl CommentAttachPass._largest_ending_at(tok: uni.Token) -> uni.UniNode {
    target: uni.UniNode = tok;
    cur = tok.parent;
    while (
        cur is not None
        and (not isinstance(cur, uni.Module))
        and (cur.loc.last_line == tok.loc.last_line)
        and (cur.loc.col_end == tok.loc.col_end)
    ) {
        target = cur;
        cur = cur.parent;
    }
    return target;
}

impl CommentAttachPass._largest_starting_at(tok: uni.Token) -> uni.UniNode {
    target: uni.UniNode = tok;
    cur = tok.parent;
    while (
        cur is not None
        and (not isinstance(cur, uni.Module))
        and (cur.loc.first_line == tok.loc.first_line)
        and (cur.loc.col_start == tok.loc.col_start)
    ) {
        target = cur;
        cur = cur.parent;
    }
    return target;
}
