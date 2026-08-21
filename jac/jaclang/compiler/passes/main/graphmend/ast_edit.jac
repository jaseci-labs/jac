import jaclang.jac0core.unitree as uni;
import from jaclang.jac0core.codeinfo { GraphMendFacts }
import from jaclang.jac0core.constant { GraphMendHelper }

def facts_for(nd: uni.UniNode) -> GraphMendFacts {
    mod: (uni.Module | None) = None;
    if isinstance(nd, uni.Module) {
        mod = nd;
    } else {
        mod = nd.find_parent_of_type(uni.Module);
    }
    if mod is None {
        return GraphMendFacts();
    }
    facts = mod.gen.graphmend_facts;
    if facts is None {
        facts = GraphMendFacts();
        mod.gen.graphmend_facts = facts;
    }
    return facts;
}

def gen_name(at: uni.UniNode, value: str, store: bool) -> uni.Name {
    anchor: any = at;
    nm = uni.Name.gen_stub_from_node(anchor, value);
    if store {
        nm.expr_ctx = uni.ExprCtx.STORE;
    }
    return nm;
}

def gen_string(at: uni.UniNode, value: str) -> uni.String {
    return uni.String(
        orig_src=at.loc.orig_src,
        name='STRING',
        value=value,
        line=at.loc.first_line,
        end_line=at.loc.last_line,
        col_start=at.loc.col_start,
        col_end=at.loc.col_end,
        pos_start=at.loc.pos_start,
        pos_end=at.loc.pos_end
    );
}

def gen_bool(at: uni.UniNode, value: bool) -> uni.Bool {
    return uni.Bool(
        orig_src=at.loc.orig_src,
        name='BOOL',
        value='True' if value else 'False',
        line=at.loc.first_line,
        end_line=at.loc.last_line,
        col_start=at.loc.col_start,
        col_end=at.loc.col_end,
        pos_start=at.loc.pos_start,
        pos_end=at.loc.pos_end
    );
}

def need_helper(at: uni.UniNode, helper: GraphMendHelper) {
    facts_for(at).helpers.add(helper);
}

def torch_call(at: uni.UniNode, fname: str, args: list) -> uni.FuncCall {
    torch_nm = gen_name(at, 'torch', False);
    fn_nm = gen_name(at, fname, False);
    target = uni.AtomTrailer(
        target=torch_nm,
        right=fn_nm,
        is_attr=True,
        is_null_ok=False,
        kid=[torch_nm, fn_nm]
    );
    return uni.FuncCall(
        target=target, params=args, genai_call=None, kid=[target] + args
    );
}

def split_params(params: any) -> tuple[list[uni.Expr], list[uni.KWPair]] {
    pos: list[uni.Expr] = [];
    kws: list[uni.KWPair] = [];
    for p in (params or []) {
        if isinstance(p, uni.KWPair) {
            kws.append(p);
        } else {
            pos.append(p);
        }
    }
    return (pos, kws);
}

def split_params_keyed(params: any) -> tuple[list[uni.Expr], dict[str, uni.KWPair]] {
    (pos, kws) = split_params(params);
    keyed: dict[str, uni.KWPair] = {};
    for kw in kws {
        if kw.key is not None {
            keyed[kw.key.sym_name] = kw;
        }
    }
    return (pos, keyed);
}

def stmt_slot(at: uni.UniNode) -> (tuple | None) {
    cur: (uni.UniNode | None) = at;
    while cur is not None {
        parent = cur.parent;
        if parent is None {
            return None;
        }
        holder: any = parent;
        body = holder?.body;
        if isinstance(body, list) {
            return (parent, cur, body)
                if ((cur in body) and (cur in parent.kid))
                else None;
        }
        cur = parent;
    }
    return None;
}

def insert_after(stmt: uni.UniNode, new_stmt: uni.UniNode) -> bool {
    slot = stmt_slot(stmt);
    if slot is None {
        return False;
    }
    (parent, anchor, body) = slot;
    holder: any = parent;
    i = body.index(anchor);
    j = parent.kid.index(anchor);
    setattr(holder, 'body', list(body[:(i + 1)]) + [new_stmt] + list(body[(i + 1):]));
    parent.set_kids(
        list(parent.kid[:(j + 1)]) + [new_stmt] + list(parent.kid[(j + 1):])
    );
    new_stmt.parent = parent;
    return True;
}

def insert_before(stmt: uni.UniNode, new_stmt: uni.UniNode) -> bool {
    slot = stmt_slot(stmt);
    if slot is None {
        return False;
    }
    (parent, anchor, body) = slot;
    holder: any = parent;
    i = body.index(anchor);
    j = parent.kid.index(anchor);
    setattr(holder, 'body', list(body[:i]) + [new_stmt] + list(body[i:]));
    parent.set_kids(list(parent.kid[:j]) + [new_stmt] + list(parent.kid[j:]));
    new_stmt.parent = parent;
    return True;
}

def append_stmt(owner: uni.UniNode, new_stmt: uni.UniNode) -> bool {
    holder: any = owner;
    body = holder?.body;
    if not isinstance(body, list) {
        return False;
    }
    last = body[-1] if body else None;
    setattr(holder, 'body', list(body) + [new_stmt]);
    if (last is not None) and (last in owner.kid) {
        j = owner.kid.index(last);
        owner.set_kids(
            list(owner.kid[:(j + 1)]) + [new_stmt] + list(owner.kid[(j + 1):])
        );
    } else {
        owner.set_kids(list(owner.kid) + [new_stmt]);
    }
    new_stmt.parent = owner;
    return True;
}

def replace_stmt(old: uni.UniNode, new_nodes: list) -> bool {
    parent = old.parent;
    if parent is None {
        return False;
    }
    holder: any = parent;
    body = holder?.body;
    if (not isinstance(body, list)) or (old not in body) or (old not in parent.kid) {
        return False;
    }
    i = body.index(old);
    j = parent.kid.index(old);
    setattr(holder, 'body', list(body[:i]) + new_nodes + list(body[(i + 1):]));
    parent.set_kids(list(parent.kid[:j]) + new_nodes + list(parent.kid[(j + 1):]));
    for child in new_nodes {
        child.parent = parent;
    }
    return True;
}
